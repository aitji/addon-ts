function New-Guid { [guid]::NewGuid().ToString() }
function Get-Package { param([string]$packageName) ((Get-Content -Raw -Path "package.json" | ConvertFrom-Json).dependencies."$packageName" -replace "-beta.*", "-beta") -replace "\^", "" }

function wColor {
    param (
        [string]$text,
        [string]$color = "White"
    )
    Write-Host -ForegroundColor $color -NoNewline $text
}

function checkAndForceTo {
    $nodeVersion = node --version 2>$null
    if (!$nodeVersion) {
        wColor -text "Node.js is not installed`n" -color "Red"
        $response = Read-Host "Would you like to install Node.js? (1/0)"
        if ($response -eq "1") {
            Write-Output "Downloading and installing the latest version of Node.js..."
            $installerUrl = "https://nodejs.org/dist/v20.16.0/node-v20.16.0-x64.msi"
            $installerPath = "$env:TEMP\nodejs_installer.msi"
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath

            Write-Output "Node.js has been installed. Please restart your terminal to use it."
            Read-Host -Prompt "( Press ENTER to exit this terminal! )"
            exit
        } else {
            Read-Host -Prompt "Node.js is required for this script. "
            exit
        }
    }
}

function display {
    param (
        [string]$title,
        [string]$description,
        [int]$totalSteps,
        [int]$currentStep
    )
    if ($global:showProgress) {
        $progress = [math]::Floor(($currentStep / $totalSteps) * 5)
        $remaining = 5 - $progress
        $progressBar = "1" * $progress + "0" * $remaining
        $speed = [math]::Round(100 / $totalSteps, 2)
        $timeRemaining = [math]::Round(($totalSteps - $currentStep) * ($speed / 100), 2)

        Clear-Host
        wColor -text "$title`n" -color "Cyan"
        wColor -text "$description`n" -color "White"
        Write-Host ""
        wColor -text "Task: " -color "Green"
        wColor -text "$progressBar ($currentStep/$totalSteps)`n" -color "Green"
        wColor -text "Speed: " -color "Yellow"
        wColor -text "$speed m/s (Time Remaining: ~ $timeRemaining seconds)`n" -color "Yellow"
        Start-Sleep -Milliseconds 500
    }
}

function buildT {
    $totalSteps = 2
    $currentStep = 0

    display -title "Setting Up Project Structure" -description "Creating 'src' directory..." -totalSteps $totalSteps -currentStep $currentStep
    New-Item -ItemType Directory -Path "src" -Force
    $currentStep++

    display -title "Setting Up Project Structure" -description "Creating 'src/index.ts' file..." -totalSteps $totalSteps -currentStep $currentStep
    New-Item -ItemType File -Path "src/index.ts" -Force
    if (!$global:showProgress) { wColor -text "Project structure created.`n" -color "Green" }
}

function setRemote {
    $totalSteps = 1
    $currentStep = 0

    $currentStep++
    display -title "Setting Execution Policy" -description "Checking current execution policy..." -totalSteps $totalSteps -currentStep $currentStep
    $currentPolicy = Get-ExecutionPolicy -List | Where-Object { $_.Scope -eq 'CurrentUser' }
    if ($currentPolicy.Policy -eq 'RemoteSigned') {
        if (!$global:showProgress) { wColor -text "Execution policy is already set.`n" -color "Green" }
    } else {
        if (!$global:showProgress) { wColor -text "Setting execution policy...`n" -color "Yellow" }
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        if (!$global:showProgress) { wColor -text "Execution policy set.`n" -color "Green" }
    }
}

function iModule {
    $totalSteps = 4
    $currentStep = 0

    $currentStep++
    display -title "Installing Modules" -description "Installing TypeScript globally..." -totalSteps $totalSteps -currentStep $currentStep
    npm install -g typescript

    $currentStep++
    display -title "Installing Modules" -description "Initializing npm..." -totalSteps $totalSteps -currentStep $currentStep
    npm init -y

    $currentStep++
    display -title "Installing Modules" -description "Choosing version and installing packages..." -totalSteps $totalSteps -currentStep $currentStep
    $versionChoice = Read-Host "Choose version (stable/beta)"
    if ($versionChoice -eq "beta") {
        npm install @minecraft/server@beta
        npm install @minecraft/server-ui@beta
    } else {
        npm install @minecraft/server
        npm install @minecraft/server-ui
    }
}

function gen-manifest {
    $totalSteps = 2
    $currentStep = 0

    $currentStep++
    display -title "Generating Manifest" -description "Generating UUIDs and getting versions..." -totalSteps $totalSteps -currentStep $currentStep
    $uuid1 = New-Guid
    $uuid2 = New-Guid
    $uuid3 = New-Guid
    $serverVersion = Get-Package -packageName "@minecraft/server"
    $serverUiVersion = Get-Package -packageName "@minecraft/server-ui"

    $currentStep++
    display -title "Generating Manifest" -description "Creating manifest.json file..." -totalSteps $totalSteps -currentStep $currentStep
    $manifestContent = @"
{"format_version":2,"header":{"name":"typescript project","description":"my typescript project!~","uuid":"$uuid1","version":[0,0,1],"min_engine_version":[1,19,70]},"modules":[{"type":"data","uuid":"$uuid2","version":[1,0,0]},{"type":"script","uuid":"$uuid3","version":[1,0,0],"entry":"scripts/index.js"}],"dependencies":[{"module_name":"@minecraft/server","version":"$serverVersion"},{"module_name":"@minecraft/server-ui","version":"$serverUiVersion"}]}
"@
    Set-Content -Path "manifest.json" -Value $manifestContent
    if (!$global:showProgress) { wColor -text "Manifest file created.`n" -color "Green" }
}

