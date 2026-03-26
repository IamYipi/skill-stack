[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..\..\..\claude'),
    [string]$ClaudeDir  = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Resolve-AbsolutePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Copy-SkillDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath | Out-Null
    }

    $items = Get-ChildItem -LiteralPath $SourcePath -Recurse -Force
    foreach ($item in $items) {
        $relativePath = $item.FullName.Substring($SourcePath.Length).TrimStart('\\', '/')
        $targetPath   = Join-Path $DestinationPath $relativePath

        if ($item.PSIsContainer) {
            if (-not (Test-Path -LiteralPath $targetPath)) {
                New-Item -ItemType Directory -Path $targetPath | Out-Null
            }
            continue
        }

        $targetDirectory = Split-Path -Path $targetPath -Parent
        if (-not (Test-Path -LiteralPath $targetDirectory)) {
            New-Item -ItemType Directory -Path $targetDirectory | Out-Null
        }

        if ($PSCmdlet.ShouldProcess($targetPath, 'Copy file')) {
            Copy-Item -LiteralPath $item.FullName -Destination $targetPath -Force
        }
    }
}

# ---------------------------------------------------------------------------
# Determinar directorio destino .claude
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '=========================================='
Write-Host '   Instalador de Claude Skills (Windows)  '
Write-Host '=========================================='
Write-Host ''

$defaultClaudeDir = Join-Path $env:USERPROFILE '.claude'

if ($ClaudeDir -eq '') {
    Write-Host "Directorio base donde instalar las skills de Claude."
    Write-Host "  [1] Carpeta personal del usuario: $defaultClaudeDir  (por defecto)"
    Write-Host "  [2] Indicar ruta personalizada"
    Write-Host ''
    $option = Read-Host "Selecciona una opcion [1/2, Enter = 1]"
    if ($option -eq '' -or $option -eq '1') {
        $ClaudeDir = $defaultClaudeDir
    } else {
        $ClaudeDir = Read-Host "Introduce la ruta completa del directorio .claude"
        if ($ClaudeDir -eq '') {
            throw 'No se introdujo ninguna ruta.'
        }
    }
}

$resolvedSourceRoot = Resolve-AbsolutePath -Path $SourceRoot
$resolvedClaudeDir  = Resolve-AbsolutePath -Path $ClaudeDir
$resolvedSkillsDir  = Join-Path $resolvedClaudeDir 'skills'

Write-Host ''
Write-Host "Destino de skills : $resolvedSkillsDir"
Write-Host "Destino CLAUDE.md : $(Join-Path $resolvedClaudeDir 'CLAUDE.md')"
Write-Host ''

# ---------------------------------------------------------------------------
# Validar directorio fuente
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $resolvedSourceRoot)) {
    throw "No existe el directorio de skills de origen: $resolvedSourceRoot"
}

# ---------------------------------------------------------------------------
# Crear directorio destino si no existe
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $resolvedSkillsDir)) {
    New-Item -ItemType Directory -Path $resolvedSkillsDir -Force | Out-Null
}

# ---------------------------------------------------------------------------
# Copiar directorios de skills (los que contengan SKILL.md)
# ---------------------------------------------------------------------------
$skillDirectories = Get-ChildItem -LiteralPath $resolvedSourceRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
    Sort-Object -Property Name

if (-not $skillDirectories) {
    Write-Warning "No se encontraron skills con SKILL.md en: $resolvedSourceRoot"
} else {
    $installedSkillNames = New-Object System.Collections.Generic.List[string]

    foreach ($skillDirectory in $skillDirectories) {
        $destinationSkillPath = Join-Path $resolvedSkillsDir $skillDirectory.Name

        if ($PSCmdlet.ShouldProcess($destinationSkillPath, 'Install skill')) {
            # Eliminar destino previo para garantizar copia limpia
            if (Test-Path -LiteralPath $destinationSkillPath) {
                Remove-Item -LiteralPath $destinationSkillPath -Recurse -Force
            }
            Copy-SkillDirectory -SourcePath $skillDirectory.FullName -DestinationPath $destinationSkillPath
        }

        $installedSkillNames.Add($skillDirectory.Name) | Out-Null
        Write-Host "Instalada skill: $($skillDirectory.Name)  ->  $destinationSkillPath"
    }

    Write-Host ''
    Write-Host "Skills instaladas: $($installedSkillNames.Count)"
    Write-Host ($installedSkillNames -join [Environment]::NewLine)
}

# ---------------------------------------------------------------------------
# Añadir contenido de CLAUDE.md al fichero destino
# ---------------------------------------------------------------------------
$claudeMdSource = Join-Path $resolvedSourceRoot 'CLAUDE.md'
$claudeMdDest   = Join-Path $resolvedClaudeDir  'CLAUDE.md'

if (Test-Path -LiteralPath $claudeMdSource) {
    Write-Host ''
    $sourceContent = Get-Content -LiteralPath $claudeMdSource -Raw
    $firstLine     = (Get-Content -LiteralPath $claudeMdSource -TotalCount 1)

    if (Test-Path -LiteralPath $claudeMdDest) {
        $destContent = Get-Content -LiteralPath $claudeMdDest -Raw
        if ($destContent -like "*$firstLine*") {
            Write-Host "El contenido de CLAUDE.md ya esta presente en $claudeMdDest — sin cambios."
        } else {
            if ($PSCmdlet.ShouldProcess($claudeMdDest, 'Append CLAUDE.md')) {
                Add-Content -LiteralPath $claudeMdDest -Value ''
                Add-Content -LiteralPath $claudeMdDest -Value $sourceContent
                Write-Host "Contenido de CLAUDE.md anadido al final de $claudeMdDest"
            }
        }
    } else {
        if ($PSCmdlet.ShouldProcess($claudeMdDest, 'Create CLAUDE.md')) {
            Copy-Item -LiteralPath $claudeMdSource -Destination $claudeMdDest
            Write-Host "Creado $claudeMdDest"
        }
    }
} else {
    Write-Warning "No se encontro CLAUDE.md en $resolvedSourceRoot"
}

Write-Host ''
Write-Host '=========================================='
Write-Host '  Instalacion completada.'
Write-Host "  Directorio .claude: $resolvedClaudeDir"
Write-Host '=========================================='
