# Streamlined Development Environment Setup Script
# Installs selected development tools with improved progress tracking

# Self-elevate if not admin
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Enable script execution for this process
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Config
$installDir = "C:\DevTools"
$tempDir = "$env:TEMP\dev_setup"

# Create directories
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Helper Functions
function Add-ToPath {
    param($path)
    $envPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($envPath -notlike "*$path*") {
        [Environment]::SetEnvironmentVariable("Path", "$envPath;$path", "Machine")
    }
}

function Show-Progress {
    param($activity, $status, $percentComplete)
    Write-Progress -Activity $activity -Status $status -PercentComplete $percentComplete
}

function Download-File {
    param($url, $destination)
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $destination)
        return $true
    }
    catch {
        Write-Host "Download failed: $_" -ForegroundColor Red
        return $false
    }
}

# Display menu for tool selection
Write-Host "`n===== Development Environment Setup =====" -ForegroundColor Cyan
Write-Host "Select tools to install (separate with commas, e.g.: 1,3,4)" -ForegroundColor Yellow
Write-Host "1) MinGW (GCC/G++)" -ForegroundColor White
Write-Host "2) Python" -ForegroundColor White
Write-Host "3) Java" -ForegroundColor White
Write-Host "4) Visual Studio Code" -ForegroundColor White
Write-Host "5) All of the above" -ForegroundColor White

$selection = Read-Host "Your selection"

# Parse selection
$installTools = @()
if ($selection -eq "5") {
    $installTools = @("mingw", "python", "java", "vscode")
} else {
    $selectedOptions = $selection -split "," | ForEach-Object { $_.Trim() }
    foreach ($option in $selectedOptions) {
        switch ($option) {
            "1" { $installTools += "mingw" }
            "2" { $installTools += "python" }
            "3" { $installTools += "java" }
            "4" { $installTools += "vscode" }
        }
    }
}

# Install MinGW
function Install-MinGW {
    $mingwDir = "$installDir\MinGW"
    
    Write-Host "Installing MinGW..." -ForegroundColor Blue
    
    # Download and install 7-Zip if needed
    $7zPath = "$env:ProgramFiles\7-Zip\7z.exe"
    if (-not (Test-Path $7zPath)) {
        Show-Progress "MinGW Setup" "Downloading 7-Zip..." 10
        $7zUrl = "https://www.7-zip.org/a/7z2301-x64.exe"
        $7zInstaller = "$tempDir\7z-installer.exe"
        
        if (-not (Download-File $7zUrl $7zInstaller)) {
            Write-Host "Failed to download 7-Zip" -ForegroundColor Red
            return
        }
        
        Show-Progress "MinGW Setup" "Installing 7-Zip..." 20
        Start-Process -FilePath $7zInstaller -ArgumentList "/S" -Wait
    }
    
    # Download MinGW
    Show-Progress "MinGW Setup" "Downloading MinGW..." 30
    $mingwUrl = "https://github.com/niXman/mingw-builds-binaries/releases/download/13.1.0-rt_v11-rev1/x86_64-13.1.0-release-posix-seh-msvcrt-rt_v11-rev1.7z"
    $mingwArchive = "$tempDir\mingw64.7z"
    
    if (-not (Download-File $mingwUrl $mingwArchive)) {
        Write-Host "Failed to download MinGW" -ForegroundColor Red
        return
    }
    
    # Extract MinGW
    Show-Progress "MinGW Setup" "Extracting MinGW..." 70
    New-Item -ItemType Directory -Path $mingwDir -Force | Out-Null
    Start-Process -FilePath $7zPath -ArgumentList "x", "$mingwArchive", "-o$mingwDir", "-y" -Wait
    
    # Add to PATH
    Show-Progress "MinGW Setup" "Updating PATH..." 90
    Add-ToPath "$mingwDir\mingw64\bin"
    
    # Verify
    Show-Progress "MinGW Setup" "Verifying installation..." 100
    if (Test-Path "$mingwDir\mingw64\bin\g++.exe") {
        Write-Host "MinGW installed successfully" -ForegroundColor Green
    } else {
        Write-Host "MinGW installation failed" -ForegroundColor Red
    }
}

# Install Python with optimized approach
function Install-Python {
    $pythonDir = "$installDir\Python"
    
    Write-Host "Installing Python..." -ForegroundColor Blue
    
    # Download Python with progress
    Show-Progress "Python Setup" "Downloading Python installer..." 20
    $pythonVersion = "3.11.6"
    $pythonUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-amd64.exe"
    $pythonInstaller = "$tempDir\python-installer.exe"
    
    if (-not (Download-File $pythonUrl $pythonInstaller)) {
        Write-Host "Failed to download Python" -ForegroundColor Red
        return
    }
    
    # Install Python with optimized silent parameters
    Show-Progress "Python Setup" "Installing Python..." 60
    $pythonArgs = "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_doc=0 Include_launcher=1 " + 
                  "Include_tcltk=0 TargetDir=$pythonDir CompileAll=0 Shortcuts=0"
    Start-Process -FilePath $pythonInstaller -ArgumentList $pythonArgs -Wait
    
    # Add to PATH (redundancy)
    Show-Progress "Python Setup" "Updating PATH..." 90
    Add-ToPath $pythonDir
    Add-ToPath "$pythonDir\Scripts"
    
    # Verify
    Show-Progress "Python Setup" "Verifying installation..." 100
    if (Test-Path "$pythonDir\python.exe") {
        Write-Host "Python installed successfully" -ForegroundColor Green
        
        # Install pip and setuptools only - minimal essential packages
        Show-Progress "Python Setup" "Installing essential packages..." 100
        Start-Process -FilePath "$pythonDir\python.exe" -ArgumentList "-m pip install --upgrade pip setuptools" -Wait
    } else {
        Write-Host "Python installation failed" -ForegroundColor Red
    }
}

