# FE 관점 체크리스트 A~H (Agent C/D 상세 점검 항목)

> "FE 화면이 굴러가지 않는다" 사례를 카테고리별로 망라.
> Agent C는 BE 분석 시 아래 항목 전부를 도메인별로 점검(✅/❌/N/A 표),
> Agent D는 시나리오 시뮬레이션 시 ❌ 중 FE에서 실제 필요한 것만 갭으로 승격.
> (CRUD 라운드트립은 `crud-roundtrip-matrix.md`, production/BOM 특화는 `production-pr-lessons.md`)

## A. Response 필드 누락 (조회/표시)

- [ ] **A1. isActive 플래그**: 마스터 엔티티 Response에 `isActive` 포함 (비활성 항목 회색 처리)
- [ ] **A2. colorId**: 색상 구분 엔티티(factory, equipment, process)에 `colorId` 포함
- [ ] **A3. sortOrder**: DnD 정렬 지원 엔티티에 `sortOrder` 포함
- [ ] **A4. description**: hover tooltip / 상세 설명 필드
- [ ] **A5. FK 이름 함께 반환**: factoryId 옆에 factoryName 등 (FE 추가 fetch 없이 표시)
- [ ] **A6. 하위 집계 (count)**: 마스터-디테일(Factory→Equipment)에서 `equipmentCount` 등
- [ ] **A7. 감사 필드**: 상세 Response에 `createdAt`, `updatedAt`, `createdBy`, `updatedBy`
- [ ] **A8. 소프트 삭제 정보**: `deletedAt`, `deletedBy` (휴지통/복원 UI)
- [ ] **A9. version**: 낙관적 락 충돌 알림 UI 필요 시 `version`
- [ ] **A10. status 요약**: 목록에서 상태 분포(완료/미완료 count) 미리보기

## B. 마스터 데이터 조회 (드롭다운 / 자동완성)

- [ ] **B1. 단순 GET 목록 API**: 폼 드롭다운에 쓰일 모든 참조 엔티티의 GET /api/v1/xxx 존재
- [ ] **B2. 활성만 필터**: `?isActive=true` / `?includeInactive=false` (등록 폼 비활성 숨김)
- [ ] **B3. keyword 검색**: 자동완성용 `?keyword=`
- [ ] **B4. 상위 ID 필터**: 종속 드롭다운(공장→설비) `?factoryId=` 등
- [ ] **B5. 옵션 마스터 API**: enum 대체 옵션(EquipmentType, VesselMaterial, Unit) 조회 또는 정적 enum 노출
- [ ] **B6. 색상 팔레트 API**: colorId 후보값 BE 노출 또는 FE 하드코딩 정책 명시

## C. 목록 조회 부가 기능

- [ ] **C1. 페이지네이션**: 100건 이상 가능 목록은 page/size 또는 limit/offset
- [ ] **C2. 정렬**: FE 컬럼 헤더 정렬 → BE `sortBy`, `sortOrder` 모두 지원
- [ ] **C3. 날짜 범위 필터**: `from`, `to` (생산계획, 입출고 등 시계열)
- [ ] **C4. 다중 상태 필터**: `?status=A&status=B`
- [ ] **C5. 완료 상태 필터**: `completionStatus` (ALL/COMPLETED/INCOMPLETE) 등
- [ ] **C6. 응답 메타**: `{ data, totalCount, page, size }` 구조

## D. 액션 / 상태 전이

- [ ] **D1. 활성/비활성 토글**: `PATCH /xxx/{id}/active`
- [ ] **D2. DnD 순서 변경**: `PATCH /xxx/reorder`
- [ ] **D3. 취소/복원**: 소프트 삭제 후 복원 액션 API
- [ ] **D4. 벌크 삭제**: 다중 선택 일괄 삭제 (`DELETE /xxx?ids=...` 또는 body)
- [ ] **D5. 벌크 상태 변경**: 다중 선택 일괄 활성/비활성/취소
- [ ] **D6. 삭제 가능 사전 체크**: 삭제 전 사용중 여부 조회 또는 실패 응답에 사용처 정보

## E. 에러 응답

- [ ] **E1. ErrorCode 표준**: ApiResponse.error에 enum.name 일관성
- [ ] **E2. 사람 읽을 메시지**: ApiResponse.message에 사용자 노출 한국어 메시지
- [ ] **E3. 필드 검증 에러 구조**: `@Valid` 실패 시 필드별 에러 배열
- [ ] **E4. 참조 무결성 에러**: 삭제 시 "등록된 X가 N건 있어 삭제 불가" 구체 메시지

## F. 데이터 정합성

- [ ] **F1. 시간 형식**: 시각 `Instant`(ISO-8601 Z), 날짜 `LocalDate`(YYYY-MM-DD), 시간 `LocalTime`(HH:mm)
- [ ] **F2. 소수 정밀도**: 수량/금액 BigDecimal, FE 표시 자릿수 정책 일치
- [ ] **F3. 단위 일관성**: Quantity unit 필드 형식(kg/L/EA) FE 표시 매핑
- [ ] **F4. 소프트 삭제 필터**: 목록 조회 기본 `deletedAt IS NULL` 자동 필터
- [ ] **F5. 테넌트 격리**: organizationId 자동 주입 + 타 조직 노출 차단

## G. 첨부 / 메모 / 이력

- [ ] **G1. 메모 필드**: 등록/수정 시 memo Request/Response 양방향
- [ ] **G2. 변경 이력 조회**: 수정 히스토리 조회 API 필요 도메인 식별
- [ ] **G3. 첨부파일**: 업로드/다운로드/삭제 API + Response에 attachment list

## H. Export / Import

- [ ] **H1. Excel Export 응답 필드**: FE 표시 컬럼과 Export 컬럼 일치 (displayUnit/conversionRate 등)
- [ ] **H2. Import 검증 응답**: 행별 에러 위치/메시지 반환 구조
