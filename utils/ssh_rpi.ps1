# ==============================================================================
# Raspberry Pi 5 원격 SSH 자동 실행 스크립트 (utils/ssh_rpi.ps1)
# ==============================================================================
# [안내]
# Tailscale IP 주소(100.x.y.z)는 사용하는 라즈베리파이 기기마다 고유하게 부여됩니다.
#
# 접속 대상 IP를 지정하는 3가지 방법:
# 1) 환경 변수 지정 (현재 PowerShell 세션에 유지):
#    $env:RPI_HOST = "100.x.y.z"   (Tailscale IP)
#    $env:RPI_HOST = "10.12.194.1" (USB Gadget 케이블 직결 시)
#
# 2) 일회성 실행:
#    $env:RPI_HOST = "100.x.y.z"; .\utils\ssh_rpi.ps1 "명령어"
#
# 3) 스크립트 기본값 영구 수정:
#    아래 $DEFAULT_HOST 값을 본인의 라즈베리파이 Tailscale IP로 변경하세요.
# ==============================================================================

# 기본값 (사용자별 RPi의 Tailscale IP로 변경 가능)
$DEFAULT_HOST = "100.92.169.70"

$targetHost = if ($env:RPI_HOST) { $env:RPI_HOST } else { $DEFAULT_HOST }

# 비대화형 자동 비밀번호 인증 설정 (askpass_rpi.bat: 기본 비밀번호 '1')
$askpassPath = Join-Path $PSScriptRoot "askpass_rpi.bat"
if (Test-Path $askpassPath) {
    $env:SSH_ASKPASS = $askpassPath
    $env:SSH_ASKPASS_REQUIRE = "force"
    $env:DISPLAY = "1"
}

$cmd = $args -join ' '

if ([string]::IsNullOrWhiteSpace($cmd)) {
    # 인자가 없으면 대화형 터미널 쉘 접속
    Write-Host "[INFO] Connecting to Raspberry Pi 5 ($targetHost)..." -ForegroundColor Cyan
    ssh -o StrictHostKeyChecking=no "pi@$targetHost"
} else {
    # 인자가 있으면 원격 명령 실행 후 결과 반환
    ssh -o StrictHostKeyChecking=no "pi@$targetHost" "$cmd"
}
