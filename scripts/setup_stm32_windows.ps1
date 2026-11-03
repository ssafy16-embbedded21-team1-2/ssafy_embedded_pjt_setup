param(
    [switch]$CheckOnly,
    [switch]$SkipExtensions
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repoRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $repoRoot '.tools/stm32'
$packages = @(
    @{
        Name = 'Arm GNU Toolchain (xPack 15.2.1-1.1)'
        Folder = 'xpack-arm-none-eabi-gcc-15.2.1-1.1'
        Exe = 'bin/arm-none-eabi-gcc.exe'
        Url = 'https://github.com/xpack-dev-tools/arm-none-eabi-gcc-xpack/releases/download/v15.2.1-1.1/xpack-arm-none-eabi-gcc-15.2.1-1.1-win32-x64.zip'
        Sha256 = 'bae6a3d1667697ce750c3b13d6d26d80973ecedc2cc87bf04869e83447fd93ea'
    },
    @{
        Name = 'OpenOCD (xPack 0.12.0-7)'
        Folder = 'xpack-openocd-0.12.0-7'
        Exe = 'bin/openocd.exe'
        Url = 'https://github.com/xpack-dev-tools/openocd-xpack/releases/download/v0.12.0-7/xpack-openocd-0.12.0-7-win32-x64.zip'
        Sha256 = '6bfd3c97135aafef8affc9af1acf34fd0e2b9ca26044506f6abd7f95b7630052'
    }
)

function Install-Package($package) {
    $exe = Join-Path (Join-Path $toolRoot $package.Folder) $package.Exe
    if (Test-Path -LiteralPath $exe) {
        Write-Host "[OK] $($package.Name): $exe"
        return $true
    }
    if ($CheckOnly) {
        Write-Host "[MISSING] $($package.Name): $exe"
        return $false
    }
    New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null
    $archive = Join-Path $toolRoot ($package.Folder + '.zip.download')
    try {
        Write-Host "[DOWNLOAD] $($package.Name)"
        Invoke-WebRequest -Uri $package.Url -OutFile $archive -UseBasicParsing
        $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $package.Sha256) { throw "SHA-256 mismatch for $($package.Name)" }
        Write-Host "[EXTRACT] $($package.Name)"
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($archive, $toolRoot)
        if (-not (Test-Path -LiteralPath $exe)) { throw "Executable not found after extraction: $exe" }
        Write-Host "[OK] $exe"
        return $true
    } finally {
        if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    }
}

$allReady = $true
foreach ($package in $packages) {
    if (-not (Install-Package $package)) { $allReady = $false }
}
$requiredCommands = @('cmake', 'ninja')
if (-not $SkipExtensions) { $requiredCommands += 'code' }
foreach ($command in $requiredCommands) {
    if (Get-Command $command -ErrorAction SilentlyContinue) {
        Write-Host "[OK] $command"
    } else {
        Write-Host "[MISSING] $command (install separately and reopen the terminal)"
        $allReady = $false
    }
}
if (-not $CheckOnly -and -not $SkipExtensions -and (Get-Command code -ErrorAction SilentlyContinue)) {
    foreach ($extension in @('ms-vscode.cpptools', 'ms-vscode.cmake-tools', 'marus25.cortex-debug', 'stmicroelectronics.stm32-vscode-extension')) {
        & code --install-extension $extension
        if ($LASTEXITCODE -ne 0) { throw "VS Code extension installation failed: $extension" }
    }
}
if ($CheckOnly -and -not $SkipExtensions -and (Get-Command code -ErrorAction SilentlyContinue)) {
    $installedExtensions = @(& code --list-extensions)
    if ($LASTEXITCODE -ne 0) { throw 'Failed to list VS Code extensions.' }
    foreach ($extension in @('ms-vscode.cpptools', 'ms-vscode.cmake-tools', 'marus25.cortex-debug', 'stmicroelectronics.stm32-vscode-extension')) {
        if ($installedExtensions -contains $extension) {
            Write-Host "[OK] VS Code extension: $extension"
        } else {
            Write-Host "[MISSING] VS Code extension: $extension"
            $allReady = $false
        }
    }
}
if (-not $allReady) { exit 1 }
Write-Host '[OK] STM32 tools available. Select a CMake preset and build; no board was flashed.'
