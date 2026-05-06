# 작업 로그

날짜별 변경 사항 요약. 최신 항목이 위에 옵니다.

---

## 2026-05-07

### 새로고침 시 액션 progress 초기화 버그 수정
- 웹 빌드에서 액션 진행 중 새로고침하면 진행률이 0으로 보이던 문제. [scripts/GameClock.gd](../scripts/GameClock.gd)이 60게임분(=1실분)마다만 `_save()`를 호출했기 때문에:
  - 액션 시작 → `pet.active_action.started_at_minutes = 100.5` 저장
  - GameClock은 60-min 경계 사이라 clock.json은 여전히 `total = 60` 상태
  - 새로고침 → 시계는 60으로 되돌아가는데 액션은 100.5에 시작한 것으로 → `progress = (60 - 100.5)/dur` 음수 → clamp(0)
- 두 단계 수정:
  1. [scripts/GameClock.gd](../scripts/GameClock.gd)에 public `save()` 메서드 추가, 저장 주기 60 → 1 게임분(=1실초)으로 단축. 웹 IndexedDB는 작은 write 부담 없음.
  2. [scripts/PetStore.gd](../scripts/PetStore.gd) `persist()`가 끝에 `GameClock.save()` 호출 — pet 상태와 시계가 항상 같은 시점의 스냅샷이 되도록 묶음.

### 행복도 시스템 추가 (표시 전용)
- 캐릭터에 능력치와는 별개의 `happiness` (0~100) 추가. 일단 표시 전용 — 다른 시스템(이벤트/출산/능력치)에는 영향 없음.
- [scripts/Stats.gd](../scripts/Stats.gd):
  - `HAPPINESS_MIN/MAX/START/DECAY_PER_HOUR` 상수 (시작 70, 시간당 −1).
  - `current_happiness(pet, now)` — 게으른 디케이 계산. 저장된 `happiness`는 `happiness_updated_at_minutes` 시점의 스냅샷이고, 읽을 때마다 경과 게임-시간만큼 감소시킨 값을 반환. 매 틱 쓰기 없음.
  - `apply_happiness_delta(pet, now, delta)` — 델타를 적용할 때만 스냅샷을 다시 잡고 타임스탬프 갱신.
- [scripts/PetStore.gd](../scripts/PetStore.gd):
  - `generate_random_pet`이 `happiness: 70`, `happiness_updated_at_minutes: GameClock 현재값`로 초기화.
  - `_migrate_pets`가 기존 세이브에 두 필드를 백필.
- [scripts/Actions.gd](../scripts/Actions.gd) `_complete`가 액션 카탈로그의 `happiness_delta`를 읽어 적용.
- [data/actions.json](../data/actions.json) 액션별 행복도 변화량:
  - play +8, rest +3, club_activity +6, date +12 (즐거운 활동들)
  - study −4 (공부는 힘들다)
- [scenes/StatModal.tscn](../scenes/StatModal.tscn) + [scripts/StatModal.gd](../scripts/StatModal.gd): 능력치 그리드 위에 `행복` ProgressBar + `xx/100` 라벨 추가.

### 성별 마크 ♂/♀ → SVG 아이콘
- 웹 빌드에서 ♂(U+2642) / ♀(U+2640)이 raw codepoint 숫자(`2642`)로 표시되던 문제. Godot 4 웹 빌드는 시스템 폰트 폴백이 없어 neodgm에 없는 글리프가 그대로 깨짐.
- 처음엔 한글 "남"/"여"로 교체했다가 폰트 의존성 자체를 없애고 **SVG 아이콘**으로 전환 — Mars/Venus 심볼을 흰색 stroke로 그려 [assets/icons/gender_male.svg](../assets/icons/gender_male.svg) / [assets/icons/gender_female.svg](../assets/icons/gender_female.svg) 24×24로 번들. 색상은 `modulate`로 MALE_COLOR/FEMALE_COLOR 적용.
- [scripts/StatModal.gd](../scripts/StatModal.gd), [scripts/BondDetailModal.gd](../scripts/BondDetailModal.gd):
  - `gender_mark` 타입 Label → TextureRect.
  - 두 SVG를 const로 preload(`GENDER_ICON_MALE` / `GENDER_ICON_FEMALE`).
  - `_apply_gender_mark`가 텍스처 + modulate 세팅으로 단순화.
