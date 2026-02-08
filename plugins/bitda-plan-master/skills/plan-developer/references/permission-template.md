# 권한 명세 템플릿

> **목적**: 백엔드/프론트엔드 개발자가 권한 체계를 명확히 이해하고 구현할 수 있도록 명세

---

## 1. 권한 체계 구조

```
역할 (Role)
    │
    └─▶ 모듈 (Module)
            │
            └─▶ 기능 (Feature)
                    │
                    └─▶ 권한 (Permission)
```

### 권한 코드 형식
```
{resource}:{action}
```

**예시:**
- `warehouse:read` - 창고 조회
- `warehouse:create` - 창고 등록
- `warehouse:update` - 창고 수정
- `warehouse:delete` - 창고 삭제
- `warehouse:approve` - 창고 승인

---

## 2. 표준 액션 목록

| 액션 코드 | 설명 | HTTP 메서드 |
|----------|------|------------|
| `read` | 조회 (목록/상세) | GET |
| `create` | 등록 | POST |
| `update` | 수정 | PUT/PATCH |
| `delete` | 삭제 | DELETE |
| `approve` | 승인 | POST |
| `reject` | 반려 | POST |
| `export` | 내보내기 | GET |
| `import` | 가져오기 | POST |

---

## 3. 모듈/기능 코드 체계

### 3.1 모듈 코드 (Module Code)
| 모듈 코드 | 모듈명 | 설명 |
|----------|--------|------|
| `CM` | Common | 공통 관리 |
| `WH` | Warehouse | 창고 관리 |
| `PRD` | Product | 상품 관리 |
| `ORD` | Order | 주문 관리 |
| `INV` | Inventory | 재고 관리 |
| `SLS` | Sales | 영업 관리 |
| `PUR` | Purchase | 구매 관리 |
| `RPT` | Report | 리포트 |

### 3.2 기능 코드 (Feature Code)
```
{모듈코드}-{기능약어}
```

| 기능 코드 | 기능명 | 모듈 |
|----------|--------|------|
| `CM-CMP` | 회사 관리 | Common |
| `CM-USR` | 사용자 관리 | Common |
| `WH-MGT` | 창고 마스터 | Warehouse |
| `PRD-MGT` | 상품 마스터 | Product |

---

## 4. 권한 명세 작성 예시

### 4.1 페이지별 권한 명세

#### [창고 목록] 페이지
| 기능 | 권한 코드 | 역할별 허용 |
|------|----------|------------|
| 목록 조회 | `warehouse:read` | ADMIN, MANAGER, USER |
| 상세 조회 | `warehouse:read` | ADMIN, MANAGER, USER |
| 등록 | `warehouse:create` | ADMIN, MANAGER |
| 수정 | `warehouse:update` | ADMIN, MANAGER |
| 삭제 | `warehouse:delete` | ADMIN |
| 내보내기 | `warehouse:export` | ADMIN, MANAGER |

### 4.2 버튼/UI 요소별 권한
| UI 요소 | 필요 권한 | 권한 없을 때 |
|---------|----------|-------------|
| 등록 버튼 | `warehouse:create` | 숨김 또는 비활성화 |
| 수정 버튼 | `warehouse:update` | 숨김 |
| 삭제 버튼 | `warehouse:delete` | 숨김 |
| 내보내기 버튼 | `warehouse:export` | 숨김 |

---

## 5. API 권한 매핑

### 5.1 엔드포인트별 권한
| 엔드포인트 | 메서드 | 필요 권한 | 역할 |
|-----------|--------|----------|------|
| `/api/warehouses` | GET | `warehouse:read` | ADMIN, MANAGER, USER |
| `/api/warehouses` | POST | `warehouse:create` | ADMIN, MANAGER |
| `/api/warehouses/{id}` | GET | `warehouse:read` | ADMIN, MANAGER, USER |
| `/api/warehouses/{id}` | PUT | `warehouse:update` | ADMIN, MANAGER |
| `/api/warehouses/{id}` | DELETE | `warehouse:delete` | ADMIN |

### 5.2 권한 검증 로직
```typescript
// 프론트엔드 - 버튼 표시 여부
const canCreate = hasPermission('warehouse:create');
const canDelete = hasPermission('warehouse:delete');

// 백엔드 - API 권한 검증
@RequirePermission('warehouse:create')
async createWarehouse(dto: CreateWarehouseDto) { ... }
```

---

## 6. 역할 매트릭스 템플릿

### 6.1 전체 권한 매트릭스
| 리소스 | 액션 | ADMIN | MANAGER | USER | VIEWER |
|--------|------|-------|---------|------|--------|
| warehouse | read | ✓ | ✓ | ✓ | ✓ |
| warehouse | create | ✓ | ✓ | ✗ | ✗ |
| warehouse | update | ✓ | ✓ | ✗ | ✗ |
| warehouse | delete | ✓ | ✗ | ✗ | ✗ |
| product | read | ✓ | ✓ | ✓ | ✓ |
| product | create | ✓ | ✓ | ✓ | ✗ |

### 6.2 참조 URL
권한 매트릭스 관리: https://prepub.invigoworks.co.kr/admin/role-matrix

---

## 7. 작성 시 체크리스트

### 기획자 체크리스트
- [ ] 모듈 코드 확정
- [ ] 기능 코드 확정
- [ ] 각 기능별 필요 액션 목록 작성
- [ ] 권한 코드 형식 통일 (resource:action)
- [ ] 역할별 권한 매핑 완료
- [ ] 승인/삭제 권한 분리 여부 결정

### 검토 사항
- [ ] 같은 페이지 내 다른 버튼별 권한 구분 필요한가?
- [ ] 본인 데이터만 수정 가능한 제약 필요한가?
- [ ] 특정 상태에서만 수정 가능한 제약 필요한가?
- [ ] 권한 없는 사용자의 UI 처리 방식 결정 (숨김 vs 비활성화)
