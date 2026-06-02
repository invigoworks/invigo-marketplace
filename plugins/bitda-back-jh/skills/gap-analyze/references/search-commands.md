# Gap Analyze 탐색 명령어 레퍼런스

## FE 코드 탐색

FE API 호출 패턴 찾기:
```bash
grep -r "useRepository\|fetch(\|axios\.\|\.get(\|\.post(\|\.patch(\|\.delete(" \
  /Users/gimjinhyeog/Desktop/coding/plan-master/apps/liquor/src/{domain} \
  --include="*.ts" --include="*.tsx" -n
```

FE 드롭다운 데이터 조회 패턴 (마스터 데이터):
```bash
grep -r "useRepository\|useFetch\|useQuery" \
  /Users/gimjinhyeog/Desktop/coding/plan-master/apps/liquor/src/{domain} \
  --include="*.ts" --include="*.tsx" -n \
  | grep -v "POST\|PATCH\|PUT\|DELETE"
```

기획서 파일 목록:
```bash
find /Users/gimjinhyeog/Desktop/coding/plan-master/docs/specs/liquor \
  -name "*.md" | sort
```

## BE 코드 탐색

BE Controller 목록:
```bash
find /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/api/src \
  -name "*Controller.kt" | sort
```

Flyway 마이그레이션 목록:
```bash
find /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/infrastructure/src \
  -name "V*.sql" | sort | tail -20
```

Domain 모델 필드 확인:
```bash
grep -r "val \|var " \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/domain/src \
  --include="*.kt" -n | grep -v "//\|test\|Test"
```

마스터 데이터 조회 Result 클래스 필드 확인:
```bash
grep -r "data class\|val " \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/core/src \
  --include="*Result.kt" -n | grep -v "test\|Test"
```

form-data 통합 API 존재 여부 (없으면 form-data API 누락 갭):
```bash
grep -r "form-data\|formData\|FormData" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/api/src \
  --include="*.kt" -n | grep -i "GetMapping\|RequestMapping"
# 결과 없으면 → 해당 도메인 form-data API 갭 판정
```

## Agent E 검증 명령어 (체크리스트 항목별 grep)

### A. Response 필드 누락 검증

A1 isActive 포함 여부:
```bash
grep -r "isActive\|is_active" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/core/src \
  --include="*Result.kt" -n
```

A2 colorId 포함 여부:
```bash
grep -r "colorId\|color_id" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/core/src \
  --include="*Result.kt" -n
```

A5 FK 이름 함께 반환 (XxxName 패턴):
```bash
grep -r "factoryName\|processName\|warehouseName\|equipmentName\|itemName" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/core/src \
  --include="*Result.kt" -n
```

A7 감사 필드:
```bash
grep -r "createdAt\|updatedAt\|createdBy\|updatedBy" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/core/src \
  --include="*Result.kt" -n
```

### B. 마스터 데이터 조회 검증

B2 isActive 필터 파라미터:
```bash
grep -r "isActive\|includeInactive" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/api/src \
  --include="*Controller.kt" -n
```

B3 keyword 검색 파라미터:
```bash
grep -r "keyword" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/api/src \
  --include="*Controller.kt" -n
```

B4 상위 ID 필터 (factoryId 등):
```bash
grep -r "factoryId\|parentId\|warehouseId" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/api/src \
  --include="*Controller.kt" -n
```

### C. 목록 조회 부가 기능 검증

C1 페이지네이션:
```bash
grep -r "page\|size\|PageRequest\|Pageable" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/core/src \
  --include="*Query.kt" -n
```

C2 정렬 파라미터:
```bash
grep -r "sortBy\|sortOrder\|sort_by" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/api/src \
  --include="*Controller.kt" -n
```

### D. 액션 / 상태 전이 검증

D1 활성/비활성 토글 엔드포인트:
```bash
grep -r "active\|inactive\|toggle" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/api/src \
  --include="*Controller.kt" -n | grep -i "PatchMapping"
```

D4 벌크 삭제:
```bash
grep -r "bulk\|Bulk\|ids\b" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/api/src \
  --include="*Controller.kt" -n | grep -i "Delete\|delete"
```
