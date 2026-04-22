# tamaworld

Godot 4.6 기반 다마고치 월드. tamagotchi-paradise-gene-simulator의 에셋과 조립 로직을 이식해서 시작.

## 실행

Godot 4.6+ 에디터로 프로젝트 폴더 열고 F5. 또는:

```
Godot_v4.6.2-stable_win64.exe --path <project-root>
```

## 작업 로그

- **프로젝트 초기화**: `project.godot`, `icon.svg` 생성. Forward+ 렌더러, viewport 640×480, stretch=canvas_items.
- **에셋 이식**: tamagotchi-paradise-gene-simulator의 `public/tamagotchi/` 전체(217 PNG, forest/land/sea/sky 4필드, 67종 캐릭터)를 `assets/tamagotchi/`로 복사.
- **캐릭터 데이터**: `src/data/characters.ts`를 `data/characters.json`으로 이식. 필드별 `id`, `field`, `eyePosition`, 옵션 `eyeOffset`, `hasMouth`, `hasShadow`, `hasHighlight`, `color` 보존.
- **블렌드 셰이더**: `shaders/overlay.gdshader`, `shaders/soft_light.gdshader` — CSS W3C Compositing 스펙 그대로 구현. `hint_screen_texture`로 뒤 레이어 샘플링.
- **Tamagotchi 씬**: `scripts/Characters.gd` (데이터 로더), `scripts/Tamagotchi.gd` (합성 노드, 230×236 캔버스), `scenes/Tamagotchi.tscn`. 레이어 순서 `body → shadow → highlight → eyes → mouth`.
- **투명 배경 지원**: body PNG의 불투명 흰색 영역(캐릭터 바깥)을 투명으로 변환하는 `shaders/body.gdshader` 추가. 투명 픽셀은 `body_color`로 채우고 외곽선은 그대로 통과. overlay/soft-light 셰이더도 `back.a` 마스킹 추가해서 블렌드가 투명 영역에 새어나가지 않게 수정.
- **탭 분리**: `Main.tscn`을 `TabContainer`로 감싸고 시뮬레이터/가계도 두 탭으로 분리. 기존 콘텐츠는 `scenes/Simulator.tscn` + `scripts/Simulator.gd`로 이동.
- **가계도 탭 최초 구현**: `scripts/PetStore.gd`가 `user://pets.json`에 영속 저장, 최초 방문 시 랜덤 다마고치 1마리 자동 생성(랜덤 body/eyes, 24종 한국어 이름 중 하나). `scenes/FamilyTree.tscn`은 상단 `{surname} 가계` 라벨 + 가로 스크롤 구성원 스트립, 중앙 230×236 합성 뷰, 하단 `{given_name} {surname}` 큰 이름 라벨, 푸터 "새로 뽑기" 버튼.
- **UX 보정**: 구성원 스트립 가로 스크롤바 숨김(`horizontal_scroll_mode = 3`). `default_clear_color` 흰색.
- **폴카도트 배경**: `shaders/polkadot_bg.gdshader`로 흰 배경 위 핑크·라이트블루 원형 도트 무작위 배치 셰이더. `Main.tscn`에 전체화면 ColorRect로 적용하고 `TabContainer.panel`을 `StyleBoxEmpty`로 덮어써서 탭 콘텐츠가 투명하게 배경 위에 뜨도록.
- **창 모드 원복 및 리사이즈 대응**: `window/size/mode=3`(전체화면) 제거, `window/stretch/mode="disabled"`로 변경해서 창을 가로/세로 어떻게 늘려도 Control 앵커(anchors_preset=15)로 UI가 자연스럽게 꽉차게.
- **README 인코딩 복구**: 파일이 UTF-16 LE(한글 모자이크)로 저장되어 있던 것을 `bash` heredoc + `cat` 리다이렉트로 UTF-8 재작성.
- **탭 디자인 개선 (귀여운 도트 컨셉)**: `Main.tscn`에 `Theme` 서브리소스로 TabContainer 커스텀 스타일 적용. 선택 탭 핑크(#FBD1D4), 비선택 탭 흰색+연핑크 테두리, 호버 옅은 핑크, 모두 상단 코너 18px 라운드. 폰트 사이즈 18, 선택 탭 폰트 색 짙은 자주, tabbar 배경은 `StyleBoxEmpty`로 투명 → 폴카도트 배경이 탭 바 뒤로 비침.
- **탭 순서 변경**: 가계도 탭을 첫 번째(기본 선택)로, 시뮬레이터를 두 번째로 이동. `Main.tscn`의 `TabContainer` 자식 순서 스왑 및 `visible` 플래그 이동.
- **가계도 탭 우선화**: 탭 순서는 가계도 먼저, 시뮬레이터 나중. 가계도가 기본 선택.
- **도트 폰트 도입**: 한글 지원 도트 폰트 [neodgm](https://github.com/neodgm/neodgm) v1.601 TTF를 `assets/fonts/neodgm.ttf`로 번들.
- **게임 시계 (GameClock 오토로드)**: `scripts/GameClock.gd`가 1 실제초 = 1 게임분 비율로 시간 진행. 8:00 AM 시작, `user://clock.json` 저장. `time_changed` 신호 매분 발행. `format_day`/`format_time` 헬퍼(`1일차`, `오전 8:05`).
- **HUD**: `scenes/Hud.tscn` + `scripts/Hud.gd` — 상단 패널(라운드, 연핑크 테두리). 좌측 일차, 우측 오전/오후 시간. 모두 neodgm 20px. 가계도 탭 상단에 마운트.
- **PetStore 가족 모델**: `parent_ids`, `spouse_id`, `born_at_minutes`, `married_at_minutes` 필드 추가. `protagonist()`, `spouse_of()`, `children_of()`, `marry()` API. 가족 성은 주인공의 body_id에서 파생.
- **유전 로직 (`scripts/Genetics.gd`)**: 자식 생성 시 각 유전자(body/eyes/color)를 부모 45% × 2 + 조상 풀 10%로 확률 롤. 조상 풀은 parent_ids 체인을 BFS로 수집해 중복 제거.
- **이벤트 시스템 (EventManager 오토로드)**: `scripts/EventManager.gd`가 GameClock 틱마다 주인공 상태 체크. 시작 30 게임분 후 `partner_candidate_appeared` 발행. 결혼 수락 시 `PetStore.marry()` 호출, 배우자 가족에 추가. 결혼/직전 자식으로부터 60 게임분 후 자식 출생(`child_born` 발행), 최대 3자녀.
- **가계도 UI 확장**: `scripts/FamilyTree.gd`가 이벤트 구독. 파트너 나타남 → 핑크 배너 + "결혼하기" 버튼. 자식 출생 → 가장 최근 자식을 메인 스테이지에 표시. 가족 스트립에 역할 라벨(주인공/배우자/자식).
- **메인(타이틀) 스크린**: `scenes/MainScreen.tscn` + `scripts/MainScreen.gd` — 로고 이미지(`assets/images/logo.png` 경로 예약) + 시작하기 버튼. 이미지가 없으면 "타마월드" 폰트 타이틀로 폴백. `scenes/Main.tscn`에 `scripts/Main.gd` 추가해서 시작 버튼 누르면 MainScreen 숨기고 Tabs 표시.
- **메인 스크린 배경 정리**: 로고 이미지(`assets/images/logo.png`)의 흰색 배경이 폴카도트와 어울리지 않아, `MainScreen.tscn`에 풀사이즈 흰색 `ColorRect`(`WhiteBackground`, mouse_filter=ignore)를 가장 뒤에 배치. 로고가 깨끗한 흰색 타이틀 페이지로 보이고, "시작하기" 누르면 MainScreen 숨겨져서 폴카도트 배경 + Tabs가 노출되는 자연스러운 전환.
- **로고 임포트 트리거**: `logo.png`를 추가한 직후에는 Godot 리소스 임포트가 안 된 상태라 `ResourceLoader.exists()`가 false를 반환해 폴백 텍스트만 나옴. `--headless --import`로 강제 임포트 후(`logo.png.import` 생성) 다음 실행부터 실제 로고 표시됨.
- **가계도 상단 헤더 제거**: `{species} 가계` 형태의 `SurnameLabel`을 `FamilyTree.tscn`과 `FamilyTree.gd`에서 제거. HUD 바로 아래에 이벤트 배너 → 가족 스트립이 이어지는 더 간결한 레이아웃.
- **START 버튼 이미지 교체**: `assets/images/start.png`(1024×1024) 번들. `MainScreen.tscn`의 텍스트 버튼을 `TextureButton`으로 교체, `texture_normal=start.png`, `ignore_texture_size=true`, `stretch_mode=KEEP_ASPECT_CENTERED`. 사이즈 420×200으로 키우고 로고와의 간격은 VBox separation 4px로 좁혀 타이틀 바로 아래 붙어 보이게.
- **홈 버튼**: `Main.tscn`에 `HomeButton` 추가(우상단 앵커, 60×40 라운드 버튼, 흰 배경 + 연핑크 테두리, 호버 시 핑크 채움). `scripts/Main.gd`에 `_show_title`/`_show_tabs` 상태 전환 함수로 Tabs 표시 중에만 홈 버튼 보이게, 홈 클릭 시 MainScreen으로 원복. MainScreen.gd의 `start_button` 타입을 `BaseButton`으로 완화해 TextureButton 수용.
- **메인 스크린 레이아웃 조정**: logo.png에 하단 흰 여백이 많아 시작 버튼이 밑으로 밀려나고 작게 보이던 문제 수정. `AtlasTexture`로 `Rect2(0, 0, 1024, 620)` 영역만 잘라 LogoRect에 공급(540×330). StartButton 크기 560×280으로 키우고 VBox `separation` 0으로 로고 바로 아래 붙임. `MainScreen.gd`의 런타임 logo 재할당 제거(씬의 AtlasTexture 유지).
- **시작 버튼 배경 확인 + 커서 변경**: `start.png`의 네 귀퉁이 픽셀을 `Image.get_pixel`로 검사해 이미 알파 0(완전 투명)임을 확인. 버튼 자체는 투명 배경에 캐릭터만 그려진 상태. StartButton과 HomeButton에 `mouse_default_cursor_shape = 2`(CURSOR_POINTING_HAND) 추가해 호버 시 손가락 포인터 커서 표시.
- **크롭된 start.png 대응**: 새 start.png 사이즈 1024×356(가로 2.87:1 비율). StartButton `custom_minimum_size`를 560×280 → 640×222로 조정해 이미지 비율과 일치, KEEP_ASPECT_CENTERED 모드에서 여백 없이 이미지가 꽉 차게. `--headless --import`로 재임포트.
- **MainScreen 레이아웃 상단 고정**: CenterContainer가 VBox를 수직 중앙 정렬해 타이틀이 화면 중앙으로 내려가고 START 버튼과 겹쳐 보이던 문제 수정. LogoRect와 StartButton을 각각 `anchors_preset=5`(TOP_CENTER)로 직접 앵커링해서 로고는 y=20~310(480×290), 버튼은 y=330~483(440×153)에 고정. 버튼 사이즈 640×222 → 440×153으로 축소.
- **창 크기 변화 대응 (responsive)**: 전체화면/큰 창 기준으로 맞춘 절대 좌표가 작은 창에서 잘려 보이는 문제 수정. `project.godot`의 `window/stretch/mode`를 `disabled` → `canvas_items`, `aspect`를 `keep` → `expand`로 변경해 기본 뷰포트 640×480 캔버스가 창 크기에 맞춰 스케일되고 종횡비가 다르면 확장됨. `MainScreen.tscn`의 LogoRect를 440×266, StartButton 360×125로 컴팩트하게 재조정해 작은 창에서도 잘 들어맞도록.
- **MainScreen 타이틀 상단 배치 + 버튼 축소**: LogoRect을 380×230, offset_top=8으로 위로 올리고, StartButton을 300×104로 축소해 버튼 주변 여백 최소화(이미지 2.88:1 비율에 거의 정확히 매칭). 로고와 버튼 사이 y=238~320(82px)은 자연스러운 흰색 여백.
- **가계도 탭 주인공 카드 제거**: `FamilyTree.gd._build_family_strip`에서 protagonist id 건너뛰도록 처리 — 주인공은 메인 스테이지에 이미 크게 표시되므로 가족 스트립에서 중복 제거. 결과: 스트립에는 배우자/자식만 표시, 가족이 주인공 혼자일 때는 스트립 비어있음.
- **가계도 드래그/줌 + 슬라이더 (`핀`)**: 기존 `ScrollContainer`를 `Panel`(`clip_contents=true`) + 내부 `HBoxContainer`(FamilyStrip) 구조로 교체. 옆에 `VSlider`(ZoomSlider, min=0.3 max=3.0) 추가. `TreePanel.gui_input`이 mouse wheel로 ±10% 줌, 좌클릭 드래그로 pan. 슬라이더 값 변경 시 scale 동기화. `_set_zoom`은 `set_value_no_signal`로 피드백 루프 방지.
- **로고 크롭 수정**: 로고 이미지 픽셀을 y축 스캔해 실제 콘텐츠 위치 파악 — 메인 타이틀 y=280~580, 부제(たまごっちワールド) y=600~680, 나머지 흰 여백. 기존 크롭 `Rect2(0, 0, 1024, 620)`이 부제를 y=620에서 잘라내던 문제 → `Rect2(0, 260, 1024, 440)`으로 변경해 콘텐츠만 정확히 캡처. LogoRect 440×189 (아스펙트 2.33:1 매칭).
- **StartButton 배경 투명화**: MainScreen의 WhiteBackground를 풀사이즈 → `anchors_preset=10`(TOP_WIDE) + `offset_bottom=220`으로 상단 220px만 커버. 하단(StartButton 위치)은 투명 → 폴카도트 배경이 비침. StartButton은 start.png 비율(2.88:1) 맞는 360×125 크기로.
- **START 버튼 0.7배 축소**: 360×125 → 252×88. offset_top=290, offset_bottom=378로 같은 세로 중심 유지.
- **START 버튼 2배 확대**: 직전 축소를 되돌려 252×88 → 504×176. offset_top=246, offset_bottom=422로 같은 세로 중심 유지. 아스펙트 2.87:1 그대로.
- **START 버튼 비율 정확화 + 0.7배**: start.png 원본 비율 1024:356(2.876:1)에 맞춰 512×178로 조정 후 사용자 요청대로 0.7배 축소 → 최종 **358×124**. offset_left=-179, offset_right=179, offset_top=272, offset_bottom=396. 세로 중심 y≈334 유지.
- **주인공 이름 입력 플로우**: `PetStore.ensure_loaded`의 자동 랜덤 생성 제거. `PetStore.create_protagonist(name)` 신규 API. `scenes/NameInputScreen.tscn` + `scripts/NameInputScreen.gd` 추가 — 흰 배경 + "다마고치의 이름을 지어주세요" 프롬프트 + 핑크 테두리 `LineEdit`(max_length 12) + 핑크 라운드 "확인" 버튼. Enter/버튼 모두로 확정. `Main.gd`를 `_show_title` / `_show_naming` / `_show_tabs` 3 상태로 라우팅해 START 시 pets 비어있으면 naming, 아니면 tabs 바로 이동. `FamilyTree`의 "가족 초기화"는 PetStore/EventManager 리셋 후 `get_tree().current_scene._show_title()`로 메인 복귀 → 재시작 시 다시 naming 화면.
- **메인 스크린 로고 교체**: logo.png → main.png. main.png 픽셀 스캔 결과 콘텐츠는 y=400~680 구간에 있어 `AtlasTexture.region=Rect2(0, 400, 1024, 280)`로 크롭(아스펙트 3.66:1). LogoRect 480×131로 조정, WhiteBackground offset_bottom=180으로 축소. `MainScreen.gd`의 LOGO_PATH 상수도 main.png로.
- **다마고치 스테이지 축소 (1/4 면적)**: FamilyTree의 SubViewportContainer/SubViewport를 230×236 → **115×118**로 축소, 내부 Tamagotchi 인스턴스에 `scale = Vector2(0.5, 0.5)` 적용. 세부 렌더 해상도는 절반이지만 가계도 확장을 위한 화면 공간 확보.
- **이름 둥둥 떠있는 애니메이션**: FamilyTree 씬에서 기존 하단 NameLabel 제거. StageCenter → StageStack(VBox) → FloatHost(Control 200×48, 컨테이너 아님) → FloatingName(Label, anchors_preset=CENTER, neodgm 24px) → Stage 순으로 배치. `FamilyTree.gd._start_name_bob`이 `await process_frame` 후 현재 position.y를 기준점으로 잡고 `Tween.set_loops()`로 y±6px SINE 이즈 1초씩 반복하는 부드러운 bob. 포커스 캐릭터가 바뀌면 `floating_name.text = pet.given_name`만 업데이트되고 애니메이션은 계속 돌음.
- **가계도 위쪽 트리 맵 제거**: 배우자/자식이 상단 패널에 따로 카드로 뜨는 게 불필요하다는 피드백 반영. `FamilyTree.tscn`에서 TreeArea(TreePanel + ZoomSlider + FamilyStrip) 전체 삭제, `FamilyTree.gd`에서 관련 zoom/pan/strip 로직 모두 제거. 레이아웃은 이제 HUD → EventBanner → 메인 다마고치(FloatingName + Stage) → "가족 초기화" 푸터만 남음. 배우자는 결혼 이벤트로만, 자식은 출생 시 메인 스테이지에 포커스되는 방식으로 표현.
- **메인 스크린 장식 스프라이트**: `assets/images/image.png`(607×607) 3×3 스프라이트 시트에서 9개 장식(이미지별 `AtlasTexture`, 202×202 셀)을 `MainScreen.gd._spawn_decorations`로 스폰. 각 장식은 64×64 `TextureRect`, `pivot_offset`를 중심으로 잡고 개별 회전(-15°~+14°)을 `rotation`에 적용. 위치는 로고 상/좌우, 버튼 상/좌우/하단에 `DECO_LAYOUT` 상수로 하드코딩. 각 장식마다 랜덤 phase(0~1.5s) + 랜덤 period(0.9~1.4s)로 `position:y` ±5px SINE 이즈 Tween을 `set_loops()`로 영원히 돌려 둥둥 떠다니는 효과. `mouse_filter=IGNORE`로 START 버튼 클릭 방해 안 함.
- **메인 스크린 레이아웃 조정 + 장식 재분포**: LogoRect `offset_top` 20→50, `offset_bottom` 151→181(30px ↓). StartButton `offset_top` 230→290, `offset_bottom` 354→414(60px ↓). WhiteBackground를 `anchors_preset=15`(FULL_RECT)로 확장해 메인 화면 전체가 완전 흰색(폴카도트 배경 숨김). `DECO_LAYOUT`을 9개→**12개**로 확장: 타이틀 주변 8개(좌상/상좌/상중/상우/우상 + 좌하/중하/우하), START 버튼 주변 4개(좌/우/좌하/우하). 인덱스 0,1,3이 재사용됨(9 unique sprite로 12 장식 구성).
- **장식 위치 고정 (타이틀/버튼 자식화) + 타이틀 밀착**: 기존 캔버스 절대 좌표로 배치하던 장식들을 `LogoRect`와 `StartButton`의 자식으로 재부모화. 타이틀 주변 8개는 `DECO_LAYOUT_TITLE`(LogoRect 480×131 기준 로컬 좌표), 버튼 주변 4개는 `DECO_LAYOUT_BUTTON`(StartButton 358×124 기준). 창 리사이즈 시 LogoRect/StartButton이 센터 앵커를 따라 이동하면 자식 장식들도 상대 위치 유지 → 전체화면/작은 창에서도 장식 배치가 변하지 않음. 타이틀 장식 로컬 위치는 LogoRect 둘레에 밀착(상단 -25~-10, 좌우 -30/510, 하단 +140)으로 밀도 높임.
- **자연스러운 둥둥 떠다니는 효과**: 기존 Tween 기반 단순 y축 바운스를 `_process` 기반 Lissajous 방식으로 교체. 각 장식마다 x/y/rotation 3축 독립 sine(진폭/주기/위상 모두 랜덤)을 합성 — `amp_y 4~7.5px`, `amp_x 1.5~3.5px`, `amp_rot 0.03~0.09 rad`, 주기 1.8~4.0s, 위상 0~TAU. 결과: 상하뿐 아니라 좌우 살짝 흔들리고 각도도 미세하게 왔다갔다 하는 유기적 부유 감각.
- **parse 에러 수정**: `d.period_y` 같은 Dictionary 값 접근은 Variant로 반환되므로 `var dy := sin(...)` 타입 추론 실패. `float(d.period_y)` 명시 캐스팅으로 해결.
- **가족 초기화 → 네이밍 화면 직행**: FamilyTree의 reset 핸들러가 `_show_title()` 대신 `_show_naming()` 호출하도록 변경. 리셋 시 바로 이름 입력 화면으로.
- **이름 짓고 바로 캐릭터 표시**: FamilyTree에 `visibility_changed` 시그널 → `_on_visibility_changed`가 visible해질 때마다 `_refresh()`. 원인은 FamilyTree._ready가 앱 시작 시 1회만 돌았기 때문 — 네이밍 후 protagonist가 생긴 시점에 refresh가 안 돌아 빈 상태. 이제 탭이 보일 때마다 재렌더링.
- **한글 이름 마지막 글자 잘림 수정**: Windows + 한글 IME에서 Enter 키가 IME의 조합 커밋이 끝나기 전에 `LineEdit.text_submitted`를 발행해 마지막 음절이 잘리는 문제. `NameInputScreen.gd`에서 Enter 처리 시 `await get_tree().process_frame`로 한 프레임 늦춰 IME가 조합을 flush한 뒤 `line_edit.text`를 읽도록 수정. 확인 버튼 클릭은 포커스 변경이 조합 커밋을 트리거하므로 원래부터 문제 없음.
- **이벤트 배너 absolute 오버레이 전환**: 결혼 이벤트 배너가 VBox 안에 있어서 나타날 때 캐릭터를 아래로 밀던 문제. `FamilyTree.tscn`에서 `EventBanner`를 VBox 밖 FamilyTree 직계 자식으로 이동, `anchors_preset=8`(CENTER) + offset(-220, -40, 220, 40)으로 화면 중앙에 440×80 크기로 떠있는 오버레이 전환. 레이아웃을 밀지 않고 캐릭터 위에 겹쳐서 표시. 시각적 강조를 위해 StyleBoxFlat에 drop shadow 추가.
- **결혼 후 배우자 옆에 표시 + 이름도 각자**: `FamilyTree.tscn`의 단일 Stage 구조를 `StageRow`(HBoxContainer) → `Slot1` + `Slot2` 두 슬롯 구조로 확장. 각 슬롯에 FloatHost/FloatingName + Stage/SubViewport/Tama가 독립. `Slot2`는 기본 숨김. `FamilyTree.gd._refresh`에서 `PetStore.spouse_of(proto)`로 배우자 조회해 있으면 `Slot2.visible=true`로 보이고 배우자 캐릭터/이름 렌더링. 두 이름은 `_start_name_bob(label, phase_delay)` 헬퍼로 각자 살짝 엇갈린 위상(0s / 0.5s)으로 부드럽게 떠다님. 자식이 태어나도 메인 스테이지는 부모 2명 유지(포커스를 child로 전환하던 기존 로직 제거).
- **이름-캐릭터 간격 축소**: FloatHost 높이 48 → 30, 라벨 offset을 -14~14로 조정. 폰트 24→22. 라벨 하단과 Stage 상단 사이 공백이 약 12px에서 3~4px로 줄어들어 이름이 머리 바로 위에 뜨는 느낌.
- **메인 스크린 장식 아틀라스 재배치**: 센터 상단에 나란히 뜨던 하트(atlas 1, 2)를 로고 좌우 중단(`(-30, 55)`, `(510, 55)`)으로 이동. 그 자리에 아틀라스 4, 5로 교체. 고양이↔알(atlas 0↔8) 위치 상호 교환 — 타이틀 좌상단과 버튼 상단 사이 스왑. 버튼 주변도 atlas 인덱스 0↔8, 1→7, 3→6 재배치로 전반적 분포 변경.
- **가계도 배경 opacity 0.8**: `FamilyTree.tscn` 루트 바로 아래에 `BackdropOverlay` ColorRect 추가(`anchors_preset=15` 풀렉트, `color=(1, 1, 1, 0.8)`, `mouse_filter=IGNORE`). 뒤의 폴카도트 배경이 80% 흰색 오버레이 아래로 은은히 비침.
- **메인 장식 중복 제거**: 12개(타이틀 8 + 버튼 4) → **9개**(타이틀 6 + 버튼 3)로 축소, atlas 인덱스 0~8이 정확히 한 번씩만 사용되도록. 타이틀 주변의 하단 2개와 버튼 주변의 아래쪽 1개를 제거.
- **장식 모션 중심 기준 타원 궤도**: 기존 x/y/rotation 3축 독립 Lissajous(산만) → x와 y를 같은 주기에 90° 위상차로 묶어 `angle=t*TAU/period+phase`, `dx=cos*amp_x`, `dy=sin*amp_y` 형식의 **부드러운 타원 궤도**. 진폭도 x/y 2~3.5px(기존 1.5~7.5), rotation 0.015~0.04 rad(기존 0.03~0.09)로 절반 이하로 축소. 각 장식이 base position 주변을 조용히 선회하는 느낌.
- **결혼 후 자녀 이벤트 + 3번째 슬롯**: `EventManager.MAX_CHILDREN` 3→1. `FamilyTree.tscn`에 `Slot3`(FloatHost3+FloatingName3+Stage3+Tama3) 추가, 기본 숨김. `FamilyTree.gd._refresh`가 `PetStore.children_of(proto)` 첫 자식을 Slot3에 표시. `_on_child_born` 핸들러가 "자녀가 태어났습니다! {name}" 배너를 3초간 표시(결혼 배너와 달리 자동 사라짐, 수락 버튼 숨김). 세 슬롯 모두 이름 bob은 0/0.3/0.6초 위상차로 엇갈림.
- **탭 바 제거 + HOME → HUD 통합**: `Main.tscn`의 TabContainer에 `tabs_visible = false`로 상단 탭 스트립 숨김(가계도 콘텐츠만 보임). Main 루트의 독립 HomeButton 노드 및 관련 StyleBox 삭제. `Hud.tscn`에 `HomeButton`을 HBox 오른쪽에 추가(흰 배경 + 연핑크 테두리 라운드 스타일). `Hud.gd._on_home_pressed`가 `get_tree().current_scene._show_title()` 호출로 메인으로 복귀. 결과: `3일차 · 오전 8:00 · 홈` 한 줄 정렬.
- **자식은 부모 아래, 전체 드래그/줌 + 줌 슬라이더**: FamilyTree 스테이지 영역 재구성. `StageViewport`(Panel, clip_contents) 안에 `StageCanvas`(Control, CENTER 앵커, 280×340)를 배치. Slot1(부모) (0,0), Slot2(배우자) (150,0), Slot3(자식) (75,180)로 자식이 부모 아래에. `StageViewport.gui_input`이 휠 업/다운으로 ±10% 줌, 좌클릭 드래그로 pan. 오른쪽 하단에 `VSlider`(ZoomSlider, min=0.4 max=2.5) 배치 — 슬라이더와 양방향 동기. `StageCanvas.scale`/`position` 조정으로 확대/축소/이동, 중앙 정렬 유지.
- **HUD 구조 재설계 (투명 래퍼)**: 기존 PanelContainer 루트 → 투명 `HBoxContainer` 래퍼로 변경. 내부 구성: `HudPanel`(PanelContainer, 기존 핑크 테두리 라운드 + Day/Spacer/Time) + `HomeButton`(독립 라운드 버튼). 레이아웃: `[3일차 ... 오전 3:14] [홈]`으로 패널은 flex expand, HOME은 우측 자연 크기. `Hud.gd`도 `extends PanelContainer` → `extends HBoxContainer`.
- **이름-캐릭터 간격 30px 추가 축소**: 기존 FloatHost(VBox 안의 중간 레이어) 제거. 각 Slot을 VBoxContainer → **Control**로 변경(자동 레이아웃 X). Stage를 Slot 내부에 full rect로 배치 후 FloatingName을 Stage보다 **나중에** 자식으로 추가해 z-order상 Label이 Stage 위에 렌더되도록. Label 위치 `anchors_preset=5`(TOP_CENTER), offset_top=-10 / offset_bottom=20 → 라벨이 Stage 상단에서 10px 위부터 20px 내부까지 걸쳐 배치되어 캐릭터 머리 바로 위에 표시. Stage 위 z-order 문제 해결 위해 Slot을 Container가 아닌 Control로 바꿈.
- **이름 5px 상향**: FloatingName offsets offset_top=-10 → -15, offset_bottom=20 → 15. 라벨이 위로 5px 이동해 캐릭터와의 간격 +5.
- **초기 뷰 주인공 중심**: `FamilyTree.gd._center_on_protagonist` 추가 — StageCanvas 중앙 좌표와 Slot1 중앙 좌표의 차만큼 `_pan` 설정해 viewport 중앙에 주인공이 오도록. `_ready`와 `_on_reset_pressed`에서 호출. 배우자/자식 슬롯은 오른쪽/아래로 화면 밖에 배치되며 사용자가 드래그로 탐색.
- **주인공 중앙 배치 재구현**: 기존 StageCanvas를 CENTER 앵커(offsets -125..125)로 두면 Slot1(0,0)이 좌상단이라 중앙이 아닌 좌상단에 표시되던 문제. StageCanvas를 TOP_LEFT 앵커로 변경하고(`offset_right=250, offset_bottom=268`), `_center_on_protagonist`가 `stage_viewport.size * 0.5 - slot1_centre`로 `_canvas_base`를 직접 계산 → Slot1 중심이 viewport 정확히 중앙. `_pan`은 0에서 시작, 사용자 드래그 후 가산.
- **주인공 중앙 정렬 타이밍 수정**: `_ready`에서 `await get_tree().process_frame` 한 번으로 `_center_on_protagonist`를 호출했지만, FamilyTree가 TabContainer 안에 있고 시작 시 `tabs.visible=false`라 viewport.size가 아직 0인 상태였음. 결과적으로 잘못된 위치 계산. 수정: 센터링 로직을 `_on_visibility_changed`로 이동, `is_visible_in_tree()` 후 `process_frame` 두 번 대기 → 레이아웃 settling 보장. 매번 화면 보일 때마다 재중앙정렬.
- **주인공 중앙 정렬 로직 견고화**: 
  1. **타이밍**: `await process_frame` 두 번도 viewport.size가 0인 케이스(컨테이너 layout 지연) 있어 `stage_viewport.resized` 시그널을 추가 연결. 사이즈가 정해지면 자동으로 `_center_on_protagonist` 트리거.
  2. **줌 보정**: 기존 `viewport_size/2 - slot1_centre` 공식이 zoom=1일 때만 정확. pivot_offset이 캔버스 중심이라 줌 적용 시 슬롯 중심이 다르게 이동. 새 공식: `_canvas_base = viewport/2 - canvas_half - (slot1_centre - canvas_half) * zoom` — 줌과 무관하게 슬롯 중심을 viewport 중심에 정확히 매핑.
  3. **유저 입력 보존**: resize 핸들러가 `_pan != ZERO || _zoom != 1`이면 재중앙정렬 스킵 → 사용자가 드래그/줌한 위치를 리사이즈 후에도 유지.
- **캐릭터 호버 커서**: Slot1/2/3에 `mouse_filter = 1`(PASS) + `mouse_default_cursor_shape = 2`(CURSOR_POINTING_HAND). PASS라 마우스 이벤트는 부모 StageViewport로 통과되어 드래그/줌 영향 없이 커서만 변경.
- **캐릭터 클릭 → 모달**: `scenes/CharacterModal.tscn` + `scripts/CharacterModal.gd` 신규. 풀스크린 반투명 검정 backdrop + 중앙 흰 PanelContainer(핑크 테두리, drop shadow). 내부에 캐릭터 이름 + 플레이스홀더 라벨("(상태 / 행동 영역 — 추후 추가 예정)") + 하단 "확인" 버튼. `FamilyTree.gd`가 각 슬롯의 `gui_input` 시그널에 연결, 클릭/드래그를 거리(6px) 임계값으로 구분해 진짜 클릭일 때만 모달 표시. `_get_slot`/`_pet_for_slot` 헬퍼로 슬롯 인덱스 → 해당 펫 매핑.
  - **TODO (추후 구현 예정)**:
    1. 모달 내부에 캐릭터 직업(job) 표시 — 직업 시스템 자체 설계 필요
    2. 능력치(stats) 표시 — 어떤 능력치(체력/지력/매력/근력 등)를 둘지 정의 + PetStore 스키마 확장 + 갱신 로직
    3. 캐릭터 행동 선택 버튼 — 가능한 행동(예: 일하기/공부하기/놀기/먹기/쉬기) 정의 + 각 행동이 능력치/시간/이벤트에 미치는 영향 정의
    4. 모달 레이아웃을 좌측(스탯) / 우측(행동) 2단 또는 탭형으로 확장
    5. 직업/능력치/행동에 따른 결혼/자식 유전 영향 (옵션)
- **능력치 + 나이 + 수명 시스템**: 신규 `scripts/Stats.gd` (RefCounted, static API). 능력치 6종(`strength/intelligence/charisma/stamina/agility/luck` = 근력/지능/매력/체력/민첩/운), 1~10 정수. 수명은 출생 시 1~3 게임일 랜덤(개발용 상수 `LIFESPAN_MINUTES_MIN/MAX`, 추후 한 곳만 수정).
  - **나이 곡선 4단계**: 유년기(0~20% 수명, 배율 0.3→0.7) → 청년기(20~60%, 0.7→1.0) → 노년기(60~100%, 1.0→0.3) → 사망(>=100%, 모든 값 0). 표시 능력치 = base × age_factor.
  - **유전**: 자식 베이스 능력치 = `(부모A + 부모B) / 2 + randf_range(-2, 2)`, 1~10 클램프. body/eyes/color는 기존 45/45/10 유전 유지.
  - **PetStore 스키마 확장**: `stats`, `lifespan_minutes`, `died_at_minutes` 필드 추가. `_migrate_pets()`로 옛 저장 파일에 누락 필드 자동 backfill.
  - **EventManager 사망 감지**: `_check_deaths()`가 매 game minute tick마다 모든 펫의 수명 체크, 만료 시 `died_at_minutes` 기록 + `pet_died` 시그널 발행 + persist.
  - **CharacterModal 확장**: 플레이스홀더 → 나이 라벨(`"3일차 / 5일 (청년기)"`) + `GridContainer(columns=3)`로 능력치 6행(라벨 + ProgressBar + `값/10`). 사망 펫은 회색 톤 + `"사망 (X일 살았음)"` 표시.
  - **추후 연동 포인트**: 직업 시스템은 `current_stats(pet, now)` 결과를 임계값 비교해 직업 적성 판정. 행동 버튼은 `pet["stats"][k] += delta` 직접 갱신 후 `PetStore.persist()`.
- **주인공 초기 위치 50px 상향**: `_PROTAGONIST_VIEW_OFFSET = Vector2(0, -50)` 상수 추가, `_center_on_protagonist`의 `_canvas_base` 계산에 가산. 자식 슬롯이 아래쪽에 위치하므로 주인공을 약간 위로 올려서 자식 등장 시 화면에 자연스럽게 들어오는 여백 확보.
- **자녀 출생 시 사용자 이름 입력 + 추천 버튼**: 
  - `EventManager`의 자녀 출생 흐름 변경 — 자동 생성 → 시간 도래 시 `child_naming_requested(parent_a, parent_b)` 시그널만 발행하고 `_pending_child_parents`에 부모 보관. 사용자가 이름 확정 시 `confirm_child_birth(name)`이 실제로 `Genetics.create_child` + `PetStore.add_pet` + `child_born` 발행.
  - `NameInputScreen.tscn`에 "추천" 버튼 추가(LineEdit 우측 HBox). 클릭 시 `PetStore.GIVEN_NAMES`에서 랜덤 추출해 입력칸에 채워줌. 사용자는 그대로 확인하거나 수정 가능. 결정은 항상 사용자.
  - `NameInputScreen.gd`: `set_prompt(text)` API로 프롬프트 문구 컨텍스트별 변경. 주인공/자녀 양쪽에서 재사용.
  - `Main.gd`: `_naming_context` 상태(`"protagonist"|"child"`)로 confirm 시 분기. `EventManager.child_naming_requested` 구독해 자녀 이벤트 발생 시 `_open_child_naming()`. 세션 복원 시 보류된 자녀가 있으면 START 후 즉시 네이밍 화면으로.
- **자녀 출생 모달 분리**: 자녀 이름 받기를 풀스크린 NameInputScreen 재사용에서 전용 모달로 분리. `EventManager`가 자녀 시간 도래 시 `Genetics.create_child`로 **미리 굴림**(body/eyes/color/stats 결정)해서 `_pending_child` 보관 → `child_naming_requested(pending_child)` 발행. `confirm_child_birth(name)`에서 given_name만 갱신해 `add_pet`. `pending_child()` getter도 추가(세션 복원용).
  - 신규 `scenes/ChildBirthModal.tscn` + `scripts/ChildBirthModal.gd` — 반투명 backdrop + 380×380 라운드 패널. 구성: "자녀가 태어났습니다." → SubViewport(115×118)에 미리 굴린 자녀 캐릭터 표시 → 이름 입력 + 추천 버튼 HBox → 확인 버튼.
  - `FamilyTree.tscn`에 모달 인스턴스 추가, `FamilyTree.gd`가 `child_naming_requested` 구독 → `child_birth_modal.show_for(pending)`. `_on_child_born` 핸들러의 "자녀가 태어났습니다!" 배너/3초 타이머 제거(모달이 그 역할 대체).
- **가족 초기화 후 주인공 네이밍 분기 버그 수정**: 이전 변경에서 `_naming_context` 상태가 stale로 남아 reset 후에도 자녀 confirm 분기로 들어가던 버그. `Main.gd`를 주인공 전용으로 단순화(상태 변수 제거, EventManager 구독 제거). 자녀 네이밍은 FamilyTree 내부 모달이 전담하므로 책임 분리도 명확해짐.
