# E2E Test: {테스트 이름}

## 테스트 정보

| 항목 | 값 |
|------|-----|
| **테스트 일시** | {YYYY-MM-DD HH:mm:ss} |
| **테스트 환경** | local (8080 포트) |
| **Keycloak 앱** | {bitda-admin-app / bitda-liquor-app / bitda-manufact-app} |

## 로그인 계정 정보

| 항목 | 값 |
|------|-----|
| **이메일** | {email} |
| **User ID** | {user_id} |
| **Organization ID** | {organization_id 또는 N/A} |
| **역할(Roles)** | {ADMIN, OWNER, ...} |
| **권한(Permissions)** | {permission1, permission2, ...} |

## 테스트 결과 요약

| # | API | 메서드 | 결과 | 비고 |
|---|-----|--------|------|------|
| 1 | {endpoint} | {GET/POST/...} | {✅ 성공 / ❌ 실패} | {설명} |

## 상세 테스트 케이스

### Case {N}: {케이스 설명}

**Request:**
```http
{METHOD} {endpoint}
Authorization: Bearer {token}
Content-Type: application/json

{request body if any}
```

**Response:** `{status code} {status text}`
```json
{response body}
```

---

## Import/Export 테스트 (해당 시)

### Import 테스트

**사용 파일:** `files/{filename}`

| 파일명 | 행 수 | 결과 |
|--------|-------|------|
| {filename} | {rows} | {결과} |

**실패 상세 (있는 경우):**
- Row {N}: {실패 사유}

### Export 테스트

**결과 파일:** `files/{filename}`

---

## 예외 케이스 검증

| # | 케이스 | 예상 에러 | 실제 에러 | 결과 |
|---|--------|----------|----------|------|
| 1 | 인증 없이 요청 | 401 Unauthorized | {actual} | {✅/❌} |
| 2 | 권한 없는 사용자 | 403 Forbidden | {actual} | {✅/❌} |
| 3 | 존재하지 않는 리소스 | 404 Not Found | {actual} | {✅/❌} |
| 4 | 잘못된 입력값 | 400 Bad Request | {actual} | {✅/❌} |
| 5 | 중복 데이터 | 409 Conflict | {actual} | {✅/❌} |

---

## 비고

{추가 메모 또는 발견된 이슈}
