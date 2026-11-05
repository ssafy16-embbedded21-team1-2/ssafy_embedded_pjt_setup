# RPi5 Docker 메모리 제한과 Qwen 자동 시작

대상은 `pi@100.92.169.70` (`pi32`)의 Raspberry Pi OS / Debian 13, RPi 커널 `6.18.50+rpt-rpi-2712`입니다. 2026-11-05에 기존 Agent 환경을 유지하면서 적용한 작업을 기록합니다.

## Docker 메모리 컨트롤러 활성화

이 기기는 커널에 `CONFIG_MEMCG=y`가 있지만 `/sys/fs/cgroup/cgroup.controllers`에 `memory`가 없고, Docker에서 `memory=false swap=false`로 표시되었습니다. 기존 Agent 컨테이너의 실제 메모리 제한도 0이었습니다.

RPi 펌웨어는 기본 커널 인자에 `cgroup_disable=memory`를 넣을 수 있습니다. 최근 RPi 커널에서는 `cmdline.txt`에 그보다 나중에 적용되는 `cgroup_enable=memory`를 추가해 활성화할 수 있습니다. `/proc/cmdline`에 비활성화 문자열이 남는지만으로 실패를 판단하지 않고, 컨트롤러와 실제 제한값을 확인해야 합니다. [RPi 커널 유지관리자 설명](https://github.com/raspberrypi/linux/issues/6980)

적용 순서는 다음과 같습니다.

1. `/boot/firmware/cmdline.txt`, `config.txt`, 현재 부팅 인자와 기존 Qwen 사용자 서비스를 백업합니다.
2. `cmdline.txt`의 루트 파일시스템·콘솔 등 기존 인자를 유지하고, 명시적으로 들어 있는 `cgroup_disable=memory`는 제거한 뒤 `cgroup_enable=memory`를 추가합니다. 다른 컨트롤러 설정은 보존합니다.
3. 파일은 한 줄로 저장하고 재부팅합니다.
4. 기존 컨테이너는 메모리 제한 0으로 생성되어 있으므로, Compose 설정으로 다시 생성합니다.

이번 기기는 `cmdline.txt`가 **0바이트**였습니다. 활성화 옵션만 쓰면 커널의 기본 루트 파일시스템 인자가 대체될 수 있어, `/boot/config-$(uname -r)`의 `CONFIG_CMDLINE`과 현재 부팅 인자를 대조해 복원했습니다. 이 기기에 적용한 값은 다음과 같습니다. 다른 기기는 `root=`와 콘솔 값이 다를 수 있으므로 그대로 복사하지 않습니다.

```text
console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait console=tty1 cgroup_enable=memory
```

재부팅 후 확인·적용 명령입니다.

```bash
cat /sys/fs/cgroup/cgroup.controllers
docker info --format 'memory={{.MemoryLimit}} swap={{.SwapLimit}}'

cd ~/RPI5_Agent_Docker
docker compose up -d --no-build --force-recreate agent
docker inspect --format '{{.HostConfig.Memory}}' rpi5-agent-agent-1
docker exec rpi5-agent-agent-1 cat /sys/fs/cgroup/memory.max
docker stats --no-stream
```

`AGENT_MEMORY_LIMIT=768m`인 현재 환경에서는 inspect 값과 `memory.max`가 모두 `805306368`바이트여야 합니다. 컨테이너 재생성은 `.env`나 호스트의 검증 데이터를 삭제하지 않습니다. Docker 리소스 제한은 커널 지원이 필요하며, Qwen 호스트 프로세스는 이 Agent 컨테이너 제한에 포함되지 않습니다. [Docker 리소스 제한 문서](https://docs.docker.com/engine/containers/resource_constraints/)

## Qwen 영구 systemd 서비스

기존 `systemd-run --user` 임시 서비스를 시스템 서비스로 전환했습니다. 프로세스는 기존처럼 일반 사용자 `pi`로 실행합니다. SSH 로그인이나 사용자 linger 설정 없이 부팅 시 시작합니다.

- 서비스 파일: `/etc/systemd/system/rpi5-agent-llama.service`
- 실행 스크립트: `/usr/local/libexec/run_rpi5_qwen_service.sh`
- 모델: `/home/pi/models/qwen2.5-3b-instruct-q4_k_m.gguf`
- API: `127.0.0.1:8080`과 Docker 기본 브리지 게이트웨이의 8080 포트
- 기존 옵션 유지: alias `local-qwen`, 4스레드, context 2048, parallel 1, temperature 0.2

서비스는 Docker 시작 후 실행하며, 실행 스크립트가 현재 Docker 브리지 주소를 조회합니다. Docker가 재시작되면 Qwen 서비스도 함께 재시작하도록 구성했습니다. 모델이 로딩되는 동안 `/health`는 준비 완료 상태가 아닐 수 있습니다. 프로세스의 `active` 상태와 모델의 HTTP 준비 완료를 구분해야 합니다.

이 저장소에서 재설치하는 명령입니다. `pi` 외의 계정이나 다른 모델 경로를 사용하면 먼저 서비스 파일의 `User`, `Group`, `WorkingDirectory`, `LLAMA_MODEL`을 수정하세요. 실행 계정은 Docker 소켓에 접근할 수 있어야 합니다.

```bash
sudo install -D -m 0755 scripts/run_rpi5_qwen_service.sh /usr/local/libexec/run_rpi5_qwen_service.sh
sudo install -D -m 0644 config/systemd/rpi5-agent-llama.service /etc/systemd/system/rpi5-agent-llama.service
sudo systemd-analyze verify /etc/systemd/system/rpi5-agent-llama.service

# 같은 포트에서 기존 사용자 서비스가 실행 중인 경우 먼저 중지합니다.
# systemctl --user stop rpi5-agent-llama.service

sudo systemctl daemon-reload
sudo systemctl enable --now rpi5-agent-llama.service
```

상태 확인과 운영 명령입니다. 시스템 서비스로 전환한 뒤에는 `--user`를 붙이지 않습니다.

```bash
systemctl is-enabled rpi5-agent-llama.service
systemctl status rpi5-agent-llama.service --no-pager
curl -fsS http://127.0.0.1:8080/health
sudo journalctl -u rpi5-agent-llama.service -b --no-pager -n 50

sudo systemctl restart rpi5-agent-llama.service
# 현재 실행만 중지하려면:
# sudo systemctl stop rpi5-agent-llama.service
# 부팅 시 자동 시작도 해제하려면:
# sudo systemctl disable --now rpi5-agent-llama.service
```

## 백업과 복구

이번 설정 변경 전 백업은 `/var/backups/rpi5-runtime/20261105T071721Z-Uc7qpn`에 보관했습니다. `/var/backups/rpi5-runtime/latest-backup-path`에도 백업 디렉터리 경로를 기록했습니다. 백업에는 원래 0바이트였던 `cmdline.txt`, 원래 `config.txt`, 기존 임시 사용자 서비스 정의, 변경 전 boot ID와 Agent `.env`의 SHA-256이 있습니다. 백업 디렉터리는 root만 접근할 수 있습니다.

부팅 설정을 되돌리려면 해당 백업의 `cmdline.txt`를 `/boot/firmware/cmdline.txt`로 복원하고 재부팅합니다. Qwen 자동 시작을 해제하려면 위 `systemctl disable --now` 명령을 사용합니다. 기존 임시 서비스 정의는 백업의 `previous-user.service`에서 확인할 수 있습니다.

## 재부팅 후 실기기 검증 결과

2026-11-05 16:20 KST 이후 다음 항목을 확인했습니다.

| 항목                 | 결과                                                                                               |
| -------------------- | -------------------------------------------------------------------------------------------------- |
| 실제 재부팅          | boot ID가 `983b5982-5e76-4a35-a660-1e7be648d396`에서 `a6f2aeb0-d99c-4edb-9ced-2b4f247474c7`로 변경 |
| 메모리 컨트롤러      | `cpuset cpu io memory pids`                                                                        |
| Docker 기능          | `memory=true swap=true`                                                                            |
| Agent 메모리 제한    | Docker 설정과 컨테이너 `memory.max` 모두 `805306368`바이트, 768 MiB                                |
| Agent Swap 설정      | Docker 기본값으로 RAM+Swap 합산 한도 1,536 MiB, Swap 추가 허용량 768 MiB                           |
| Agent 통계           | 점검 시 약 `94.05 MiB / 768 MiB`, `healthy`                                                        |
| Qwen 자동 시작       | 재부팅 후 별도 시작 명령 없이 `enabled`, `active`, 재시작 횟수 0                                   |
| Qwen 접근            | 호스트와 Agent 컨테이너 양쪽에서 `/health` 정상 응답                                               |
| Agent 실제 모델 연동 | `bms_timeout`, `use_llm=true` 요청 성공. 입력 관측은 기존 가상 데이터                              |
| 모델 출력            | `llm_status=generated`, `finish_reason=stop`, 입력 366 / 출력 35토큰                               |
| 이번 모델 요청 시간  | 22.32초. 부팅 직후 조건의 단일 측정으로 성능 보장값은 아님                                         |

실제 제한 적용 여부는 운영 중인 Agent 대신 별도 테스트 컨테이너로 검증했습니다. 해당 컨테이너에 메모리·합산 메모리/Swap 한도를 각각 64 MiB로 지정하고, 자식 프로세스가 96 MiB를 할당하게 했습니다. 자식 프로세스가 SIGKILL로 종료되고, 컨테이너의 커널 `memory.events`에서 `oom_kill`이 0에서 1로 증가했습니다. 테스트 컨테이너는 종료 후 제거했습니다.

검증 데이터는 RPi Agent 저장소의 다음 무시 대상 파일에 저장했습니다.

- `data/runtime-memory-enforcement-20261105.json`
- `data/runtime-qwen-verification-20261105.json`

Agent의 `.env`는 변경 전 SHA-256과 대조해 보존 여부를 확인했습니다. RPi Agent 저장소의 소스 파일은 수정하지 않았습니다. 전체 검증 요약은 백업 디렉터리의 `verification.json`에도 기록했습니다.

추론 직후 RPi 온도는 83.4°C, `get_throttled=0xe0008`이었습니다. 당시 현재 soft temperature limit 비트가 설정되어 있었으며, 장시간 추론에는 냉각 보완이 필요합니다. 16:23 KST 최종 점검에서는 63.7°C, `0xe0000`으로 현재 제한 비트가 해제된 것을 확인했습니다. 이번 작업은 메모리 제한과 자동 시작을 적용한 것이며 냉각 장치를 변경하지 않았습니다.