- [scenes/StatModal.tscn](../scenes/StatModal.tscn), [scenes/BondDetailModal.tscn](../scenes/BondDetailModal.tscn) GenderMark 노드를 TextureRect로 교체. `expand_mode=1`(IGNORE_SIZE) + `stretch_mode=5`(KEEP_ASPECT_CENTERED) + `custom_minimum_size`로 크기 고정.
- Godot `--headless --import`로 SVG들을 사전 import 처리해서 .ctex 캐시 + .import 메타파일 생성, 다음 export부터 깔끔히 번들됨.

### Vercel 배포 파일 리포 루트로 이동
- 기존 `build/web/vercel.json` + `build/web/serve.js`가 Godot 재export 시 사라지는 문제. Godot이 build/web/ 내 PNG들을 자동 import하면서 `.import` 파일을 만드는 등 디렉토리를 적극적으로 건드리기 때문에, 배포 설정 파일은 **리포 루트**에 두는 게 안전.
- 신규 [vercel.json](../vercel.json) (리포 루트):
  - 헤더: COOP/COEP/CORP + `.wasm` MIME 타입.
  - **rewrites**: `/` → `/build/web/index.html`, `/:path*` → `/build/web/:path*`. 사용자가 보는 URL은 `tamaworld.vercel.app/`이지만 내부적으로 build/web/에서 서빙.
- 신규 [.vercelignore](../.vercelignore) — Godot 소스(scripts/scenes/shaders/assets/...), tools, docs, 에디터 파일을 deploy 업로드에서 제외. 결과적으로 build/web/ + vercel.json만 Vercel CDN으로 올라감.
- [serve.js](../serve.js)도 리포 루트로 이동, `BUILD_DIR = path.join(__dirname, 'build', 'web')`로 build/web/에서 서빙. `node serve.js`로 실행, http://localhost:8080.
- [.gitignore](../.gitignore)에 `build/web/*.import` 추가 — Godot이 build/web 내부 PNG들에 만들어내는 import 메타파일은 배포에 불필요.
- **Vercel 프로젝트 설정에서 Root Directory 변경 불필요** — repo root 기본값 그대로 두면 vercel.json이 알아서 라우팅.

---

## 2026-04-29

### 동호회 활동 비용 (money_cost 카탈로그 필드)
- 동호회 활동에 일회성 비용을 붙여 인연 형성에 자원 부담을 추가. [data/actions.json](../data/actions.json) `club_activity`에 `money_cost: 1000` 필드 추가(가족 수입 페이스 대비 의미 있는 부담).
- 신규 카탈로그 필드 `money_cost`는 일반화돼서 어떤 액션에도 적용 가능. [scripts/Actions.gd](../scripts/Actions.gd):
  - `_can_afford(pet, action)` / `_deduct_cost(pet, action)` 헬퍼 — 가족 펫만 가족 자금에서 차감(NPC는 비용 없이 활동), 잔액 부족이면 시작 거부.
  - `start` / `start_club_activity` 양쪽에서 시작 직전 호출. 시작과 동시에 즉시 차감(상위 활동의 한 사이클 단위로 비용을 지불하는 모델).
- [scripts/ActModal.gd](../scripts/ActModal.gd):
  - `_meta_text`가 `money_cost`도 인식해 라벨에 "-N원" 포함, `money_reward`와 함께 있을 경우 둘 다 표기 가능 (`90분 · -20원 · +0원` 등 — reward=0이면 생략).
  - 잔액 부족 시 row 버튼 비활성화 + 메타 라벨 "N원 부족". 진행 중인 row는 잔액 부족이어도 disabled 처리에서 제외(이미 시작된 것은 그대로 진행).

