# 기획문서 vs 구현 검토 체크리스트

## 1. API 엔드포인트 검토

### 확인 항목
- [ ] HTTP Method 일치 (GET/POST/PUT/PATCH/DELETE)
- [ ] URL 경로 일치 (`/api/v1/...`)
- [ ] Path Variable 일치
- [ ] Query Parameter 일치
- [ ] Request Body 필드 일치 (타입, 필수 여부)
- [ ] Response Body 필드 일치

### 판단 기준
| 상태 | 조건 |
|------|------|
| **구현 완료** | 모든 항목 일치 |
| **상이** | 일부 불일치 (사유 기록 필요) |
| **누락** | API 자체가 존재하지 않음 |

## 2. 필드 검토

### 확인 항목
- [ ] 필드명 일치 (camelCase 변환 고려)
- [ ] 데이터 타입 일치
- [ ] 필수/선택 여부 일치
- [ ] 기본값 일치
- [ ] 최대 길이/범위 제약 일치

### 흔한 상이 케이스
- 기획: `사업자등록번호` → 구현: `businessRegistrationNumber` (정상)
- 기획: `String` → 구현: `BusinessRegistrationNumber` VO (정상, 더 엄격)
- 기획: `필수` → 구현: `Optional` (상이, 사유 필요)

## 3. 비즈니스 로직 검토

### 확인 항목
- [ ] 검증 규칙 구현 여부
- [ ] 계산 로직 정확성
- [ ] 상태 전이 규칙 준수
- [ ] 조건부 로직 구현

### 검증 위치 확인
| 검증 유형 | 기대 위치 |
|----------|----------|
| 형식 검증 (이메일, 전화번호) | API DTO `@Valid` |
| 비즈니스 규칙 | Domain `require()`, `check()` |
| 참조 무결성 | Service/UseCase |

## 4. 권한 검토

### 확인 항목
- [ ] `@PreAuthorize` 어노테이션 존재
- [ ] 권한 표현식 적절성
- [ ] 테넌트 격리 적용 (`tenantFilter`)
- [ ] 소유자 검증 (본인 데이터만 접근)

### 권한 표현식 패턴
```kotlin
// 읽기 권한
@PreAuthorize("hasAuthority('WAREHOUSE:READ')")

// 쓰기 권한
@PreAuthorize("hasAuthority('WAREHOUSE:WRITE')")

// 복합 권한
@PreAuthorize("hasAuthority('ADMIN') or hasAuthority('MANAGER')")
```

### 흔한 권한 누락 케이스
- 목록 조회 API에 권한 미적용
- 상세 조회에서 소유자 검증 누락
- 수정/삭제에서 본인 데이터 검증 누락

## 5. 에러 처리 검토

### 확인 항목
- [ ] 예외 케이스 처리 여부
- [ ] 에러 메시지 일치
- [ ] HTTP 상태 코드 적절성
- [ ] 에러 응답 형식 일관성

### 표준 에러 패턴
| 상황 | 예외 | HTTP 코드 |
|------|------|----------|
| 필수값 누락 | `MethodArgumentNotValidException` | 400 |
| 리소스 없음 | `ResourceNotFoundException` | 404 |
| 비즈니스 규칙 위반 | `BusinessException` | 400/422 |
| 권한 없음 | `AccessDeniedException` | 403 |
| 중복 | `DuplicateResourceException` | 409 |

## 6. 상이 판정 시 사유 분류

### 정당한 상이 (개선)
- **타입 강화**: `String` → Value Object (더 엄격한 검증)
- **보안 강화**: 추가 권한 검증
- **성능 최적화**: 페이징 방식 변경
- **표준 준수**: REST 규약, 프로젝트 컨벤션

### 협의 필요 상이
- 기능 범위 축소/확대
- 필수/선택 여부 변경
- 응답 필드 누락/추가
- 에러 메시지 변경

## 7. 검토 우선순위

1. **Critical**: API 엔드포인트 누락, 권한 미적용
2. **High**: 필수 필드 누락, 비즈니스 로직 상이
3. **Medium**: 응답 필드 상이, 에러 메시지 불일치
4. **Low**: 네이밍 차이, 타입 강화
