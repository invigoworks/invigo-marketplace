# UI 일관성 규칙 (Shift Left)

> ui-improver/ui-supervisor에서 반복 발견되는 이슈를 기획 단계에서 사전 방지하기 위한 규칙.

---

## 5대 필수 컴포넌트 규칙

기획서에 반드시 명시해야 하는 UI 컴포넌트 규칙:

| 규칙 | 올바른 컴포넌트 | 금지 패턴 |
|------|----------------|----------|
| 페이지 타이틀 | `PageTitle` 컴포넌트 | `<h1>` 직접 사용 |
| Sheet/폼 | `FormSheet` + `FormSheetFooter` | Sheet + 수동 패딩 |
| 날짜 선택 | `DateRangeFilter` / `DateRangePicker` | `<input type="date">` |
| 테이블 래퍼 | `overflow-x-auto px-4 py-2` | 패딩 없이 Table 렌더링 |
| 상세 기본정보 | 컴팩트 그리드 (`lg:grid-cols-6`, 세로 라벨-값, `px-4 py-3`) | `flex-wrap` 인라인, `justify-between` 2컬럼 |

---

## 재사용 컴포넌트 인벤토리

기획 시 검색 필수. 기존 컴포넌트를 명시적으로 지정하면 ui-designer가 신규 구현 대신 재사용합니다.

| UI 요소 | 기존 공유 컴포넌트 | 위치 |
|---------|-------------------|------|
| 시간 입력 | `TimeInput` | `@bitda/web-platform` |
| 검색 선택 | `SearchableSelect` | `@bitda/web-platform` |
| 상태 뱃지 | `StatusBadge`, `LiquorTypeBadge` | `@bitda/web-platform` |
| 증빙 뱃지 | `EvidenceStatusBadge` | 앱 레벨 components |
| 확인 다이얼로그 | `ConfirmActionDialog` | `@bitda/web-platform` |
| 수량+단위 | `QuantityUnitInput` | `@bitda/web-platform` |
| 다중 품목 선택 | `MultiItemSelectDialog` | `@bitda/web-platform` |

---

## UI 요소 필요성 판단

기획에서 과도한 UI 요소를 정의하여 나중에 제거하는 낭비를 방지:

| UI 요소 | 필요성 질문 | 판단 기준 |
|---------|------------|----------|
| 요약 카드 | 이 통계가 사용자 의사결정에 필수인가? | 데이터 10건 미만이면 불필요할 수 있음 |
| 필터 | 목록 30건 이상일 때 필요한가? | 소규모 데이터셋은 검색만으로 충분 |
| 검색창 | 데이터 건수가 검색이 필요한 수준인가? | 20건 미만이면 불필요할 수 있음 |
| 탭 분리 | 하나의 뷰로 충분한데 탭을 나누는 건 아닌가? | 데이터 성격이 확연히 다를 때만 |

---

## 유사 페이지 참조 (기획서에 포함)

> UI 생성 후 반복적인 스타일 수정을 방지하기 위해, 기획 단계에서 참조할 기존 페이지를 명시.

```markdown
### 참조 페이지
| 참조 페이지 | 경로 | 참조 포인트 |
|------------|------|------------|
| [유사 기능 페이지명] | apps/[앱]/src/[경로] | 테이블 구조, 뱃지 패턴, 필터 구성 |

### UI 스타일 일관성 지시
- 테이블 세로 구분선: [참조 페이지]의 border-r 패턴 따름
- 뱃지 컴포넌트: [LiquorTypeBadge/StatusBadge 등] 사용
- 액션 버튼 배치: [참조 페이지]와 동일한 CardHeader 구성
```

**필수 확인**:
- 동일 도메인에 이미 구현된 페이지 검색
- 해당 페이지의 테이블 스타일, 뱃지, 필터 구성을 참조 페이지로 명시
- 시각적 일관성을 ui-designer가 보장할 수 있도록 구체적 지시 포함
