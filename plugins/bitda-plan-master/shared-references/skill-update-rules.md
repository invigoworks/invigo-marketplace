# 스킬 업데이트 공통 규칙

> 모든 스킬 생성/수정 시 이 규칙을 준수해야 합니다.
> 출처: rosettalens.com Claude Code 6개월 실전 사용 팁 + 프로젝트 경험 축적

## 1. 파일 크기 제한

| 항목 | 제한 |
|------|------|
| SKILL.md 본문 | **500줄 이하** |
| CLAUDE.md | **200줄 이하** |
| 단일 references 파일 | **300줄 이하** |

**500줄 초과 시 필수 리팩터링:**
1. 상세 내용을 `references/` 하위 파일로 분리
2. SKILL.md에는 워크플로우 골격 + 참조 링크만 유지
3. `Read` 도구로 필요 시 로드 (progressive loading)

## 2. 구조 분리 원칙

### SKILL.md에 유지할 것
- 프론트매터 (name, description, triggers)
- 목적 (Purpose) — 2~5줄
- 실행 시점 (When to Run) — 3~5개 조건
- 워크플로우 단계 골격 (각 단계 제목 + 핵심 동작)
- 출력 형식 (Output Format) — 테이블 템플릿
- 예외사항 (Exceptions) — 2~3개

### references/로 분리할 것
- 상세 템플릿 (document-template.md, report-template.md)
- 체크리스트 (analysis-checklist.md)
- 프롬프트 텍스트 (agent별 프롬프트)
- 설정 상수 (DB 스키마, 매핑 테이블)
- 사용 예시 (usage-examples.md)

## 3. 규칙 작성 원칙

### 3a. 중복 금지
- 동일한 규칙이 2개 이상의 스킬에 존재하면 안 됨
- 공통 규칙은 이 파일(`skill-update-rules.md`)이나 `CLAUDE.md`에 한 번만 작성
- 개별 스킬에서는 "공통 규칙 참조" 링크로 대체

### 3b. 구체적 규칙 > 추상적 원칙
```
❌ "코드 품질을 유지한다"
✅ "toast는 sonner를 사용한다. useToast 사용 금지"

❌ "일관된 패턴을 따른다"
✅ "SortableHeader는 @bitda/web-platform에서 import. enableSorting:false는 select/action 컬럼에만"
```

### 3c. 탐지 가능한 규칙만
- 모든 규칙에는 grep/glob으로 검증 가능한 패턴이 있어야 함
- "좋은 코드를 작성한다" 같은 주관적 규칙 금지
- PASS/FAIL 판정이 자동화 가능해야 함

### 3d. 예외를 명시
- 모든 규칙에 2~3개의 "이것은 위반이 아님" 케이스 포함
- 예외 없는 규칙은 false positive 폭발의 원인

## 4. 업데이트 안전 수칙

### 4a. 기존 검사 보존
- 작동하는 기존 검사는 **절대 삭제하지 않음**
- 오래된 검사: 삭제가 아닌 업데이트
- 제거가 필요한 경우 사유를 명시하고 사용자 확인

### 4b. 점진적 추가
- 한 번의 업데이트에서 3개 이하의 새 규칙 추가
- 대량 규칙 추가 시 references 파일로 분리 후 단계적 도입
- 각 추가 규칙에 대해 기존 코드베이스에서 false positive 테스트

### 4c. 연쇄 업데이트 체크
스킬 수정 시 반드시 동기화해야 하는 파일:
1. `manage-skills/SKILL.md` — 등록된 검증 스킬 테이블
2. `verify-implementation/SKILL.md` — 실행 대상 스킬 테이블
3. `CLAUDE.md` — Available Skills 테이블

## 5. Progressive Loading 패턴

```
SKILL.md (항상 로드됨, <500줄)
  ├── references/template.md (필요 시 Read)
  ├── references/checklist.md (필요 시 Read)
  └── references/examples.md (필요 시 Read)
```

**SKILL.md 내 참조 방식:**
```markdown
### Step 3: 템플릿 적용

**참조:** `references/template.md`를 Read 도구로 로드하여 템플릿을 적용합니다.
```

## 6. 스킬 간 의존성 관리

```
독립 스킬: verify-* (각각 독립 실행 가능)
통합 스킬: verify-implementation (모든 verify-* 순차 실행)
관리 스킬: manage-skills (스킬 CRUD + 등록 테이블 관리)
프로세스 스킬: plan-developer → ui-designer → github-deployer (순차 의존)
```

- 순환 의존 금지 (A→B→A)
- 통합 스킬은 개별 스킬의 내용을 복제하지 않고 호출만 함
- 프로세스 스킬은 이전 단계의 output을 input으로 받는 인터페이스만 정의

## 7. 네이밍 규칙

| 유형 | 접두사 | 예시 |
|------|--------|------|
| 검증 스킬 | `verify-` | `verify-ui-patterns`, `verify-routing` |
| 프로세스 스킬 | 동사 | `plan-developer`, `ui-designer` |
| 리뷰 스킬 | `-reviewer` | `plan-reviewer`, `plan-review-team` |
| 유틸리티 스킬 | 명사 | `manage-skills`, `marketplace-updater` |

## 8. 품질 게이트

스킬 생성/수정 완료 전 반드시 확인:

- [ ] SKILL.md가 500줄 이하인가?
- [ ] 모든 파일 경로가 실제 존재하는가? (`ls`로 검증)
- [ ] 탐지 명령어가 현재 코드베이스에서 작동하는가?
- [ ] 기존 규칙이 의도치 않게 삭제되지 않았는가?
- [ ] 연쇄 업데이트 파일이 모두 동기화되었는가?
- [ ] 중복 규칙이 다른 스킬에 없는가?
- [ ] 예외사항이 2개 이상 명시되었는가?
