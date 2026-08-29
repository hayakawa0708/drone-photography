[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$buildRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.aws-build'))
$siteRoot = [System.IO.Path]::GetFullPath((Join-Path $buildRoot 'drone-site'))

if (-not $buildRoot.StartsWith($projectRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Build directory escaped the project root.'
}
if ($siteRoot -ne [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.aws-build\drone-site'))) {
    throw 'Unexpected site build path.'
}
if (Test-Path -LiteralPath $buildRoot) {
    Remove-Item -LiteralPath $buildRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $siteRoot -Force | Out-Null

$allowedFiles = @(
    'drone_checker.html',
    'law_status.json',
    'vendor\leaflet\leaflet.css',
    'vendor\leaflet\leaflet.js',
    'vendor\leaflet\images\layers.png',
    'vendor\leaflet\images\layers-2x.png',
    'vendor\leaflet\images\marker-icon.png',
    'vendor\leaflet\images\marker-icon-2x.png',
    'vendor\leaflet\images\marker-shadow.png',
    'vendor\leaflet\LICENSE',
    'vendor\jszip\jszip.min.js',
    'vendor\jszip\LICENSE.markdown'
)

foreach ($relativePath in $allowedFiles) {
    $source = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required release file is missing: $relativePath"
    }
    $destination = Join-Path $siteRoot $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
}

$actualFiles = @(Get-ChildItem -LiteralPath $siteRoot -Recurse -Force -File)
$actualRelative = @($actualFiles | ForEach-Object { $_.FullName.Substring($siteRoot.Length + 1) })
$difference = @(Compare-Object -ReferenceObject $allowedFiles -DifferenceObject $actualRelative)
if ($difference.Count -ne 0) {
    throw 'Release file set does not match the allowlist.'
}

$forbidden = @($actualRelative | Where-Object {
    $_ -match '(?i)(^|\\)(\.git|\.claude|\.aws-build|tests?|data|logs?|venv|\.env)(\\|$)' -or
    $_ -match '(?i)(\.db|\.log|\.pem|\.key|credentials|token)($|\.)'
})
if ($forbidden.Count -ne 0) {
    throw "Forbidden release files: $($forbidden -join ', ')"
}

$html = Get-Content -Raw -Encoding utf8 (Join-Path $siteRoot 'drone_checker.html')
if ($html -match 'unpkg\.com' -or $html -match 'xlsx\.full\.min\.js') {
    throw 'The release still references a third-party script that must not be shipped.'
}

$manifest = @($actualFiles | Sort-Object FullName | ForEach-Object {
    [ordered]@{
        path = $_.FullName.Substring($siteRoot.Length + 1).Replace('\', '/')
        bytes = $_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
})
$manifest | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $buildRoot 'release-manifest.json') -Encoding utf8

Write-Host "Release directory created and verified: $siteRoot"
Write-Host "Files: $($actualFiles.Count)"
