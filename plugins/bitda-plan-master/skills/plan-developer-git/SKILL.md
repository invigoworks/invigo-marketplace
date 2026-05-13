---
name: plan-developer-git
description: Git 기반 기획문서 작성·수정 스킬. docs/specs/ 디렉토리에 markdown으로 기획서를 작성하고 PR 흐름으로 리뷰·머지한다. Notion 기반 plan-developer와 병행 운영되며, 신규 기획은 이 스킬을 사용한다. Triggers on "git 기획해줘", "git 페이지별 기획", "docs/specs에 기획 작성", "/plan-developer-git", "PR로 기획 만들어". 기획 변경(Mode 1·4)도 동일 흐름 — 원본 파일을 직접 수정하고 PR description으로 변경 이유 추적. 기획 전용 PR을 만들고 싶을 때, git diff로 기획 변경을 추적하고 싶을 때, 기존 Notion 흐름의 버전 관리 부족을 해결하고 싶을 때 반드시 사용한다.
---

# plan-developer-git

Notion 기반 `plan-developer`의 git 변종. 기획서를 markdown으로 코드 repo
안(`docs/specs/`)에 두고, PR 워크플로우로 리뷰·머지·디프 추적한다.

> **병행 운영**: 기존 plan-developer(Notion)는 그대로 유지. 신규 기획·변경은
> 이 스킬을 사용한다. 이미 Notion에 머지된 페이지가 git에 처음 작성되면
> 스킬이 자동으로 Notion 페이지 status를 `로그 저장용`으로 전환한다(예외 적용).

## When to use

| 상황 | 사용 |
|------|------|
| 신규 페이지/기능 기획서 작성 | ✅ |
| 이미 git에 있는 기획서 수정 (Mode 1) | ✅ |
| 기획 변경 명세 (Mode 4) | ✅ — 원본 직접 수정 + PR description |
| 재설계 (Mode 2) | ✅ — 기존 spec을 `status: DEPRECATED`로 두고 신규 작성 |
| 기존 Notion 페이지 그대로 수정 | ❌ → 기존 `plan-developer` 사용 |
| Notion 페이지 검색·조회 | ❌ → Notion MCP 직접 |

## Prerequisites

- **prepub-analyzer**: Prepub 코드가 있는 모듈의 Mode 1·4·5 작업 시 **선행 실행**
  (`/tmp/<module>-ui-code-gap.md` 산출). Mode 2·3은 생략 가능.
- **공통 규칙 파일** (`.claude/shared-references/`):
  - `ui-consistency-rules.md`
  - `cross-reference-rules.md`
  - `backend-architecture.md`
  (없으면 작업 전 plan-developer에서 이동시킴 — 이 스킬 첫 사용 시 마이그레이션 필요)
- **로컬 도구**: `pnpm tsx` 사용 가능 (`scripts/specs-index.ts` 실행용)

## File Structure

```
docs/specs/
├── README.md                    # 자동 생성 (specs-index.ts)
├── _schema/page-spec.schema.json # frontmatter JSON Schema
├── _templates/
│   ├── page-spec.md             # 페이지(하위 메뉴) 단위
│   └── document.md              # 기능(상위 메뉴) 단위
├── _golden/                     # 회귀 추적용 골든 케이스
└── {liquor|manufacturing|admin}/
    └── {도메인}/
        └── {화면코드}-{화면유형}-({화면명}).md
```

**파일명 규칙**: `BITDA-{앱}-{도메인}-S{NNN}-{유형}-({한글명}).md`
예: `BITDA-LQ-PRD-S001-PAGE-(생산계획-등록).md`

화면 유형: `PAGE`(페이지), `MOD`(모달), `FUNC`(기능 묶음)

## Frontmatter Schema

모든 spec 파일은 다음 frontmatter를 가진다. 검증은 `pnpm tsx scripts/specs-index.ts --validate`
또는 pre-commit hook이 자동 수행.

```yaml
---
screen_code: BITDA-LQ-PRD-S001       # 필수, 전역 유일
screen_type: PAGE                     # PAGE | MOD | FUNC
title: 생산계획-등록                  # 필수
status: DRAFT | REVIEW | CONFIRMED | DEPRECATED  # 필수
owner: gimjinhyeog                    # GitHub 핸들
version: 1.0.0                        # semver
related_screens: [BITDA-LQ-PRD-S002]  # 다른 spec의 screen_code 배열
related_code:                         # 구현 파일/디렉토리 경로
  - apps/liquor/src/production/plan/
notion_legacy_url: https://www.notion.so/... # 기존 Notion 페이지가 있을 때만
last_updated: 2026-05-13
---
```

## Workflow

### Mode 1: 기존 기획 업데이트

1. 사용자 요청에서 대상 spec 파일 식별 (화면코드 또는 경로)
2. **prepub-analyzer** 실행 (해당 모듈 prepub 코드 있을 때)
3. 파일 Read → 변경 부분 Edit
4. frontmatter `version` 마이너 증가, `last_updated` 갱신
5. `pnpm tsx scripts/specs-index.ts` 실행 → README 갱신, 검증 통과 확인
6. 사용자에게 git diff 표시 → 승인 요청
7. 브랜치 `spec/<화면코드>` 체크아웃(이미 있으면 재사용) → 커밋 → push → PR 생성
   - 커밋 메시지: `spec(<화면코드>): <변경 요약>`
   - PR title: `spec: <화면명> 기획 업데이트`
   - PR body: 변경 이유, 영향받는 코드 경로

