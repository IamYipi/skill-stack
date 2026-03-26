import argparse
import json
import sys
from pathlib import Path

import requests

CONFIG_DIR = Path.home() / ".claude" / "skills" / "jira"
CONFIG_FILE = CONFIG_DIR / "config.json"
SEARCH_ENDPOINT = "/rest/api/2/search"


def load_config() -> dict:
    if CONFIG_FILE.exists():
        try:
            return json.loads(CONFIG_FILE.read_text())
        except (json.JSONDecodeError, OSError):
            return {}
    return {}


def save_config(config: dict) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_FILE.write_text(json.dumps(config, indent=2))
    CONFIG_FILE.chmod(0o600)


def normalize_url(url: str) -> str:
    cleaned = url.strip().rstrip("/")
    if not cleaned.startswith(("http://", "https://")):
        raise ValueError("La URL debe empezar por http:// o https://")
    return cleaned


def get_or_prompt_config_value(config: dict, key: str, prompt: str, normalizer=None) -> str:
    current = str(config.get(key, "")).strip()
    if current:
        return normalizer(current) if normalizer else current

    print(f"No se encontró '{key}' en {CONFIG_FILE}")
    value = input(prompt).strip()
    if not value:
        print(f"Error: '{key}' no puede estar vacío.", file=sys.stderr)
        sys.exit(1)

    value = normalizer(value) if normalizer else value
    config[key] = value
    save_config(config)
    print(f"'{key}' guardado en {CONFIG_FILE}\n")
    return value


def parse_args():
    parser = argparse.ArgumentParser(description="Consulta issues de Jira")
    parser.add_argument("-p", "--project", help="Clave de proyecto, por ejemplo: DATAPLAT")
    parser.add_argument("-s", "--search", help="Búsqueda de texto libre")
    parser.add_argument("--sprint", help="Nombre o ID de sprint")
    parser.add_argument("-o", "--open-only", action="store_true", help="Solo issues abiertas")
    parser.add_argument("-m", "--max-results", type=int, default=10, help="Máximo de resultados")
    parser.add_argument("--all", action="store_true", help="Traer todos los resultados (paginado)")
    parser.add_argument("--include-description", action="store_true", help="Incluir description")
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


def extract_description(fields: dict) -> str:
    description = fields.get("description")
    if description is None:
        return "No description"
    if isinstance(description, str):
        return " ".join(description.split()) or "No description"
    return str(description)


def compress_text(value) -> str:
    return " ".join(str(value).split()).replace("|", "/")


def print_issues(payload: dict, compact: bool = False, include_description: bool = False) -> None:
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
                description = compress_text(extract_description(fields))
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
            print(f"Description: {extract_description(fields)}")


def print_error_response(response: requests.Response) -> None:
    print(f"HTTP {response.status_code}", file=sys.stderr)
    content_type = response.headers.get("Content-Type", "")
    if "application/json" in content_type.lower():
        try:
            print(response.json(), file=sys.stderr)
            return
        except requests.exceptions.JSONDecodeError:
            pass
    text = response.text.strip()
    print(text[:1200] if text else "Empty response", file=sys.stderr)


def parse_json_response(response: requests.Response) -> dict:
    content_type = response.headers.get("Content-Type", "")
    if "application/json" not in content_type.lower():
        snippet = response.text.strip()[:200]
        raise ValueError(
            "La respuesta no es JSON. Revisa URL/token. "
            f"Content-Type recibido: {content_type}. Primeros caracteres: {snippet}"
        )
    return response.json()


def fetch_issues(args, jira_url: str, headers: dict):
    jql = build_jql(args)
    fields = ["summary", "status", "project"]
    if args.include_description:
        fields.append("description")

    base_params = {"jql": jql, "fields": ",".join(fields)}
    endpoint = f"{jira_url}{SEARCH_ENDPOINT}"

    if not args.all:
        return requests.get(
            endpoint,
            params={**base_params, "maxResults": args.max_results},
            timeout=30,
            headers=headers,
        )

    start_at, batch_size, issues, total = 0, 100, [], None
    while total is None or start_at < total:
        response = requests.get(
            endpoint,
            params={**base_params, "startAt": start_at, "maxResults": batch_size},
            timeout=30,
            headers=headers,
        )
        if not response.ok:
            return response

        payload = parse_json_response(response)
        batch = payload.get("issues", [])
        issues.extend(batch)
        total = payload.get("total", len(batch))
        if not batch:
            break
        start_at += len(batch)

    return {"issues": issues, "total": total or len(issues)}


def main():
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

    try:
        token = get_or_prompt_config_value(config, "token", "Introduce tu PAT token de Jira: ")
        jira_url = get_or_prompt_config_value(
            config,
            "url",
            "Introduce la URL de Jira (ej. https://jira.tuempresa.com): ",
            normalizer=normalize_url,
        )
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    headers = {"Accept": "application/json", "Authorization": f"Bearer {token}"}

    try:
        result = fetch_issues(args, jira_url, headers)
    except requests.RequestException as exc:
        print(f"Error de red: {exc}", file=sys.stderr)
        sys.exit(1)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    if isinstance(result, requests.Response):
        if not result.ok:
            print_error_response(result)
            sys.exit(1)
        try:
            result = parse_json_response(result)
        except ValueError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            sys.exit(1)

    print_issues(result, compact=args.all, include_description=args.include_description)


if __name__ == "__main__":
    main()
