---
name: plan-review-team
description: |
  기획서를 3명의 전문가 팀(논리 검토, UX 검토, 컴포넌트 분석)으로 병렬 검토하는 skill입니다.
  Agent Teams를 활용하여 3가지 관점의 검토를 동시에 수행합니다.

  Use this skill when:
  - User requests team-based plan review with `/plan-review-team [Notion URL or target]`
  - User mentions "팀 검토", "기획 팀 리뷰", "3관점 검토"
  - User asks "기획서 검토 팀 돌려줘", "팀으로 검토해줘"
  - Before using /ui-designer, to validate planning completeness

  The skill creates an agent team with 3 parallel reviewers:
  - logic-reviewer: 논리적 빈틈, 누락 케이스, 의존성
  - ux-reviewer: UX 흐름, 상태 디자인, 접근성
  - component-analyst: 기존 컴포넌트 재사용, 반복 패턴
---

# Plan Review Team

## Overview

기획서를 3명의 전문가가 동시에 검토하여 종합 리포트를 생성합니다.

```
                    기획서 (Notion / 마크다운)
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
    logic-reviewer    ux-reviewer    component-analyst
    (논리 검토)        (UX 검토)      (컴포넌트 분석)
            │               │               │
            └───────────────┼───────────────┘
                            ▼
                   leader: 종합 리포트
```

### 기존 plan-reviewer와 차이

| 항목 | plan-reviewer (단일) | plan-review-team (팀) |
|------|---------------------|----------------------|
| 검토자 | 1명 (순차 분석) | 3명 (병렬 분석) |
| 관점 | 논리 중심 | 논리 + UX + 컴포넌트 |
| 소요 시간 | 빠름 | 약간 더 걸리나 깊이 있음 |
| 토큰 비용 | 낮음 | 높음 (3x) |
| 적합 상황 | 간단한 기획, 빠른 확인 | UI 개발 전 종합 검토 |

## Trigger

```
/plan-review-team [Notion URL 또는 대상]
```

Examples:
- `/plan-review-team https://www.notion.so/...`
- `/plan-review-team 위 기획서`
- `팀으로 기획 검토해줘`

## Input Types

### 1. Notion URL
```
https://www.notion.so/workspace/Page-Title-{pageId}
```
Page ID 추출 후 Notion MCP로 조회.

### 2. Markdown/Text
대화에 직접 입력된 기획 내용.

### 3. 이전 대화 컨텍스트
"위 기획서", "방금 작성한 기획" 등 이전 대화 참조.

---

## Workflow

### Phase 1: 입력 파싱 및 팀 생성

1. **입력 타입 판별**
   - Notion URL → Page ID 추출 (마지막 32자리 hex, 하이픈 제거)
   - 텍스트/마크다운 → 직접 전달
   - 컨텍스트 참조 → 이전 대화에서 추출

2. **팀 생성**
   ```
   TeamCreate: plan-review
   Description: 기획서 검토 팀
   ```

3. **작업 생성** (3개)
   - Task #1: 기획서 논리적 완성도 검토
   - Task #2: UX/사용자 경험 관점 검토
   - Task #3: 기존 컴포넌트 재사용 분석

### Phase 2: 팀원 생성 (3명 동시)

**중요: 3명을 반드시 동시에(하나의 메시지에서) 생성해야 병렬 실행됨.**

#### Teammate 1: logic-reviewer

```
Task({
  name: "logic-reviewer",
  team_name: "plan-review",
  subagent_type: "general-purpose",
  mode: "bypassPermissions",
  prompt: <logic-reviewer-prompt with page ID>
})
```

Prompt는 `references/logic-reviewer-prompt.md` 참조.

#### Teammate 2: ux-reviewer

```
Task({
  name: "ux-reviewer",
  team_name: "plan-review",
  subagent_type: "general-purpose",
  mode: "bypassPermissions",
  prompt: <ux-reviewer-prompt with page ID>
})
```

Prompt는 `references/ux-reviewer-prompt.md` 참조.

#### Teammate 3: component-analyst

```
Task({
  name: "component-analyst",
  team_name: "plan-review",
  subagent_type: "general-purpose",
  mode: "bypassPermissions",
  prompt: <component-analyst-prompt with page ID>
})
```

Prompt는 `references/component-analyst-prompt.md` 참조.

### Phase 3: 결과 대기

- 3명의 팀원이 각자 검토 완료 후 SendMessage로 보고
- 각 보고 수신 시 해당 Task를 completed로 업데이트
- 3명 모두 완료될 때까지 대기

### Phase 4: 종합 리포트 작성

모든 보고를 종합하여 다음 형식으로 출력:

```markdown
# 기획 검토 종합 리포트

## 검토 대상: [기획서 제목]
검토자: logic-reviewer, ux-reviewer, component-analyst

## Critical (즉시 해결 필요) - N건
| # | 관점 | 발견 사항 | 제안 |
|---|------|----------|------|

## Major (해결 권장) - N건
| # | 관점 | 발견 사항 | 제안 |
|---|------|----------|------|

## Minor (개선 고려) - N건
(요약만, 상세는 접어두기)

## 컴포넌트 재사용 요약
### 바로 쓸 수 있는 기존 컴포넌트
| 용도 | 컴포넌트 | Import |

### 신규 생성 필요
| 컴포넌트 | 사유 | 배치 위치 |

### 공통화 권장 (기존 중복 해소)
| 대상 | 현재 상태 | 권장 조치 |

## 확인 필요 질문
1. ...
```

### Phase 5: 팀 정리

1. 3명 팀원에게 shutdown_request 전송
2. 종료 확인 후 TeamDelete 실행

---

## Reference Files

| 파일 | 용도 |
|------|------|
| `references/logic-reviewer-prompt.md` | logic-reviewer 팀원 프롬프트 |
| `references/ux-reviewer-prompt.md` | ux-reviewer 팀원 프롬프트 |
| `references/component-analyst-prompt.md` | component-analyst 팀원 프롬프트 |

---

## Error Handling

| 상황 | 처리 |
|------|------|
| Notion URL 접근 실패 | 에러 메시지 + URL 재확인 요청 |
| 팀원이 5분 이상 응답 없음 | 리더가 직접 메시지로 상태 확인 |
| 팀원 오류 중지 | 대체 팀원 생성 또는 해당 관점 수동 검토 |
| 기획 내용 없음 | 기획 내용 입력 요청 |

---

## Examples

### Example 1: Notion 기획서 팀 검토

```
User: /plan-review-team https://www.notion.so/workspace/FEAT-abc123def456

Response:
기획서를 3명의 전문가가 동시에 검토합니다.

[팀 생성 → 3명 동시 생성 → 결과 대기 → 종합 리포트]

# 기획 검토 종합 리포트
## 검토 대상: [FEAT] 실감량 관리 v1.3
...
```

### Example 2: 대화 컨텍스트 기반

```
User: 방금 작성한 기획서 팀으로 검토해줘

Response:
이전 대화의 기획 내용을 기반으로 팀 검토를 시작합니다.
[동일 워크플로우 실행]
```
