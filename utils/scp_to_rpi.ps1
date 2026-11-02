# ==============================================================================
# Raspberry Pi 5 SCP 파일 전송기 (utils/scp_to_rpi.ps1)
# ==============================================================================
# ⚠️ [필독 - 기기별 IP 설정 안내]
# Tailscale IP는 라즈베리파이 기기마다 완전히 다릅니다.
# 반드시 본인이 사용하는 라즈베리파이의 IP를 지정해야 합니다!
# ==============================================================================
param(
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$Destination,
    [string]$HostIp = ""
)

# 기본값 (본인 RPi IP로 변경 가능)
$DEFAULT_HOST = ""

$targetHost = if (![string]::IsNullOrWhiteSpace($HostIp)) {
    $HostIp
} elseif ($env:RPI_HOST) { 
    $env:RPI_HOST 
} elseif (![string]::IsNullOrWhiteSpace($DEFAULT_HOST)) { 
    $DEFAULT_HOST 
} else { 
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host " ⚠️  Raspberry Pi IP 주소 입력 필요" -ForegroundColor Yellow
    Write-Host " Tailscale IP는 기기마다 다릅니다." -ForegroundColor Yellow
    Write-Host " 본인 RPi 터미널에서 'tailscale ip -4'로 확인한 IP를 입력하세요." -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Yellow
    $prompted = Read-Host "파일을 전송할 본인의 RPi IP 입력 (예: 100.x.y.z)"
    if ([string]::IsNullOrWhiteSpace($prompted)) {
        Write-Error "[오류] IP가 입력되지 않아 파일 전송을 중단합니다."
        exit 1
    }
    $prompted
}

$askpass = Join-Path $PSScriptRoot "askpass_rpi.bat"
if (Test-Path $askpass) {
    $env:SSH_ASKPASS = $askpass
    $env:SSH_ASKPASS_REQUIRE = "force"
    $env:DISPLAY = "1"
}

Write-Host "[INFO] Copying '$Source' to 'pi@${targetHost}:${Destination}'..." -ForegroundColor Cyan
scp -o StrictHostKeyChecking=no "$Source" "pi@${targetHost}:${Destination}"
