#!/bin/bash
set -euo pipefail

# PreCompact hook: 컨텍스트 압축 시 핵심 아키텍처 규칙 재주입
# 긴 세션에서 compaction 후에도 규칙 일관성 유지

jq -n --arg msg '## CLAUDE.md 핵심 규칙 (PreCompact 재주입)

### 아키텍처 3원칙
- Strict Hexagonal: 기술 상세는 Adapter, Core는 기술에 오염 금지
- Pure Domain: 도메인 엔티티는 순수 코틀린, JPA 어노테이션 절대 금지
- CQS: Command(상태 변경)와 Query(조회) 철저 분리

### 가시성
- Service/Adapter 구현체: `internal` 필수
- 도메인 필드: `private set`, DTO: `val`

### 네이밍
- UseCase: `Action + Domain + UseCase` (예: CreateUserUseCase)
- 입력: Command/Query, 출력: Result(Core)/Response(API)
- Repository: 명령=XXRepository(domain), 조회=XXQueryRepository(application)
- POST→UUID, PATCH/PUT/DELETE→Unit

### 패키지 배치
- Domain Model: domain.xx.model (순수 코틀린)
- Domain Port: domain.xx.port (Entity 반환)
- Query Port: application.xx.port (Result 반환)
- JpaEntity: persistence.xx.entity (@Version, Audit)
- 구현체: persistence.xx.adapter (internal)

### 기술 정책
- 시간: Instant only (Zero-LocalTime), DB: TIMESTAMPTZ
- 트랜잭션: 명령=@Transactional, 조회=readOnly=true
- E2E: Track 상속 강제 (E2ETestSupport/SecurityE2ESupport)
- DB 마이그레이션: Flyway, V{YYYYMMDD}{NNN}__{desc}.sql, 병합 후 수정 금지

### 시행령 문서 (해당 도메인 작업 시 반드시 참조)
- docs/standards/ai-agent-guide.md (Communication, Kotlin, Architecture, Testing 규칙)
- docs/standards/ 디렉토리의 각 정책 문서' \
  '{ systemMessage: $msg }'
