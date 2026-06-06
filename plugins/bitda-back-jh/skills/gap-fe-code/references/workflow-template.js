// gap-fe-code 멀티팀 워크플로우 템플릿
// 사용법: {DOMAIN}, {FE_DIR}, 기존 이슈 번호만 바꿔 Workflow 도구로 실행.
// 원칙: plan-master FE 코드만 1차소스. 기획서 .md 절대 읽지 않음.

export const meta = {
  name: 'gap-fe-code-teams',
  description: 'FE 코드만 1차소스. 팀1=비즈니스로직 도출, 팀2=필요 API 추출, 총괄=BE 실측대조, 직렬 verifier 갭확정',
  phases: [
    { title: 'TeamScan', detail: '팀1 비즈니스로직 + 팀2 API항목 (FE 코드만) 병렬' },
    { title: 'Synthesize', detail: '총괄: 두 팀 결과 → BE 실측 대조 갭 발굴' },
    { title: 'Verify', detail: '각 갭 직렬 verifier BE 직접 실측 확정' },
  ],
}

// ── 도메인별로 바꿀 값 ────────────────────────────────────────────
const FE = '/Users/gimjinhyeog/Desktop/coding/plan-master/apps/liquor/src/{DOMAIN_PATH}' // 예: production/work-status
const FEROOT = '/Users/gimjinhyeog/Desktop/coding/plan-master/apps/liquor/src'
const BE = '/Users/gimjinhyeog/Desktop/coding/bitda-back'
const EXISTING_ISSUES = '#0000 / #0000' // 이미 생성돼 중복 배제할 이슈 번호+요지
// ─────────────────────────────────────────────────────────────────

const GAP_SCHEMA = {
  type: 'object',
  properties: {
    gaps: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          category: { type: 'string', description: 'API누락|필드누락|비즈니스로직누락|상태전이누락|집계API누락|필터파라미터누락|검증규칙누락|도메인누락' },
          title: { type: 'string' },
          feSource: { type: 'string', description: 'plan-master FE 코드 파일:라인' },
          whyNeeded: { type: 'string', description: 'FE가 동작하려면 왜 BE에 필요한가' },
          beClaimedState: { type: 'string', description: '총괄이 직접 확인한 현재 BE 상태' },
          severity: { type: 'string', enum: ['High', 'Medium', 'Low'] },
        },
        required: ['id', 'category', 'title', 'feSource', 'whyNeeded', 'beClaimedState', 'severity'],
      },
    },
  },
  required: ['gaps'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    isRealGap: { type: 'boolean' },
    confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
    reason: { type: 'string' },
    correctedBeState: { type: 'string' },
    alreadyIssued: { type: 'string', description: '기존 이슈와 중복이면 번호, 아니면 NONE' },
    mockParadigmRisk: { type: 'boolean', description: 'plan-master 자유CRUD vs BE 종속설계 차이로 사람확인 필요한가' },
  },
  required: ['id', 'isRealGap', 'confidence', 'reason', 'correctedBeState', 'alreadyIssued', 'mockParadigmRisk'],
}

phase('TeamScan')

const [bizLogic, apiNeeds] = await parallel([
  () => agent(
    `[팀1: 비즈니스 로직 도출관] plan-master ${FE} 의 FE 코드 **만** 읽어라. 기획서 .md는 절대 읽지 마라.
이 화면이 올바로 동작하려면 BE가 보장/검증해야 하는 비즈니스 로직·규칙·불변식을 FE 코드에서 역도출하라:
상태 전이 규칙(버튼 enable 조건), submit 전 검증(FE 가드 = BE도 보장해야 할 것), 계산/파생식,
멱등/동시성 기대, 집계 의미(전체기준 vs 페이지기준). types.ts/seed-data.ts의 데이터 형태도 규칙 증거.
출력: '## BE가 보장해야 할 비즈니스 로직' (규칙 + FE 코드 파일:라인 + 왜 BE 책임). 기획서 인용 금지.`,
    { label: '팀1:비즈니스로직', phase: 'TeamScan' },
  ),
  () => agent(
    `[팀2: API 항목 추출관] plan-master ${FE} 의 FE 코드 **만** 읽어라. 기획서 .md는 절대 읽지 마라.
FE가 BE 연동으로 작업하려면 필요한 API 전부 추출: 목록(필터/정렬/페이지/검색), 집계/요약 배지,
상세 조회 필드, 상태 전이 액션, 편집/저장 페이로드, 인쇄 데이터(상세조회로 충족되는지), export.
plan-master는 localStorage 목업이므로 repository 인터페이스 메서드 시그니처 = API 명세로 환산하라.
(${FEROOT}/providers/RepositorySetup.tsx 의 repository 정의 참조)
출력: '## FE 작업에 필요한 API 항목' (조회/액션별 요청·응답 필드). 응답 필드는 types.ts + 사용처에서 역추출. 기획서 인용 금지.`,
    { label: '팀2:API항목', phase: 'TeamScan' },
  ),
])

