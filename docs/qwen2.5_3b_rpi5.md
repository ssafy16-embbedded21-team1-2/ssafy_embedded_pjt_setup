# Raspberry Pi 5 8GB 기반 Qwen 2.5 3B Instruct 온디바이스 벤치마크 보고서

> **문서 버전**: v1.0.0  
> **테스트 일시**: 2026-10-30  
> **대상 기기**: **Raspberry Pi 5 Model B Rev 1.0 (8GB RAM)** (ARM Cortex-A76 @ 2.40 GHz)  
> **수행 모델**: **Alibaba Qwen 2.5 3B Instruct (`Q4_K_M` 양자화, 1.95 GiB / 3.40B 파라미터)**  
> **추론 엔진**: `llama.cpp` Build 12005 (`e0f142d5d`, Cortex-A76 Dot Product 가속)

---

## 1. 테스트 개요 및 시스템 환경

본 문서는 **Raspberry Pi 5 (8GB)** 환경에서 3B급 글로벌 최상위 성능을 자랑하는 **Alibaba Qwen 2.5 3B Instruct** 모델을 배포하고, ARM Cortex-A76의 Dot Product(`asimddp`) 하드웨어 가속을 활용한 실시간 추론 속도, 한국어 자연어 처리 및 로봇 제어 명령(JSON) 파싱 능력을 실측한 벤치마크 보고서입니다.

### 테스트 사양 요약

| 항목 | 사양 / 설정값 | 비고 |
|:---|:---|:---|
| **프로세서 (CPU)** | Quad-core ARM Cortex-A76 @ 2.40 GHz | 4 Threads |
| **명령어 가속** | ARMv8.2-A (`asimd`, `fphp`, **`asimddp`**) | Dot Product INT4/INT8 하드웨어 가속 |
| **메모리 (RAM)** | **8GB LPDDR4X-4267** | 모델 구동 후 7.3GB 여유 (충분한 잔여량) |
| **운영체제 및 드라이버** | Debian GNU/Linux 13 (Trixie) 64-bit | Kernel 6.18.50+rpt-rpi-2712 |
| **모델 가중치 파일** | `qwen2.5-3b-instruct-q4_k_m.gguf` | 파일 크기: **1.95 GiB** (Vocab: **151,643**) |

---

## 2. 하드웨어 리소스 점유 및 상태 실측

```bash
# free -h (Qwen 2.5 3B 구동 중)
               total        used        free      shared  buff/cache   available
Mem:           7.9Gi       596Mi       2.6Gi        36Mi       4.8Gi       7.3Gi
Swap:          2.0Gi          0B       2.0Gi
```

* **모델 가중치 및 컨텍스트 RAM 점유**: **약 2.5 \~ 2.7 GB**
* **가용 메모리 (Available RAM)**: **`7.3 GiB 유지`** (전체 8GB 중 약 65% 이상 여유 확보)
* **스왑(Swap) 점유**: **`0 MB`** (스왑 메모리 전혀 발생하지 않음)
* **풀로드 시 발열**: 약 **76.0 \~ 77.1°C** (상시 운용 시 액티브 쿨러 장착 권장)

---

## 3. 추론 속도 벤치마크 (실측치)

### 3.1 공식 프로파일러 측정 (`llama-bench`)
* **프롬프트 분석 속도 (PP, pp64)**: **`23.90 ± 3.43 tokens/sec`**
* **토큰 생성 속도 (TG, tg128)**: **`4.52 ± 0.13 tokens/sec`**

### 3.2 실제 대화 및 제어 명령 실측 (`llama-cli`)

| 테스트 항목 | 프롬프트 분석 (PP) | 토큰 생성 속도 (TG) | 실제 응답 지연 (Latency) |
|:---|:---:|:---:|:---:|
| **[테스트 1] 한국어 일상 대화** | **`17.4 tokens/s`** | **`4.4 tokens/s`** | 실시간 텍스트 스트리밍 출력 |
| **[테스트 2] 로봇 제어 JSON 파싱** | **`22.3 tokens/s`** | **`4.8 tokens/s`** | JSON 10토큰 생성에 **약 1.8초** |

