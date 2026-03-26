[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SourceRoot       = (Join-Path $PSScriptRoot '..\..\..\codex'),
    [string]$DestinationRoot  = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path)
}

function Copy-SkillDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath | Out-Null
    }

    $items = Get-ChildItem -LiteralPath $SourcePath -Recurse -Force
    foreach ($item in $items) {
        $relativePath = $item.FullName.Substring($SourcePath.Length).TrimStart('\\', '/')
        $targetPath = Join-Path $DestinationPath $relativePath

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
# Determinar directorio destino
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '=========================================='
Write-Host '   Instalador de Codex Skills (Windows)   '
Write-Host '=========================================='
Write-Host ''

if (-not $env:USERPROFILE) {
    throw 'No se pudo resolver USERPROFILE para construir la ruta destino de Codex.'
}

$defaultCodexSkillsDir = Join-Path $env:USERPROFILE '.codex\skills'

if ($DestinationRoot -eq '') {
    Write-Host "Directorio base donde instalar las skills de Codex."
    Write-Host "  [1] Carpeta personal del usuario: $defaultCodexSkillsDir  (por defecto)"
    Write-Host "  [2] Indicar ruta personalizada"
    Write-Host ''
    $option = Read-Host "Selecciona una opcion [1/2, Enter = 1]"
    if ($option -eq '' -or $option -eq '1') {
        $DestinationRoot = $defaultCodexSkillsDir
    } else {
        $DestinationRoot = Read-Host "Introduce la ruta completa del directorio .codex\skills"
        if ($DestinationRoot -eq '') {
            throw 'No se introdujo ninguna ruta.'
        }
    }
}

$resolvedSourceRoot = Resolve-AbsolutePath -Path $SourceRoot
$resolvedDestinationRoot = Resolve-AbsolutePath -Path $DestinationRoot

Write-Host ''
Write-Host "Destino: $resolvedDestinationRoot"
Write-Host ''

if (-not (Test-Path -LiteralPath $resolvedSourceRoot)) {
    throw "No existe el directorio de skills de origen: $resolvedSourceRoot"
}

if (-not (Test-Path -LiteralPath $resolvedDestinationRoot)) {
    New-Item -ItemType Directory -Path $resolvedDestinationRoot -Force | Out-Null
}

$skillDirectories = Get-ChildItem -LiteralPath $resolvedSourceRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
    Sort-Object -Property Name

if (-not $skillDirectories) {
    throw "No se encontraron skills con SKILL.md en: $resolvedSourceRoot"
}

$installedSkillNames = New-Object System.Collections.Generic.List[string]

foreach ($skillDirectory in $skillDirectories) {
    $destinationSkillPath = Join-Path $resolvedDestinationRoot $skillDirectory.Name

    if ($PSCmdlet.ShouldProcess($destinationSkillPath, 'Install skill')) {
        Copy-SkillDirectory -SourcePath $skillDirectory.FullName -DestinationPath $destinationSkillPath
    }

    $installedSkillNames.Add($skillDirectory.Name) | Out-Null
    Write-Host "Instalada skill: $($skillDirectory.Name) -> $destinationSkillPath"
}

Write-Host ''
Write-Host "Skills instaladas: $($installedSkillNames.Count)"
Write-Host ($installedSkillNames -join [Environment]::NewLine)

# ---------------------------------------------------------------------------
# Añadir contenido de AGENTS.md al fichero destino
# ---------------------------------------------------------------------------
$agentsMdSource = Join-Path $resolvedSourceRoot 'AGENTS.md'
$agentsMdDest   = Join-Path (Split-Path $resolvedDestinationRoot -Parent) 'AGENTS.md'

if (Test-Path -LiteralPath $agentsMdSource) {
    Write-Host ''
    $sourceContent = Get-Content -LiteralPath $agentsMdSource -Raw
    $firstLine     = (Get-Content -LiteralPath $agentsMdSource -TotalCount 1)

    if (Test-Path -LiteralPath $agentsMdDest) {
        $destContent = Get-Content -LiteralPath $agentsMdDest -Raw
        if ($destContent -like "*$firstLine*") {
            Write-Host "El contenido de AGENTS.md ya esta presente en $agentsMdDest — sin cambios."
        } else {
            if ($PSCmdlet.ShouldProcess($agentsMdDest, 'Append AGENTS.md')) {
                Add-Content -LiteralPath $agentsMdDest -Value ''
                Add-Content -LiteralPath $agentsMdDest -Value $sourceContent
                Write-Host "Contenido de AGENTS.md anadido al final de $agentsMdDest"
            }
        }
    } else {
        if ($PSCmdlet.ShouldProcess($agentsMdDest, 'Create AGENTS.md')) {
            Copy-Item -LiteralPath $agentsMdSource -Destination $agentsMdDest
            Write-Host "Creado $agentsMdDest"
        }
    }
} else {
    Write-Warning "No se encontro AGENTS.md en $resolvedSourceRoot"
}

Write-Host ''
Write-Host '=========================================='
Write-Host '  Instalacion completada.'
Write-Host "  Directorio .codex: $(Split-Path $resolvedDestinationRoot -Parent)"
Write-Host '=========================================='
