# 拉取 7-Zip LZMA SDK（7z 解压）供 libvenera_qjs 编译
$dest = Join-Path $PSScriptRoot "..\entry\src\main\cpp\third_party\lzma"
if (Test-Path (Join-Path $dest "C\7zDec.c")) {
    Write-Host "LZMA SDK already exists at $dest"
    exit 0
}
$zip = Join-Path $env:TEMP "lzma2301.7z"
$url = "https://www.7-zip.org/a/lzma2301.7z"
Write-Host "Downloading LZMA SDK..."
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
$extract = Join-Path $env:TEMP "lzma2301"
if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
New-Item -ItemType Directory -Force -Path $extract | Out-Null
# 需要本机 7z 解压；若失败请手动解压 lzma2301.7z 到 third_party/lzma
& 7z x $zip "-o$extract" -y 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "7z CLI not found. Extract lzma2301.7z manually to entry/src/main/cpp/third_party/lzma"
    exit 1
}
Copy-Item -Recurse -Force (Join-Path $extract "*") $dest
Write-Host "LZMA SDK installed to $dest"
