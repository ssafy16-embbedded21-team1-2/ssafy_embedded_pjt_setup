# Raspberry Pi 5 SCP 파일 전송기 (utils/scp_to_rpi.ps1)
param(
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$Destination
)
$targetHost = if ($env:RPI_HOST) { $env:RPI_HOST } else { "100.92.169.70" }
$askpass = Join-Path $PSScriptRoot "askpass_rpi.bat"
if (Test-Path $askpass) {
    $env:SSH_ASKPASS = $askpass
    $env:SSH_ASKPASS_REQUIRE = "force"
    $env:DISPLAY = "1"
}
scp -o StrictHostKeyChecking=no "$Source" "pi@${targetHost}:${Destination}"
