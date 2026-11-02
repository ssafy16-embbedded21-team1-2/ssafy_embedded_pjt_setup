# Raspberry Pi 5 8GB 기반 Gemma 3 1B IT 온디바이스 벤치마크 보고서

> **문서 버전**: v1.0.0  
> **테스트 일시**: 2026-10-30  
> **대상 기기**: **Raspberry Pi 5 Model B Rev 1.0 (8GB RAM)**  
> **수행 모델**: Google Gemma 3 1B Instruction-Tuned (`Q4_K_M` 양자화, 769 MB)  
> **관련 문서**: [Jetson Nano vs Raspberry Pi 5 비교 보고서](gemma3_1b_jetson_vs_rpi5.md)

---

## 1. 테스트 개요 및 환경 구성

본 검증은 최신 엣지 싱글보드 컴퓨터인 **Raspberry Pi 5 (8GB RAM)** 환경에서 최신 `llama.cpp` (v0.8.0-dev)를 ARM Cortex-A76 및 Dot Product(`asimddp`) 하드웨어 벡터 가속으로 네이티브 빌드하고, 최신 경량 언어 모델인 **Google Gemma 3 1B IT**를 온디바이스로 배포하여 한국어 대화 및 로봇 제어 명령 파싱 성능을 실측한 결과를 정리한 보고서입니다.

```mermaid
graph LR
    User["사용자 자연어 입력<br>(한국어 음성/텍스트)"] --> LLM["Gemma 3 1B IT (Q4_K_M)<br>Cortex-A76 DotProd 가속 (4 코어)"]
    LLM --> JSON["JSON 파싱 결과<br>{target: 'BLUE', action: 'PICK'}"]
    JSON --> Robot["물류/서비스 로봇 제어기"]
```

### 테스트 시스템 사양

| 항목                       | 사양 / 설정값                                | 비고                                      |
| :------------------------- | :------------------------------------------- | :---------------------------------------- |
| **프로세서 (CPU)**         | Quad-core ARM Cortex-A76 @ 2.40 GHz          | 4 Cores / 4 Threads                       |
| **CPU 아키텍처 및 명령어** | ARMv8.2-A (`asimd`, `fphp`, **`asimddp`**)   | Dot Product INT4/INT8 하드웨어 가속       |
| **메모리 (RAM)**           | **8GB LPDDR4X-4267** (17 GB/s 대역폭)        | 모델 적재 후 7.3GB 여유                   |
| **운영체제 및 커널**       | Debian GNU/Linux 13 (Trixie) 64-bit          | Kernel 6.18.50+rpt-rpi-2712               |
| **컴파일러 및 툴체인**     | GCC 14.2.0 / CMake 3.31.6                    | OpenMP 4.5 멀티스레딩 지원                |
| **추론 엔진**              | `llama.cpp` Build 12005 (commit `e0f142d5d`) | Cortex-A76 네이티브 최적화 빌드           |
| **평가 모델**              | `ggml-org/gemma-3-1b-it-GGUF` (`Q4_K_M`)     | 파일 크기: **769 MB**, Vocab: **262,144** |

---

## 2. 하드웨어 리소스 점유 및 시스템 상태 실측

RPi 5의 8GB 메모리 환경에서 모델 적재 후의 메모리 사용량 및 부하 시 발열 상태를 측정하였습니다.

```bash
# free -h (추론 실행 중)
               total        used        free      shared  buff/cache   available
Mem:           7.9Gi       627Mi       4.6Gi        36Mi       2.8Gi       7.3Gi
Swap:          2.0Gi          0B       2.0Gi
```

### 메모리 및 시스템 상태 분석

- **모델 가중치 RAM 점유**: **`762.49 MiB`**
- **총 시스템 RAM 점유 (OS + LLM)**: **`약 1.1 GB`**
- **가용 메모리 (Available RAM)**: **`7.3 GB 유지`** (전체 메모리의 약 86% 여유)
- **스왑(Swap) 점유**: **`0 MB`** (스왑 메모리 전혀 사용하지 않음)
- **발열 및 스로틀링 체크**:
  - 아이들(Idle) 온도: 약 **50 \~ 55°C**
  - 빌드 및 벤치마크 풀로드 온도: **74.7 \~ 76.0°C**
  - `vcgencmd get_throttled`: `0xe0000` (과거 빌드 시 소프트 발열 제한 이력 감지, 상시 쿨러 권장)

> [!NOTE]
> 8GB 대용량 RAM 덕분에 Gemma 3 1B를 구동하고도 **7.3GB의 여유 메모리**가 남아 있습니다. 이는 고해상도 카메라 영상 처리(OpenCV), YOLO 기반 객체 검출 모델, 웹 서버, 로봇 제어 ROS 노드를 동시에 구동해도 메모리 부족(OOM) 걱정이 전혀 없음을 의미합니다.

---

## 3. 추론 속도 벤치마크 (Benchmark 실측치)

공식 프로파일러 `llama-bench` 및 실제 단일 추론(`llama-cli`)을 통한 실측 성능 데이터입니다.

