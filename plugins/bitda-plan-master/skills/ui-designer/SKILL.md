---
name: ui-designer
description: This skill generates production-ready React/Next.js UI code using shadcn/studio MCP server. Use this skill after plan-developer completes feature specifications to create UI components with shadcn blocks. Triggers on requests like "UI 코드 생성해줘", "화면 만들어줘", "shadcn으로 디자인해줘", "/cui", "/iui", "/rui", or when transitioning from plan-developer skill.
---

# UI Designer

## Overview

UI 코드 생성 스킬:
- **/cui**: 기존 shadcn studio 블록으로 새 화면 생성
- **/iui**: 베스트 프랙티스 기반 창의적 디자인 (Pro only)
- **/rui**: 기존 컴포넌트 업데이트/개선

Output: Production-ready React/Next.js code using shadcn/ui components.

## Reference Files

| 파일 | 용도 |
|------|------|
| `references/component-reuse.md` | **CRITICAL** 컴포넌트 재사용 분석 가이드 |
| `references/consistency-rules.md` | **CRITICAL** UI 일관성 필수 규칙 |
| `references/component-templates.md` | 코드 템플릿 (List, Form, Dialog) |
| `references/agent-integration.md` | 에이전트 활용 + Vercel Best Practices |
| `references/visual-verification.md` | 시각적 검증 가이드 |

---

## Workflow

| Phase | 설명 |
|-------|------|
| 0 | 프로젝트 구조 + **컴포넌트 재사용 분석** |
| 1 | Planning Document Intake |
| 2 | Block Selection & Collection |
| 3 | Code Generation |
| 4 | **반복 패턴 컴포넌트화** |
| 5 | shadcn Studio Workflows |
| 6 | Validation Schema |
| 7-8 | Test Planning & Visual Verification |
| 9 | UI Consistency Check |

---

## Phase 0: Project Structure & Component Analysis (CRITICAL)

> **상세: `references/component-reuse.md`**

### 필수 수행 사항

1. `feature-dev:code-explorer` 에이전트로 구조 파악
2. **기존 컴포넌트 탐색** (재사용 우선)
3. 기존 import 패턴, 명명 규칙 준수
4. **동일 도메인 유사 페이지 스타일 복사** (Shift Left - 아래 참조)

### 컴포넌트 탐색 우선순위

1. `packages/web-platform/src/components/` - 공통
2. `apps/[앱명]/src/components/` - 앱 레벨
3. `apps/[앱명]/src/[도메인]/components/` - 도메인

**CRITICAL**: 기존 컴포넌트가 존재하면 반드시 재사용. 신규 생성은 기존이 없을 때만.

### 동일 도메인 스타일 참조 (CRITICAL - Shift Left)

> **목적**: ui-improver에서 반복 발견되는 "도메인 내 스타일 불일치"를 코드 생성 시 사전 방지

**필수 절차**:
1. **유사 페이지 검색**: 같은 앱/도메인 폴더에서 이미 구현된 페이지를 Glob으로 찾기
2. **스타일 패턴 추출**: 해당 페이지의 다음 요소를 읽고 동일하게 적용
   - 테이블 세로 구분선 (`border-r` 패턴)
   - 뱃지 컴포넌트 (LiquorTypeBadge, StatusBadge, EvidenceStatusBadge 등)
   - CardHeader 액션 버튼 배치 패턴
   - 필터/검색 구성
3. **기획서 vs 기존 패턴 충돌 시**: 기존 패턴을 우선하고 사용자에게 알림

```typescript
// Phase 0에서 반드시 실행
const domainPages = await Glob({ pattern: `apps/${app}/src/${domain}/**/page.tsx` });
// 각 페이지의 테이블 스타일, 뱃지 사용, 버튼 배치 패턴 확인
```

**빈번한 불일치 사례** (과거 ui-improver 세션에서 발견):
| 불일치 유형 | 발생 빈도 | 방지 방법 |
|------------|----------|----------|
| 일반 Badge → 도메인 전용 뱃지 | 높음 | 기존 페이지에서 import된 뱃지 컴포넌트 확인 |
| 테이블 border-r 누락 | 높음 | 같은 탭 그룹의 다른 탭과 비교 |
| 불필요한 요약 카드/필터 | 중간 | 데이터 규모와 기획 의도 재확인 |
| CardHeader 버튼 위치 불일치 | 중간 | 동일 도메인 페이지의 버튼 배치 복사 |

### Preview 앱 구조

```
apps/preview/src/router.tsx  ← 모든 앱 라우트 통합
  ├── /liquor, /manufacturing, /admin, /tax-office
```

개발 서버: `http://localhost:3000/[앱명]/[경로]` (기본 포트)

> **서버 실행**: 서버가 없으면 `pnpm dev:preview` 또는 `cd apps/preview && pnpm dev --port 3000`

---

## Phase 1-2: Planning & Block Selection

### Block 매핑

| 화면 유형 | 권장 블록 |
|----------|----------|
| 대시보드 (D) | dashboard-*, stats-*, chart-* |
| 목록 (S) | table-*, data-table-* |
| 등록/수정 (F) | form-*, input-*, sheet-* |
| 팝업 (P) | dialog-*, modal-*, alert-* |

### /cui Workflow

