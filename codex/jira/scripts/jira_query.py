#!/usr/bin/env python3
import argparse
import base64
import getpass
import json
import os
import sys
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


CONFIG_DIR = Path.home() / ".codex" / "skills" / "jira"
CONFIG_FILE = CONFIG_DIR / "config.json"
SEARCH_ENDPOINT = "/rest/api/2/search"
DEFAULT_TIMEOUT = 30


def load_config() -> dict[str, Any]:
    if not CONFIG_FILE.exists():
        return {}
    try:
        return json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}


def save_config(config: dict[str, Any]) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_FILE.write_text(json.dumps(config, indent=2), encoding="utf-8")
    try:
        CONFIG_FILE.chmod(0o600)
    except OSError:
        # Best-effort only. Windows may ignore POSIX modes.
        pass


def normalize_url(url: str) -> str:
    cleaned = url.strip().rstrip("/")
    if not cleaned.startswith(("http://", "https://")):
        raise ValueError("La URL debe empezar por http:// o https://")
    return cleaned


def compress_text(value: Any) -> str:
    return " ".join(str(value).split()).replace("|", "/")


def extract_description(value: Any) -> str:
    if value is None:
        return "No description"
    if isinstance(value, str):
        return " ".join(value.split()) or "No description"
    if isinstance(value, dict):
        parts: list[str] = []
        if "text" in value and isinstance(value["text"], str):
            parts.append(value["text"])
        for item in value.get("content", []) if isinstance(value.get("content"), list) else []:
            extracted = extract_description(item)
            if extracted != "No description":
                parts.append(extracted)
        text = " ".join(part for part in parts if part).strip()
        return " ".join(text.split()) if text else "No description"
    if isinstance(value, list):
        parts = [extract_description(item) for item in value]
        text = " ".join(part for part in parts if part != "No description").strip()
        return " ".join(text.split()) if text else "No description"
    return compress_text(value) or "No description"


def get_or_prompt_config_value(
    *,
    config: dict[str, Any],
    env_name: str,
    cli_value: str | None,
    config_key: str,
    prompt: str,
    normalizer=None,
    secret: bool = False,
) -> str:
    env_value = str(os.getenv(env_name, "")).strip()
    if env_value:
        return normalizer(env_value) if normalizer else env_value

    if cli_value:
        return normalizer(cli_value) if normalizer else cli_value

    current = str(config.get(config_key, "")).strip()
    if current:
        return normalizer(current) if normalizer else current

    print(f"No se encontró '{config_key}' en {CONFIG_FILE}")
    value = getpass.getpass(prompt) if secret else input(prompt).strip()
    if not value:
        print(f"Error: '{config_key}' no puede estar vacío.", file=sys.stderr)
        sys.exit(1)

    value = normalizer(value) if normalizer else value
    config[config_key] = value
    save_config(config)
    print(f"'{config_key}' guardado en {CONFIG_FILE}\n")
    return value


def parse_args():
    parser = argparse.ArgumentParser(description="Consulta issues de Jira")
    parser.add_argument("-p", "--project", help="Clave de proyecto, por ejemplo: SIEM")
    parser.add_argument("-s", "--search", help="Búsqueda de texto libre")
    parser.add_argument("--sprint", help="Nombre o ID de sprint")
    parser.add_argument("-o", "--open-only", action="store_true", help="Solo issues abiertas")
    parser.add_argument("-m", "--max-results", type=int, default=10, help="Máximo de resultados")
    parser.add_argument("--all", action="store_true", help="Traer todos los resultados paginando")
    parser.add_argument("--include-description", action="store_true", help="Incluir description")
    parser.add_argument("--token", help="Token Jira para esta ejecución")
    parser.add_argument("--url", help="URL Jira para esta ejecución")
    parser.add_argument(
        "--auth-mode",
        choices=("bearer", "basic"),
        help="Modo de autenticación para esta ejecución",
    )
    parser.add_argument("--user", help="Usuario Jira para basic auth en esta ejecución")
    parser.add_argument("--reset-token", action="store_true", help="Borrar token guardado")
    parser.add_argument("--reset-url", action="store_true", help="Borrar URL guardada")
    return parser.parse_args()


