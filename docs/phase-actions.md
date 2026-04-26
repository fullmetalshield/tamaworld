# 단계별 행동 매핑

펫의 생애 단계와 각 단계에서 가능한 행동을 정리합니다.
출처: [scripts/Stats.gd](../scripts/Stats.gd)의 `PHASES`, [scripts/Actions.gd](../scripts/Actions.gd)의 `CATALOG`.

## 단계별 가능한 행동

| 단계 | 가능한 행동 |
|---|---|
| 알 | — |
| 신생아기 | — |
| 영아기 | 쉬기 |
| 유아기 | 놀기, 쉬기 |
| 아동기 | 놀기, 공부하기, 쉬기 |
| 청소년기 | 놀기, 공부하기, 쉬기 |
| 청년기 | 놀기, 공부하기, 쉬기 |
| 중년기 | 놀기, 공부하기, 쉬기 |
| 장년기 | 놀기, 쉬기 |
| 노년기 | 쉬기 |
| 사망 | — |

## 행동별 가용 단계

| 행동 | 가용 단계 | 소요(실분) | 보상금 | 효과 |
|---|---|---:|---:|---|
| 놀기 | 유아기 ~ 장년기 | 2분 | +5원 | 매력 +1, 운 +1 |
| 공부하기 | 아동기 ~ 중년기 | 3분 | +10원 | 지능 +1 |
| 쉬기 | 영아기 ~ 노년기 | 1분 | — | 체력 +1 |
| 공립 초등학교 입학 | 아동기 | 즉시 | — | `school = "public"` (초당 0원) |
| 사립 초등학교 입학 | 아동기 | 즉시 | — | `school = "private"` (초당 -1원) |
| 엘리트 초등학교 입학 | 아동기 | 즉시 | — | `school = "elite"` (초당 -3원) |
| 동호회 활동하기 | 청년기 ~ 장년기 | 즉시(picker) | — | 3개 무작위 동호회 중 선택해 `clubs`에 추가 (게임일 1일 쿨타임) |
| 독서하기 / 축구하기 / … | 청년기 ~ 장년기 (가입 후) | 1.5분 | — | 매력 +1, `bonds`에 무작위 NPC 인연 +1 |

학교 입학 행동은 한 번 선택하면 다른 두 학교 선택지는 사라집니다(`Actions.available_ids`가 `pet["school"] != null`인 경우 enrolment 항목을 제외). 졸업은 캐릭터가 아동기를 벗어나면 [scripts/EventManager.gd](../scripts/EventManager.gd) `_tick_economy`가 자동으로 `pet["school"] = null`로 비웁니다. 자동 행동 루프는 의도적인 선택을 보존하기 위해 학교 입학·동호회 가입처럼 picker가 열리는 행동(`opens_picker`)도 무작위로 고르지 않습니다.

## 동호회

[scripts/Clubs.gd](../scripts/Clubs.gd) `Clubs.CATALOG`에 10개의 동호회가 정의되어 있습니다(독서/축구/베이킹/음악/등산/게임/사진/요가/코딩/영화). 각 항목은 `label`과 카드 색상(`color`)을 가집니다.

흐름:
1. 청년기 이상의 캐릭터가 `동호회 활동하기` 액션을 선택 (ActModal에서 `opens_picker: "club"` 메타로 식별).
2. ActModal이 닫히고 [scenes/ClubPickerModal.tscn](../scenes/ClubPickerModal.tscn) 모달이 열림. `Clubs.random_three(exclude=pet.clubs)`이 이미 가입한 동호회를 제외해 무작위 3개를 표시.
3. 하나를 고르면 `pet["clubs"]`에 추가되고 ActModal이 다시 열림. 취소해도 ActModal로 복귀.
4. 가입한 펫의 ActModal에서는 generic "동호회 활동" 한 줄이 아니라 **가입한 동호회별로 한 줄씩** 보임 — 예: 독서 가입 시 "독서하기", 축구 가입 시 "축구하기" (`Clubs.activity_label`/`progress_label`로 라벨 결정, 색상은 동호회 색상 그대로). 내부 action id는 모두 `club_activity`이고, `pet["active_action"].club_id`로 어느 동호회의 활동인지 구분해 완료 시 적절한 본드 풀에 반영.
5. 동호회 활동은 1.5분 진행 후 완료 시 매력 +1과 함께 `Clubs.NPC_NAMES`에서 무작위 이름을 골라 `pet["bonds"][이름] += 1`.
6. **쿨타임**: `동호회 활동하기` picker는 한 번 가입할 때마다 1 게임일(1440 게임-분 = 24 실분) 쿨타임이 걸림. ActModal은 쿨타임 중인 행을 비활성화하고 "X분 후 가능"을 메타에 표시. 자동 행동 픽 루프도 쿨타임을 존중. 펫 데이터는 `pet["action_cooldowns"][action_id] = 만료시각(게임-분)`으로 저장.