### 데이트 시간/쿨다운 유저 시간 기준으로 재조정
- 데이트 쿨다운/지속시간을 게임분 기준 → 실시간 기준 단위로 늘려, 데이트 중 상태가 슬롯 인디케이터에 충분히 보이도록.
- [scripts/BondDetailModal.gd](../scripts/BondDetailModal.gd) `DATE_COOLDOWN_MIN`: 3 → **180** (실시간 3분).
- [data/actions.json](../data/actions.json) `date.duration`: 1 → **120** (실시간 2분).
- 데이트 성공 시 `Actions.start_date`가 양쪽 펫의 `active_action.id`를 "date"로 세팅하므로 슬롯 인디케이터(donut + "데이트 중")가 자동으로 2분간 노출됨. 별도 변경 없음.

### BondDetailModal 컴팩트화
- 모달 높이가 작은 창에서 잘리는 문제. [scenes/BondDetailModal.tscn](../scenes/BondDetailModal.tscn) 내부 콘텐츠를 줄여 화면에 잘 들어오도록 조정.
- 변경:
  - `ModalPanel.custom_minimum_size`: (420, 520) → **(420, 420)**
  - `Tabs.custom_minimum_size`: (0, 240) → **(0, 160)** — 능력치를 숨겼더니 240은 과대했음.
  - 메인 VBox `separation`: 10 → 6, 행동 탭 `separation`: 14 → 8, `TopSpacer` 12 → 6.
  - 행동 버튼 StyleBox 4종(hangout/gift/date 각 normal+hover, disabled)의 `content_margin_top/bottom`: 10 → 6 — 버튼 자체도 살짝 컴팩트.

### 인연 인터랙션 쿨다운 표시 실시간화
- BondDetailModal의 hangout / date 쿨다운이 그동안 게임분 단위(`120분 후`, `3분 후`)로 표시돼 실제 대기 시간(=실시간 초)과 단위가 어긋나던 문제. GameClock이 1게임분=1실초로 돌기 때문에 유저가 보는 단위로 환산해 표기.
- [scripts/BondDetailModal.gd](../scripts/BondDetailModal.gd):
  - `_cooldown_remaining`을 int → float 반환으로 변경(GameClock이 float이라 sub-second 정밀도 확보).
  - 신규 헬퍼 `_format_wait(game_min: float)` — 60초 미만은 `"3초 후"`, 1분 이상이면 `"1분 30초 후"` / `"2분 후"`. ceil 적용으로 0초 직전까지 1초로 표시.
  - 쿨다운 라벨이 매 프레임 갱신되도록 `_process(_delta)` 추가 — 모달이 visible일 때만 viewer/npc lookup 후 `_refresh_buttons` 재실행. 버튼 텍스트/disabled만 다시 쓰는 가벼운 패스라 60Hz로 돌려도 부담 없음.
- 결과: hangout 후 버튼 라벨이 `"함께 시간 보내기 (1분 59초 후)"` → ... → `"(3초 후)"` → ... 로 매 초 줄어들고, 데이트는 `(3초 후)` → `(1초 후)` → 활성화로 자연스럽게 카운트다운.

### 데이트 쿨다운 60→3분
- [scripts/BondDetailModal.gd](../scripts/BondDetailModal.gd) `DATE_COOLDOWN_MIN` 60 → 3. 1게임시간이 너무 길어 데이트 시도 텀이 답답했음. 3게임분(=3실초)이면 거절 후 즉시 재시도까진 못해도 곧 다시 도전 가능.

### 데이트 NPC busy 체크 제거 (preempt)
- 데이트 버튼이 NPC가 거의 항상 자동 행동(rest 60분 / play 120분 / study 180분 등) 중이라 "다른 일 중"으로 잠겨 있던 문제. 데이트 신청은 NPC 입장에선 하던 일 중단 후 수락이 자연스러우므로, 성공 시 NPC의 현재 `active_action`을 그대로 덮어쓰도록 변경.
- [scripts/Actions.gd](../scripts/Actions.gd) `start_date`에서 partner busy 체크 제거 — viewer(주인공) busy일 때만 거부. NPC는 무조건 데이트로 전환.
- [scripts/BondDetailModal.gd](../scripts/BondDetailModal.gd) `_refresh_buttons` / `_on_date_pressed`도 NPC busy 검사 제거. 버튼 라벨은 viewer 자신이 바쁠 때 "내가 다른 일 중"으로 명확히 표기.