1. `get-create-instructions` → 2. `get-blocks-metadata` → 3. `get-block-meta-content` → 4. `collect_selected_blocks` → 5. `get_add_command_for_items` → 6. Execute install → 7. Customize

**CRITICAL**: 단계별 순서 준수. 건너뛰기 금지.

---

## Phase 3: Code Generation

> **상세 템플릿: `references/component-templates.md`**
> **필수 규칙: `references/consistency-rules.md`**

### 4대 필수 규칙

| 항목 | 올바른 사용 |
|------|------------|
| 페이지 타이틀 | `<PageTitle>` 컴포넌트 |
| Sheet 패딩 | `<FormSheet>` 사용 |
| 날짜 선택 | `<DateRangeFilter>` 또는 `<DateRangePicker>` |
| 테이블 패딩 | `overflow-x-auto px-4 py-2` 래퍼 |

### React 코드 품질 체크리스트 (CRITICAL)

| 항목 | 규칙 |
|------|------|
| 검색 입력 | `SearchInput` 컴포넌트 사용 (Search 아이콘+Input 직접 조합 금지) |
| Fragment key | `.map()` 내 다중 요소 → `<Fragment key={id}>` 필수 (`<>` 금지) |
| useMemo | 필터링/정렬 파생 데이터는 반드시 `useMemo` 사용 |
| console.log | 디버그용 `console.log` 미포함 확인 |

### File Structure

```
apps/[앱명]/src/pages/[도메인]/
├── [Feature]Page.tsx
└── components/
    ├── [Feature]Sheet.tsx
    └── [Feature]Dialog.tsx
```

---

## Phase 4: Reusable Component Creation (CRITICAL)

> **상세: `references/component-reuse.md`**

### 반복 패턴 규칙

| 반복 횟수 | 조치 |
|----------|------|
| 1-2회 | 인라인 허용 |
| **3회 이상** | **반드시 컴포넌트화** |
| 앱 간 공유 | `@bitda/web-platform`에 추가 |

### 기본 재사용 패턴

| 패턴 | 컴포넌트 |
|------|---------|
| 검색 가능한 선택 | SearchableSelect |
| 날짜 범위 | DateRangePicker |
| 상태 배지 | StatusBadge |
| 확인 다이얼로그 | ConfirmDialog |
| 시간 입력 | TimeInput |
| 수량+단위 | QuantityUnitInput |

---

## Phase 5: shadcn Studio Workflows

| 명령 | 용도 |
|------|------|
| /cui | 기존 블록으로 새 화면 생성 |
| /iui | 영감받아 창의적 디자인 (Pro) |
| /rui | 기존 컴포넌트 업데이트 |

---

## Phase 6: Validation Schema

```tsx
import { z } from "zod";

export const workOrderSchema = z.object({
  productId: z.string().min(1, "제품을 선택해주세요"),
  quantity: z.number().min(1, "수량은 1 이상"),
  dueDate: z.date({ required_error: "작업기한 필수" }),
});
```

---

## Phase 7-8: Test & Visual Verification

> **상세: `references/test-planning.md`, `references/visual-verification.md`**

1. 테스트 시나리오 그룹화
2. `/agent-browser` **스킬**로 UI 검증 (⚠️ 에이전트 아님, Skill 도구로 호출)
3. 스크린샷 캡처 및 보고

**호출 방법:**
```typescript
// ✅ 올바른 호출 (스킬)
Skill({ skill: "agent-browser", args: "http://localhost:3000/..." })

// ❌ 잘못된 호출 (에이전트로 오인)
// Task({ subagent_type: "agent-browser", ... })
```

> **서버 확인**: `lsof -i :3000`으로 확인 후, 없으면 `pnpm dev:preview` 실행

---

## Phase 9: UI Consistency Check (AUTO)

코드 생성 완료 후 `ui-supervisor` 에이전트 자동 실행:

```typescript
Task({
  subagent_type: "ui-supervisor",
  prompt: `UI 일관성 검사: [생성된 파일 목록]
    1. 기존 페이지와 레이아웃 일관성
    2. 공유 컴포넌트 재사용 여부
    3. 테이블/폼/다이얼로그 패턴 준수`
})
```

| 결과 | 액션 |
|------|------|
| Critical 발견 | 즉시 `/ui-improver` 실행 |
| Major 발견 | 사용자 확인 후 적용 |
| Minor만 발견 | 권장사항 안내 |
| 이슈 없음 | 배포 진행 |

---

## Agent Summary

| Agent | 용도 |
|-------|------|
| `feature-dev:code-explorer` | 프로젝트 구조 분석 |
| `feature-dev:code-architect` | 아키텍처 설계 |
| `invigo-agents:frontend-developer` | 컴포넌트 생성 |
| `invigo-agents:code-reviewer` | 코드 리뷰 |

---

## Error Handling

| 에러 | 대응 |
|------|------|
| MCP Server Not Connected | shadcn-studio-mcp 설정 확인 |
| Block Not Found | 대안 블록 또는 커스텀 구현 |
| Install Failed | 프로젝트 설정 확인 |

---

## Handoff

코드 생성 완료 후: Visual Verification → 코드 리뷰 → `github-deployer` 스킬로 배포

Trigger: "GitHub에 배포해줘", "코드 푸시해줘"
