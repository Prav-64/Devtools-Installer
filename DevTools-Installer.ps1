# Streamlined Development Environment Setup Script
# Installs selected development tools with parallel processing for speed

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

# Add to PATH function
function Add-ToPath($path) {
    $envPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($envPath -notlike "*$path*") {
        [Environment]::SetEnvironmentVariable("Path", "$envPath;$path", "Machine")
    }
}

# Install MinGW function
function Install-MinGW {
    $mingwDir = "$installDir\MinGW"
    $logFile = "$tempDir\mingw_install.log"
    
    Write-Host "Installing MinGW..." -ForegroundColor Blue
    
    # Download and install 7-Zip if needed
    $7zPath = "$env:ProgramFiles\7-Zip\7z.exe"
    if (-not (Test-Path $7zPath)) {
        $7zUrl = "https://www.7-zip.org/a/7z2301-x64.exe"
        $7zInstaller = "$tempDir\7z-installer.exe"
        Invoke-WebRequest -Uri $7zUrl -OutFile $7zInstaller
        Start-Process -FilePath $7zInstaller -ArgumentList "/S" -Wait
    }
    
    # Download and extract MinGW
    $mingwUrl = "https://github.com/niXman/mingw-builds-binaries/releases/download/13.1.0-rt_v11-rev1/x86_64-13.1.0-release-posix-seh-msvcrt-rt_v11-rev1.7z"
    $mingwArchive = "$tempDir\mingw64.7z"
    Invoke-WebRequest -Uri $mingwUrl -OutFile $mingwArchive
    
    New-Item -ItemType Directory -Path $mingwDir -Force | Out-Null
    Start-Process -FilePath $7zPath -ArgumentList "x", "$mingwArchive", "-o$mingwDir", "-y" -Wait
    
    # Add to PATH
    Add-ToPath "$mingwDir\mingw64\bin"
    
    # Verify
    if (Test-Path "$mingwDir\mingw64\bin\g++.exe") {
        Write-Host "MinGW installed successfully" -ForegroundColor Green
    } else {
        Write-Host "MinGW installation failed" -ForegroundColor Red
    }
}

# Install Python function
function Install-Python {
    $pythonDir = "$installDir\Python"
    $logFile = "$tempDir\python_install.log"
    
    Write-Host "Installing Python..." -ForegroundColor Blue
    
    # Download and install Python
    $pythonVersion = "3.11.6"
    $pythonUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-amd64.exe"
    $pythonInstaller = "$tempDir\python-installer.exe"
    Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
    
    $pythonArgs = "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 TargetDir=$pythonDir"
    Start-Process -FilePath $pythonInstaller -ArgumentList $pythonArgs -Wait
    
    # Add to PATH (redundancy)
    Add-ToPath $pythonDir
    Add-ToPath "$pythonDir\Scripts"
    
    # Verify
    if (Test-Path "$pythonDir\python.exe") {
        Write-Host "Python installed successfully" -ForegroundColor Green
    } else {
        Write-Host "Python installation failed" -ForegroundColor Red
    }
}

# Install Java function
function Install-Java {
    $javaDir = "$installDir\Java"
    $logFile = "$tempDir\java_install.log"
    
    Write-Host "Installing Java..." -ForegroundColor Blue
    
    # Download and extract Java
    $javaUrl = "https://download.java.net/java/GA/jdk17.0.2/dfd4a8d0985749f896bed50d7138ee7f/8/GPL/openjdk-17.0.2_windows-x64_bin.zip"
    $javaArchive = "$tempDir\java.zip"
    Invoke-WebRequest -Uri $javaUrl -OutFile $javaArchive
    
    New-Item -ItemType Directory -Path $javaDir -Force | Out-Null
    Expand-Archive -Path $javaArchive -DestinationPath $javaDir -Force
    
    # Find JDK directory
    $jdkDir = Get-ChildItem -Path $javaDir -Directory | Where-Object { $_.Name -like "jdk*" } | 
              Select-Object -First 1 -ExpandProperty FullName
    if (-not $jdkDir) {
        $jdkDir = $javaDir
    }

    # Set JAVA_HOME and add to PATH
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkDir, "Machine")
    Add-ToPath "$jdkDir\bin"
    
    # Verify
    if (Test-Path "$jdkDir\bin\java.exe") {
        Write-Host "Java installed successfully" -ForegroundColor Green
    } else {
        Write-Host "Java installation failed" -ForegroundColor Red
    }
}

# Install Visual Studio Code function
function Install-VSCode {
    $logFile = "$tempDir\vscode_install.log"
    
    Write-Host "Installing Visual Studio Code..." -ForegroundColor Blue
    
    # Download and install VS Code
    $vscodeUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"
    $vscodeInstaller = "$tempDir\vscode-installer.exe"
    Invoke-WebRequest -Uri $vscodeUrl -OutFile $vscodeInstaller
    
    Start-Process -FilePath $vscodeInstaller -ArgumentList "/VERYSILENT", "/MERGETASKS=`"addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath`"" -Wait
    
    # Verify
    if (Test-Path "$env:ProgramFiles\Microsoft VS Code\Code.exe") {
        Write-Host "Visual Studio Code installed successfully" -ForegroundColor Green
    } else {
        Write-Host "Visual Studio Code installation failed" -ForegroundColor Red
    }
}

# Run installations in parallel
$jobs = @()

foreach ($tool in $installTools) {
    switch ($tool) {
        "mingw" {
            $jobs += Start-Job -ScriptBlock {
                param($script, $dir)
                . ([ScriptBlock]::Create($script))
                Install-MinGW
            } -ArgumentList ${function:Install-MinGW}, $installDir
        }
        "python" {
            $jobs += Start-Job -ScriptBlock {
                param($script, $dir)
                . ([ScriptBlock]::Create($script))
                Install-Python
            } -ArgumentList ${function:Install-Python}, $installDir
        }
        "java" {
            $jobs += Start-Job -ScriptBlock {
                param($script, $dir)
                . ([ScriptBlock]::Create($script))
                Install-Java
            } -ArgumentList ${function:Install-Java}, $installDir
        }
        "vscode" {
            $jobs += Start-Job -ScriptBlock {
                param($script, $dir)
                . ([ScriptBlock]::Create($script))
                Install-VSCode
            } -ArgumentList ${function:Install-VSCode}, $installDir
        }
    }
}

# Show progress while waiting for jobs
$spinner = @('|', '/', '-', '\')
$spinnerPos = 0
$startTime = Get-Date

Write-Host "`nInstalling selected tools in parallel..." -ForegroundColor Cyan
while ($jobs | Where-Object { $_.State -eq 'Running' }) {
    $runningJobs = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
    $completedJobs = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
    $totalJobs = $jobs.Count
    
    $elapsedTime = (Get-Date) - $startTime
    $formattedTime = "{0:mm}:{0:ss}" -f $elapsedTime
    
    Write-Host "`r$($spinner[$spinnerPos]) Progress: $completedJobs of $totalJobs completed (Elapsed time: $formattedTime)" -NoNewline
    
    $spinnerPos++
    if ($spinnerPos -ge $spinner.Length) {
        $spinnerPos = 0
    }
    
    Start-Sleep -Milliseconds 250
}

Write-Host "`r " -NoNewline
Write-Host "`nAll installation jobs completed!" -ForegroundColor Green

# Get job results
foreach ($job in $jobs) {
    Receive-Job -Job $job
}

# Clean up jobs
$jobs | Remove-Job

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
