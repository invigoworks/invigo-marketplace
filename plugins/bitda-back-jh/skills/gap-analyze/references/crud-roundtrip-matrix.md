# CRUD 라운드트립 매트릭스 (Agent C/D 필수)

> **배경**: "Prepub 기준 CRUD를 돌려보니 빈틈이 많고, 완전 상이한 게 많다"는 피드백.
> 기존 갭 분석은 **생성(Create) Request 필드 + 특정 시나리오** 위주여서
> R(조회)/U(수정)/D(삭제) 각 단계의 왕복 정합성과 **구조 불일치(완전 상이)**를 놓쳤다.
>
> 이 매트릭스는 FE가 다루는 **모든 도메인 엔티티**에 대해 C·R·U·D 4종을
> 빠짐없이 점검하고, 각 단계에서 FE↔BE 데이터 구조가 일치하는지 검증한다.

---

## 1. 엔티티별 CRUD 4종 완주 매트릭스

Agent C는 분석 대상 도메인의 **각 엔티티마다** 아래 표를 채운다.
✅(있음+정합) / ⚠️(있으나 구조 불일치) / ❌(없음) / N/A(불필요).

| 엔티티 | C: POST | R-목록: GET /xxx | R-단건: GET /xxx/{id} | U: PATCH/PUT | D: DELETE | 비고 |
|--------|---------|------------------|------------------------|--------------|-----------|------|
| (예) Factory | ✅ | ✅ | ❌ 단건조회 없음 | ⚠️ name만, color 누락 | ✅ | 단건 상세 API 누락 |

### 단계별 필수 점검 포인트

- **C (Create)**: FE submit body의 모든 필드가 Request DTO에 존재 + 필수/선택 일치.
- **R-목록**: 목록 화면이 표시하는 컬럼 전부가 목록 Response에 존재 (FK 이름, count, isActive 등 §A 참조). 페이지네이션 메타(§C6).
- **R-단건**: **수정 폼을 채우기 위한 단건 상세 조회 API 존재 여부.** 목록 Response만으로 수정 폼을 못 채우면 단건 GET 필요. 흔한 누락.
- **U (Update)**: ① 수정 폼 초기값을 채우는 조회(단건 R) → ② PATCH body 필드 → ③ 부분 수정 시 nullable 처리. PATCH가 전체 필드를 요구하는데 FE가 변경 필드만 보내면 불일치.
- **D (Delete)**: 소프트/하드 삭제 구분, 참조 무결성 에러 응답(§E4), 삭제 가능 사전 체크(§D6).

> **단건 조회(R-단건) 누락이 가장 흔한 CRUD 빈틈.** 목록에는 표시용 요약만 담고,
> 수정 폼은 전체 필드가 필요한데 단건 상세 API가 없어 수정 진입 자체가 막힌다.
> 탐지: FE에 `useXxxRepo`의 `findById`/`detail`/`get(id)` 호출이 있는데
> BE에 `@GetMapping("/{id}")`가 없으면 → 갭.

---

## 2. "완전 상이" 구조 정합성 점검 (FE 타입 ↔ BE Response)

필드명만 grep으로 비교하면 **구조 불일치**를 놓친다. 다음을 명시적으로 대조:

- [ ] **S1. nested 객체 vs flat**: FE 타입이 `factory: { id, name }`인데 BE가 `factoryId` + `factoryName` flat 반환 (또는 반대) → 매핑 깨짐.
- [ ] **S2. 배열 vs 단일**: FE가 `items: Item[]` 기대인데 BE가 단일 객체 / 페이지 래퍼로 감쌈.
- [ ] **S3. enum 값 집합**: FE 타입의 union(`'DRAFT' | 'CONFIRMED'`)과 BE enum(`LabeledEnum`) **값 문자열이 정확히 일치**하는지. 대소문자/언더스코어 차이도 불일치.
- [ ] **S4. 응답 래퍼**: FE가 `data` 직접 기대 vs BE `ApiResponse<T>` 래핑 (`{ data, error, message }`). 목록은 `data.content` vs `data` 차이.
- [ ] **S5. 날짜/시간 타입**: §F1과 연계 — FE가 `string`(ISO)으로 받는데 BE가 epoch millis 등.
- [ ] **S6. 숫자 타입**: BigDecimal → FE에서 string vs number 수신. JSON 직렬화 방식 일치 확인.
- [ ] **S7. id 타입**: UUID(string) vs Long. FE 타입과 BE 식별자 타입 일치.
- [ ] **S8. null vs 빈값/미포함**: FE가 `null` 기대 vs BE가 필드 자체를 누락(undefined). 옵셔널 표시 정합.

각 항목 불일치 시 → **"필드 누락"이 아닌 "구조 불일치(완전 상이)" 갭 유형**으로 분류.

---

## 3. 탐지 명령어

도메인의 FE 타입 정의:
```bash
find /Users/gimjinhyeog/Desktop/coding/plan-master/apps/liquor/src/{domain} \
  -name "types.ts" -o -name "*.schema.ts" | sort
```

FE Repository 훅의 CRUD 메서드 (C/R/U/D 호출 추출):
```bash
grep -rn "useMutation\|useQuery\|\.post\|\.get\|\.patch\|\.put\|\.delete\|findById\|findAll\|create\|update\|remove" \
  /Users/gimjinhyeog/Desktop/coding/plan-master/apps/liquor/src/{domain} \
  --include="*Repo.ts" --include="*Repository.ts"
```

BE 도메인 Controller의 HTTP 메서드 전체 (CRUD 커버리지 확인):
```bash
grep -rn "@GetMapping\|@PostMapping\|@PatchMapping\|@PutMapping\|@DeleteMapping" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/api/src/main/kotlin/**/{domain}/ \
  --include="*Controller.kt"
```

단건 조회 API 존재 확인 (없으면 R-단건 갭):
```bash
grep -rn '@GetMapping("/{' \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application/api/src/main/kotlin/**/{domain}/ \
  --include="*Controller.kt"
```

BE Response/Result 클래스 필드 (구조 대조용):
```bash
grep -rn "data class .*Response\|data class .*Result" \
  /Users/gimjinhyeog/Desktop/coding/bitda-back/modules/application \
  --include="*.kt" -A 15 | grep -E "data class|val "
```

---

## 4. Agent D 승격 규칙

Agent D는 매트릭스의 ⚠️/❌ 중 다음만 갭으로 승격:
- FE Repository 훅이 **실제로 호출**하는 CRUD 메서드에 대응하는 BE API가 없거나 구조 불일치
- 구조 불일치(S1~S8)는 200 응답이어도 FE 파싱 실패 → **"버그성" 갭으로 High 우선순위**

오탐 방지: FE에 호출 코드가 없는 CRUD는 N/A 처리 (FE 미사용 기능은 갭 아님).
