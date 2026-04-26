# 작업 로그

날짜별 변경 사항 요약. 최신 항목이 위에 옵니다.

---

## 2026-04-26

### 카탈로그 데이터 분리 + 로더 + 검증기 (Phase 1: 액션 트리 에디터의 토대)
- 신규 [data/](../data/) 폴더 + `actions.json` / `clubs.json` / `schools.json` / `jobs.json`. 모든 카탈로그가 게임 코드 밖 데이터로 분리되어 비프로그래머도 편집 가능. 각 파일은 `{"catalog": {...}}` 형태로 일관성 유지.
- 색상은 JSON에서 `"#FFC7D6"` 같은 hex 문자열로 저장; 로더가 `Color.html()`로 파싱.
- [scripts/Actions.gd](../scripts/Actions.gd), [scripts/Clubs.gd](../scripts/Clubs.gd), [scripts/Schools.gd](../scripts/Schools.gd), [scripts/Jobs.gd](../scripts/Jobs.gd)의 `const CATALOG := {...}` 블록을 `static var CATALOG: Dictionary = {}`로 단순화 — 데이터는 JSON에서만. 헬퍼/메서드는 그대로 유지.
- 신규 [scripts/CatalogLoader.gd](../scripts/CatalogLoader.gd) 오토로드 (project.godot의 GameClock과 EventManager 사이에 등록). 부팅 시 JSON 4개를 읽어 CATALOGs 채우고 cross-reference 검증:
  - 액션의 `phases`가 Stats.PHASES에 있는 id인지
  - 액션의 `sets_school`이 Schools.CATALOG에 있는 id인지
  - 액션의 `opens_picker`가 알려진 picker 타입인지
  - `Jobs.STARTING_JOB`이 Jobs.CATALOG에 있는지
  - 색상 hex가 유효한지
- 문제는 push_error로 보고하고 게임은 계속 로드 — 디자인 작업 중에 빠른 피드백 루프 확보.
- 다음 단계(Phase 2): 위 JSON 위에 React Flow 기반 웹 에디터를 얹어 트리 시각화 + 인스펙터 + 시뮬레이션 미리보기를 제공할 예정.

### 동호회: 트리 구조 + 가입 쿨타임
- 가입한 동호회별로 ActModal에 별도 행이 보이도록 변경 — 독서 → "독서하기", 축구 → "축구하기" 등. [scripts/Clubs.gd](../scripts/Clubs.gd) 카탈로그에 `activity_label` / `progress_label` 추가.
- 내부 액션 id는 그대로 `club_activity`를 유지하고 `pet["active_action"].club_id`로 어느 동호회의 활동인지 구분. 신규 [Actions.start_club_activity(pet, club_id)](../scripts/Actions.gd) + `_complete`이 `a.club_id`를 읽어 적절한 본드 풀로 라우팅.
- [scripts/ActModal.gd](../scripts/ActModal.gd)을 row 기반으로 리팩터링 — `_action_slots`가 `action_id` 대신 `row_id`("play" 또는 "club_act:reading") 기준으로 정리되고, `_expand_rows`가 available_ids를 펼쳐 클럽별 행 생성. 활성 행 매칭은 `_active_row_id`가 active_action.id + club_id로 계산.
- `동호회 활동하기` picker에 `cooldown_minutes: 1440`(1 게임일) 추가. [Actions.set_cooldown / is_on_cooldown / cooldown_remaining_minutes](../scripts/Actions.gd) 헬퍼 신설. 펫 데이터에 `action_cooldowns` 마이그레이션·팩토리 추가.
- ActModal이 쿨타임 중인 행을 비활성화 + "X분 후 가능" / "X초 후 가능" 메타 표시(`_format_cooldown`). [scripts/EventManager.gd](../scripts/EventManager.gd) 자동 픽 필터에 `Actions.is_on_cooldown` 추가.
- [scripts/FamilyTree.gd](../scripts/FamilyTree.gd) `_on_club_chosen`이 가입 후 `Actions.set_cooldown(pet, "join_club")` 호출.

