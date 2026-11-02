# ==============================================================================
# Raspberry Pi 5 원격 SSH 실행 스크립트 (utils/ssh_rpi.ps1)
# ==============================================================================
# ⚠️ [필독 - 기기별 IP 설정 안내]
# Tailscale 가상 IP(100.x.y.z)는 라즈베리파이 기기마다 완전히 다르게 부여됩니다.
# 다른 팀원의 IP나 예시 IP를 사용하면 다른 사람의 보드에 접속되거나 연결이 실패합니다.
# 반드시 본인이 사용하는 라즈베리파이에서 'tailscale ip -4'를 실행하여 확인한
# 【본인 기기의 고유 IP】를 지정해야 합니다!
#
# [접속 IP 지정 방법 3가지]
# 1) 본인 IP 기본값 등록 (영구): 아래 $DEFAULT_HOST에 본인 RPi IP를 입력
# 2) PowerShell 환경 변수 지정: $env:RPI_HOST = "100.x.y.z"
# 3) 미설정 시 실행하면 터미널에서 본인 IP를 입력받도록 안내됩니다.
# ==============================================================================

# [설정] 본인이 사용할 라즈베리파이 IP를 입력해 두세요. (예: "100.92.169.70")
# 비워둘 경우 $env:RPI_HOST 또는 대화형 입력을 통해 지정합니다.
$DEFAULT_HOST = ""

$targetHost = if ($env:RPI_HOST) { 
    $env:RPI_HOST 
} elseif (![string]::IsNullOrWhiteSpace($DEFAULT_HOST)) { 
    $DEFAULT_HOST 
} else { 
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host " ⚠️  Raspberry Pi IP 주소 입력 필요" -ForegroundColor Yellow
    Write-Host " Tailscale IP는 기기마다 다릅니다." -ForegroundColor Yellow
    Write-Host " 본인 RPi 터미널에서 'tailscale ip -4'로 확인한 IP를 입력하세요." -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Yellow
    $prompted = Read-Host "접속할 본인의 RPi IP 입력 (예: 100.x.y.z 또는 10.12.194.1)"
    if ([string]::IsNullOrWhiteSpace($prompted)) {
        Write-Error "[오류] IP가 입력되지 않아 종료합니다. 본인의 RPi IP를 지정해 주세요."
        exit 1
    }
    $prompted
}

# 비대화형 자동 비밀번호 인증 설정 (askpass_rpi.bat: 기본 비밀번호 '1')
$askpassPath = Join-Path $PSScriptRoot "askpass_rpi.bat"
if (Test-Path $askpassPath) {
    $env:SSH_ASKPASS = $askpassPath
    $env:SSH_ASKPASS_REQUIRE = "force"
    $env:DISPLAY = "1"
}

$cmd = $args -join ' '

if ([string]::IsNullOrWhiteSpace($cmd)) {
    Write-Host "[INFO] Connecting to Raspberry Pi ($targetHost)..." -ForegroundColor Cyan
    ssh -o StrictHostKeyChecking=no "pi@$targetHost"
} else {
    ssh -o StrictHostKeyChecking=no "pi@$targetHost" "$cmd"
}
