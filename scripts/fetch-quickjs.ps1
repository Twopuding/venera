# 拉取 QuickJS 源码供 NAPI 模块编译（bellard/quickjs）
$dest = Join-Path $PSScriptRoot "..\entry\src\main\cpp\third_party\quickjs-ng-temp"
if (Test-Path $dest) {
    Write-Host "QuickJS already exists at $dest"
    exit 0
}
git clone --depth 1 https://github.com/bellard/quickjs.git $dest
if ($LASTEXITCODE -eq 0) {
    Write-Host "QuickJS cloned to $dest"
}
