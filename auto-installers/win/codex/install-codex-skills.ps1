[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..\..\..\codex'),
    [string]$DestinationRoot = (Join-Path $env:USERPROFILE '.codex\skills')
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

if (-not $env:USERPROFILE) {
    throw 'No se pudo resolver USERPROFILE para construir la ruta destino de Codex.'
}

$resolvedSourceRoot = Resolve-AbsolutePath -Path $SourceRoot
$resolvedDestinationRoot = Resolve-AbsolutePath -Path $DestinationRoot

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
Write-Host ''
Write-Host "Destino: $resolvedDestinationRoot"