phase('Synthesize')

const candidates = await agent(
  `[총괄 점검관] 팀1(비즈니스 로직)·팀2(필요 API)을 BE 구현과 대조해 갭을 발굴하라.

[팀1] ${bizLogic}

[팀2] ${apiNeeds}

[BE] ${BE}/modules/application/{api,core}/... + Flyway ${BE}/modules/infrastructure/src/main/resources/db/migration/
작업: 팀1 로직·팀2 API가 BE에 있는지 직접 grep/read 확인. 없는 것 = 갭 후보.
오탐 방지: BE Response/Adapter/Flyway/Domain 중 하나라도 실제 없을 때만. FE 로컬가공/타입부재는 증거 아님.
[중복 배제] 기존 이슈 ${EXISTING_ISSUES} 와 겹치면 새로 올리지 마라.
상세화면(편집/액션/집계)을 특히 깊이 파라 — 목록 위주 분석이 놓치는 곳이다.
각 갭 schema 구조화. beClaimedState에 직접 확인한 BE 상태.`,
  { label: '총괄:BE대조', phase: 'Synthesize', schema: GAP_SCHEMA, agentType: 'invigo-agents:architect-reviewer' },
)

const gaps = (candidates?.gaps || [])
log(`총괄 갭 후보 ${gaps.length}건 → 직렬 검증`)

phase('Verify')

const verdicts = await pipeline(
  gaps,
  (g) => agent(
    `갭 후보를 BE 코드 직접 실측으로 검증하라. 오탐이면 isRealGap=false. 기존 이슈(${EXISTING_ISSUES})와 중복이면 alreadyIssued에 번호.
후보 #${g.id} [${g.category}] (${g.severity}) — ${g.title}
FE: ${g.feSource} | 왜: ${g.whyNeeded} | 총괄추정BE: ${g.beClaimedState}
검증(반드시 실제 grep/read, ${BE}): API→Controller grep / 필드→Response DTO+Result+Adapter SELECT / 로직→Domain require·check+Service / DB→Flyway.
⚠️ 메모리: 직전 라운드 18후보중 11이 "BE에 이미 있음" 오탐. 실측 우선. FE 타입/로컬가공/목업 경로불일치는 갭 아님.
⚠️ mockParadigmRisk: plan-master가 자유CRUD 하는데 BE가 종속 자동생성+상태전이 설계면, 그 편집API가 진짜 요구인지 불명 → true로 표시(사람 확인 대상).
isRealGap, confidence, reason(실측근거), correctedBeState, alreadyIssued, mockParadigmRisk 반환.`,
    { label: `verify:${g.id}`, phase: 'Verify', schema: VERDICT_SCHEMA },
  ),
)

const merged = gaps.map((g) => ({ ...g, verdict: (verdicts || []).find((x) => x && x.id === g.id) }))
const confirmed = merged.filter((m) => m.verdict?.isRealGap && (!m.verdict?.alreadyIssued || m.verdict.alreadyIssued === 'NONE'))
const duplicates = merged.filter((m) => m.verdict?.isRealGap && m.verdict?.alreadyIssued && m.verdict.alreadyIssued !== 'NONE')
const refuted = merged.filter((m) => m.verdict && !m.verdict.isRealGap)
const needsHumanReview = confirmed.filter((m) => m.verdict?.mockParadigmRisk)
log(`신규확정 ${confirmed.length} (사람확인필요 ${needsHumanReview.length}) / 기존중복 ${duplicates.length} / 기각 ${refuted.length}`)

return { confirmed, duplicates, refuted, needsHumanReview, totalCandidates: gaps.length }
