---
name: skill-improver
description: 기획봇 피드백에서 승인된 인사이트를 기반으로 기획 관련 프로세스 스킬(plan-developer, plan-review-team, prepub-analyzer, ui-designer, ui-improver)을 자동 업데이트합니다. 트리거 - "스킬 개선해줘", "/skill-improve", "피드백 반영해줘"
argument-hint: "[선택: 특정 스킬 이름 또는 인사이트 ID]"
---

# Skill Improver — 기획 프로세스 스킬 자동 업데이트

## 목적

기획봇(plan-chatbot)에서 수집된 에스컬레이션 → 제안 → 승인 → 인사이트의 피드백 루프를 통해,
**기획 관련 프로세스 스킬**의 규칙과 체크리스트를 자동으로 보강합니다.

```
기획봇 질문 → 에스컬레이션 → 코드 분석 제안 → 승인 → 패턴 분류 → 인사이트
                                                                    ↓
                                           이 스킬이 인사이트를 스킬 파일에 반영
```

### manage-skills와의 차이

| | manage-skills | skill-improver |
|--|--------------|----------------|
| **대상** | `verify-*` 검증 스킬 | 프로세스 스킬 (plan-developer 등) |
| **트리거** | 코드 변경 후 커버리지 갭 분석 | 기획봇 피드백 인사이트 승인 후 |
| **변경 내용** | 파일 참조, 탐지 명령어 추가 | 비즈니스 규칙, 체크리스트, 템플릿 보강 |

## 대상 스킬

| 스킬 | 파일 | 업데이트 대상 |
|------|------|-------------|
| `plan-developer` | `.claude/skills/plan-developer/SKILL.md` | 기획 규칙, 체크리스트, 템플릿 |
| `plan-review-team` | `.claude/skills/plan-review-team/SKILL.md` | 리뷰 관점, 검토 항목 |
| `prepub-analyzer` | `.claude/skills/prepub-analyzer/SKILL.md` | 분석 패턴, 갭 탐지 규칙 |
| `ui-designer` | `.claude/skills/ui-designer/SKILL.md` | UI 패턴, 컴포넌트 규칙 |
| `ui-improver` | `.claude/skills/ui-improver/SKILL.md` | 개선 체크리스트, 분석 항목 |

## 실행 시점

- 기획봇 `/스킬분석`으로 인사이트가 생성되고 승인된 후
- 주기적으로 누적된 승인 인사이트를 반영할 때
- 수동으로 특정 스킬을 개선하고 싶을 때

## 워크플로우

### Step 1: 승인된 인사이트 수집

기획봇 DB에서 승인된 인사이트를 조회합니다.

```bash
cd tools/plan-chatbot
python -c "
from src.log_db import LogDB
db = LogDB('./data/logs.db')
insights = [i for i in db.get_pending_skill_insights() if True]  # 또는 approved
for i in insights:
    print(f'#{i[\"id\"]} [{i[\"pattern_category\"]}] → {i[\"target_skill\"]}')
    print(f'  {i[\"description\"][:100]}...')
"
```

인사이트가 없으면 직접 분석을 먼저 실행합니다:
```bash
python -c "
from src.log_db import LogDB
from src.skill_analyzer import analyze_and_generate_insights
db = LogDB('./data/logs.db')
approved = db.get_approved_suggestions()
insights = analyze_and_generate_insights(approved)
for ins in insights:
    db.log_skill_insight(**ins)
print(f'{len(insights)}건 인사이트 생성')
"
```

### Step 2: 대상 스킬 분석

각 인사이트의 `target_skill`에 해당하는 스킬 파일을 Read합니다.

**확인 사항:**
1. 현재 SKILL.md 줄 수 (500줄 제한 확인)
2. references/ 하위 파일 목록
3. 인사이트와 관련된 기존 규칙이 이미 있는지 (중복 방지)

### Step 3: 변경 계획 수립

**공통 규칙 참조:** `.claude/shared-references/skill-update-rules.md`를 Read하여 준수합니다.

인사이트 패턴별 변경 위치:

| 패턴 카테고리 | 변경 위치 | 변경 유형 |
|-------------|----------|----------|
| `data_model_gap` | plan-developer 템플릿의 데이터 명세 섹션 | references 파일에 체크 항목 추가 |
| `business_rule_omission` | plan-developer 비즈니스 규칙 섹션 | SKILL.md 또는 references에 규칙 추가 |
| `ui_state_gap` | ui-designer 상태별 UI 섹션 | references/체크리스트에 항목 추가 |
| `edge_case_miss` | plan-review-team 리뷰어 프롬프트 | references/프롬프트에 검토 항목 추가 |
| `compliance_evidence` | plan-developer 비즈니스 규칙 | SKILL.md에 컴플라이언스 규칙 추가 |
| `code_plan_mismatch` | prepub-analyzer 분석 패턴 | SKILL.md에 갭 탐지 패턴 추가 |
| `component_reuse_failure` | ui-designer 컴포넌트 규칙 | references/component-reuse에 항목 추가 |

