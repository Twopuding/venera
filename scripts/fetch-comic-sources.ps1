# 拉取 venera-app/venera-configs 自带图源（index.json + 全部 .js），对齐上游默认 comicSourceListUrl
$ErrorActionPreference = "Stop"
$baseUrl = "https://raw.githubusercontent.com/venera-app/venera-configs/main"
$dest = Join-Path $PSScriptRoot "..\entry\src\main\resources\rawfile\comic_sources"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host "Fetching index.json ..."
$indexPath = Join-Path $dest "index.json"
Invoke-WebRequest -Uri "$baseUrl/index.json" -OutFile $indexPath -UseBasicParsing
$index = Get-Content $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json

$count = 0
foreach ($entry in $index) {
    $fileName = $entry.fileName
    if (-not $fileName) { continue }
    $out = Join-Path $dest $fileName
  if ((Test-Path $out) -and ((Get-Item $out).Length -gt 0)) {
        Write-Host "  skip $fileName (exists)"
        continue
    }
    Write-Host "  fetch $fileName ..."
    Invoke-WebRequest -Uri "$baseUrl/$fileName" -OutFile $out -UseBasicParsing
    $count++
}
Write-Host "Done. New downloads: $count. Output: $dest"
