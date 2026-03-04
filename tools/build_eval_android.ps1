$ErrorActionPreference = "Stop"

Write-Host "== Marine Safe: evaluator APK build ==" -ForegroundColor Cyan

Write-Host "Flutter version:" -ForegroundColor Yellow
flutter --version

Write-Host "`nCleaning..." -ForegroundColor Yellow
flutter clean

Write-Host "`nGetting packages..." -ForegroundColor Yellow
flutter pub get

Write-Host "`nBuilding release APK..." -ForegroundColor Yellow
# IMPORTANT: Android won't install an "update" unless versionCode increases.
# Use a timestamp-based build number that stays under 32-bit int.
$buildNumber = [int](Get-Date -Format "yyMMddHH")  # e.g. 26020317
Write-Host "Build number (versionCode): $buildNumber" -ForegroundColor Yellow
flutter build apk --release --build-number $buildNumber

$apk = Join-Path $PSScriptRoot "..\build\app\outputs\flutter-apk\app-release.apk"
$apk = (Resolve-Path $apk).Path

Write-Host "`nRelease APK:" -ForegroundColor Green
Write-Host $apk

# Copy to dist/ with a timestamped name for easy sharing
$distDir = Join-Path $PSScriptRoot "..\dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

$ts = Get-Date -Format "yyyyMMdd-HHmm"
$out = Join-Path $distDir "marine-safe-eval-$ts.apk"
Copy-Item -Force -Path $apk -Destination $out

Write-Host "`nCopied to:" -ForegroundColor Green
Write-Host (Resolve-Path $out).Path

Write-Host "`nDone." -ForegroundColor Cyan

