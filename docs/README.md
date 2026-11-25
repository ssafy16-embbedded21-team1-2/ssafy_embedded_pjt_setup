# `docs/` 문서 안내 및 디렉토리 분류

`ssafy_embedded_pjt_setup` 저장소의 문서를 역할별로 분류한 인덱스입니다.

| 디렉토리 | 포함 범위 |
| :--- | :--- |
| [`architecture/`](architecture) | 시스템 아키텍처 v3.4, 보드·Agent Tool 인터페이스, 진단 시나리오, 검증 계획 |
| [`guides/`](guides) | STM32 · RPi 5 · Tailscale 환경 구축, 운영 설정, 실물 보드 등록 가이드 |
| [`hardware/`](hardware) | RPi 5 CAN HAT 핀 점검·전압 측정·첫 CAN 통신 시험 기록, CLI 명령어, 부품 목록 |
| [`benchmarks/`](benchmarks) | 온디바이스 SLM (`Qwen 2.5 3B`, `Qwen 3 4B`, `Gemma 3 1B`) 성능 비교 |
| [`meetings/`](meetings) | CAN 통신 규약 합의 회의 템플릿, 아키텍처 호환성 분석 |
| [`학습자료/`](학습자료/README.md) | CAN · STM32 · SocketCAN · DBC · ISO-TP/UDS 단계별 온보딩 자료 |
| [`board_records/`](board_records) | 실물 `NUCLEO-F103RB` 보드 수집 기록 (`collection.json`, `README.md`) |
| [`archive/`](archive) | 이전 v2 USB/SWD 직결 설계 보관본 |

---

## 1. 아키텍처 · 진단 설계 (`architecture/`)

* [차량용_CAN_통신_도입_및_아키텍처_설계.md](architecture/차량용_CAN_통신_도입_및_아키텍처_설계.md) — `[설계 v3.4]` `NUCLEO-F103RB` 2대(보드 A·B) + RPi 5 단일 Classic CAN(`500 kbps`) 아키텍처
* [설계_장비별기능_및_AgentTool인터페이스.md](architecture/설계_장비별기능_및_AgentTool인터페이스.md) — `[설계 v3.4]` 보드 A·B 기능 명세, CAN/UART/SWD Tool 계약, L0\~L4 진단 흐름
* [장비_정보_기반_검증_계획.md](architecture/장비_정보_기반_검증_계획.md) — 검증 우선 범위, 준비 자료 체크리스트 및 수용 기준
* [CAN_현장_통신불량_진단_시나리오_설계.md](architecture/CAN_현장_통신불량_진단_시나리오_설계.md) — 현장 CAN 통신 불량 진단 시나리오 및 고장 주입·복구 기준
* [ECU_GPIO_출력열화_자가진단_시나리오_설계.md](architecture/ECU_GPIO_출력열화_자가진단_시나리오_설계.md) — RP1/GPIO 출력 전압 열화 결함 사례 기반 3계층 BIST 시나리오

## 2. 개발 · 운영 · 등록 가이드 (`guides/`)

* [STM32_빠른_시작.md](guides/STM32_빠른_시작.md) — Windows 도구 설치, CubeIDE / VS Code `NUCLEO-F103RB` 빠른 시작
* [stm32_개발_환경_구축_가이드.md](guides/stm32_개발_환경_구축_가이드.md) — `NUCLEO-F103RB` 개발 환경 및 Classic CAN(`bxCAN`) 설정 가이드
* [stm32_디버깅_작업_가이드.md](guides/stm32_디버깅_작업_가이드.md) — SWD 코어 디버깅 및 Classic CAN·UART 진단 매뉴얼
* [STM32 보드 등록 가이드.md](<guides/STM32 보드 등록 가이드.md>) — ST-LINK / pyOCD / SVD 기반 실물 STM32 보드 등록 절차
* [STM32 보드 등록 템플릿.md](<guides/STM32 보드 등록 템플릿.md>) — 신규 보드 등록 시 작성하는 메타데이터 템플릿
* [setup_guide_rpi5_diagnosis_agent.md](guides/setup_guide_rpi5_diagnosis_agent.md) — RPi 5 신규 보드 진단 환경 구축 가이드
* [RPi5_런타임_운영_설정.md](guides/RPi5_런타임_운영_설정.md) — `systemd` 서비스, cgroup 메모리 제한, 쿨러 설정 기록
* [tailscale_초간단_설치_가이드.md](guides/tailscale_초간단_설치_가이드.md) — 팀원 PC/RPi 5 Tailscale 3분 설치 가이드

