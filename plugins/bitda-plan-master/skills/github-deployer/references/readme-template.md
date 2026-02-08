# README Template for Pre-Publishing Repository

이 파일은 `invigoworks/pre-publishing` 저장소의 README.md 템플릿입니다.

---

## 기본 README.md 템플릿

```markdown
# Pre-Publishing Repository

BITDA ERP UI 코드 사전 검토용 저장소입니다.

## 개요

이 저장소는 BITDA ERP 시스템의 UI 코드를 사전 검토하기 위한 목적으로 사용됩니다.
ui-designer 스킬로 생성된 코드가 이곳에 배포되며, 검토 후 메인 프로젝트에 통합됩니다.

## 구현된 기능 (Implemented Features)

| 기능 코드 | 기능명 | 화면 | 상태 | 날짜 |
|-----------|--------|------|------|------|
| - | - | - | - | - |

## 기술 스택

- **프레임워크**: Next.js 14+ (App Router)
- **언어**: TypeScript
- **UI 라이브러리**: shadcn/ui
- **폼 관리**: React Hook Form + Zod
- **테이블**: TanStack Table v8
- **스타일링**: Tailwind CSS

## 디렉토리 구조

```
src/
├── app/                    # Next.js App Router 페이지
│   └── [feature]/          # 기능별 페이지
│       ├── page.tsx        # 목록 페이지
│       └── components/     # 기능별 컴포넌트
│           ├── columns.tsx # 테이블 컬럼 정의
│           └── *Sheet.tsx  # 등록/수정 폼
├── components/
│   └── shared/             # 공유 컴포넌트
├── lib/
│   └── validations/        # Zod 스키마
└── types/                  # TypeScript 타입 정의
```

## 검토 프로세스

1. **코드 배포**: ui-designer → github-deployer로 기능 브랜치에 배포
2. **코드 확인**: 브라우저에서 GitHub 코드 리뷰
3. **피드백**: 수정 필요 시 ui-designer로 재작업
4. **승인**: PR 검토 및 승인
5. **등록**: notion-uploader로 Notion DB에 화면 등록

## 브랜치 네이밍 규칙

- `feature/[기능코드]-[기능명-영문]`
- 예시:
  - `feature/PRD-WO-work-orders`
  - `feature/MST-ITEM-products`
  - `feature/ADM-USR-users`

## 커밋 컨벤션

```
<type>(<scope>): <subject>

<body>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

### Type 종류
- `feat`: 새 기능
- `fix`: 버그 수정
- `refactor`: 리팩토링
- `style`: 스타일 변경
- `docs`: 문서 변경

---

🤖 Generated with Claude Code
```

---

## README.md 업데이트 가이드

### 새 기능 추가 시

"구현된 기능" 테이블에 새 행을 추가:

```markdown
| DCL01 | 주세신고 | S001, F001, P001 | ✅ 완료 | 2025-01-12 |
```

### 화면 코드 형식

- `S001`: 목록/조회 화면
- `F001`: 등록/수정 폼
- `P001`: 팝업/모달
- `D001`: 상세 화면

### 상태 표시

- `✅ 완료`: 구현 및 검토 완료
- `🔄 검토중`: PR 검토 진행 중
- `🚧 개발중`: 기능 개발 진행 중