def escape_jql_value(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def build_jql(args) -> str:
    clauses = []
    if args.project:
        clauses.append(f'project = "{escape_jql_value(args.project)}"')
    if args.sprint:
        clauses.append(f'sprint = "{escape_jql_value(args.sprint)}"')
    if args.search:
        clauses.append(f'text ~ "{escape_jql_value(args.search)}"')
    if args.open_only:
        clauses.append("statusCategory != Done")
    return (" AND ".join(clauses) + " ORDER BY updated DESC") if clauses else "ORDER BY updated DESC"


def build_headers(*, token: str, auth_mode: str, user: str | None) -> dict[str, str]:
    headers = {"Accept": "application/json"}
    if auth_mode == "basic":
        if not user:
            raise ValueError("JIRA_USER o --user es obligatorio cuando auth_mode=basic")
        encoded = base64.b64encode(f"{user}:{token}".encode("utf-8")).decode("ascii")
        headers["Authorization"] = f"Basic {encoded}"
    else:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def parse_json_response(*, headers, body: bytes) -> dict[str, Any]:
    content_type = headers.get("Content-Type", "")
    text_body = body.decode("utf-8", errors="replace")
    if "application/json" not in content_type.lower():
        snippet = text_body.strip()[:200]
        raise ValueError(
            "La respuesta no es JSON. Revisa URL/token. "
            f"Content-Type recibido: {content_type}. Primeros caracteres: {snippet}"
        )
    return json.loads(text_body)


def print_error_response(exc: HTTPError) -> None:
    print(f"HTTP {exc.code}", file=sys.stderr)
    body = exc.read().decode("utf-8", errors="replace")
    content_type = exc.headers.get("Content-Type", "")
    if "application/json" in content_type.lower():
        try:
            print(json.loads(body), file=sys.stderr)
            return
        except json.JSONDecodeError:
            pass
    print(body[:1200] if body else "Empty response", file=sys.stderr)


def fetch_json(*, url: str, params: dict[str, Any], headers: dict[str, str]) -> dict[str, Any]:
    query = urlencode(params, doseq=True)
    request = Request(f"{url}?{query}", headers=headers, method="GET")
    with urlopen(request, timeout=DEFAULT_TIMEOUT) as response:
        return parse_json_response(headers=response.headers, body=response.read())


def fetch_issues(args, jira_url: str, headers: dict[str, str]) -> dict[str, Any]:
    jql = build_jql(args)
    fields = ["summary", "status", "project"]
    if args.include_description:
        fields.append("description")

    base_params = {"jql": jql, "fields": ",".join(fields)}
    endpoint = f"{jira_url}{SEARCH_ENDPOINT}"

    if not args.all:
        return fetch_json(
            url=endpoint,
            params={**base_params, "maxResults": args.max_results},
            headers=headers,
        )

    start_at = 0
    batch_size = 100
    issues: list[dict[str, Any]] = []
    total: int | None = None

    while total is None or start_at < total:
        payload = fetch_json(
            url=endpoint,
            params={**base_params, "startAt": start_at, "maxResults": batch_size},
            headers=headers,
        )
        batch = payload.get("issues", [])
        issues.extend(batch)
        total = int(payload.get("total", len(batch)))
        if not batch:
            break
        start_at += len(batch)

    return {"issues": issues, "total": total or len(issues)}


def print_issues(payload: dict[str, Any], *, compact: bool = False, include_description: bool = False) -> None:
    issues = payload.get("issues", [])
    total = payload.get("total", len(issues))

    if not issues:
        print(f"META|total={total}|showing=0")
        print("No se encontraron issues con ese filtro.")
        return

    if compact:
        print(f"META|total={total}|showing={len(issues)}|format=llm-compact")
        print("FIELDS|key|summary" + ("|description" if include_description else ""))
        for issue in issues:
            fields = issue.get("fields", {})
            code = compress_text(issue.get("key", "No key"))
            summary = compress_text(fields.get("summary") or "No summary")
            if include_description:
                description = compress_text(extract_description(fields.get("description")))
                print(f"ISSUE|{code}|{summary}|{description}")
            else:
                print(f"ISSUE|{code}|{summary}")
        return

    print(f"Total encontrados: {total}\nMostrando: {len(issues)}")
    for idx, issue in enumerate(issues, 1):
        fields = issue.get("fields", {})
        print(f"\nIssue {idx}")
        print(f"Summary: {fields.get('summary') or 'No summary'}")
        print(f"Key: {issue.get('key', 'No key')}")
        if include_description:
            print(f"Description: {extract_description(fields.get('description'))}")


def main() -> None:
    args = parse_args()
    config = load_config()

    if args.reset_token:
        config.pop("token", None)
        if config:
            save_config(config)
        elif CONFIG_FILE.exists():
            CONFIG_FILE.unlink()
        print("Token eliminado. Se pedirá de nuevo en la próxima ejecución.")
        sys.exit(0)

    if args.reset_url:
        config.pop("url", None)
        if config:
            save_config(config)
        elif CONFIG_FILE.exists():
            CONFIG_FILE.unlink()
        print("URL eliminada. Se pedirá de nuevo en la próxima ejecución.")
        sys.exit(0)

    auth_mode = (
        (args.auth_mode or os.getenv("JIRA_AUTH_MODE") or str(config.get("auth_mode", "")).strip() or "bearer")
        .strip()
        .lower()
    )
    if auth_mode not in {"bearer", "basic"}:
        print("Error: JIRA_AUTH_MODE debe ser 'bearer' o 'basic'.", file=sys.stderr)
        sys.exit(1)

    user = (args.user or os.getenv("JIRA_USER") or str(config.get("user", "")).strip() or None)

    try:
        token = get_or_prompt_config_value(
            config=config,
            env_name="JIRA_TOKEN",
            cli_value=args.token,
            config_key="token",
            prompt="Introduce tu PAT token de Jira: ",
            secret=True,
        )
        jira_url = get_or_prompt_config_value(
            config=config,
            env_name="JIRA_URL",
            cli_value=args.url,
            config_key="url",
            prompt="Introduce la URL de Jira (ej. https://jira.tuempresa.com): ",
            normalizer=normalize_url,
        )
        headers = build_headers(token=token, auth_mode=auth_mode, user=user)
        result = fetch_issues(args, jira_url, headers)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
    except HTTPError as exc:
        print_error_response(exc)
        sys.exit(1)
    except URLError as exc:
        print(f"Error de red: {exc}", file=sys.stderr)
        sys.exit(1)

    print_issues(
        result,
        compact=args.all,
        include_description=args.include_description,
    )


if __name__ == "__main__":
    main()