function tsConFig {
    $totalSteps = 1
    $currentStep = 0

    $currentStep++
    display -title "Creating tsconfig.json" -description "Writing tsconfig.json file..." -totalSteps $totalSteps -currentStep $currentStep
    $tsConfigContent = @"
{"compilerOptions":{"module":"ES2020","target":"ES2021","moduleResolution":"Node","allowSyntheticDefaultImports":true,"baseUrl":"./src","rootDir":"./src","outDir":"./scripts"},"exclude":["node_modules"],"include":["src"]}
"@
    Set-Content -Path "tsconfig.json" -Value $tsConfigContent
    if (!$global:showProgress) { wColor -text "tsconfig.json file created.`n" -color "Green" }
}

function fdv {
    $filesToCheck = @("manifest.json", "tsconfig.json", "src/index.ts")
    $dirsToCheck = @("src")
    $totalSteps = $filesToCheck.Count + $dirsToCheck.Count
    $currentStep = 0

    foreach ($file in $filesToCheck) {
        $currentStep++
        display -title "Checking Files" -description "Checking file: $file" -totalSteps $totalSteps -currentStep $currentStep
        if (-not (Test-Path -Path $file)) {
            if (!$global:showProgress) { wColor -text "File '$file' is missing. Recreating...`n" -color "Yellow" }
            switch ($file) {
                "manifest.json" { gen-manifest }
                "tsconfig.json" { tsConFig }
            }
        } else { if (!$global:showProgress) { wColor -text "File '$file' is present.`n" -color "Green" } }
    }

    foreach ($dir in $dirsToCheck) {
        $currentStep++
        display -title "Checking Directories" -description "Checking directory: $dir" -totalSteps $totalSteps -currentStep $currentStep
        if (-not (Test-Path -Path $dir)) {
            if (!$global:showProgress) { wColor -text "Directory '$dir' is missing. Recreating...`n" -color "Yellow" }
            buildT
        } else { if (!$global:showProgress) { wColor -text "Directory '$dir' is present.`n" -color "Green" } }
    }
}

function isYouAdmin {
    Clear-Host
    $isAdmin = $false
    try {
        $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $windowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($windowsIdentity)
        $isAdmin = $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltinRole]::Administrator)
    } catch { wColor -text "Error checking admin rights.`n" -color "Red" }

    if (-not $isAdmin) {
        wColor -text "You need to run on administrator to do this action!`n" -color "Red"
        wColor -text "okay! so I will popup a gui ask for run in administrator mode and this would restart the program`n" -color "Yellow"
        Read-Host -Prompt "Press ENTER to continue"
        try {
            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            exit
        }
        catch {
            wColor -text "Exiting script. Please run as administrator.`n" -color "Red"
            Read-Host -Prompt "Press ENTER to go back... "
            index
        }
    }
}

$global:showProgress = $true
$global:diT = ''
function index {
    $debugPath = Get-Location
    $loop = $true
    while ($loop) {
        Clear-Host
        Write-Host $global:diT
        wColor -text "Howdy, This is TypeScript Project Builder!`n" -color "Cyan"
        wColor -text "This project is made to help you focus on your addon, not just getting confused about setting up your TypeScript project.`n`n" -color "Cyan"
        wColor -text "Okay! What do you want to do?`n" -color "Cyan"
        wColor -text "Current Path: $debugPath`n" -color "Yellow"
        Write-Host ''
        wColor -text "1) Setup Project`n" -color "White"
        wColor -text "| This will generate files and setup the project for you!`n" -color "White"
        wColor -text "2) Watch TypeScript Compiler`n" -color "White"
        wColor -text "| This will watch your TS and compile it to JS`n" -color "White"
        wColor -text "3) File & Directory Verifier`n" -color "White"
        wColor -text "| This will scan files`n" -color "White"
        wColor -text "| If something is wrong, it will try to fix it`n" -color "White"
        wColor -text "4) Config Builder`n" -color "White"
        wColor -text "0) Exit?`n" -color "White"
        $ch = Read-Host " "
        switch ($ch) {
            "0" {
                wColor -text "Exiting...`n" -color "Cyan"
                $loop = $false
            }
            "1" {
                $global:diT = "Setup complete. TypeScript project ready!`n"
                isYouAdmin
                wColor -text "Setting up...`n" -color "Cyan"
                setRemote; iModule; gen-manifest; tsConFig; buildT
                wColor -text "Setup complete. TypeScript project ready!`n" -color "Green"
            }
            "2" {
                $global:diT = "Starting tsc --watch...`n"
                wColor -text "Starting tsc --watch...`n" -color "Cyan"
                tsc --watch
            }
            "3" {
                $global:diT = "Checking and reinstalling files...`n"
                isYouAdmin
                wColor -text "Checking and reinstalling files...`n" -color "Cyan"
                fdv
            }
            "4" {
                $showProgressChoice = Read-Host "Do you want to see the progress? (1/0)"
                if ($showProgressChoice -eq "1") {
                    $global:diT = "Setting Changed: showProgress: true"
                    $global:showProgress = $true
                } elseif ($showProgressChoice -eq "0") {
                    $global:diT = "Setting Changed: showProgress: false"
                    $global:showProgress = $false
                }
            }
            default { wColor -text "Invalid choice, try again!`n" -color "Red" }
        }
    }
}

$scriptPath = $PSScriptRoot
Set-Location -Path $scriptPath

try {
    checkAndForceTo
    $global:diT = "SYSTEM: you already install node js quite cool!!"
} catch {
    wColor -text "some cool error happend post this on issuse tab https://github.com/aitji/addon-ts/issues/new" -color "Red" 
    Read-Host "( Press ENETR to kill program! ) "
}
index