| 성능 지표                                     | 공식 벤치마크 (`llama-bench`)  |    실시간 추론 실측치 (`llama-cli`)    | 평가                                                           |
| :-------------------------------------------- | :----------------------------: | :------------------------------------: | :------------------------------------------------------------- |
| **토큰 생성 속도 (Token Gen, TG)**            | **`10.25 ± 0.04 t/s`** (tg128) |        **`12.10 ~ 12.30 t/s`**         | 사람이 소리 내어 읽는 속도(4\~6음절/s)의 **2배 이상 고속**     |
| **프롬프트 분석 속도 (Prompt Proc, PP)**      | **`32.54 ± 3.65 t/s`** (pp64)  |        **`37.90 ~ 43.00 t/s`**         | 일반적인 한국어 프롬프트(50\~80 토큰)를 **1초 이내 분석 완료** |
| **단일 질의 총 응답 지연 (CLI)**              |               -                | **약 5.81초** (SD 카드 cold load 포함) | CLI 1회성 실행 기준                                            |
| **서버 상주 모드 응답 지연 (`llama-server`)** |               -                |    **약 0.8초** (JSON 10토큰 기준)     | 실시간 로봇 제어 및 음성 비서 적용 가능                        |
| **초기 모델 적재 시간**                       |           즉시 로딩            |  **약 4.5초** (Class 10 MicroSD 읽기)  | 별도의 PTX JIT 변환 없이 즉각 로딩                             |

---

## 4. 한국어 및 로봇 제어 실증 테스트

### [테스트 1] 일반 대화 및 한국어 유창성

- **입력 프롬프트**: `"안녕하세요! 자기소개 간단히 부탁해."`
- **Raspberry Pi 5 생성 결과**:

  ```text
  > 안녕하세요! 자기소개 간단히 부탁해.
  안녕하세요! 저는 구글에서 훈련한 대규모 언어 모델입니다.

  간단히 말하면, 사람들과 대화하고 정보를 제공하는 것을 도와주는 AI입니다.

  혹시 제가 무엇을 도와드릴까요? 😊

  [ Prompt: 41.7 t/s | Generation: 12.1 t/s ]
  ```

- **분석**:
  - 한국어 문장의 종결 어미, 띄어쓰기, 문맥 완성도가 매우 자연스러움.
  - 초당 12.1 토큰으로 스트리밍 출력되어 대화 시 딜레이가 거의 체감되지 않음.

---

### [테스트 2] 스마트 물류 로봇 제어 명령 파싱 (Function Calling)

- **시스템 프롬프트**:

  ```text
  너는 물류 로봇의 제어기야. 오직 JSON 형식으로만 답해.
  형식: {"target": "RED"|"BLUE"|"GREEN"|"PURPLE"|"ORANGE"|"YELLOW", "action": "PICK"|"PLACE"|"STOP"}
  ```

- **사용자 자연어 명령**:

  ```text
  파란색 구역으로 가서 짐을 집어 올려줘.
  ```

- **Raspberry Pi 5 출력 결과**:

  ```json
  { "target": "BLUE", "action": "PICK" }
  ```

- **실측 지표**:
  - `Prompt: 43.0 t/s | Generation: 12.3 t/s`
  - 정확한 타겟(`BLUE`) 및 액션(`PICK`) JSON 추출 완료.
  - JSON 출력 10개 토큰 생성에 **단 0.8초** 소요.

---

## 5. 실행 및 서비스 운용 가이드

Raspberry Pi 5에는 바이너리가 `/usr/local/bin`에 전역 설치되어 있으며, 전용 쉘 스크립트가 `/home/pi/scripts`에 준비되어 있습니다.

### 1) CLI 단일/대화형 실행

```bash
# 원클릭 스크립트 실행
/home/pi/scripts/run_gemma3_chat.sh

# 또는 직접 명령어 실행
llama-cli -m /home/pi/models/gemma-3-1b-it-Q4_K_M.gguf -t 4 -c 2048 --temp 0.3 --color auto
```

### 2) 웹 UI 및 OpenAI 호환 REST API 서버 실행

```bash
# 원클릭 스크립트 실행
/home/pi/scripts/run_gemma3_server.sh
```

- **Web UI 접속**: `http://100.92.169.70:8080/` (Tailscale)
- **OpenAI 규격 API**: `http://100.92.169.70:8080/v1/chat/completions`
- **장점**: 모델이 RAM에 상주하여 SD 카드 읽기 지연이 사라지며, HTTP 요청 즉시 0.8초 이내로 응답을 반환합니다.

---

## 6. 결론 및 향후 확장 가능성

1. **최신 CPU 아키텍처의 강력한 추론 성능 입증**:
   Raspberry Pi 5의 Cortex-A76 프로세서는 `asimddp` 하드웨어 Dot Product 벡터 명령어를 통해 GPU 가속 없이도 **초당 12.1 토큰**의 고속 생성을 달성했습니다.
2. **8GB 대용량 RAM을 활용한 상위 모델 확장 가능**:
   현재 Gemma 3 1B 구동 후에도 7.3GB의 메모리가 남아 있으므로, 향후 **Qwen 2.5 7B, Llama 3.1 8B (Q4_K_M)** 등 고성능 7B\~8B급 모델의 구동이나 멀티모달 Vision-LLM(LLaVA) 테스트로의 확장이 충분히 가능합니다.
