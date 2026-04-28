# TamaWorld Catalog Editor

`data/*.json`(actions / clubs / schools / jobs)을 브라우저에서 직접 편집하는 로컬 도구입니다. Vite 개발 서버 안에 작은 미들웨어가 들어 있어 별도의 백엔드 없이 디스크의 JSON 파일을 그대로 읽고 씁니다.

## 실행

```bash
cd tools/catalog-editor
npm install
npm run dev
```

브라우저에서 안내된 주소(기본 `http://localhost:5179`)를 열면 됩니다.

## 구성

- **상단 탭**: 행동 / 동호회 / 학교 / 직업 / 단계 미리보기
- **검증 바**: 단계 id 오타·잘못된 색상 hex·`sets_school` 누락 같은 cross-reference 문제를 실시간으로 표시
- **좌측 리스트**: 선택한 카테고리의 항목들 (색상 스와치 + 라벨 + id). 하단에서 새 id로 항목 추가 가능
- **우측 인스펙터**: 선택한 항목의 필드를 폼으로 편집 — phase 칩 토글, 색상 피커, 스탯 효과 입력 등
- **단계 미리보기**: 단계별로 어떤 행동이 게이트되어 있는지 한눈에 확인

저장 버튼은 `dirty` 상태일 때만 활성화되며, 저장 시 디스크의 JSON 파일이 prettified 되어 덮어씌워집니다. 저장 후 Godot 게임을 재실행하면 [scripts/CatalogLoader.gd](../../scripts/CatalogLoader.gd)가 새 데이터를 읽어들여 반영합니다.

## 알려진 한계 (MVP)

- 단계 비율(Stats.PHASES)·번역 키(translations/strings.json)는 편집 불가 — 필요해지면 분리해 대응 예정
- React Flow 같은 풀 그래프 뷰 없음 — 단계 카드 그리드로 대체
- 펫 시뮬레이터 미니 패널 없음 (다음 반복에서 추가 예정)
- 자동 저장 없음 — 명시적인 "저장" 버튼만 있음
- 저장 시 게임은 재실행 필요 (핫 리로드 미구현)
