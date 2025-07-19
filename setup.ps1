function New-Guid { [guid]::NewGuid().ToString() }

function wColor {
    param([string]$text, [string]$color = "White")
    Write-Host -ForegroundColor $color -NoNewline $text
}

function Test-NodeJS {
    try {
        $nodeVersion = node --version 2>$null
        return $null -ne $nodeVersion
    }
    catch {
        return $false
    }
}

function Install-NodeJS {
    wColor -text "Node.js is not installed`n" -color "Red"
    $response = Read-Host "Would you like to install Node.js? (1/0)"
    if ($response -eq "1") {
        wColor -text "Downloading and installing Node.js v20.16.0...`n" -color "Yellow"
        $installerUrl = "https://nodejs.org/dist/v20.16.0/node-v20.16.0-x64.msi"
        $installerPath = "$env:TEMP\nodejs_installer.msi"
        
        try {
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
            Start-Process -FilePath $installerPath -Wait
            wColor -text "Node.js installed! Please restart terminal.`n" -color "Green"
            Read-Host "Press ENTER to exit"
            exit
        }
        catch {
            wColor -text "Failed to download/install Node.js`n" -color "Red"
            wColor -text "Please install manually from https://nodejs.org`n" -color "Yellow"
        }
    }
    else {
        wColor -text "Node.js is required. Exiting...`n" -color "Red"
        exit
    }
}

