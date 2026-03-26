# skill-stack

Repositorio centralizado de skills reutilizables para agentes de IA. Contiene dos bloques independientes:

- **Claude skills** — instrucciones modulares y scripts para Claude (Anthropic). Se instalan bajo `~/.claude/skills/` y su prompt operativo se añade a `~/.claude/CLAUDE.md`.
- **Codex skills** — skills estructuradas con contrato `SKILL.md` para OpenAI Codex. Se instalan bajo `~/.codex/skills/`.

Cada skill es un directorio autónomo con su propio `SKILL.md` que define capacidades, contexto y recursos reusables, convirtiendo al agente en una herramienta especializada para esa tarea.

---

## Estructura del repositorio

```
skill-stack/
├── claude/                         # Skills para Claude
│   ├── CLAUDE.md                   # Prompt operativo global
│   ├── */                          # Skills individuales (cada una en su propio directorio)
│  
│
├── codex/                          # Skills para Codex
│   ├── AGENTS.md                   # Prompt operativo global
│   └── */                          # Skills individuales (cada una en su propio directorio)
│
└── auto-installers/
    ├── unix/
    │   ├── claude/
    │   │   └── install-claude-skills.sh    # Instala skills Claude en Unix/macOS
    │   └── codex/
    │       └── install-codex-skills.sh     # Instala skills Codex en Unix/macOS
    └── win/
        ├── claude/
        │   ├── install-claude-skills.ps1   # Instala skills Claude en Windows
        │   └── install-claude-skills.bat   # Lanzador de doble clic
        └── codex/
            ├── install-codex-skills.ps1    # Instala skills Codex en Windows
            └── install-codex-skills.bat    # Lanzador de doble clic
```

---

## Instalación rápida

### Unix / macOS

**Claude:**
```bash
chmod +x auto-installers/unix/claude/install-claude-skills.sh
./auto-installers/unix/claude/install-claude-skills.sh
```

**Codex:**
```bash
chmod +x auto-installers/unix/codex/install-codex-skills.sh
./auto-installers/unix/codex/install-codex-skills.sh
```

Ambos scripts son **interactivos**: preguntan si quieres instalar en la carpeta personal del usuario (`~/.claude` o `~/.codex`) o en una ruta personalizada (por ejemplo, un directorio de proyecto). También puedes pasar la ruta directamente como argumento:

```bash
./install-claude-skills.sh /ruta/de/proyecto/.claude
./install-codex-skills.sh  /ruta/de/proyecto/.codex
```

---

### Windows

**Doble clic** sobre el `.bat` correspondiente:
- `auto-installers\win\claude\install-claude-skills.bat`
- `auto-installers\win\codex\install-codex-skills.bat`

O desde PowerShell para controlar la ruta de instalación:

```powershell
# Instalación interactiva (te pregunta dónde)
.\auto-installers\win\claude\install-claude-skills.ps1

# Instalación en ruta personalizada
.\auto-installers\win\claude\install-claude-skills.ps1 -ClaudeDir "C:\proyectos\mi-proyecto\.claude"
.\auto-installers\win\codex\install-codex-skills.ps1  -DestinationRoot "C:\proyectos\mi-proyecto\.codex\skills"
```

> Si la política de ejecución de PowerShell lo requiere, ejecuta primero:
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

---

## ¿Qué hace el instalador?

| Acción | Claude | Codex |
|--------|--------|-------|
| Copia los directorios de skills | `~/.claude/skills/<skill>` | `~/.codex/skills/<skill>` |
| Actualiza el prompt global | Añade `CLAUDE.md` a `~/.claude/CLAUDE.md` (sin duplicar) | — |
| Sobreescribe instalaciones previas | Sí (copia limpia) | Sí (copia limpia) |

---

## Requisitos

- **Unix/macOS:** bash 4+, coreutils estándar.
- **Windows:** PowerShell 5.1 o superior (incluido en Windows 10/11).
- No se requieren dependencias externas ni permisos de administrador.

---

## Licencia

MIT — ver [LICENSE](LICENSE).  