같은 이름이 반복적으로 선택되면 자연스럽게 인연 수치가 누적되어 "친한 사람"이 형성됩니다. StatModal 하단에 가입 동호회 목록과 인연 상위 5명을 표시.

## 직업

[scripts/Jobs.gd](../scripts/Jobs.gd) `Jobs.CATALOG`에 정의됩니다. 주인공은 [scripts/PetStore.gd](../scripts/PetStore.gd) `create_protagonist()`에서 `Jobs.STARTING_JOB`("clerk")을 가지고 청년기 초반(수명의 ~37% 지점)에서 등장합니다.

| id | 라벨 | 분류 | 초당 수입 |
|---|---|---|---:|
| clerk | 타마상사 신입사원 | office | 3원 |
| teacher | 타마초등 보조교사 | service | 5원 |
| doctor | 타마종합병원 인턴 | service | 10원 |
| merchant | 타마시장 잡화상인 | commerce | 4원 |
| athlete | 타마구단 신인선수 | sports | 6원 |
| artist | 인디 가수 | creative | 4원 |
| engineer | 타마전자 연구원 | technical | 7원 |
| farmer | 타마농장 일꾼 | primary | 3원 |

`pet["job"]`이 설정되어 있고 살아있는 펫은 매 게임-분(=1 실초)마다 `Jobs.income_per_second(job_id)` 만큼 가계 보유금에 가산됩니다. 학교 비용과 직업 수입은 단일 net 델타로 합산되어 한 번에 `Family.add_money(net)` 호출로 반영됩니다.

> 내부적으로 `duration`은 게임-분 단위(60/120/180)로 저장되며, 1 실초 = 1 게임-분 스케일에 따라 실시간으로는 1/2/3분에 해당합니다. UI는 실분으로 환산해 표기합니다.

## 단계 비율 참고

`Stats.PHASES`의 `max_p`(나이/수명 비율 상한) 기준입니다. 6일 수명 = 144 실분, 8일 수명 = 192 실분.

| 단계 | 단계 비율 | 누적 max_p | 6일 수명 시 실시간 | 8일 수명 시 실시간 |
|---|---:|---:|---:|---:|
| 알 | 2% | 0.02 | 2.9분 | 3.8분 |
| 신생아기 | 2% | 0.04 | 2.9분 | 3.8분 |
| 영아기 | 4% | 0.08 | 5.8분 | 7.7분 |
| 유아기 | 6% | 0.14 | 8.6분 | 11.5분 |
| 아동기 | 10% | 0.24 | 14.4분 | 19.2분 |
| 청소년기 | 12% | 0.36 | 17.3분 | 23.0분 |
| 청년기 | 16% | 0.52 | 23.0분 | 30.7분 |
| 중년기 | 18% | 0.70 | 25.9분 | 34.6분 |
| 장년기 | 15% | 0.85 | 21.6분 | 28.8분 |
| 노년기 | 15% | 1.00 | 21.6분 | 28.8분 |
| 사망 | — | ≥1.00 | — | — |

## 튜닝 가이드

- **단계 길이 조정**: `Stats.PHASES`의 `max_p` 한 컬럼만 수정 (배열 끝은 반드시 1.00 유지).
- **행동의 단계 가용성 조정**: `Actions.CATALOG[id].phases` 배열에서 단계 id를 추가/제거.
- **행동 시간/보상 조정**: 같은 항목의 `duration`(게임-분), `money_reward`, `effects` 수정.
- **새 행동 추가**: `CATALOG`에 새 키 추가 (label/progress 라벨 키, duration, effects, money_reward, color, phases 필드 채우기). 번역 키는 [translations/strings.json](../translations/strings.json)에 추가.
