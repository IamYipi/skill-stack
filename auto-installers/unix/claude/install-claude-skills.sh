#!/usr/bin/env bash
# =============================================================================
# install-claude-skills.sh
# Instala las skills de Claude y registra el contenido de CLAUDE.md
# en el directorio .claude del usuario (o en la ruta que se indique).
#
# Uso:
#   ./install-claude-skills.sh                  # modo interactivo
#   ./install-claude-skills.sh /ruta/personalizada/.claude
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CLAUDE_SOURCE="$REPO_ROOT/claude"

DEFAULT_CLAUDE_DIR="$HOME/.claude"

echo "=========================================="
echo "   Instalador de Claude Skills            "
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Determinar directorio destino
# ---------------------------------------------------------------------------
if [[ -n "${1:-}" ]]; then
    CLAUDE_DIR="$1"
    # Expandir ~ si el usuario la usa como primer argumento
    CLAUDE_DIR="${CLAUDE_DIR/#\~/$HOME}"
    echo "Directorio destino (argumento): $CLAUDE_DIR"
else
    echo "Directorio base donde instalar las skills de Claude."
    echo "  [1] Carpeta personal del usuario: $DEFAULT_CLAUDE_DIR  (por defecto)"
    echo "  [2] Indicar ruta personalizada"
    echo ""
    read -rp "Selecciona una opción [1/2, Enter = 1]: " OPTION
    OPTION="${OPTION:-1}"

    if [[ "$OPTION" == "2" ]]; then
        read -rp "Introduce la ruta completa del directorio .claude: " CLAUDE_DIR
        CLAUDE_DIR="${CLAUDE_DIR/#\~/$HOME}"
        if [[ -z "$CLAUDE_DIR" ]]; then
            echo "Error: no se introdujo ninguna ruta." >&2
            exit 1
        fi
    else
        CLAUDE_DIR="$DEFAULT_CLAUDE_DIR"
    fi
fi

SKILLS_DIR="$CLAUDE_DIR/skills"

echo ""
echo "Destino de skills : $SKILLS_DIR"
echo "Destino CLAUDE.md : $CLAUDE_DIR/CLAUDE.md"
echo ""

# ---------------------------------------------------------------------------
# Verificar que existe el directorio fuente
# ---------------------------------------------------------------------------
if [[ ! -d "$CLAUDE_SOURCE" ]]; then
    echo "Error: no se encontró el directorio de skills en $CLAUDE_SOURCE" >&2
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
done < <(find "$CLAUDE_SOURCE" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

echo ""
if [[ $installed -eq 0 ]]; then
    echo "Advertencia: no se encontraron skills con SKILL.md en $CLAUDE_SOURCE"
else
    echo "Skills instaladas: $installed"
fi

# ---------------------------------------------------------------------------
# Añadir contenido de CLAUDE.md al fichero destino
# ---------------------------------------------------------------------------
CLAUDE_MD_SOURCE="$CLAUDE_SOURCE/CLAUDE.md"
CLAUDE_MD_DEST="$CLAUDE_DIR/CLAUDE.md"

if [[ -f "$CLAUDE_MD_SOURCE" ]]; then
    echo ""
    FIRST_LINE="$(head -1 "$CLAUDE_MD_SOURCE")"

    if [[ -f "$CLAUDE_MD_DEST" ]]; then
        if grep -qF "$FIRST_LINE" "$CLAUDE_MD_DEST" 2>/dev/null; then
            echo "El contenido de CLAUDE.md ya está presente en $CLAUDE_MD_DEST — sin cambios."
        else
            printf '\n' >> "$CLAUDE_MD_DEST"
            cat "$CLAUDE_MD_SOURCE" >> "$CLAUDE_MD_DEST"
            echo "Contenido de CLAUDE.md añadido al final de $CLAUDE_MD_DEST"
        fi
    else
        cp "$CLAUDE_MD_SOURCE" "$CLAUDE_MD_DEST"
        echo "Creado $CLAUDE_MD_DEST"
    fi
else
    echo "Advertencia: no se encontró CLAUDE.md en $CLAUDE_SOURCE"
fi

echo ""
echo "=========================================="
echo "  Instalación completada."
echo "  Directorio .claude: $CLAUDE_DIR"
echo "=========================================="
