#!/usr/bin/env bash
# =============================================================================
# install-codex-skills.sh
# Instala las skills de Codex en el directorio .codex del usuario
# (o en la ruta que se indique).
#
# Uso:
#   ./install-codex-skills.sh                   # modo interactivo
#   ./install-codex-skills.sh /ruta/personalizada/.codex
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CODEX_SOURCE="$REPO_ROOT/codex"

DEFAULT_CODEX_DIR="$HOME/.codex"

echo "=========================================="
echo "   Instalador de Codex Skills             "
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Determinar directorio destino
# ---------------------------------------------------------------------------
if [[ -n "${1:-}" ]]; then
    CODEX_DIR="$1"
    CODEX_DIR="${CODEX_DIR/#\~/$HOME}"
    echo "Directorio destino (argumento): $CODEX_DIR"
else
    echo "Directorio base donde instalar las skills de Codex."
    echo "  [1] Carpeta personal del usuario: $DEFAULT_CODEX_DIR  (por defecto)"
    echo "  [2] Indicar ruta personalizada"
    echo ""
    read -rp "Selecciona una opción [1/2, Enter = 1]: " OPTION
    OPTION="${OPTION:-1}"

    if [[ "$OPTION" == "2" ]]; then
        read -rp "Introduce la ruta completa del directorio .codex: " CODEX_DIR
        CODEX_DIR="${CODEX_DIR/#\~/$HOME}"
        if [[ -z "$CODEX_DIR" ]]; then
            echo "Error: no se introdujo ninguna ruta." >&2
            exit 1
        fi
    else
        CODEX_DIR="$DEFAULT_CODEX_DIR"
    fi
fi

SKILLS_DIR="$CODEX_DIR/skills"

echo ""
echo "Destino: $SKILLS_DIR"
echo ""

# ---------------------------------------------------------------------------
# Verificar que existe el directorio fuente
# ---------------------------------------------------------------------------
if [[ ! -d "$CODEX_SOURCE" ]]; then
    echo "Error: no se encontró el directorio de skills en $CODEX_SOURCE" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Crear directorio destino si no existe
# ---------------------------------------------------------------------------
mkdir -p "$SKILLS_DIR"

# ---------------------------------------------------------------------------
# Copiar directorios de skills (los que contengan SKILL.md)
# ---------------------------------------------------------------------------
installed=0
while IFS= read -r -d '' skill_dir; do
    if [[ -f "$skill_dir/SKILL.md" ]]; then
        skill_name="$(basename "$skill_dir")"
        dest="$SKILLS_DIR/$skill_name"
        echo "Instalando skill: $skill_name  ->  $dest"
        rm -rf "$dest"
        cp -r "$skill_dir" "$dest"
        (( installed++ )) || true
    fi
done < <(find "$CODEX_SOURCE" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

echo ""
if [[ $installed -eq 0 ]]; then
    echo "Advertencia: no se encontraron skills con SKILL.md en $CODEX_SOURCE"
else
    echo "Skills instaladas: $installed"
fi

# ---------------------------------------------------------------------------
# Añadir contenido de AGENTS.md al fichero destino
# ---------------------------------------------------------------------------
AGENTS_MD_SOURCE="$CODEX_SOURCE/AGENTS.md"
AGENTS_MD_DEST="$CODEX_DIR/AGENTS.md"

if [[ -f "$AGENTS_MD_SOURCE" ]]; then
    echo ""
    FIRST_LINE="$(head -1 "$AGENTS_MD_SOURCE")"

    if [[ -f "$AGENTS_MD_DEST" ]]; then
        if grep -qF "$FIRST_LINE" "$AGENTS_MD_DEST" 2>/dev/null; then
            echo "El contenido de AGENTS.md ya está presente en $AGENTS_MD_DEST — sin cambios."
        else
            printf '\n' >> "$AGENTS_MD_DEST"
            cat "$AGENTS_MD_SOURCE" >> "$AGENTS_MD_DEST"
            echo "Contenido de AGENTS.md añadido al final de $AGENTS_MD_DEST"
        fi
    else
        cp "$AGENTS_MD_SOURCE" "$AGENTS_MD_DEST"
        echo "Creado $AGENTS_MD_DEST"
    fi
else
    echo "Advertencia: no se encontró AGENTS.md en $CODEX_SOURCE"
fi

echo ""
echo "=========================================="
echo "  Instalación completada."
echo "  Directorio .codex: $CODEX_DIR"
echo "=========================================="