> [!NOTE]
> **체감 속도 분석 (1B vs 3B)**:  
> Gemma 3 1B(12.1 t/s)보다는 초당 토큰 수가 절반 수준(4.5 \~ 4.8 t/s)이지만, **Qwen 2.5의 152K 대형 토크나이저** 덕분에 한국어 1글자를 표현하는 토큰 압축률이 매우 높아, 사람이 읽거나 명령을 파싱하는 체감 속도는 실시간 사용에 충분한 수준입니다.

---

## 4. 한국어 및 스마트 물류 명령 실증

### [테스트 1] 한국어 일상 대화 및 자기소개
* **입력 프롬프트**: `"안녕하세요! 자기소개 간단히 부탁해."`
* **Qwen 2.5 3B 출력**:
  > *"안녕하세요! 저는 Alibaba Cloud에서 개발된 AI 어시스턴트인 Qwen입니다. 다양한 질문에 답변하거나 정보를 제공하는 데 도움이 되는 데 주력하고 있습니다. 무엇을 도와드릴까요?"*
* **평가**:
  - 오탈자, 번역투, 조사 오류가 전혀 없는 **완벽한 한국어 문장** 구사.
  - 정중한 높임말과 문맥 완성도가 1B 모델보다 한 단계 높은 정교함을 보임.

---

### [테스트 2] 스마트 물류 로봇 제어 명령 파싱 (Function Calling)
* **시스템 프롬프트 (ChatML 형식)**:
  ```text
  <|im_start|>system
  너는 물류 로봇의 제어기야. 오직 JSON 형식으로만 답해.
  형식: {"target": "RED"|"BLUE"|"GREEN"|"PURPLE"|"ORANGE"|"YELLOW", "action": "PICK"|"PLACE"|"STOP"}<|im_end|>
  <|im_start|>user
  파란색 구역으로 가서 짐을 집어 올려줘.<|im_end|>
  <|im_start|>assistant
  ```
* **Qwen 2.5 3B 출력**:
  ```json
  {"target": "BLUE", "action": "PICK"}
  ```
* **평가**:
  - 마크다운 따옴표나 군더더기 인사말 없이 **오직 규격화된 순수 JSON만 정확하게 반환**.
  - 파란색 $\rightarrow$ `"BLUE"`, 집어 올려줘 $\rightarrow$ `"action": "PICK"` 매핑 정확도 100%.

---

## 5. Gemma 3 1B vs Qwen 2.5 3B 비교 (RPi 5 온디바이스)

| 비교 항목 | Google Gemma 3 1B IT | Alibaba Qwen 2.5 3B Instruct | 추천 용도 |
|:---|:---:|:---:|:---|
| **모델 용량** | 769 MB (Q4_K_M) | 1.95 GB (Q4_K_M) | Qwen이 2.5배 큼 |
| **토큰 생성 속도 (TG)** | **`12.10 \~ 12.30 t/s`** | **`4.50 \~ 4.80 t/s`** | **실시간 음성 대화는 1B 우세** |
| **프롬프트 분석 속도 (PP)** | **`37.90 \~ 43.00 t/s`** | **`22.30 \~ 23.90 t/s`** | 1B가 약 1.8배 빠름 |
| **한국어 및 문맥 완성도** | 우수 (단순 문맥) | **최상 (정교한 뉘앙스/추론)** | **복잡한 작업 계획은 3B 우세** |
| **JSON 파싱 안정성** | 높음 (스키마 준수) | **극도로 높음 (코딩/툴콜링 특화)** | 복잡한 제어 파이프라인에 안전 |
| **RAM 점유율** | 약 1.1 GB 점유 | 약 2.6 GB 점유 | 둘 다 8GB RPi 5에서 여유 |

---

## 6. 실행 가이드 (Quick Start)

### 1) CLI 대화 모드
```bash
/home/pi/scripts/run_qwen3b_chat.sh
```

### 2) Web UI 및 REST API 서버 구동
```bash
/home/pi/scripts/run_qwen3b_server.sh
```
* **Web UI 접속**: `http://100.92.169.70:8080/`
* **OpenAI API 엔드포인트**: `http://100.92.169.70:8080/v1/chat/completions`