### 같이 데이트하기 (확률 + 양방향 점유 액션)
- 신규 인터랙션 "같이 데이트하기"를 BondDetailModal에 추가. 클릭 시 확률 롤로 성패 결정, 1게임분 동안 양쪽 캐릭터를 점유. 쿨다운 1게임시간(60분)은 결과와 무관하게 적용.
- [data/actions.json](../data/actions.json)에 `date` 엔트리 추가 — `duration: 1`, `effects: {}`, `triggered_only: true`. 새 플래그 `triggered_only`는 일반 행동 모달에는 노출하지 않고 외부(BondDetailModal)에서만 시작하는 액션을 표시. [scripts/Actions.gd](../scripts/Actions.gd) `available_ids`가 이 플래그를 필터링하므로 ActModal/auto-pick 양쪽에서 자동으로 제외됨. NPC도 데이트를 자율 시작하지 않음.
- [scripts/Actions.gd](../scripts/Actions.gd) `start_date(viewer, partner)` 신설 — 둘 다 한가할 때만 `active_action`을 동시에 설정(`partner_id` 보관). 1분 후 각자의 `tick()`이 독립적으로 `_complete`해서 active_action 해제. 효과 없는 빈 액션이라 _complete의 부작용은 무해.
- [scripts/BondDetailModal.gd](../scripts/BondDetailModal.gd):
  - 쿨다운 키를 `npc_id` → 복합 키 `"{npc_id}::{action}"`으로 리팩터. `_cooldown_key/_cooldown_remaining/_stamp_cooldown` 헬퍼로 hangout/date 양쪽이 독립 추적.
  - 확률 공식 `_date_chance`: `0.30 + bond * 0.03`, 최대 0.95. hangout/gift로 호감도를 쌓으면 데이트 성공률이 자연스럽게 올라감.
  - `_on_date_pressed`: 클릭 직후 60분 쿨다운 stamp → 확률 롤 → 성공 시 mutual ♥+3 + `Actions.start_date` + 상태 라벨 "데이트 약속이 잡혔습니다!"; 실패 시 "X에게 거절당했습니다." 메시지만.
  - `_refresh_buttons`가 데이트 버튼의 (1) 쿨다운 (2) 양쪽 중 한쪽이라도 다른 일 중 (3) 정상 — 세 상태에 따른 라벨/disabled 분기. 정상 상태에서는 "성공률 N%"를 노출해 의사결정 정보 제공.
- [scripts/PetStore.gd](../scripts/PetStore.gd) `bond_cooldowns` 마이그레이션 — 기존 `{npc_id: int}` 형식의 키를 `"{npc_id}::hangout"`로 자동 승격. 신규 인터랙션이 추가돼도 같은 dict에 깔끔히 추가 가능.
- [scenes/BondDetailModal.tscn](../scenes/BondDetailModal.tscn) `행동` 탭에 `DateButton` 추가, 산뜻한 핫핑크 톤 StyleBox(`#FFC7DA` normal / `#F594B8` hover, `#EB7399` 테두리). hover 시 글씨 흰색.
- [translations/strings.json](../translations/strings.json)에 `ACTION_DATE` / `ACTION_DATE_PROGRESS` 추가.

### BondModal 카운트 표기 ×→♥
- [scripts/BondModal.gd](../scripts/BondModal.gd)의 인연 버튼 라벨 `"{이름} ×N"` → `"{이름} ♥N"`. 같은 값이 BondDetailModal에서 "내 호감도 N"으로 보이므로 ×는 횟수 잔재 표기였음 — 이제 양쪽 모두 호감도 의미로 일관.

