# Tailscale 초간단 3분 설치 및 원격 연결 가이드

본 문서는 Raspberry Pi 5에 아직 **Tailscale 가상 사설망(VPN)**을 설정하지 않은 팀원을 위한 **단계별 쉬운 설정 매뉴얼**입니다.

Tailscale을 설정해 두면 공유기 포트포워딩이나 복잡한 네트워크 설정 없이, **강의실, 집, 카페 등 어디서나 PC와 RPi 5를 인터넷으로 안전하게 1:1 직결**할 수 있습니다.

---

## 0단계. RPi 5에 처음 접속하기 (초기 진입 방법)

Tailscale을 설치하려면 먼저 라즈베리파이 터미널에 접속하여 명령어를 입력할 수 있어야 합니다. 순정 라즈베리파이 OS는 USB 가젯(직결) 모드가 기본 활성화되어 있지 않으므로, 아래 3가지 방법 중 가능한 방식을 선택하세요:

### 방법 A: 모니터(Micro HDMI) + USB 키보드 직결 (가장 확실함 ⭐)
* 라즈베리파이에 Micro-HDMI 모니터와 USB 키보드를 직접 꽂고 전원을 켭니다.
* 바탕화면이 뜨면 상단 터미널 아이콘(또는 단축키 `Ctrl + Alt + T`)을 열어 곧바로 명령어를 입력합니다.

### 방법 B: 같은 Wi-Fi 또는 유선 공유기(LAN) 연결 후 접속 (Headless 추천)
* 라즈베리파이를 공유기 랜선에 꽂거나 Wi-Fi에 연결합니다.
  *(참고: Raspberry Pi Imager로 OS를 구울 때 사전에 Wi-Fi와 SSH 설정을 입력해 두었다면 부팅 시 자동으로 Wi-Fi에 연결됩니다.)*
* 동일한 네트워크(공유기)에 연결된 PC의 PowerShell을 열고 호스트 이름으로 접속합니다:
  ```powershell
  ssh pi@raspberrypi.local
  # 패스워드: 1 (또는 Imager에서 본인이 설정한 비밀번호)
  ```

### 방법 C: USB-C 케이블 직결 (사전 설정된 키트 전용)
* **주의**: 이 방식은 `config.txt`와 네트워크 설정에 **USB Gadget 이더넷(`dwc2`, `g_ether`)이 사전에 구성된 교육용 기기에서만 작동**합니다.
* 사전 설정된 기기의 경우 USB-C 케이블로 PC와 직결 후 고정 IP로 접속 가능합니다:
  ```powershell
  ssh pi@10.12.194.1
  ```

---

## 1단계. RPi 5에 Tailscale 설치 및 활성화 (2분 소요)

RPi 5 터미널에서 다음 3개 명령어를 순서대로 실행합니다:

### 1) Tailscale 원클릭 설치 스크립트 실행
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### 2) Tailscale 시작 및 계정 인증
```bash
sudo tailscale up
```
* 명령어를 입력하면 터미널에 인증 URL이 출력됩니다:
  ```text
  To authenticate, visit:
          https://login.tailscale.com/a/123456789abc
  ```
* 위 URL을 마우스로 복사하여 **PC 또는 스마트폰 웹 브라우저** 주소창에 붙여넣습니다.
* **Google, GitHub, Microsoft** 계정 중 원하는 계정으로 1초 만에 로그인합니다.
* 인증이 완료되면 RPi 터미널에 **`Success.`** 메시지가 뜨며 연결이 완료됩니다.

### 3) 내 RPi의 고유 IP 확인 (메모 필수!)
```bash
tailscale ip -4
# 출력 예시: 100.115.24.89 (기기마다 숫자가 완전히 다릅니다)
```
> [!IMPORTANT]
> 화면에 출력된 **`100.x.y.z`** 주소가 본인 RPi의 고유 주소입니다. 이 주소를 메모해 두세요!

### 4) 부팅 시 자동 실행 등록
```bash
sudo systemctl enable --now tailscaled
```
이제 라즈베리파이를 재부팅해도 전원만 켜지면 자동으로 Tailscale에 연결됩니다.

---

## 2단계. 내 PC(Windows/Mac)에 Tailscale 설치

RPi와 통신할 내 개발자 PC에도 Tailscale이 켜져 있어야 합니다.

1. **PC용 클라이언트 다운로드**:
   - [Tailscale 공식 다운로드 페이지 (Windows/macOS)](https://tailscale.com/download)에서 설치 파일을 받아 설치합니다.
2. **로그인**:
   - Windows 작업표시줄 우측 하단의 Tailscale 트레이 아이콘을 우클릭 ➡️ `Log in...` 클릭.
   - **⚠️ 중요**: **1단계에서 RPi 5를 인증할 때 사용했던 동일한 계정(Google/GitHub 등)**으로 로그인해야 같은 사설망(Tailnet)으로 묶입니다.
3. **연결 확인**:
   - Tailscale 트레이 아이콘을 클릭했을 때 내 라즈베리파이 기기 이름(예: `raspberrypi` 또는 `pi5`)이 목록에 보이면 성공입니다.

---

## 3단계. PC에서 RPi 5로 원격 SSH 접속 테스트

이제 PC의 PowerShell을 열고 메모해 둔 본인의 `100.x.y.z` IP로 접속해 봅니다:

### 1) 일반 SSH 터미널 접속
```powershell
ssh pi@100.x.y.z
# 패스워드: 1
```

### 2) 제공된 유틸리티 스크립트 활용
```powershell
# 현재 세션에 본인 IP 지정
$env:RPI_HOST = "100.x.y.z"

# RPi 5 원격 접속 (비밀번호 자동 입력)
.\utils\ssh_rpi.ps1

# 또는 RPi 5에 원격 명령어 1회성 실행
.\utils\ssh_rpi.ps1 "uname -a"
```

---

## 4단계. (선택) 팀원 간에 서로 다른 계정을 쓸 때 RPi 보드 공유하는 법

팀원들이 서로 다른 개인 구글 계정으로 Tailscale을 쓰고 있다면, 장비 공유(Share) 기능을 사용하면 됩니다:

1. PC 웹 브라우저에서 [Tailscale 관리자 콘솔(Machines)](https://login.tailscale.com/admin/machines)에 접속.
2. 내 라즈베리파이 기기 우측의 **`...` (더보기 버튼)** ➡️ **`Share...`** 클릭.
3. 생성된 **초대 링크(Invite Link)**를 팀원에게 전달하거나 팀원 이메일을 입력.
4. 팀원이 링크를 열어 수락하면, 팀원의 PC에서도 내 라즈베리파이의 `100.x.y.z` IP로 즉시 접속할 수 있습니다.

---

## 자주 묻는 질문 (FAQ)

### Q1. IP가 기억나지 않아요. 어디서 확인하나요?
* RPi5 터미널이 열려 있다면: `tailscale ip -4`
* PC 웹 브라우저에서: [Tailscale Admin Machines 콘솔](https://login.tailscale.com/admin/machines)에 로그인하면 등록된 모든 기기의 이름과 100.x.y.z IP가 실시간으로 표시됩니다.

### Q2. PC에서 `ssh pi@100.x.y.z`를 했는데 연결 시간 초과(Timeout)가 뜹니다.
1. PC의 Tailscale이 `Connected` 상태인지 트레이 아이콘을 확인하세요.
2. PC와 RPi 5가 **동일한 계정**으로 로그인되어 있는지 확인하세요.
3. RPi 5가 인터넷(Wi-Fi 또는 이더넷)에 정상 연결되어 있는지 확인하세요.