function Test-AdminRights {
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltinRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Request-AdminRights {
    if (-not (Test-AdminRights)) {
        wColor -text "Administrator rights required!`n" -color "Red"
        wColor -text "Restarting with admin privileges...`n" -color "Yellow"
        Read-Host "Press ENTER to continue"
        try {
            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            exit
        }
        catch {
            wColor -text "Failed to restart as admin. Please run manually.`n" -color "Red"
            Read-Host "Press ENTER to return"
            return $false
        }
    }
    return $true
}
function Get-NPMVersions {
    param([string]$packageName)
    try {
        $response = Invoke-RestMethod -Uri "https://registry.npmjs.org/$packageName" -Method Get -ErrorAction Stop
        $versions = $response.versions.PSObject.Properties.Name
        return $versions | Sort-Object { 
            $parts = $_ -split '\.' | ForEach-Object { [int]($_ -replace '\D.*', '') }
            [System.Version]"$($parts[0]).$($parts[1]).$($parts[2])"
        } -Descending
    }
    catch {
        wColor -text "Failed to fetch versions for $packageName`n" -color "Red"
        return @()
    }
}

function Get-FilteredVersions {
    param(
        [string]$packageName,
        [string[]]$includeFilters = @(),
        [string[]]$excludeFilters = @()
    )
    $allVersions = Get-NPMVersions -packageName $packageName
    $filtered = $allVersions
    
    if ($includeFilters.Count -gt 0) {
        $filtered = $filtered | Where-Object {
            $version = $_
            ($includeFilters | ForEach-Object { $version -like "*$_*" }) -contains $true
        }
    }
    
    if ($excludeFilters.Count -gt 0) {
        $filtered = $filtered | Where-Object {
            $version = $_
            ($excludeFilters | ForEach-Object { $version -like "*$_*" }) -notcontains $true
        }
    }
    
    return $filtered
}

function Show-VersionMenu {
    param([string]$packageName)
    
    Clear-Host
    wColor -text "=== Version Selection for $packageName ===`n" -color "Cyan"
    wColor -text "1) Latest Stable Only`n" -color "White"
    wColor -text "2) Latest Beta Only`n" -color "Yellow"
    wColor -text "3) Latest Beta-Stable`n" -color "Green"
    wColor -text "4) Custom Version Selection`n" -color "White"
    wColor -text "5) Auto (Recommended)`n" -color "Cyan"
    wColor -text "0) Skip Package`n" -color "Red"
    
    $choice = Read-Host " "
    
    switch ($choice) {
        "1" {
            $stable = Get-FilteredVersions -packageName $packageName -excludeFilters @("beta", "rc", "preview", "alpha") | Select-Object -First 1
            return @($stable)
        }
        "2" {
            $beta = Get-FilteredVersions -packageName $packageName -includeFilters @("beta") -excludeFilters @("stable") | Select-Object -First 1
            return @($beta)
        }
        "3" {
            $betaStable = Get-FilteredVersions -packageName $packageName -includeFilters @("beta", "stable") | Select-Object -First 1
            return @($betaStable)
        }
        "4" {
            return Select-CustomVersion -packageName $packageName
        }
        "5" {
            $betaStable = Get-FilteredVersions -packageName $packageName -includeFilters @("beta", "stable") | Select-Object -First 1
            if ($betaStable) { return @($betaStable) }
            $stable = Get-FilteredVersions -packageName $packageName -excludeFilters @("beta", "rc", "preview", "alpha") | Select-Object -First 1
            return @($stable)
        }
        "0" { return @() }
        default {
            wColor -text "Invalid choice!`n" -color "Red"
            Start-Sleep 1
            return Show-VersionMenu -packageName $packageName
        }
    }
}

function Select-CustomVersion {
    param([string]$packageName)
    
    Clear-Host
    wColor -text "Available versions for $packageName (top 15):`n" -color "Cyan"
    
    $versions = Get-NPMVersions -packageName $packageName | Select-Object -First 15
    
    for ($i = 0; $i -lt $versions.Count; $i++) {
        $color = "White"
        if ($versions[$i] -like "*beta*stable*") { $color = "Green" }
        elseif ($versions[$i] -like "*beta*") { $color = "Yellow" }
        elseif ($versions[$i] -like "*rc*") { $color = "Cyan" }
        
        wColor -text "$($i + 1)) " -color "White"
        wColor -text "$($versions[$i])`n" -color $color
    }
    
    wColor -text "0) Back`n" -color "Red"
    $choice = Read-Host "Select version (1-$($versions.Count))"
    
    if ($choice -eq "0") { return Show-VersionMenu -packageName $packageName }
    
    $index = [int]$choice - 1
    if ($index -ge 0 -and $index -lt $versions.Count) {
        return @($versions[$index])
    }
    
    wColor -text "Invalid selection!`n" -color "Red"
    Start-Sleep 1
    return Select-CustomVersion -packageName $packageName
}

function Show-Progress {
    param([string]$title, [string]$description, [int]$current, [int]$total)
    
    if ($global:showProgress) {
        $percent = [math]::Round(($current / $total) * 100, 1)
        $progressChars = [math]::Floor(($current / $total) * 20)
        $progressBar = "█" * $progressChars + "░" * (20 - $progressChars)
        
        Clear-Host
        wColor -text "=== $title ===`n" -color "Cyan"
        wColor -text "$description`n" -color "White"
        wColor -text "`nProgress: [$progressBar] $percent% ($current/$total)`n" -color "Green"
        Start-Sleep -Milliseconds 300
    }
}

function New-ProjectStructure {
    $steps = @("Creating src directory", "Creating index.ts", "Creating package.json structure")
    
    for ($i = 0; $i -lt $steps.Count; $i++) {
        Show-Progress -title "Project Structure" -description $steps[$i] -current ($i + 1) -total $steps.Count
        
        switch ($i) {
            0 { New-Item -ItemType Directory -Path "src" -Force | Out-Null }
            1 { 
                $indexContent = @"
import { world } from "@minecraft/server"
world.sendMessage('HALO DEV :D!')
"@
                Set-Content -Path "src/index.ts" -Value $indexContent
            }
            2 { 
                if (-not (Test-Path "package.json")) {
                    npm init -y | Out-Null
                }
            }
        }
    }
    
    if (-not $global:showProgress) { wColor -text "Project structure created!`n" -color "Green" }
}

function Set-ExecutionPolicy {
    Show-Progress -title "Security Settings" -description "Configuring PowerShell execution policy" -current 1 -total 1
    
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -ne 'RemoteSigned') {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        if (-not $global:showProgress) { wColor -text "Execution policy configured!`n" -color "Green" }
    }
    else {
        if (-not $global:showProgress) { wColor -text "Execution policy already configured!`n" -color "Green" }
    }
}

function Install-Dependencies {
    $steps = @("Installing TypeScript globally", "Installing Minecraft packages")
    
    Show-Progress -title "Dependencies" -description $steps[0] -current 1 -total $steps.Count
    npm install -g typescript 2>$null | Out-Null
    
    Show-Progress -title "Dependencies" -description $steps[1] -current 2 -total $steps.Count
    
    $packages = @("@minecraft/server", "@minecraft/server-ui")
    
    foreach ($package in $packages) {
        wColor -text "`nConfiguring $package...`n" -color "Yellow"
        $selectedVersions = Show-VersionMenu -packageName $package
        
        foreach ($version in $selectedVersions) {
            if ($version) {
                wColor -text "Installing $package@$version...`n" -color "White"
                npm install "$package@$version" 2>$null | Out-Null
            }
        }
    }
    
    if (-not $global:showProgress) { wColor -text "All dependencies installed!`n" -color "Green" }
}