## 3. 하드웨어 실측 · CAN HAT 점검 (`hardware/`)

* [RPi5_F103_CAN_첫_통신_테스트.md](hardware/RPi5_F103_CAN_첫_통신_테스트.md) — 교체 RPi 5 ↔ `NUCLEO-F103RB` `0x100`/`0x123` 양방향 통신·UART 실측 완료 기록
* [RPi5_CAN_40핀_종합_점검_결과.md](hardware/RPi5_CAN_40핀_종합_점검_결과.md) — CAN HAT 40핀 점검, 보드 교차 시험 및 쿨러 검증 결과
* [RPi5_CAN_GPIO_추가_측정_요약.md](hardware/RPi5_CAN_GPIO_추가_측정_요약.md) — GPIO 전압 추가 측정 및 기존 RPi 5 RP1 고장 분리 확정
* [RPi5_CAN_초기_연결_점검_기록.md](hardware/RPi5_CAN_초기_연결_점검_기록.md) — 초기 SPI/IRQ 연결 점검 및 해결 이력
* [RPi5_CAN_HAT_전압_측정_가이드.md](hardware/RPi5_CAN_HAT_전압_측정_가이드.md) — 멀티미터를 이용한 CAN HAT·SPI/INT 핀 전압 점검 가이드
* [RPI5_CAN_HAT_명령어_모음.md](hardware/RPI5_CAN_HAT_명령어_모음.md) — `ip link`, `candump`, `cansend`, `/proc/interrupts` 수동 점검 명령어 모음
* [부품_구매_목록.csv](hardware/부품_구매_목록.csv) — 프로젝트 부품 구매 목록

## 4. 온디바이스 SLM 벤치마크 (`benchmarks/`)

* [qwen2.5_3b_rpi5.md](benchmarks/qwen2.5_3b_rpi5.md) — `Qwen 2.5 3B` RPi 5 실측 성능 보고서 (추천 1순위)
* [qwen3_4b_rpi5.md](benchmarks/qwen3_4b_rpi5.md) — `Qwen 3 4B` RPi 5 실측 성능 보고서
* [gemma3_1b_rpi5.md](benchmarks/gemma3_1b_rpi5.md) — `Gemma 3 1B` RPi 5 실측 성능 보고서
* [gemma3_1b_jetson_vs_rpi5.md](benchmarks/gemma3_1b_jetson_vs_rpi5.md) — `Gemma 3 1B` Jetson Orin Nano vs RPi 5 비교

## 5. 회의 · 협의 (`meetings/`) & 학습 자료 (`학습자료/`) & 보관본 (`archive/`)

* [CAN_통신규약_합의_회의_템플릿.md](meetings/CAN_통신규약_합의_회의_템플릿.md) — 보드 A·B·AI 간 CAN ID·신호·진단 규약 합의 템플릿
* [회의_아키텍처_호환성_분석.md](meetings/회의_아키텍처_호환성_분석.md) — 회의 후보안 vs CAN 진단 벤치 호환성 검토
* [회의 이미지.tldr](<meetings/회의 이미지.tldr>) — 회의 아키텍처 스케치 원본 (`tldraw`)
* [학습자료/README.md](학습자료/README.md) — CAN/STM32/SocketCAN/UDS 학습 자료 5부작 목차
* [%28OLD%29아키텍처_v2_RPi-STM32_진단Agent.md](archive/%28OLD%29아키텍처_v2_RPi-STM32_진단Agent.md) — 이전 v2 USB/SWD 직결 설계 보관본