# Install Java
function Install-Java {
    $javaDir = "$installDir\Java"
    
    Write-Host "Installing Java..." -ForegroundColor Blue
    
    # Download Java
    Show-Progress "Java Setup" "Downloading Java..." 20
    $javaUrl = "https://download.java.net/java/GA/jdk17.0.2/dfd4a8d0985749f896bed50d7138ee7f/8/GPL/openjdk-17.0.2_windows-x64_bin.zip"
    $javaArchive = "$tempDir\java.zip"
    
    if (-not (Download-File $javaUrl $javaArchive)) {
        Write-Host "Failed to download Java" -ForegroundColor Red
        return
    }
    
    # Extract Java
    Show-Progress "Java Setup" "Extracting Java..." 60
    New-Item -ItemType Directory -Path $javaDir -Force | Out-Null
    Expand-Archive -Path $javaArchive -DestinationPath $javaDir -Force
    
    # Find JDK directory
    Show-Progress "Java Setup" "Setting up environment..." 80
    $jdkDir = Get-ChildItem -Path $javaDir -Directory | Where-Object { $_.Name -like "jdk*" } | 
              Select-Object -First 1 -ExpandProperty FullName
    if (-not $jdkDir) {
        $jdkDir = $javaDir
    }

    # Set JAVA_HOME and add to PATH
    Show-Progress "Java Setup" "Updating PATH..." 90
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkDir, "Machine")
    Add-ToPath "$jdkDir\bin"
    
    # Verify
    Show-Progress "Java Setup" "Verifying installation..." 100
    if (Test-Path "$jdkDir\bin\java.exe") {
        Write-Host "Java installed successfully" -ForegroundColor Green
    } else {
        Write-Host "Java installation failed" -ForegroundColor Red
    }
}

# Install Visual Studio Code
function Install-VSCode {
    Write-Host "Installing Visual Studio Code..." -ForegroundColor Blue
    
    # Download VS Code
    Show-Progress "VS Code Setup" "Downloading VS Code..." 30
    $vscodeUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"
    $vscodeInstaller = "$tempDir\vscode-installer.exe"
    
    if (-not (Download-File $vscodeUrl $vscodeInstaller)) {
        Write-Host "Failed to download VS Code" -ForegroundColor Red
        return
    }
    
    # Install VS Code
    Show-Progress "VS Code Setup" "Installing VS Code..." 70
    Start-Process -FilePath $vscodeInstaller -ArgumentList "/VERYSILENT", "/MERGETASKS=`"addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath`"" -Wait
    
    # Verify
    Show-Progress "VS Code Setup" "Verifying installation..." 100
    if (Test-Path "$env:ProgramFiles\Microsoft VS Code\Code.exe") {
        Write-Host "Visual Studio Code installed successfully" -ForegroundColor Green
    } else {
        Write-Host "Visual Studio Code installation failed" -ForegroundColor Red
    }
}

# Run installations sequentially with clear progress tracking
Write-Host "`nStarting installation of selected tools..." -ForegroundColor Cyan
$totalTools = $installTools.Count
$currentTool = 0

foreach ($tool in $installTools) {
    $currentTool++
    $toolProgress = [math]::Round(($currentTool / $totalTools) * 100)
    Write-Progress -Id 0 -Activity "Overall Progress" -Status "Tool $currentTool of $totalTools ($($tool.ToUpper()))" -PercentComplete $toolProgress
    
    switch ($tool) {
        "mingw" { Install-MinGW }
        "python" { Install-Python }
        "java" { Install-Java }
        "vscode" { Install-VSCode }
    }
}

Write-Progress -Id 0 -Activity "Overall Progress" -Completed

# Clean up temp files
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# Summary
Write-Host "`n===== Installation Summary =====" -ForegroundColor Cyan
if ($installTools -contains "mingw") {
    Write-Host "✓ MinGW (GCC/G++): $installDir\MinGW\mingw64\bin" -ForegroundColor Green
}
if ($installTools -contains "python") {
    Write-Host "✓ Python: $installDir\Python" -ForegroundColor Green
}
if ($installTools -contains "java") {
    $jdkDir = Get-ChildItem -Path "$installDir\Java" -Directory | Where-Object { $_.Name -like "jdk*" } | 
              Select-Object -First 1 -ExpandProperty FullName
    if (-not $jdkDir) { $jdkDir = "$installDir\Java" }
    Write-Host "✓ Java: $jdkDir" -ForegroundColor Green
}
if ($installTools -contains "vscode") {
    Write-Host "✓ Visual Studio Code: $env:ProgramFiles\Microsoft VS Code" -ForegroundColor Green
}

Write-Host "`nThe PATH environment variables have been set." -ForegroundColor Yellow
Write-Host "Please restart your computer for all changes to take effect." -ForegroundColor Yellow
Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