### 동호회 시스템
- 신규 [scripts/Clubs.gd](../scripts/Clubs.gd): 10개 동호회 카탈로그 + NPC 이름 풀 + `random_three(exclude)` / `random_member_name` 헬퍼.
- [scripts/Actions.gd](../scripts/Actions.gd) `CATALOG`에 두 행동 추가: `join_club`(`opens_picker: "club"`, 청년기~장년기), `club_activity`(`requires_club: true`, 1.5분 / 매력 +1 / 인연 +1).
- `available_ids`가 `requires_club`을 가진 행동을 가입 동호회가 없는 펫에게는 숨김. `_complete`에 `_form_club_bond` 추가 — 무작위 동호회·NPC 이름으로 `pet["bonds"][name] += 1`.
- 자동 행동 픽 필터에 `opens_picker` 추가(학교와 동일한 이유 — 의도적 결정 보존).
- 신규 [scenes/ClubPickerModal.tscn](../scenes/ClubPickerModal.tscn) + [scripts/ClubPickerModal.gd](../scripts/ClubPickerModal.gd): 동호회 색상 카드 3개를 보여주는 picker 모달, `club_chosen(id)` / `cancelled` 시그널.
- [scripts/ActModal.gd](../scripts/ActModal.gd)에 `picker_requested(picker_type, pet_id)` 시그널 — 액션이 `opens_picker`를 가지면 즉시 닫고 시그널만 발행.
- [scripts/FamilyTree.gd](../scripts/FamilyTree.gd)이 picker 흐름 라우팅 — `_on_picker_requested` → 모달 표시, `_on_club_chosen` → 펫 `clubs` 업데이트 후 ActModal 재오픈, 취소 시에도 ActModal 복귀.
- [scripts/StatModal.gd](../scripts/StatModal.gd) + [scenes/StatModal.tscn](../scenes/StatModal.tscn): 능력치 그리드 아래에 `ClubsLabel`("동호회: ~"), `BondsLabel`("인연: 지은 ×3, 민수 ×2 외 N명") 추가.
- 펫 스키마에 `clubs: []`, `bonds: {}` 마이그레이션·팩토리·자녀 초기화.



### 행동 시스템 (실시간 대기 + 도넛 진행)
- 행동을 즉시 효과 적용 → "시작 → 대기 → 완료 시 보상"으로 전환. `pet["active_action"]`에 `id/started_at_minutes/duration_minutes` 저장. [scripts/Actions.gd](../scripts/Actions.gd)에 `start/tick/progress/is_busy/active_id`.
- 행동 진행 중 도넛형 프로그레스 표시 신규 [scripts/DonutProgress.gd](../scripts/DonutProgress.gd) — `draw_arc`로 그리는 Control. 기본 두께를 6 → 10 → 20으로 단계적으로 조정.
- 모달이 닫혀 있어도 행동 완료가 처리되도록 [scripts/EventManager.gd](../scripts/EventManager.gd) `_tick_actions`이 매 게임-분 틱마다 모든 펫에 `Actions.tick()` 호출.
- 진행 중 라벨 분리 (`progress_label_key`): "놀기 → 노는 중", "공부하기 → 공부하는 중", "쉬기 → 쉬는 중".

### 캐릭터 인디케이터
- 슬롯 하단(캐릭터 발 밑)에 작은 도넛 + 행동명 라벨 표시 — [scripts/FamilyTree.gd](../scripts/FamilyTree.gd) `_build_slot_indicators`. 줌과 함께 스케일.
- 이름 라벨을 캐릭터 머리 위로 10px 추가 이동.

### 결혼/자녀 이벤트 자동 발생 비활성
- [scripts/EventManager.gd](../scripts/EventManager.gd) `_tick()`에서 `_maybe_fire_partner_event` / `_maybe_fire_child_event` 호출 제거. 결혼/출산 헬퍼 함수, 시그널, confirm 플로우는 그대로 유지 — 추후 명시적 액션에서 호출.

### 자동 행동 (비-주인공)
- 비-주인공·살아있는·idle 펫이 매 틱마다 `Actions.available_ids` 중 하나를 무작위로 시작.
- 학교 입학 같은 결정성 행동(`sets_school` 메타)은 자동 픽에서 제외.

### 가계 보유금 단일화
- 신규 [scripts/Family.gd](../scripts/Family.gd) — 정적 API(`money/add_money/set_money/reset`), `user://family.json` 영속.
- 기존 펫의 `money` 필드는 마이그레이션이 합산해 Family로 이관 후 펫에서 제거.
- HUD 가운데에 보유금 표시 — [scenes/Hud.tscn](../scenes/Hud.tscn)을 `DayLabel | SpacerLeft | MoneyLabel | SpacerRight | TimeLabel` 구조로 변경.
- 보유금 라벨이 매 프레임 `Family.money()`로 lerp 보간 — 한 번에 +3씩 끊기지 않고 부드럽게 상승.