### BondDetailModal 다듬기
- ModalPanel 최소 높이 440 → 520 원복(잘리지 않으니 굳이 줄일 필요 없음).
- 능력치는 데이터에는 남기되 UI에서는 숨김 — 상태 탭의 `StatsGrid`와 위 `HSeparator`를 `visible = false`. `_render`는 그대로 값을 채우므로 추후 재노출만 하면 됨.
- 호감도 표시 가로 → **세로** 배치. `AffectionRow`(HBox) → `AffectionColumn`(VBox, separation=4), 라벨 horizontal_alignment=1. 텍스트도 정리: "내 호감도 ♥ N" / "{이름}의 호감도 ♥ N" → **"내 호감도 N"** / **"상대의 호감도 N"** ([scripts/BondDetailModal.gd](../scripts/BondDetailModal.gd)).
- 행동 탭이 탭 바와 너무 붙어있던 문제: 탭 VBox 맨 위에 12px `TopSpacer`(Control) 추가, `separation` 10 → 14.
- 행동 버튼 색상을 회색 디폴트 → 산뜻한 톤으로:
  - **함께 시간 보내기**: 라이트 스카이블루 normal `#C7E0F5` / hover `#9EC7EB`, 짙은 블루 테두리.
  - **선물 주기**: 살구색 normal `#FFDBBD` / hover `#F5BD8C`, 따뜻한 갈색 테두리.
  - 둘 다 corner_radius 14, hover 시 폰트 흰색. 비활성화 상태는 공용 회색 `StyleBox_btn_disabled`로.
- 동적 라벨/상태 텍스트의 ♥ 기호도 "호감도"로 정리해 표기 일관성 확보.

### BondDetailModal 탭 구조화
- 인연 상세 모달 내용이 길어 작은 창에서 화면이 잘리던 문제. [scenes/BondDetailModal.tscn](../scenes/BondDetailModal.tscn) 가운데 영역(나이/직업/호감도/스탯 + 행동 버튼/상태 라벨)을 `TabContainer`로 감싸 **상태 / 행동** 두 탭으로 분리.
  - **상태 탭**: AgeLabel + JobLabel + AffectionRow(내/상대 호감도) + HSeparator + StatsGrid 6종.
  - **행동 탭**: HangoutButton + GiftButton + StatusLabel.
- 헤더(이름/성별 마크) + 캐릭터 SubViewport + 확인 버튼은 탭 밖에 유지 — 탭을 전환해도 NPC 외형과 식별 정보는 항상 보임.
- ModalPanel 최소 높이 520 → 440으로 축소. TabContainer `custom_minimum_size = (0, 240)` + `size_flags_vertical = 3`로 가용 영역 채움. neodgm 폰트가 탭 제목에도 적용되도록 `theme_override_fonts/font` 지정.
- 노드 이름을 "상태" / "행동"으로 직접 두면 TabContainer가 그대로 탭 라벨로 사용. 모든 unique_name(`%NpcName`, `%StatsGrid`, `%HangoutButton` 등)은 새 경로에서도 그대로 resolve되므로 [scripts/BondDetailModal.gd](../scripts/BondDetailModal.gd)는 변경 없음.

### 카탈로그 에디터: 트리 뷰 + 드래그 편집
- [tools/catalog-editor/](../tools/catalog-editor/)에 `@xyflow/react` 추가, 새 "트리 뷰" 탭. 단계(왼쪽) → 행동(가운데) → 학교/picker/동호회(오른쪽)의 4열 레이아웃으로 노드/엣지 시각화.
- 신규 [tools/catalog-editor/src/lib/buildGraph.ts](../tools/catalog-editor/src/lib/buildGraph.ts) — 카탈로그 3종을 React Flow `Node[] / Edge[]`로 변환. 행동은 첫 가용 단계 줄에 stack-positioning, 같은 단계에 여럿이면 64px씩 내려쌓음.
- 신규 [tools/catalog-editor/src/components/TreeNodes.tsx](../tools/catalog-editor/src/components/TreeNodes.tsx) — `PhaseNode` / `ActionNode`(색상 적용) / `SchoolNode` / `ClubNode` / `PickerNode`(점선 테두리). 각 노드는 좌·우 핸들로 드래그 연결 받음.
- 신규 [tools/catalog-editor/src/lib/applyConnection.ts](../tools/catalog-editor/src/lib/applyConnection.ts) — 엣지 생성/삭제를 카탈로그 변이로 번역:
  - Phase ↔ Action (양방향 드래그) → `action.phases` 추가/제거
  - Action → School → `action.sets_school` 설정/해제
  - Action → Picker → `action.opens_picker` 설정/해제
  - Picker → Club은 의도적으로 편집 불가(`deletable: false` + 점선 표시).
