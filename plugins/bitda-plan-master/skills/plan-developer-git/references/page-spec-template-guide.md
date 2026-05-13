# Page Spec Template Guide

`docs/specs/_templates/page-spec.md` 의 PART 1·2·3 구조 작성 가이드.

## PART 1. 화면 개요

**목표**: 이 페이지가 어떤 사용자·어떤 작업·어떤 결과에 기여하는지를 한 단락으로 설명.

### 1.1 목적
- "왜 존재하는가" 1~3문장
- 비즈니스 가치 / 사용자 가치 분리해서 적기

### 1.2 진입 경로
- 메뉴 경로 (한글)
- URL 패턴 (`/production/plans/:id`)
- 권한 (역할 enum 이름)

### 1.3 핵심 사용자 시나리오
- 3~5단계의 happy path. 사용자 → 시스템 → 사용자 행위 순서
- 부정 시나리오(에러, 거부)는 PART 3에서 다룬다

## PART 2. 화면 구성

**목표**: FE 개발자가 wireframe 없이 컴포넌트 트리를 구성 가능하도록.

### 2.1 레이아웃
- ASCII art 권장 (코드블록 ```)
- 영역 단위: 헤더 / 필터 / 본문 / 액션바 / 푸터

### 2.2 컴포넌트 명세
- TableWrapper, SearchInput, SortableHeader, ConfirmActionDialog 등 공통 컴포넌트는 **반드시 prop 이름과 함께** 명시
- 일관성 규칙은 `.claude/shared-references/ui-consistency-rules.md` 참조

### 2.3 상태별 표시
- 로딩 / 빈 / 에러 / 부분 실패 / 권한 부족 — 5개 상태 전부 다룸

## PART 3. Acceptance Criteria

**목표**: 이 spec만으로 QA 시나리오와 단위 테스트 작성 가능.

### 3.1 Given-When-Then
- 각 AC는 ID 부여 (AC-1, AC-2, …)
- 기술 상세는 별도 줄에 prefix `(기술:`로 명시 (FE/BE 어디서 처리)

### 3.2 권한 매트릭스
- 역할 × 동작 (CRUD + 도메인 특수 동작)

### 3.3 데이터 흐름
- 사용자 입력 → state → API → repo → side effect → UI 갱신
- Repository 패턴(plan-master CLAUDE.md) 준수 확인

### 3.4 엣지 케이스
- 동시 편집 / 0건 / 음수 / 네트워크 오류 / 권한 변경 / 타임아웃
- 발견되는 모든 케이스 + 처리 방식

## 변경 이력 (Mode 4)

별도 섹션을 만들지 않는다. `git log -- <파일>` 와 PR description이 source of truth.

## related_screens / related_code 채우기

- `related_screens`: 같이 보는 화면, 데이터 공유 화면, 권한 종속 화면
- `related_code`: 구현 디렉토리/파일 경로. 디렉토리 단위 권장
- `.claude/shared-references/cross-reference-rules.md` 의 7가지 식별 기준 적용