function New-ManifestFile {
    Show-Progress -title "Manifest Generation" -description "Creating manifest.json" -current 1 -total 1
    
    $uuid1 = New-Guid
    $uuid2 = New-Guid  
    $uuid3 = New-Guid
    
    function Get-InstalledVersion {
        param([string]$packageName)
        try {
            $packageJson = Get-Content "package.json" -Raw | ConvertFrom-Json
            $version = $packageJson.dependencies."$packageName"
            return ($version -replace "[\^~]", "") -replace "-beta.*", "-beta"
        }
        catch {
            return "1.19.0"
        }
    }
    
    $serverVersion = Get-InstalledVersion "@minecraft/server"
    $serverUiVersion = Get-InstalledVersion "@minecraft/server-ui"
    
    $manifest = @{
        format_version = 2
        header         = @{
            name               = "TypeScript Addon"
            description        = "TypeScript addon project"
            uuid               = $uuid1
            version            = @(1, 0, 0)
            min_engine_version = @(1, 19, 70)
        }
        modules        = @(
            @{
                type    = "data"
                uuid    = $uuid2
                version = @(1, 0, 0)
            },
            @{
                type    = "script"
                uuid    = $uuid3
                version = @(1, 0, 0)
                entry   = "scripts/index.js"
            }
        )
        dependencies   = @(
            @{
                module_name = "@minecraft/server"
                version     = $serverVersion
            },
            @{
                module_name = "@minecraft/server-ui" 
                version     = $serverUiVersion
            }
        )
    }
    
    $manifest | ConvertTo-Json -Depth 10 -Compress | Set-Content -Path "manifest.json"
    if (-not $global:showProgress) { wColor -text "Manifest created!`n" -color "Green" }
}

function New-TSConfig {
    Show-Progress -title "TypeScript Config" -description "Creating tsconfig.json" -current 1 -total 1
    
    $tsConfig = @{
        compilerOptions = @{
            target                           = "ES2021"
            module                           = "ES2020"
            moduleResolution                 = "Node"
            allowSyntheticDefaultImports     = $true
            strict                           = $true
            esModuleInterop                  = $true
            skipLibCheck                     = $true
            forceConsistentCasingInFileNames = $true
            resolveJsonModule                = $true
            baseUrl                          = "./src"
            rootDir                          = "./src"
            outDir                           = "./scripts"
            removeComments                   = $true
            sourceMap                        = $false
        }
        include         = @("src/**/*")
        exclude         = @("node_modules", "scripts")
    }
    
    $tsConfig | ConvertTo-Json -Depth 10 | Set-Content -Path "tsconfig.json"
    if (-not $global:showProgress) { wColor -text "TypeScript config created!`n" -color "Green" }
}

function Test-ProjectIntegrity {
    $requiredFiles = @("manifest.json", "tsconfig.json", "src/index.ts", "package.json")
    $requiredDirs = @("src")
    $issues = @()
    
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            $issues += "Missing file: $file"
        }
    }
    
    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path $dir -PathType Container)) {
            $issues += "Missing directory: $dir"
        }
    }
    
    if ($issues.Count -eq 0) {
        wColor -text "Project integrity check passed!`n" -color "Green"
        return $true
    }
    else {
        wColor -text "Project integrity issues found:`n" -color "Red"
        foreach ($issue in $issues) {
            wColor -text "  - $issue`n" -color "Yellow"
        }
        return $false
    }
}

function Repair-Project {
    wColor -text "Attempting to repair project...`n" -color "Yellow"
    
    if (-not (Test-Path "src")) { New-ProjectStructure }
    if (-not (Test-Path "manifest.json")) { New-ManifestFile }
    if (-not (Test-Path "tsconfig.json")) { New-TSConfig }
    
    wColor -text "Repair completed!`n" -color "Green"
}

function Start-TypeScriptWatch {
    wColor -text "Starting TypeScript compiler in watch mode...`n" -color "Cyan"
    wColor -text "Press Ctrl+C to stop watching`n" -color "Yellow"
    tsc --watch
}

$global:showProgress = $true
$global:statusMessage = ''

