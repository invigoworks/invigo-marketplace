---
name: codebase-audit
description: |
  프로젝트 전체를 대상으로 CLAUDE.md 헌법 및 시행령 문서 위반, 패턴 불일치, 코드 중복, 문서 동기화 문제를
  5개 전문 에이전트로 병렬 검사하고 통합 감사 보고서를 생성하는 스킬입니다.
  이 스킬은 다음 상황에서 사용됩니다:
  - 정기 코드베이스 감사가 필요할 때
  - 기술 부채 점검이 필요할 때
  - 사용자가 "/codebase-audit", "코드베이스 감사", "아키텍처 감사" 등을 요청할 때
---

# Codebase Audit

## Purpose

프로젝트 전체(또는 지정 도메인)를 대상으로 기술 부채와 일관성을 점검하고,
CLAUDE.md 헌법 및 시행령 문서 준수 여부를 포함한 통합 감사 보고서를 생성한다.

## 검사 영역 (5가지)

| # | 영역 | 담당 에이전트 | 검사 내용 |
|---|------|--------------|----------|
| 1 | 헌법 위반 | `constitution-checker` | CLAUDE.md 핵심 원칙 위반 |
| 2 | 시행령 위반 | `policy-checker` | docs/standards/*.md 규칙 위반 |
| 3 | 패턴 불일치 | `pattern-analyzer` | 같은 계층 내 구현 패턴 불일치 |
| 4 | 코드 중복 | `duplication-detector` | 유사 로직 반복 |
| 5 | 문서 동기화 | `doc-sync-checker` | 코드↔주석, 코드↔MD 불일치 |

## Workflow

### Step 0: 인자 파싱

```
/codebase-audit                    # 전체 감사
/codebase-audit user               # user 도메인만 감사
/codebase-audit --focus=pattern    # 패턴 검사만 수행
```

**파싱 규칙**:
- 도메인 인자: 첫 번째 비-옵션 인자 (예: `user`, `warehouse`)
- `--focus` 옵션: `constitution`, `policy`, `pattern`, `duplication`, `doc-sync`

도메인이 지정되면 해당 도메인 관련 파일만 검사 대상으로 한다:
- `modules/*/src/**/domain/{domain}/**`
- `modules/*/src/**/application/{domain}/**`
- `modules/*/src/**/persistence/{domain}/**`
- `modules/*/src/**/api/{domain}/**`

### Step 1: 프로젝트 컨텍스트 로드

1. **CLAUDE.md 읽기**: 아키텍처 핵심 원칙 파악
2. **시행령 문서 목록 확인**: CLAUDE.md에서 참조하는 문서 경로 추출
   - `docs/standards/messaging-policy.md`
   - `docs/standards/temporal-data-policy.md`
   - `docs/standards/query-pattern.md`
   - `docs/standards/validation-exception-policy.md`
   - `docs/standards/db-migration-policy.md`
   - `docs/standards/excel-export-policy.md`
   - `docs/standards/audit-logging-policy.md`
   - `docs/plans/ready/test-infrastructure-spec.md`
3. **이전 감사 보고서 확인**: `docs/audits/AUDIT_*.md` 중 가장 최근 파일

### Step 2: 검사 대상 파일 수집

도메인이 지정된 경우 해당 도메인 파일만, 아니면 전체 `modules/**/*.kt` 대상.

**제외 패턴**:
- `*Test.kt`, `*Spec.kt` (테스트 파일 - 일부 규칙에서 제외)
- `build/`, `.gradle/`

### Step 3: 5개 에이전트 병렬 실행

**반드시 단일 메시지에서 5개의 Task 도구를 동시에 호출하여 병렬 실행한다.**
`--focus` 옵션이 있으면 해당 에이전트만 실행한다.

#### 공통 프롬프트 규칙

모든 에이전트에게 다음 규칙을 전달한다:

> **필수: 최종 파일 상태 기반 검사**
> - 지적하기 전에 반드시 해당 파일을 Read 도구로 직접 읽어 현재 상태를 확인하라.
> - 모든 지적에는 파일경로:라인번호, 클래스/함수명, 코드 근거가 포함되어야 한다.
>
> **필수: 기존 코드 패턴 참조**
> - 같은 계층(controller, service, adapter 등)의 기존 파일을 2-3개 Read로 읽어 기존 패턴을 파악하라.
> - 기존 패턴과 다른 방식으로 구현된 부분을 지적하라.
>
> **필수: 심각도 기준**
> - **심각**: 런타임 오류, 데이터 손실, 보안 취약점, 아키텍처 규칙 명백한 위반
> - **중간**: 유지보수성 저하, 컨벤션 불일치, 잠재적 버그
> - **낮음**: 코드 스타일, 가독성 개선, 더 나은 대안 존재
>
> **필수: 검사 범위**
> - 도메인이 지정된 경우: 해당 도메인 관련 파일만 검사
> - 전체 감사: modules/ 하위 모든 Kotlin 파일 (테스트 제외)

에이전트별 상세 검사 항목은 `references/checklist.md` 참조.

### Step 4: 결과 통합 및 보고서 생성

5개 에이전트 결과를 수집하여 통합 감사 보고서를 생성한다.

**중복 제거**: 동일한 파일·동일한 이슈는 가장 구체적인 하나만 남긴다.

**보고서 경로**: `docs/audits/AUDIT_{YYYY-MM-DD}.md`

**보고서 형식**: `references/report-template.md` 참조

### Step 5: 트렌드 분석 (이전 감사 대비)

이전 감사 보고서가 있으면 비교 분석한다:
- 해결된 항목 수
- 새로 발생한 항목 수
- 영역별 증감 추이

### Step 6: 결과 안내

```
✅ 코드베이스 감사가 완료되었습니다.

| 항목 | 결과 |
|------|------|
| 감사 범위 | 전체 / {domain} 도메인 |
| 검사 파일 수 | N개 |
| 헌법 위반 | X건 |
| 시행령 위반 | Y건 |
| 패턴 불일치 | Z건 |
| 코드 중복 | W건 |
| 문서 동기화 | V건 |

{이전 감사 대비 변화 요약}

보고서: docs/audits/AUDIT_{date}.md
```

## CLI Reference

```bash
# 프로젝트 구조 확인
ls modules/*/src/main/kotlin/

# 특정 패턴 검색
rg "class.*Service" --type kotlin -l
rg "LocalDateTime" --type kotlin -l
rg "@DirtiesContext" --type kotlin

# 파일 목록 수집
find modules -name "*.kt" -not -path "*/build/*" -not -name "*Test.kt"

# 이전 감사 보고서 확인
ls -la docs/audits/AUDIT_*.md | tail -1
```
