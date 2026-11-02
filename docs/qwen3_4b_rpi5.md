# Raspberry Pi 5 8GB 기반 Qwen 3 4B (Thinking Mode) 온디바이스 벤치마크 보고서

> **문서 버전**: v1.0.0  
> **테스트 일시**: 2026-11-02  
> **대상 기기**: **Raspberry Pi 5 Model B Rev 1.0 (8GB RAM)** (ARM Cortex-A76 @ 2.40 GHz)  
> **수행 모델**: **Alibaba Qwen 3 4B (`Q4_K_M` 양자화, 2.32 GiB / 4.02B 파라미터)**  
> **추론 엔진**: `llama.cpp` Build 12005 (`e0f142d5d`, Cortex-A76 Dot Product 가속)

---

## 1. 테스트 개요 및 시스템 환경

본 문서는 **Raspberry Pi 5 (8GB)** 환경에서 내장 사고 모드(Reasoning / Thinking Mode)를 탑재한 **Alibaba Qwen 3 4B** 모델을 배포하고, ARM Cortex-A76의 Dot Product(`asimddp`) 하드웨어 가속을 활용한 실시간 추론 속도, 사고 모드 동작 특성, 한국어 처리 및 물류 로봇 제어 명령(JSON) 파싱 능력을 실측한 벤치마크 보고서입니다.

### 테스트 사양 요약

| 항목 | 사양 / 설정값 | 비고 |
|:---|:---|:---|
| **프로세서 (CPU)** | Quad-core ARM Cortex-A76 @ 2.40 GHz | 4 Cores / 4 Threads |
| **명령어 가속** | ARMv8.2-A (`asimd`, `fphp`, **`asimddp`**) | Dot Product INT4/INT8 하드웨어 가속 |
| **메모리 (RAM)** | **8GB LPDDR4X-4267** | 모델 구동 후 4.2GB Free / 7.3GB 가용 |
| **운영체제 및 드라이버** | Debian GNU/Linux 13 (Trixie) 64-bit | Kernel 6.18.50+rpt-rpi-2712 |
| **모델 가중치 파일** | `Qwen3-4B-Q4_K_M.gguf` | 파일 크기: **2.32 GiB** (파라미터: **4.02B**) |

---

## 2. 하드웨어 리소스 점유 및 상태 실측

```bash
# free -h (Qwen 3 4B 추론 중)
               total        used        free      shared  buff/cache   available
Mem:           7.9Gi       577Mi       4.2Gi        35Mi       3.2Gi       7.3Gi
Swap:          2.0Gi          0B       2.0Gi
```

* **모델 가중치 및 KV 캐시 RAM 점유**: **약 2.8 \~ 3.2 GB**
* **가용 메모리 (Available RAM)**: **`7.3 GiB 유지`** (전체 8GB 중 절반 이상 여유)
* **스왑(Swap) 점유**: **`0 MB`** (스왑 메모리 전혀 발생하지 않음)
* **풀로드 시 발열**: 약 **79.8°C** (사고 모드로 장시간 4코어 100% 가동 시 액티브 쿨러 필수)

---

## 3. 추론 속도 벤치마크 (실측치)

### 3.1 공식 프로파일러 측정 (`llama-bench`)
* **프롬프트 분석 속도 (PP, pp64)**: **`16.60 ± 1.97 tokens/sec`**
* **토큰 생성 속도 (TG, tg128)**: **`3.49 ± 0.06 tokens/sec`**

### 3.2 실제 대화 및 제어 명령 실측 (`llama-cli`)

| 테스트 항목 | 프롬프트 분석 (PP) | 토큰 생성 속도 (TG) | 생성 토큰 구성 | 총 응답 지연 (Latency) |
|:---|:---:|:---:|:---|:---:|
| **[테스트 1] 한국어 일상 대화** | **`13.3 tokens/s`** | **`3.3 tokens/s`** | 사고 토큰 160개 + 한국어 답변 50개 | 약 64초 |
| **[테스트 2] 로봇 제어 JSON 파싱** | **`13.8 tokens/s`** | **`3.2 tokens/s`** | 사고 토큰 130개 + JSON 10개 | 약 44초 |

---

## 4. 한국어 및 스마트 물류 제어 실증 (사고 모드 분석)

### [테스트 1] 한국어 일상 대화 및 자기소개
* **입력 프롬프트**: `"안녕하세요! 자기소개 간단히 부탁해."`
* **Qwen 3 4B 출력**:
  ```text
  [Start thinking]
  Okay, the user asked for a simple self-introduction. Let me start by thinking about what's necessary here. 
  They probably want a concise overview without too much detail. First, I should mention my name, which is Qwen...
  [End thinking]

  안녕하세요! 저는 Qwen입니다. 저는 인공지능 어시스턴트로, 질문에 답변하거나 콘텐츠를 생성하는 데 도움을 드릴 수 있습니다. 
  다양한 주제에 대한 정보를 제공하거나, 창의적인 아이디어를 도와드릴 수 있어요. 궁금한 점이 있으시면 언제든지 물어보세요! 😊
  ```
