# PRD 구조 레퍼런스

plan-master PRD 파일의 구조와 각 섹션별 파싱 포인트를 정의한다.

## 파일 경로 패턴

```
/Users/gimjinhyeog/Desktop/coding/plan-master/docs/specs/
  {domain}/
    {subdomain}/
      BITDA-BR-{모듈코드}-S{NNN}-PAGE-({화면명}).md
```

예: `liquor/production/BITDA-BR-PRD-FAC-S001-PAGE-(공장설비통-설정).md`

## Frontmatter

```yaml
---
screen_code: BITDA-BR-PRD-FAC-S001   # 이슈 제목 prefix
screen_type: PAGE
title: 공장/설비/통 설정              # 기능명
status: DRAFT | REVIEW | APPROVED
owner: github-handle
version: 1.0.0
related_screens:                      # 연관 화면 목록
  - BITDA-BR-PRD-PRS-S001
related_code:                         # 연관 프론트엔드 코드 경로
  - apps/liquor/src/production/settings/factory/
summary: 2-3문장 요약                  # 이슈 개요/배경에 사용
last_updated: 2026-05-18
---
```

**파싱 포인트:**
- `screen_code` → 모든 이슈 제목 앞에 붙임
- `title` → Epic 이슈 제목의 기능명
- `summary` → Epic/Sub 이슈의 개요 섹션
- `related_screens` → 기술적 고려사항에 "연관 화면" 항목으로 추가

## PART 1. 화면 개요

### 1.1 목적

```markdown
### 1.1 목적
{2~4문장의 화면 목적 설명}
- **{엔티티A}**: 설명
- **{엔티티B}**: 설명
```

**파싱 포인트:**
- 엔티티 목록 추출 (볼드 처리된 용어들)
- Epic 이슈 "배경" 섹션에 첫 2~3문장 인용

### 1.2 진입 경로

```markdown
### 1.2 진입 경로
- **메뉴**: {메뉴 경로}
- **URL**: `/production/settings/factory`
- **권한**: `PRODUCTION_MGR`, `ADMIN` (PRODUCTION_OPER는 읽기만)
```

**파싱 포인트:**
- 권한 목록 → API 계층 이슈의 `@PreAuthorize` 요구사항에 반영

## PART 2. 레이아웃 & 컴포넌트

**백엔드 이슈에서의 활용도**: 낮음. API 계층 이슈 작성 시 Props 인터페이스에서 API 스펙을 역추론할 때만 참조.

```typescript
// Props 인터페이스에서 API 스펙 역추론 예시
interface FactorySheetProps {
  defaultCode: string;       // → generateFactoryCode() API 또는 로직 필요
  defaultSortOrder: number;  // → sortOrder 계산 로직 필요
  isOnlyDefault?: boolean;   // → 단일 대표 공장 검증 API 필요
}
```

## PART 3. 기능 명세

### 3.1 핵심 기능 목록

```markdown
| 기능 | 대상 | 설명 |
|------|------|------|
| 조회 | 공장/설비/통 | 목록 조회 (isDeleted=false 필터링) |
| 등록 | 공장/설비/통 | 각 단계별 FormSheet로 신규 생성 |
| 수정 | 공장/설비/통 | 폼 정보 변경 후 저장 |
| 삭제 | 공장/설비/통 | 소프트 삭제 (isDeleted=true) |
| 정렬 | 공장/설비/통 | DnD로 순서 변경, sortOrder 업데이트 |
| 활성화 토글 | 공장/설비/통 | Switch로 isActive 전환 |
| 색상 선택 | 공장/설비 | ColorPalettePicker (8색 팔레트) |
| 대표 공장 설정 | 공장 | isDefault 상호배타성 |
```

**파싱 포인트:**
- "대상" 열 → 엔티티 목록 확정
- "기능" 열 → 구현할 UseCase 목록 (등록=Create, 수정=Update, 삭제=Delete, 조회=Query)
- 특수 기능 식별: 정렬(sortOrder), 토글(isActive), 소프트 삭제(isDeleted)

### 3.2 Acceptance Criteria

```markdown
#### AC-N: {기능명}
- **Given** {사전 조건}
- **When** {행동}
- **Then**
  1. {기대 결과}
  2. {기대 결과}
```

**파싱 포인트 (백엔드 관련 AC 필터링):**

