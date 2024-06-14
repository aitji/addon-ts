function New-Guid { [guid]::NewGuid().ToString() }
function Get-Package { param([string]$packageName) ((Get-Content -Raw -Path "package.json" | ConvertFrom-Json).dependencies."$packageName" -replace "-beta.*", "-beta") -replace "\^", "" }
function Setup-Tree { New-Item -ItemType Directory -Path "src" -Force; New-Item -ItemType File -Path "src/index.ts" -Force; Write-Host "Project structure created." -ForegroundColor Green }
function Set-RemoteSigned {
    $currentPolicy = Get-ExecutionPolicy -List | Where-Object { $_.Scope -eq 'CurrentUser' }
    if ($currentPolicy.Policy -eq 'RemoteSigned') { Write-Host "Execution policy is already set." -ForegroundColor Green }
    else { Write-Host "Setting execution policy..." -ForegroundColor Yellow; Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Write-Host "Execution policy set." -ForegroundColor Green }
}

function i-module {
    npm install -g typescript
    npm init -y
    $versionChoice = Read-Host "Choose version (stable/beta)"
    if ($versionChoice -eq "beta") { npm install @minecraft/server@beta; npm install @minecraft/server-ui@beta }
    else { npm install @minecraft/server; npm install @minecraft/server-ui }
}

function gen-manifest {
    $uuid1 = New-Guid; $uuid2 = New-Guid; $uuid3 = New-Guid; $serverVersion = Get-Package -packageName "@minecraft/server"; $serverUiVersion = Get-Package -packageName "@minecraft/server-ui"
    $manifestContent = @"
{"format_version":2,"header":{"name":"typescript project","description":"my typescript project!~","uuid":"$uuid1","version":[0,0,1],"min_engine_version":[1,19,70]},"modules":[{"type":"data","uuid":"$uuid2","version":[1,0,0]},{"type":"script","uuid":"$uuid3","version":[1,0,0],"entry":"scripts/index.js"}],"dependencies":[{"module_name":"@minecraft/server","version":"$serverVersion"},{"module_name":"@minecraft/server-ui","version":"$serverUiVersion"}]}
"@
    Set-Content -Path "manifest.json" -Value $manifestContent; Write-Host "Manifest file created." -ForegroundColor Green
}

function tsConFig {
    $tsConfigContent = @"
{"compilerOptions":{"module":"ES2020","target":"ES2021","moduleResolution":"Node","allowSyntheticDefaultImports":true,"baseUrl":"./src","rootDir":"./src","outDir":"./scripts"},"exclude":["node_modules"],"include":["src"]}
"@
    Set-Content -Path "tsconfig.json" -Value $tsConfigContent; Write-Host "tsconfig.json file created." -ForegroundColor Green
}

function ts-com {
    Write-Host "Run TypeScript compiler with --watch? (y/n):" -ForegroundColor Cyan; $choice = Read-Host
    if ($choice -eq "y") { Write-Host "Running TypeScript compiler..." -ForegroundColor Cyan; tsc; tsc --watch }
    else { Write-Host "Exiting without running the compiler." -ForegroundColor Red }
}

$loop = $true
while ($loop) {
    $ch = Read-Host "Install or --watch? (0:install / 1:--watch)"
    if ($ch -eq "0") {
        Write-Host "Setting up..." -ForegroundColor Cyan
        Set-RemoteSigned; i-module; gen-manifest; tsConFig; Setup-Tree
        Write-Host "Setup complete. TypeScript project ready!" -ForegroundColor Green
    } else { $loop = $false; cls; ts-com }
}