- 신규 [tools/catalog-editor/src/components/TreeView.tsx](../tools/catalog-editor/src/components/TreeView.tsx) — React Flow 통합. `onConnect`/`onEdgesDelete`로 변이 라우팅, 행동 노드 클릭 시 인스펙터 탭으로 이동하면서 해당 항목 자동 선택. MiniMap + Controls + Background.
- 결과: 새 행동을 추가한 뒤 트리 뷰에서 단계 노드로 드래그하면 `phases` 배열에 즉시 반영, 엣지를 클릭→Backspace로 지우면 빠짐. 저장 버튼은 평소처럼 dirty 상태에 따라 활성화.

## 2026-04-28

### NPC 풀 캐릭터화 + 인연 상세 모달
- 인연 상대를 단순 이름 카운터에서 **풀 캐릭터(NPC 펫)**으로 격상. NPC는 주인공과 동일한 스키마(stats / job / lifespan / 외형 등)를 가지며, EventManager `_tick_actions`가 이미 모든 펫을 자동 픽 처리하므로 자동으로 자기 행동을 함. 유저 컨트롤은 불가.
- [scripts/PetStore.gd](../scripts/PetStore.gd):
  - 펫 스키마에 `kind`(`"family"` / `"npc"`) + `bond_cooldowns: Dictionary` 추가, 마이그레이션으로 backfill.
  - `create_npc(name)` / `find_or_create_npc_by_name(name)` 신규 — NPC는 청년기~중년기(0.25~0.65) 랜덤 시점에 태어난 것으로 생성, 랜덤 직업 부여.
  - 양방향 인연 헬퍼 `add_bond(a_id, b_id, amount)` — 양쪽 펫의 `bonds[other_id]`를 동시에 증가.
  - 레거시 인연 마이그레이션: 옛 저장의 `bonds: {name: count}`를 스캔, uid 형식이 아닌 키는 NPC를 새로 만들어 id로 치환하고 NPC 측에도 동일 호감도 기록.
- [scripts/Actions.gd](../scripts/Actions.gd) `_form_club_bond` → `Clubs.random_member_name`으로 NPC를 lookup-or-create 후 `PetStore.add_bond`로 양방향 +1. 또한 `_complete`의 `money_reward`는 `kind == "family"`일 때만 가족 자금으로 입금(NPC 활동은 가족 자금에 영향 없음).
- [scripts/EventManager.gd](../scripts/EventManager.gd) `_tick_economy`도 `kind != "family"` 펫은 직장 수입/학교 비용 계산에서 제외.
- [scripts/Genetics.gd](../scripts/Genetics.gd) 자식 펫에 `kind: "family"`, `bond_cooldowns: {}` 추가.
- [scripts/BondModal.gd](../scripts/BondModal.gd) 단순 라벨 행 → 라운드 핑크 테두리 **버튼**으로 변경, 클릭 시 `bond_selected(viewer_id, npc_id)` 신호 발행. 사망 NPC는 회색 + "(사망)" 표시.
- 신규 [scenes/BondDetailModal.tscn](../scenes/BondDetailModal.tscn) + [scripts/BondDetailModal.gd](../scripts/BondDetailModal.gd):
  - 헤더(이름 + 성별 마크), SubViewport(115×118)에 NPC 캐릭터, 나이/단계/수명, 직업, **내 호감도 ♥ X / 상대 호감도 ♥ Y** 라벨, 6종 능력치 그리드, "할 수 있는 항목" 섹션.
  - 인터랙션 두 개: **함께 시간 보내기**(♥ +1, 120 게임분 쿨다운 — `viewer["bond_cooldowns"][npc_id]`로 추적) / **선물 주기**(50원 차감, ♥ +2). 사망 NPC는 둘 다 비활성화.
