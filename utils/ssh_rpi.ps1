# Raspberry Pi 5 자동 인증 SSH 실행기 (utils/ssh_rpi.ps1)
$targetHost = if ($env:RPI_HOST) { $env:RPI_HOST } else { "100.92.169.70" }
$env:SSH_ASKPASS = Join-Path $PSScriptRoot "askpass_rpi.bat"
$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "1"
$cmd = $args -join ' '
ssh -o StrictHostKeyChecking=no "pi@$targetHost" "$cmd"
