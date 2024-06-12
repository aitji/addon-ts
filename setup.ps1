function New-Guid { [guid]::NewGuid().ToString() }
function Get-PackageVersionFromJson { param ([string]$packageName) $packageJson = Get-Content -Raw -Path "package.json" | ConvertFrom-Json; $version = $packageJson.dependencies."$packageName"; $version -replace "\^", "" }
function Setup-DirectoryStructure { New-Item -ItemType Directory -Path "src" -Force; New-Item -ItemType File -Path "src/index.ts" -Force; Write-Host "Project directory structure created." -ForegroundColor Green }

function Set-ScriptExecutionPolicy {
    $currentPolicy = Get-ExecutionPolicy -List | Where-Object { $_.Scope -eq 'CurrentUser' }
    if ($currentPolicy.Policy -eq 'RemoteSigned') { Write-Host "Execution policy is already set to RemoteSigned for CurrentUser." -ForegroundColor Green }
    else { Write-Host "Setting execution policy to RemoteSigned for CurrentUser..." -ForegroundColor Yellow; Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Write-Host "Execution policy set to RemoteSigned for CurrentUser." -ForegroundColor Green }
}

function Install-Dependencies {
    npm install -g typescript
    npm init -y
    $versionChoice = Read-Host "Choose version (stable/beta)"
    if ($versionChoice -eq "beta") { npm install @minecraft/server@beta; npm install @minecraft/server-ui@beta }
    else { npm install @minecraft/server; npm install @minecraft/server-ui }
}

function Generate-Manifest {
    $uuid1 = New-Guid; $uuid2 = New-Guid; $uuid3 = New-Guid; $serverVersion = Get-PackageVersionFromJson -packageName "@minecraft/server"; $serverUiVersion = Get-PackageVersionFromJson -packageName "@minecraft/server-ui"
    $manifestContent = @"
{ "format_version": 2, "header": { "name": "typescript project", "description": "this is my typescript project!~", "uuid": "$uuid1", "version": [0,0,1], "min_engine_version": [1,19,70] }, "modules": [ { "type": "data", "uuid": "$uuid2", "version": [1,0,0] }, { "type": "script", "uuid": "$uuid3", "version": [1,0,0], "entry": "scripts/index.js" } ], "dependencies": [ { "module_name": "@minecraft/server", "version": "$serverVersion" }, { "module_name": "@minecraft/server-ui", "version": "$serverUiVersion" } ] }
"@
    Set-Content -Path "manifest.json" -Value $manifestContent; Write-Host "Manifest file created." -ForegroundColor Green
}

function Generate-TsConfig {
    $tsConfigContent = @"
{ "compilerOptions": { "module": "ES2020", "target": "ES2021", "moduleResolution": "Node", "allowSyntheticDefaultImports": true, "baseUrl": "./src", "rootDir": "./src", "outDir": "./scripts" }, "exclude": [ "node_modules" ], "include": [ "src" ] }
"@
    Set-Content -Path "tsconfig.json" -Value $tsConfigContent; Write-Host "tsconfig.json file created." -ForegroundColor Green
}

function Run-TypeScriptCompiler {
    Write-Host "Do you want to run the TypeScript compiler with --watch option? (y/n):" -ForegroundColor Cyan; $choice = Read-Host
    if ($choice -eq "y") { Write-Host "Running TypeScript compiler with --watch option..." -ForegroundColor Cyan; tsc; tsc --watch }
    else { Write-Host "Exiting without running the TypeScript compiler." -ForegroundColor Red }
}

$loop = $true
while ($loop) {
  $ch = Read-Host "Do you want to install or --watch (0:install / 1:--watch)"
  if ($ch -eq "0") {
    Write-Host "Starting setup..." -ForegroundColor Cyan
    Set-ScriptExecutionPolicy; Install-Dependencies; Generate-Manifest; Generate-TsConfig; Setup-DirectoryStructure
    Write-Host "Setup complete. Your TypeScript project is ready!" -ForegroundColor Green
  } else { $loop = $false; cls; Run-TypeScriptCompiler }
}