- [scripts/FamilyTree.gd](../scripts/FamilyTree.gd) `bond_modal.bond_selected` → `bond_detail_modal.show_for(viewer_id, npc_id)` 라우팅. [scenes/FamilyTree.tscn](../scenes/FamilyTree.tscn)에 BondDetailModal 인스턴스 추가.

### 인연을 라디얼 메뉴 항목으로 분리
- [scripts/StatModal.gd](../scripts/StatModal.gd) / [scenes/StatModal.tscn](../scenes/StatModal.tscn)에서 `BondsLabel` 및 `_apply_bonds_label` 제거. 상태 모달은 이제 능력치 + 직업 + 동호회까지만.
- 신규 [scenes/BondModal.tscn](../scenes/BondModal.tscn) + [scripts/BondModal.gd](../scripts/BondModal.gd) — 풀스크린 반투명 backdrop + 360×320 라운드 패널. "{이름}의 인연" 헤더 + 스크롤 가능한 인연 리스트(이름 ↔ ×횟수, 카운트 내림차순) + 확인 버튼. 상위 5명 컷오프 없이 전부 표시.
- [scripts/FamilyTree.gd](../scripts/FamilyTree.gd) `_open_radial_for_pet`이 `pet["bonds"]`가 비어있지 않을 때만 `{"id": "bond", "label": "인연"}` 추가. `_on_radial_item_selected`에 `"bond"` → `bond_modal.show_for(pet)` 분기. [scenes/FamilyTree.tscn](../scenes/FamilyTree.tscn)에 BondModal 인스턴스 추가.
- [translations/strings.json](../translations/strings.json)에 `RADIAL_BOND`(`인연` / `BOND`) 추가.
- [scripts/RadialMenu.gd](../scripts/RadialMenu.gd)는 이미 `angle = -PI/2 + TAU*i/n`으로 정원 배치라 항목 3개일 때 자동으로 위쪽 꼭지점 정삼각형(−90°, 30°, 150°). 추가 변경 불필요.

## 2026-04-27

### 카탈로그 웹 에디터 (Phase 2)
- 신규 [tools/catalog-editor/](../tools/catalog-editor/) — Vite + React + TypeScript 기반 로컬 에디터. `npm install && npm run dev`로 띄우면 브라우저에서 `data/*.json`을 직접 편집·저장.
- Vite 미들웨어([tools/catalog-editor/vite.config.ts](../tools/catalog-editor/vite.config.ts))가 `/api/catalog/{actions|clubs|schools|jobs}` GET/PUT를 처리해 별도 백엔드 없이 디스크 파일을 읽고 prettified JSON으로 덮어씀.
- 탭 5개: 행동/동호회/학교/직업 + 단계 미리보기. 좌측 리스트(색상 스와치 + 라벨 + id) → 우측 인스펙터(타입별 폼: phase 칩 토글, 색상 피커, 스탯 효과 6종 등).
- 항목 추가/삭제 가능. 인스펙터의 sets_school·opens_picker 같은 cross-ref 필드는 다른 카탈로그를 참조하는 셀렉트로 노출.
- 항상 떠있는 검증 바([tools/catalog-editor/src/validation.ts](../tools/catalog-editor/src/validation.ts))가 미지의 phase id, 잘못된 색상 hex, dangling sets_school, starting_job 누락 등을 실시간 표시.
- 단계 미리보기 탭은 단계 카드 그리드 — 각 단계에서 어떤 행동이 가능한지 + 청년기·중년기·장년기에는 동호회 활동 라벨도 함께 보여 트리 분기 직관 확보.
- 명시적 "저장" 버튼만 있고 자동 저장 없음 (실수 방지). 저장 후 게임 재실행 시 [scripts/CatalogLoader.gd](../scripts/CatalogLoader.gd)가 새 데이터 적용.

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