### Mode 2: 재설계

1. 기존 spec의 frontmatter `status: DEPRECATED` + `superseded_by: <신규 screen_code>` 추가
2. 신규 spec 파일 작성 (다른 screen_code 부여) — Mode 3 흐름
3. PR 한 번에 둘 다 포함

### Mode 3: 신규 기능 개발 (상위 메뉴)

1. `docs/specs/_templates/document.md` 복사 → 내용 채움
2. 경로: `docs/specs/{앱}/{도메인}/_function/<기능명>.md`
3. PR 흐름 동일

### Mode 4: 기획 변경 (확정 후 변경)

**별도 change-spec 파일을 만들지 않는다.** 원본 spec 파일을 직접 수정하고:

1. frontmatter `version` 마이너/패치 증가
2. PR description에 변경 이유 상세 기록 (구 동작 vs 신 동작, 영향 범위)
3. 머지 후 git log/blame이 변경 이력 source of truth

### Mode 5: 페이지별 기획 (하위 메뉴)

1. **prepub-analyzer** 실행 (필수)
2. 사용자 확인: 화면코드 / 도메인 / 화면유형
3. `_templates/page-spec.md` 복사 → 경로 `docs/specs/{앱}/{도메인}/<파일명>.md`
4. 템플릿 PART 1~3 채움 (page-spec-template-guide 참조)
5. `prepub-analyzer` 산출물의 `[UI]` 항목 우선 반영, `[HIDDEN→제외]`·`[ORPHAN]` 제외
6. 검증 → 사용자 승인 → 커밋 → PR

## Notion Legacy 자동 전환

기존 Notion 페이지가 있는 화면을 git에 처음 작성하는 경우 (`notion_legacy_url`이
frontmatter에 있는 경우), 스킬은 **마지막 단계**에서 다음을 수행한다:

```
1. Notion MCP `notion-update-page update_properties` 호출
2. 해당 페이지 status 속성을 "로그 저장용"으로 변경
3. 사용자에게 명시적 출력:
   - 성공: ✅ Notion 페이지 status → '로그 저장용' 전환 완료
   - 실패: ⚠️ Notion 전환 실패 — 수동 변경 필요: <URL>
           (사일런트 실패 금지)
```

> CLAUDE.md의 "🚫 로그 저장용 상태 문서 - 절대 접근 금지" 규칙은 **plan-developer-git이
> git→Notion 이행 시 1회 status 전환**에 한해 예외 적용. 이외 어떤 도구도
> 로그 저장용 문서를 변경하지 못함.

## Branch / Commit / PR 컨벤션

| 항목 | 형식 |
|------|------|
| 브랜치 | `spec/<화면코드>` (소문자, 예: `spec/lq-prd-s001`) |
| 커밋 | `spec(<화면코드>): <한 줄 요약>` |
| PR title | `spec: <화면명>(<화면코드>) <작업유형>` |
| PR body | 변경 요약 + 영향 코드 링크 + (해당 시) 관련 Notion URL |

PR 리뷰어 정책: 현재 자율 머지 (CODEOWNERS 없음). 팀 합류 시점에 재검토.

## Validation (scripts/specs-index.ts)

스킬은 작업 마지막에 항상 다음을 실행한다:

```bash
pnpm tsx scripts/specs-index.ts
```

- ajv 기반 frontmatter 검증 (`_schema/page-spec.schema.json`)
- 화면코드 중복 검사 → 발견 시 차단
- 코드블록 닫힘 검사
- `related_screens` 참조 무결성 (존재 안 하는 코드는 warning)
- `docs/specs/README.md` 재생성 (카테고리 트리 + 화면 목록)

pre-commit hook도 동일 명령을 호출하므로 사용자가 직접 commit 해도 동일 가드.

## Quality Gates

작업을 사용자에게 “완료”라고 알리기 전, 다음을 확인한다:

- [ ] frontmatter 모든 필수 필드 채워짐
- [ ] `pnpm tsx scripts/specs-index.ts` exit code 0
- [ ] git diff에 의도 외 파일 포함 안 됨
- [ ] PR description에 변경 이유 작성
- [ ] (해당 시) Notion 전환 결과 명시적 출력
- [ ] prepub-analyzer 산출물의 `[UI]` 항목 반영 완료

## Anti-patterns

- ❌ Notion에 동일 페이지를 그대로 두고 git에도 작성 (status 전환 누락)
- ❌ `_changes/` 같은 별도 변경 디렉토리 생성 (Mode 4는 원본 수정)
- ❌ 화면코드 임의 부여 (기존 plan-developer의 코드 체계 그대로 따른다)
- ❌ frontmatter 누락 또는 수기 수정 (스킬이 항상 검증 통과 후 커밋)
- ❌ `git add -A` (의도된 spec 파일만 stage)

## Reference

- `references/page-spec-template-guide.md` — 페이지 기획서 PART 구조 상세
- `.claude/shared-references/ui-consistency-rules.md` — UI 컴포넌트 일관성
- `.claude/shared-references/cross-reference-rules.md` — 연관 문서 교차 참조
- `.claude/shared-references/backend-architecture.md` — 백엔드 설계 체크리스트
- `docs/specs/_schema/page-spec.schema.json` — frontmatter 검증 스펙