| AC 패턴 | 추출 정보 | 반영 위치 |
|---------|---------|---------|
| 상호배타성 (`isOnlyDefault`, 단일 대표) | 비즈니스 규칙 | Domain/Application 이슈 |
| 계단식 삭제/상태변경 | 트랜잭션 범위 | Application 이슈 |
| 계수 자동 갱신 (`equipmentCount`, `vesselCount`) | 파생 상태 관리 | Application 이슈 |
| Unique 제약 (`code` 중복 불가) | DB 제약 | DB 마이그레이션 이슈 |
| 활성화 필터 (`isActive=false` 선택 불가) | 조회 조건 | Infrastructure/API 이슈 |
| 권한 제약 (`PRODUCTION_OPER` 읽기 전용) | `@PreAuthorize` | API 계층 이슈 |

### 3.3 데이터 흐름 & 상태 관리

프론트엔드 중심 섹션이나 다음 항목은 백엔드 설계에 참고:

```markdown
Repository Ops (useRepository):
  ├─ createFactory/Equipment/Vessel
  ├─ updateFactory/Equipment/Vessel
  └─ (삭제는 soft delete)
```

**파싱 포인트:**
- Repository 메서드 목록 → Command UseCase 목록으로 매핑
- soft delete 패턴 확인 → Domain 이슈의 `isDeleted` 필드 반영

### 3.4 엣지 케이스

```markdown
| 상황 | 현재 동작 | 검토 사항 |
```

**파싱 포인트:**
- "검토 사항"에 "서버 레벨 검증 필요", "백엔드 구현 시" 등이 있으면 → 해당 Sub-Issue 요구사항에 추가

### 3.6 데이터 타입 정의

```typescript
interface Factory {
  id: string;
  code: string;          // FAC-001 형식 (고유)
  name: string;          // 1~50자
  colorId: FactoryColorId;
  isDefault?: boolean;
  isActive: boolean;
  isDeleted: boolean;    // 소프트 삭제
  sortOrder: number;
  equipmentCount: number; // 파생 계수
  createdAt: string;
  updatedAt: string;
}
```

**파싱 포인트:**
- 각 인터페이스 → 하나의 Domain Aggregate 또는 Value Object
- FK 필드 (`factoryId: string`) → JPA 연관관계, DB FK 제약
- Optional 필드 (`?`) → nullable 컬럼
- 계수 필드 (`equipmentCount`) → 캐시 컬럼 또는 파생값 (설계 결정 필요)
- `createdAt/updatedAt` → Audit 컬럼 (`@CreatedDate`, `@LastModifiedDate`)

## PART 4. 설계 의도

### 4.3 연관 문서 정합성 체크리스트

```markdown
| 항목 | 검증 | 상태 | 비고 |
|------|------|------|------|
| API 명세 (백엔드) | GET /api/v1/factories 등 | ❌ 미정 | 향후 백엔드 구현 단계 |
| DB 마이그레이션 | factory/equipment/vessel 테이블 | ❌ 미정 | 스키마: 아래 참조 |
| 권한 정책 | PRODUCTION_OPER 읽기 전용 | ✅ 확정 | |
```

**파싱 포인트:**
- `❌ 미정` 항목 → 해당 Sub-Issue 생성 필요 여부 확인
- "스키마: 아래 참조" → 같은 섹션에 `CREATE TABLE` SQL이 있으면 그대로 DB 마이그레이션 이슈에 반영

**DB 스키마 블록 (있는 경우):**

```sql
CREATE TABLE factory (
  id VARCHAR(36) PRIMARY KEY,
  company_id VARCHAR(36) NOT NULL,
  code VARCHAR(20) NOT NULL,
  name VARCHAR(100) NOT NULL,
  ...
  UNIQUE KEY uk_factory_code (company_id, code),
  INDEX idx_factory_company (company_id, sort_order)
);
```

→ DB 마이그레이션 이슈의 **상세 요구사항**에 직접 인용한다.
→ 프로젝트 DB 마이그레이션 정책(`docs/standards/db-migration-policy.md`) 준수 필수.

## 섹션 부재 시 대응

| 섹션 | 없는 경우 처리 |
|------|--------------|
| PART 3.6 데이터 타입 | PART 2 Props 인터페이스에서 역추론 |
| PART 4.3 DB 스키마 | PART 3.6 타입 정의에서 Flyway 마이그레이션 SQL 직접 설계 |
| PART 3.1 기능 목록 | PART 3.2 AC 항목에서 기능 목록 재구성 |
| summary (Frontmatter) | PART 1.1 목적의 첫 문장 사용 |
