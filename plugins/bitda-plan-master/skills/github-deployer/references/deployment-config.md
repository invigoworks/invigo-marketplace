# Deployment Configuration

> 이 파일은 github-deployer 스킬의 배포 설정을 정의합니다.

---

## Target Repository

### Pre-Publishing Repository

| 항목 | 값 |
|-----|-----|
| Organization | invigoworks |
| Repository | pre-publishing |
| URL | https://github.com/invigoworks/pre-publishing |
| Default Branch | main |
| Purpose | UI Preview (프론트엔드 퍼블리싱) |

---

## Branch Strategy

### Branch Types

| 타입 | 패턴 | 용도 |
|-----|------|------|
| Main | `main` | 프로덕션 배포 |
| Feature | `feature/[코드]-[이름]` | 새 기능 개발 |
| Fix | `fix/[이슈번호]-[설명]` | 버그 수정 |
| Refactor | `refactor/[설명]` | 리팩토링 |

### Feature Branch Naming

```
feature/[기능코드]-[기능명-영문]
```

#### Examples

| 기능 | 기능코드 | 브랜치명 |
|-----|---------|---------|
| 작업지시 | PRD-WO | `feature/PRD-WO-work-orders` |
| 제품관리 | MST-ITEM | `feature/MST-ITEM-products` |
| 재고현황 | INV-STS | `feature/INV-STS-inventory-status` |
| 거래처관리 | MST-CUS | `feature/MST-CUS-customers` |
| 원재료관리 | MST-MATR | `feature/MST-MATR-materials` |
| 사용자관리 | ADM-USR | `feature/ADM-USR-users` |
| 회사관리 | ADM-COM | `feature/ADM-COM-companies` |

---

## Commit Convention

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

| Type | 설명 | Example |
|------|-----|---------|
| feat | 새 기능 | `feat(PRD-WO): 작업지시 목록 화면 추가` |
| fix | 버그 수정 | `fix(MST-ITEM): 제품 저장 오류 수정` |
| refactor | 리팩토링 | `refactor(shared): SearchableSelect 최적화` |
| style | 스타일 변경 | `style(ui): 버튼 호버 효과 개선` |
| docs | 문서 변경 | `docs: README 업데이트` |
| chore | 기타 작업 | `chore: 의존성 업데이트` |

### Scope

- **기능코드**: `PRD-WO`, `MST-ITEM`, `INV-STS`, `ADM-USR`
- **공통**: `shared`, `ui`, `lib`
- **설정**: `config`, `build`

### Footer

항상 다음 footer 포함:

```
🤖 Generated with Claude Code

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

---

## Directory Structure

### 기능별 디렉토리

```
src/app/
├── work-orders/           # 작업지시 (PRD-WO)
│   ├── page.tsx
│   ├── [id]/
│   │   └── page.tsx
│   └── components/
│       ├── WorkOrderSheet.tsx
│       ├── WorkOrderTable.tsx
│       └── columns.tsx
├── products/              # 제품관리 (MST-ITEM)
├── materials/             # 원재료관리 (MST-MATR)
├── customers/             # 거래처관리 (MST-CUS)
├── users/                 # 사용자관리 (ADM-USR)
├── companies/             # 회사관리 (ADM-COM)
└── inventory/             # 재고관리 (INV)
```

### 공통 컴포넌트

```
src/components/
├── ui/                    # shadcn/ui (자동 생성)
│   ├── button.tsx
│   ├── input.tsx
│   └── ...
└── shared/                # 재사용 컴포넌트
    ├── SearchableSelect.tsx
    ├── DateRangePicker.tsx
    ├── StatusBadge.tsx
    ├── ConfirmDialog.tsx
    ├── EmptyState.tsx
    ├── TableSkeleton.tsx
    └── index.ts
```

### 유틸리티

```
src/lib/
├── validations/           # Zod 스키마
│   ├── work-order.ts
│   ├── product.ts
│   └── ...
├── utils/                 # 유틸리티 함수
└── api/                   # API 클라이언트 (mock)
```

---

## PR Template

### Title Format

```
feat([기능코드]): [기능명] 화면 구현
```

### Body Template

```markdown
## Summary
[기능명] 기능의 UI 화면을 구현했습니다.

## 구현 화면
| 화면명 | 화면 코드 | 유형 |
|--------|----------|------|
| | BITDA-XX-XX-XX-S001 | 목록 |
| | BITDA-XX-XX-XX-F001 | 등록/수정 |
| | BITDA-XX-XX-XX-P001 | 팝업 |

## 기술 스택
- Next.js (App Router)
- shadcn/ui
- React Hook Form + Zod

## 테스트 체크리스트
- [ ] 목록 화면 렌더링
- [ ] 등록 폼 동작
- [ ] 수정 폼 동작
- [ ] 삭제 확인 팝업
- [ ] 반응형 레이아웃

## Screenshots
[스크린샷 첨부]

## 관련 기획서
[Notion 링크]

🤖 Generated with Claude Code
```

---

## Merge Strategy

### Squash Merge

모든 PR은 squash merge로 진행:

```bash
gh pr merge [PR번호] --squash --delete-branch
```

### Merge Commit Message

```
feat([기능코드]): [기능명] 화면 구현 (#PR번호)
```

---

## Post-Deployment Checklist

배포 완료 후 확인 사항:

- [ ] 브랜치 푸시 확인
- [ ] 코드 리뷰 요청 (필요시)
- [ ] 디자인/기능 검토
- [ ] 수정사항 반영 후 재푸시
- [ ] 검토 완료 후 notion-uploader로 DB 등록

---

## 최종 업데이트

- 날짜: 2026-02-09
- 작성자: Claude Code