* **분석**:
  - 모델 내부에 **DeepSeek-R1 스타일의 Chain-of-Thought (사고 모드)**가 기본 탑재되어 있어, 최종 한국어 답변을 내놓기 전 영문으로 세부 계획을 수립하는 과정을 거칩니다.
  - 최종 한국어 답변 품질은 정중하고 완벽합니다.

---

### [테스트 2] 스마트 물류 로봇 제어 명령 파싱 (Function Calling)
* **시스템 프롬프트 (ChatML)**:
  ```text
  <|im_start|>system
  너는 물류 로봇의 제어기야. 오직 JSON 형식으로만 답해. 생각 과정이나 부가 설명 없이 바로 순수 JSON만 출력해.
  형식: {"target": "RED"|"BLUE"|"GREEN"|"PURPLE"|"ORANGE"|"YELLOW", "action": "PICK"|"PLACE"|"STOP"}<|im_end|>
  <|im_start|>user
  파란색 구역으로 가서 짐을 집어 올려줘.<|im_end|>
  <|im_start|>assistant
  ```
* **Qwen 3 4B 출력**:
  ```text
  [Start thinking]
  Okay, the user told me to go to the blue area and pick up the item. Let me break this down. 
  First, the instruction is to move to the BLUE region. Then, the action required is to pick up the cargo. 
  So, the target should be BLUE, and the action should be PICK. I need to make sure I'm using the exact JSON format specified. 
  Let me check the possible targets again: RED, BLUE, GREEN, PURPLE, ORANGE, YELLOW. Yes, BLUE is one of them. 
  The action options are PICK, PLACE, STOP. Since the user says to pick up the cargo, PICK is correct. 
  No need for any other actions here. Just confirm that the target is BLUE and the action is PICK. Alright, that should be it.
  [End thinking]

  {"target": "BLUE", "action": "PICK"}
  ```
* **분석**:
  - 시스템 프롬프트로 "생각 과정 없이 바로 출력하라"고 지시했음에도 불구하고, 내장된 사고 모드가 발동하여 타겟(`BLUE`)과 액션(`PICK`)의 스키마 유효성을 130토큰에 걸쳐 꼼꼼하게 자체 검증했습니다.
  - **정확도**: 100% 무결점 JSON 출력.
  - **속도 한계**: 10토큰짜리 JSON 결과를 얻기 위해 약 **44초**가 소요되었습니다.

---

## 5. RPi 5 온디바이스 3개 모델 종합 비교 (1B vs 3B vs 4B)

| 비교 항목 | Google Gemma 3 1B IT | Alibaba Qwen 2.5 3B Instruct | Alibaba Qwen 3 4B (Thinking) |
|:---|:---:|:---:|:---:|
| **파라미터 및 크기** | 1.0B (769 MB) | 3.4B (1.95 GB) | **4.0B (2.32 GB)** |
| **토큰 생성 속도 (TG)** | **`12.10 \~ 12.30 t/s` (최고속)** | `4.50 \~ 4.80 t/s` (표준) | `3.20 \~ 3.50 t/s` (심층) |
| **프롬프트 분석 (PP)** | **`37.90 \~ 43.00 t/s`** | `22.30 \~ 23.90 t/s` | `13.50 \~ 16.60 t/s` |
| **단순 명령 응답 지연** | **`0.8초`** (즉답) | **`1.8초`** (즉답) | **`44초`** (사고 모드 발생) |
| **추론 방식** | 단답형 직결 생성 | 정밀 인스트럭션 직결 | **내장 Chain-of-Thought (사고 모드)** |
| **RAM 점유** | 약 1.1 GB | 약 2.6 GB | 약 3.0 GB |
| **스마트 물류 AGV 적합도** | **실시간 음성/주행 제어 최적** | **엄격한 다단계 명령 파싱 최적** | 오프라인 복잡 경로 플래닝/분석 적합 |

---

## 6. 결론 및 실무 제언

1. **사고 모드(Thinking Mode)의 강력함과 엣지 지연시간의 트레이드오프**:
   * Qwen 3 4B는 4B 체급임에도 7B\~14B 수준의 심층 검증 및 추론 능력을 보여줍니다.
   * 다만 실시간 제어가 핵심인 물류 AGV 환경에서는 단순 명령 파싱에 사고 토큰 100개 이상이 소모되어 40초 이상의 지연이 발생하므로, **실시간 로봇 제어에는 Qwen 2.5 3B 또는 Gemma 3 1B가 실무적으로 훨씬 적합**합니다.
2. **Qwen 3 4B의 최적 활용 시나리오**:
   * 1회성 배치 작업, 복잡한 물류 창고 다단계 최적화 경로 계산, 고장 진단 및 사후 보고서 자동 생성 등 **시간이 걸려도 깊은 추론이 필요한 고급 작업**에 최적입니다.