### 라디얼 메뉴 (캐릭터 중심 펼침)
- 신규 [scripts/RadialMenu.gd](../scripts/RadialMenu.gd) — N개 아이템을 `TAU/N` 간격으로 원형 배치(6개일 때 정육각형). 중심에서 시작해 0.28s `TRANS_BACK` 애니메이션으로 펼침, 0.035s stagger.
- 기존 CharacterModal을 STAT/ACT로 분리 — 신규 [scenes/StatModal.tscn](../scenes/StatModal.tscn)·[scenes/ActModal.tscn](../scenes/ActModal.tscn) + 각각의 스크립트. 옛 CharacterModal 파일 삭제.
- 라디얼 반경 92 → 130, 중심 오프셋(0, 10) — 캐릭터 정중앙 약간 아래.
- 캐릭터 클릭 시 슬롯 z_index를 100으로 띄워 백드롭 위에 캐릭터만 밝게. 이름·행동 인디케이터는 0.12s `modulate:a` 페이드 아웃 → 닫히면 페이드 인.
- 라디얼 중심을 `slot.get_global_transform_with_canvas() * (slot.size * 0.5)`로 계산해 줌/팬 무시하고 정확히 캐릭터 위치에 배치.

### 단계 시스템 11단계 확장
- [scripts/Stats.gd](../scripts/Stats.gd) `PHASES` 상수 배열 — `{id, label, max_p}`. 알/신생아기/영아기/유아기/아동기/청소년기/청년기/중년기/장년기/노년기 + 사망. `max_p` 한 컬럼만 수정해 단계 길이 즉시 조정 가능.
- [scripts/Actions.gd](../scripts/Actions.gd) 각 행동에 `phases` 필드 — 가용 단계만 노출.
- 자세한 매핑·비율 표는 [docs/phase-actions.md](phase-actions.md).

### 행동 모달 시각 개선
- ActionsBar(HBox) → ActionsList(VBox) — 목록형 카드 레이아웃.
- 행동별 색상(`color`) 추가 — 코랄 핑크(놀기), 페리윙클(공부), 민트(쉬기). `_row_style`로 normal/hover/pressed/disabled 4상태 styled.
- 행마다 좌측 행동명, 우측 메타("1분 · +5원" 또는 "초당 -1원"), 가장자리에 도넛 슬롯.
- `duration` 표기를 게임-분/60으로 환산해 실분 단위(1/2/3)로 표시. 카탈로그 듀레이션 60/120/180.

### 성별
- 신규 `pet["gender"]` 필드 + [scripts/PetStore.gd](../scripts/PetStore.gd) `random_gender()`. 마이그레이션이 기존 펫에 무작위 할당. [scripts/Genetics.gd](../scripts/Genetics.gd) 자녀에도 50/50 무작위.
- StatModal 이름 옆에 ♂(파랑)/♀(분홍) 마크 표기.

### 학교 시스템
- 신규 [scripts/Schools.gd](../scripts/Schools.gd) — 공립(0)/사립(1)/엘리트(3) 초당 비용 카탈로그.
- [scripts/Actions.gd](../scripts/Actions.gd) `CATALOG`에 학교 입학 액션 3종(아동기 한정, `sets_school` 메타). `_complete`이 `pet["school"]` 설정. `available_ids`가 이미 등록된 펫에는 학교 옵션 숨김.
- [scripts/EventManager.gd](../scripts/EventManager.gd) `_tick_economy`이 매 틱마다 학교 비용 차감 + 졸업 처리(아동기 벗어나면 `school = null`).

### 직업 시스템
- 신규 [scripts/Jobs.gd](../scripts/Jobs.gd) — 8종 직업 카탈로그. 라벨을 세계관에 맞춘 구체적인 이름으로 변경(예: "타마상사 신입사원", "인디 가수", "타마종합병원 인턴").
- 주인공이 청년기 초반(수명의 ~37% 지점)에 등장하도록 [scripts/PetStore.gd](../scripts/PetStore.gd) `create_protagonist`이 `born_at_minutes`을 후퇴시키고 `pet["job"] = Jobs.STARTING_JOB`.
- 매 틱마다 `Jobs.income_per_second`만큼 가계 보유금 가산. 학교 비용과 합산해 한 번의 `Family.add_money(net)` 호출.
- StatModal에 `직업: 타마상사 신입사원` + `급여: 3원/s` 두 줄로 표기.

### 문서
- 신규 [docs/](../docs/) 폴더 + [docs/phase-actions.md](phase-actions.md) — 단계 비율·행동 매핑·튜닝 가이드.
- 본 작업 로그 [docs/worklog.md](worklog.md) 시작.