### Step 4: 변경 적용

**핵심 원칙 (skill-update-rules.md 기반):**

1. **SKILL.md 500줄 이하 유지** — 초과 시 references/로 분리
2. **기존 규칙 절대 삭제 금지** — 추가/수정만
3. **한 번에 3개 이하 규칙 추가**
4. **구체적이고 탐지 가능한 규칙만** 작성

**변경 방식 결정 트리:**

```
IF SKILL.md에 관련 섹션이 있고, 추가해도 500줄 이하:
    → SKILL.md에 직접 추가
ELIF SKILL.md에 관련 references 파일 참조가 있음:
    → 해당 references 파일에 추가
ELIF SKILL.md가 450줄 이상:
    → 새 references 파일 생성 후 SKILL.md에 참조 링크 추가
ELSE:
    → SKILL.md에 새 섹션 추가
```

**변경 포맷 예시 — 비즈니스 규칙 추가:**
```markdown
### 학습된 규칙: [패턴명] (기획봇 인사이트 #N)

- **규칙**: [구체적 규칙 설명]
- **근거**: 기획봇 질문 #M에서 반복 에스컬레이션 (N건)
- **검증**: [grep/glob 패턴으로 검증 가능한 방법]
```

**변경 포맷 예시 — 체크리스트 항목 추가:**
```markdown
- [ ] [체크 항목] — 인사이트 #N 기반
```

### Step 5: 검증

변경 후 반드시 확인:

1. **줄 수 확인**: `wc -l` 으로 500줄 이하 검증
2. **기존 규칙 보존**: 변경 전후 diff 확인, 삭제된 라인 없는지 검증
3. **중복 확인**: 추가된 규칙이 다른 스킬에 이미 존재하지 않는지 Grep
4. **파일 경로 유효성**: 참조된 모든 references 파일 존재 확인

```bash
# 줄 수 검증
wc -l .claude/skills/<target-skill>/SKILL.md

# 변경 diff 확인
git diff .claude/skills/<target-skill>/
```

### Step 6: 인사이트 상태 업데이트

적용 완료된 인사이트의 상태를 DB에서 `applied`로 업데이트합니다.

```bash
cd tools/plan-chatbot
python -c "
from src.log_db import LogDB
db = LogDB('./data/logs.db')
db.update_skill_insight_status(<insight_id>, 'applied', '<reviewer_id>')
"
```

### Step 7: 보고

```markdown
## 스킬 개선 보고서

### 반영된 인사이트: N건

| # | 패턴 | 대상 스킬 | 변경 내용 | 변경 위치 |
|---|------|----------|----------|----------|
| 1 | data_model_gap | plan-developer | 데이터 명세 체크 항목 추가 | references/page-spec-template.md |

### 변경 파일:
- `.claude/skills/plan-developer/references/page-spec-template.md` — 2개 체크 항목 추가
- `.claude/skills/plan-review-team/references/logic-reviewer-prompt.md` — 1개 검토 관점 추가

### 스킬 줄 수 현황:
| 스킬 | 변경 전 | 변경 후 | 상태 |
|------|--------|--------|------|
| plan-developer | 391줄 | 395줄 | ✅ OK |
```

## 예외사항

다음은 **이 스킬의 범위가 아닙니다:**

1. **verify-* 스킬 관리** — `manage-skills` 스킬 담당
2. **CLAUDE.md 변경** — 스킬 설명 테이블 업데이트는 하되, 프로젝트 규칙 변경은 불가
3. **스킬 삭제/이름 변경** — 사용자 확인 없이 구조 변경 불가
4. **500줄 초과 리팩터링** — 대규모 구조 변경은 사용자와 별도 협의

## Related Files

| File | Purpose |
|------|---------|
| `.claude/shared-references/skill-update-rules.md` | 스킬 업데이트 공통 규칙 (필수 참조) |
| `tools/plan-chatbot/src/skill_analyzer.py` | 패턴 분류 + 인사이트 생성 로직 |
| `tools/plan-chatbot/src/log_db.py` | skill_insights 테이블 CRUD |
| `.claude/skills/plan-developer/SKILL.md` | 주요 업데이트 대상 |
| `.claude/skills/plan-review-team/SKILL.md` | 주요 업데이트 대상 |
| `.claude/skills/prepub-analyzer/SKILL.md` | 주요 업데이트 대상 |
| `.claude/skills/ui-designer/SKILL.md` | 주요 업데이트 대상 |
| `.claude/skills/ui-improver/SKILL.md` | 주요 업데이트 대상 |