function Show-MainMenu {
    $currentPath = (Get-Location).Path
    
    while ($true) {
        Clear-Host
        
        if ($global:statusMessage) {
            wColor -text "$($global:statusMessage)`n" -color "Green"
            $global:statusMessage = ''
        }
        
        wColor -text "TypeScript Addon Builder`n" -color "Cyan"
        wColor -text "tool for Minecraft Bedrock TypeScript development`n`n" -color "White"
        wColor -text "Current Directory: " -color "Yellow"
        wColor -text "$currentPath`n`n" -color "White"
        
        wColor -text "Main Options:`n" -color "Cyan"
        wColor -text "1) Complete Project Setup`n" -color "White"
        wColor -text "2) Start TypeScript Watcher`n" -color "White"
        wColor -text "3) Project Integrity Check`n" -color "White"
        wColor -text "4) Repair Project`n" -color "White"
        wColor -text "5) Settings`n" -color "White"
        wColor -text "6) Package Manager`n" -color "White"
        wColor -text "0) Exit`n" -color "Red"
        
        $choice = Read-Host "Select option"
        
        switch ($choice) {
            "1" {
                if (Request-AdminRights) {
                    wColor -text "Setting up complete TypeScript project...`n" -color "Cyan"
                    Set-ExecutionPolicy
                    New-ProjectStructure
                    Install-Dependencies
                    New-ManifestFile
                    New-TSConfig
                    $global:statusMessage = "Project setup completed successfully!"
                }
            }
            "2" {
                if (Test-Path "tsconfig.json") {
                    Start-TypeScriptWatch
                }
                else {
                    wColor -text "No tsconfig.json found! Run setup first.`n" -color "Red"
                    Read-Host "Press ENTER to continue"
                }
            }
            "3" {
                if (Test-ProjectIntegrity) {
                    $global:statusMessage = "Project integrity verified!"
                }
                else {
                    Read-Host "Press ENTER to continue"
                }
            }
            "4" {
                if (Request-AdminRights) {
                    Repair-Project
                    $global:statusMessage = "Project repair completed!"
                }
            }
            "5" {
                Show-SettingsMenu
            }
            "6" {
                Show-PackageMenu
            }
            "0" {
                wColor -text "Goodbye!`n" -color "Cyan"
                exit
            }
            default {
                wColor -text "Invalid choice!`n" -color "Red"
                Start-Sleep 1
            }
        }
    }
}

function Show-SettingsMenu {
    Clear-Host
    wColor -text "Settings Menu`n" -color "Cyan"
    wColor -text "1) Toggle Progress Animations (Current: " -color "White"
    wColor -text $(if ($global:showProgress) { "ON" } else { "OFF" }) -color $(if ($global:showProgress) { "Green" } else { "Red" })
    wColor -text ")`n" -color "White"
    wColor -text "0) Back to Main Menu`n" -color "Red"
    
    $choice = Read-Host "Select option"
    switch ($choice) {
        "1" {
            $global:showProgress = -not $global:showProgress
            $global:statusMessage = "Progress animations: $(if ($global:showProgress) { 'ENABLED' } else { 'DISABLED' })"
        }
        "0" { return }
    }
}

function Show-PackageMenu {
    Clear-Host
    wColor -text "Package Management`n" -color "Cyan"
    wColor -text "1) List Installed Packages`n" -color "White"
    wColor -text "2) Add Package`n" -color "White"
    wColor -text "3) Update Packages`n" -color "White"
    wColor -text "0) Back`n" -color "Red"
    
    $choice = Read-Host "Select option"
    switch ($choice) {
        "1" {
            if (Test-Path "package.json") { npm list }
            else { wColor -text "No package.json found!`n" -color "Red" }
            Read-Host "Press ENTER to continue"
        }
        "2" {
            $packageName = Read-Host "Enter package name"
            if ($packageName) {
                $versions = Show-VersionMenu -packageName $packageName
                foreach ($version in $versions) {
                    if ($version) { npm install "$packageName@$version" }
                }
            }
        }
        "3" {
            npm update
            Read-Host "Press ENTER to continue"
        }
        "0" { return }
    }
}

try {
    Set-Location $PSScriptRoot
    
    if (-not (Test-NodeJS)) {
        Install-NodeJS
    }
    
    Show-MainMenu
}
catch {
    wColor -text "Critical error occurred!`n" -color "Red"
    wColor -text "Please report this issue: $($_.Exception.Message)`n" -color "Yellow"
    Read-Host "Press ENTER to exit"
}