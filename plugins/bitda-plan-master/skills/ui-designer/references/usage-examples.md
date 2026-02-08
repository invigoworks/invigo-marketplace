# UI Designer Usage Examples

## Example 1: Full Screen Generation

```
User: 작업지시 기획서 기반으로 화면 코드 생성해줘

Response:

## Phase 0: 프로젝트 구조 분석

[code-explorer 에이전트로 프로젝트 구조 파악]
✅ 대상 앱: apps/manufacturing
✅ pages 폴더: apps/manufacturing/src/pages/
✅ 관련 도메인: production/

## Phase 1: 블록 선택

작업지시 기능에 필요한 블록:
- table-01: 목록 화면
- form-01: 등록/수정 Sheet
- dialog-01: 확인 팝업

## Phase 2: 블록 설치

[get-blocks-metadata 실행]
[collect_selected_blocks 실행]
[get_add_command_for_items 실행]

명령어: npx shadcn@latest add "https://..."

## Phase 3: 코드 생성

생성된 파일:
apps/manufacturing/src/pages/
├── index.ts                    # ← export 추가
└── production/
    ├── index.ts                # ← export 추가
    ├── OrderPage.tsx           # ← 목록 페이지
    ├── OrderSheet.tsx          # ← 등록/수정 Sheet
    └── OrderDialog.tsx         # ← 삭제 확인 Dialog

## Phase 4: router.tsx 업데이트

{ path: 'production/order', element: <OrderPage /> } 추가

## 다음 단계

테스트 후 `/github-deployer`로 PR 생성
```

---

## Example 2: /cui Command

```
User: /cui 테이블 블록으로 제품 목록 만들어줘

Response:

## Phase 0: 프로젝트 구조 확인

[Glob 패턴으로 앱 구조 파악]
- 대상 앱: apps/manufacturing
- pages 경로: apps/manufacturing/src/pages/

## Phase 1: 블록 선택

[get-create-instructions 실행]
[get-blocks-metadata 실행]
[get-block-meta-content endpoint="table" 실행]

table-01 블록을 선택합니다.

## Phase 2: 블록 설치

[collect_selected_blocks 실행]
[get_add_command_for_items 실행]

설치 명령어:
npx shadcn@latest add "https://shadcnstudio.com/r/table-01"

## Phase 3: 커스터마이징

생성 파일: apps/manufacturing/src/pages/settings/ProductsPage.tsx

코드 특징:
- import from '@bitda/web-platform/shadcn'
- React Hook Form, React Query 사용
- API 연동 및 상태 관리 구현
```

---

## Example 3: 기존 프로젝트에 기능 추가

```
User: 재고 관리 화면 만들어줘

Response:

## Phase 0: 프로젝트 구조 분석

[code-explorer 에이전트 실행]

분석 결과:
├── apps/manufacturing/src/
│   ├── pages/
│   │   ├── production/         # 생산 도메인
│   │   └── quality/            # 품질 도메인
│   └── router.tsx

권장 경로: apps/manufacturing/src/pages/inventory/

## Phase 1-3: (블록 선택 및 설치 진행)

## Phase 4: 생성 파일

apps/manufacturing/src/pages/inventory/
├── index.ts
├── StockPage.tsx          # 재고 현황
├── ReceivingPage.tsx      # 입고 관리
└── ShippingPage.tsx       # 출고 관리

router.tsx 업데이트:
{ path: 'inventory/stock', element: <StockPage /> },
{ path: 'inventory/receiving', element: <ReceivingPage /> },
{ path: 'inventory/shipping', element: <ShippingPage /> },
```

---

## Example 4: invigo-agents 활용

```
User: 복잡한 대시보드 화면 만들어줘

Response:

## Phase 0: 아키텍처 설계 (code-architect 에이전트)

[Task tool: feature-dev:code-architect 에이전트 호출]

대시보드 컴포넌트 구조:
├── DashboardPage.tsx           # 메인 레이아웃
├── components/
│   ├── StatsCard.tsx           # KPI 카드
│   ├── ProductionChart.tsx     # 생산 현황 차트
│   ├── RecentOrdersTable.tsx   # 최근 작업지시 테이블
│   └── AlertsPanel.tsx         # 알림 패널

## Phase 1-3: UI 코드 생성

[shadcn studio 블록 활용]
- stats-card-01, chart-01, table-01 블록 조합

## Phase 4: 코드 리뷰 (code-reviewer 에이전트)

[Task tool: invigo-agents:code-reviewer 에이전트 호출]

리뷰 결과:
✅ Import 패턴 일관성
✅ 타입 안전성
✅ 컴포넌트 구조 적절성
⚠️ StatsCard 공통 컴포넌트화 권장
```

---

## Example 5: feature-planner 연동

```
/feature-implementer 회사 관리 UI 구현 계획

Output:
- Phase 1: 타입 정의 + Mock 데이터 (독립)
- Phase 2: 컬럼 정의 (Phase 1 의존)
- Phase 3-A: 테이블 컴포넌트 (Phase 2 의존)
- Phase 3-B: Sheet 컴포넌트 (Phase 1 의존) ← 3-A와 병렬 가능
- Phase 3-C: Dialog 컴포넌트 (Phase 1 의존) ← 3-A, 3-B와 병렬 가능
- Phase 4: 메인 페이지 (Phase 3-A,B,C 의존)
- Phase 5: 테스트 코드 (Phase 4 의존)
  - Group A,B,D: 병렬
  - Group C,E: 순차
```
