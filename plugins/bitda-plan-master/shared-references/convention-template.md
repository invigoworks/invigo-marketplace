# BITDA ERP 화면 코드 컨벤션

> 이 파일은 Notion에서 가져온 코드 컨벤션의 공유 참조 파일입니다.
> 모든 스킬에서 이 파일을 참조합니다.
> 최종 업데이트: 2026-01-12
> Notion 원본: https://www.notion.so/invigoworks/00-BITDA-2ce471f8dcff804abd94d6a09fa4f16b

## 코드 구조

```
BITDA-[도메인]-[모듈]-[기능]-[화면유형][순번]
```

**예시:** `BITDA-CM-PRD-WO-F001` (공통 > 생산관리 > 작업지시 > 등록/수정폼 001)

---

## 1. 도메인 코드

| 코드 | 원어 | 한글 | 설명 |
|------|------|------|------|
| CM | Common | 공통 | 전 산업군 공통 기능 |
| BR | Brewery | 주류 | 주류 제조 특화 |

---

## 2. 모듈 코드

| 코드 | 원어 | 한글 | 도메인 | 설명 |
|------|------|------|--------|------|
| MST | Master Data | 기준정보 | CM | 제품, 원재료, 거래처, 창고 등 |
| SYS | System | 시스템관리 | CM | 직원, 계정정보, 회사정보, 권한 |
| CST | Cost | 원가관리 | CM | 결산, 수불부, 구매, 판매 |
| PRD | Production | 생산관리 | CM | 작업지시, 작업내역, 공정 |
| INV | Inventory | 재고관리 | CM, BR | 재고현황, 입출고, 환입/폐기(BR) |
| TAX | Tax | 주세신고 | BR | 주세신고 관련 전체 |
| OFC | Office | 세무사사무소 | BR | 세무사용 신고서/납부서 관리 |
| ADM | Admin | 관리자 | CM | 관리자 페이지 (슈퍼어드민) |
| DOC | Document | 문서관리 | BR | 환입, 폐기, 실감량, 보건증 등 증빙 자료 관리 |
				

---

## 3. 기능 코드

### MST (Master Data / 기준정보) - CM

| 코드 | 원어 | 한글 |
|------|------|------|
| ITEM | Item | 제품 |
| MATR | Material | 원재료 |
| CUS | Customer | 거래처 |
| WHS | Warehouse | 창고 |
| BOM | Bill Of Materials | 자재명세서 |
| LOT | LOT | 로트 설정 |

### SYS (System / 시스템관리) - CM

| 코드 | 원어 | 한글 |
|------|------|------|
| COM | Company | 회사정보 |
| AUTH | Authority | 권한관리 |
| USER | User | 사용자 관리 |
| NTF | Notification | 알림 설정 |
| THM | Theme | 테마 설정 |
| BILL | Billing | 요금제 |
		

### CST (Cost / 원가관리) - CM

| 코드 | 원어 | 한글 |
|------|------|------|
| CLS | Closing | 결산 |
| LED | Ledger | 원부자재수불부 |
| EXP | Expense | 제조경비등록 |
| EAC | Expense Account | 제조경비계정 |

### PRD (Production / 생산관리) - CM

| 코드 | 원어 | 한글 |
|------|------|------|
| WO | Work Order | 작업지시 |
| WH | Work History | 작업내역 |
| PRC | Process | 공정 |
| WRK | Work | 작업 |
| EQP | Equipment | 시설/설비 |
| FAC | Factory | 공장/설비/통 |
| SCH | Schedule | 생산지시현황표 |

### INV (Inventory / 재고관리) - CM

| 코드 | 원어 | 한글 |
|------|------|------|
| STS | Status | 재고현황 |
| IN | Inbound | 기타입고 |
| OUT | Outbound | 기타출고 |
| ADJ | Adjustment | 조정 |
| MOV | Movement | 이동 |
| HIS | History | 히스토리 |
| SAL | Sales | 판매 |
| PUR | Purchase | 구매 |
| PR | Production receipt | 생산입고 |

### INV (Inventory / 재고관리) - CM

| 코드 | 원어 | 한글 |
|------|------|------|
| STS | Status | 재고현황 |
| PUR | Purchase | 구매 |
| SAL | Sales | 판매 |
| PR | Production receipt | 생산입고 |
| IN | Inbound | 기타입고 |
| OUT | Outbound | 기타출고 |
| ADJ | Adjustment | 조정 |
| MOV | Movement | 이동 |
| HIS | History | 히스토리 |
		
### INV (Inventory / 재고관리) - BR

| 코드 | 원어 | 한글 |
|------|------|------|
| RTN | Return | 환입 |
| DSP | Disposal | 폐기 |
		

### TAX (Tax / 주세신고) - BR

| 코드 | 원어 | 한글 |
|------|------|------|
| BAS | Basic | 기초자료설정 |
| PRD | Product | 주류제품설정 |
| QTR | Quarterly | 분기별주세자료 |
| MON | Monthly | 월별주세자료 |
| SLR | Sales Record | 거래처별판매기록부 |
| LED | Ledger | 주류수불상황표 |
| REL | Release | 주류반출명세서 |
| RDA | Return & Disposal Application | 환입/폐기신청서 |
| DCL | Declaration | 주세신고서 |
| DMA | Declaration Management | 신고서관리 |
| PMA | Payment Management | 납부서관리 |
| SHK | Shrinkage | 실감량 |
		


### OFC (Office / 세무사사무소) - BR

| 코드 | 원어 | 한글 |
|------|------|------|
| DASH | Dashboard | 대시보드 |
| CLI | Client | 거래처관리 |
| SET | Settings | 설정 |
| PMA | Payment Management | 납부서관리 |
| LED | Liquor Entry/Delivery Status | 주류수불상황표 |
| REL | Release Statement | 주류반출명세서 |
| DCL | Declaration | 주세신고서 |
| DMA | Declaration Management | 신고서관리 |

### ADM (Admin / 관리자) - CM

| 코드 | 원어 | 한글 | 설명 |
|------|------|------|------|
| DASH | Dashboard | 대시보드 | 관리자 대시보드 현황판 |
| COM | Company | 회사관리 | 회사 목록/등록/수정/삭제 |
| USR | User | 사용자관리 | 사용자 목록/등록/수정/삭제 |
| ROLE | Role | 권한관리 | 권한 목록 |
| PERM | Permission | 권한매트릭스 | 권한별 기능 접근 설정 |
| CPA | Tax Accountant | 세무사관리 | 세무사 목록/등록/수정/삭제 |
| CMAP | CPA Mapping | 클라이언트매핑 | 세무사-회사 매핑 |
| SRV | Service | 서비스설정 | 서비스 환경설정 |
| CPT | Company Type | 회사유형 | 회사 유형 관리 |
| TIER | Tier | 요금제 관리 | 요금제 별 사용량 및 상태, 통계 관리 |


### DOC (Document / 문서관리) - BR

| 코드 | 원어 | 한글 | 설명 |
|------|------|------|------|
| EVD | Evidence | 증빙자료 | 증빙자료 관리 |
| HLC | Health Certificate | 보건증 | 보건증 관리 |
| CLS | Classification | 원·부자재별 HACCP 검사 항목 |  |
| LOG | Log | 원·부자재 검사 결과 기록 및 이력 관리 |  |

---

## 4. 화면 유형 코드

| 코드 | 원어 | 한글 | 설명 | 컴포넌트 패턴 |
|------|------|------|------|--------------|
| S | Screen | 일반화면 | 목록, 상세, 현황 등 | `page.tsx` + `*Table.tsx` |
| F | Form | 등록/수정 | 데이터 입력 폼 | `*Sheet.tsx` (Side Sheet) |
| P | Popup | 팝업/모달 | 확인, 선택, 삭제 등 | `*Dialog.tsx` |
| R | Report | 리포트 | 신고서, 명세서 출력 | `*Report.tsx` |
| D | Dashboard | 대시보드 | 현황판, 통계 | `Dashboard.tsx` |
| M | Matrix | 매트릭스 | 권한, 매핑 테이블 | `*Matrix.tsx` |

---

## 5. 순번

- **3자리 숫자** (001 ~ 999)
- 동일 기능 내 순차 부여
- 권장 순서: 목록(S001) → 상세(S002) → 등록(F001) → 수정(F002)

---

## 적용 예시

### 기준정보 (CM-MST)

```
BITDA-CM-MST-ITEM-S001   // 제품 목록
BITDA-CM-MST-ITEM-S002   // 제품 상세
BITDA-CM-MST-ITEM-F001   // 제품 등록/수정
BITDA-CM-MST-MATR-S001   // 원재료 목록
BITDA-CM-MST-MATR-F001   // 원재료 등록/수정
BITDA-CM-MST-CUS-S001    // 거래처 목록
BITDA-CM-MST-CUS-F001    // 거래처 등록/수정
BITDA-CM-MST-CUS-P001    // 거래처 검색 팝업
BITDA-CM-MST-WHS-S001    // 창고 목록
BITDA-CM-MST-WHS-F001    // 창고 등록/수정
```

### 시스템관리 (CM-SYS)

```
BITDA-CM-SYS-EMP-S001    // 직원 목록
BITDA-CM-SYS-EMP-F001    // 직원 등록/수정
BITDA-CM-SYS-ACC-S001    // 계정정보
BITDA-CM-SYS-COM-S001    // 회사정보
BITDA-CM-SYS-COM-F001    // 회사정보 수정
BITDA-CM-SYS-AUTH-S001   // 권한관리 (역할 목록)
BITDA-CM-SYS-AUTH-F001   // 역할 등록/수정
BITDA-CM-SYS-USER-S001   // 사용자 목록
BITDA-CM-SYS-USER-F001   // 사용자 초대/수정
BITDA-CM-SYS-NTF-S001    // 알림 설정
BITDA-CM-SYS-THM-S001    // 테마 설정
BITDA-CM-SYS-LOT-S001    // LOT 규칙 목록
BITDA-CM-SYS-LOT-F001    // LOT 규칙 등록/수정
BITDA-CM-SYS-BILL-S001   // 요금제 관리
```

### 원가관리 (CM-CST)

```
BITDA-CM-CST-CLS-S001    // 결산 목록
BITDA-CM-CST-LED-S001    // 원부자재수불부
BITDA-CM-CST-PUR-S001    // 구매 목록
BITDA-CM-CST-PUR-F001    // 구매 등록/수정
BITDA-CM-CST-SAL-S001    // 판매 목록
BITDA-CM-CST-SAL-F001    // 판매 등록/수정
```

### 생산관리 (CM-PRD)

```
BITDA-CM-PRD-WO-S001     // 작업지시 목록
BITDA-CM-PRD-WO-S002     // 작업지시 상세
BITDA-CM-PRD-WO-F001     // 작업지시 등록/수정
BITDA-CM-PRD-WH-S001     // 작업내역 목록
BITDA-CM-PRD-PRC-S001    // 공정 관리
BITDA-CM-PRD-EQP-S001    // 시설/설비 목록
BITDA-CM-PRD-EQP-F001    // 시설/설비 등록/수정
BITDA-CM-PRD-FAC-S001    // 공장/설비/통 설정
BITDA-CM-PRD-SCH-S001    // 생산지시현황표
```

### 재고관리 (CM-INV)

```
BITDA-CM-INV-STS-S001    // 재고현황
BITDA-CM-INV-IN-S001     // 기타입고 목록
BITDA-CM-INV-IN-F001     // 기타입고 등록
BITDA-CM-INV-OUT-S001    // 기타출고 목록
BITDA-CM-INV-ADJ-S001    // 조정 목록
BITDA-CM-INV-MOV-S001    // 이동 목록
BITDA-CM-INV-HIS-S001    // 히스토리
```

### 재고관리 - 주류 (BR-INV)

```
BITDA-BR-INV-RTN-S001    // 환입 목록
BITDA-BR-INV-RTN-F001    // 환입 등록
BITDA-BR-INV-DSP-S001    // 폐기 목록
BITDA-BR-INV-DSP-F001    // 폐기 등록
```

### 주세신고 (BR-TAX)

```
BITDA-BR-TAX-BAS-S001    // 기초자료설정
BITDA-BR-TAX-PRD-S001    // 주류제품설정
BITDA-BR-TAX-QTR-S001    // 분기별 주세자료
BITDA-BR-TAX-MON-S001    // 월별 주세자료
BITDA-BR-TAX-SLR-S001    // 거래처별 판매기록부
BITDA-BR-TAX-DCL-S001    // 주세신고서 목록
BITDA-BR-TAX-DCL-F001    // 주세신고서 작성
BITDA-BR-TAX-DCL-R001    // 주세신고서 출력
BITDA-BR-TAX-LED-R001    // 주류수불상황표 출력
BITDA-BR-TAX-REL-R001    // 주류반출명세서 출력
BITDA-BR-TAX-RDA-R001    // 환입/폐기신청서 출력
BITDA-BR-TAX-DMA-S001    // 신고서관리
BITDA-BR-TAX-PMA-S001    // 납부서관리
```

### 식품안전관리 (CM-HAC)

```
BITDA-CM-HAC-LOG-S001    // 원부자재 검사일지 목록
BITDA-CM-HAC-LOG-F001    // 원부자재 검사일지 등록/수정
```

### 세무사사무소 (BR-OFC)

```
BITDA-BR-OFC-DASH-D001   // 대시보드
BITDA-BR-OFC-CLI-S001    // 거래처관리 목록
BITDA-BR-OFC-CLI-S002    // 거래처관리 상세
BITDA-BR-OFC-SET-S001    // 설정
BITDA-BR-OFC-PMA-S001    // 납부서관리 목록
BITDA-BR-OFC-PMA-R001    // 납부서 출력
BITDA-BR-OFC-LED-S001    // 주류수불상황표 목록
BITDA-BR-OFC-LED-R001    // 주류수불상황표 출력
BITDA-BR-OFC-REL-S001    // 주류반출명세서 목록
BITDA-BR-OFC-REL-R001    // 주류반출명세서 출력
BITDA-BR-OFC-DCL-S001    // 주세신고서 목록
BITDA-BR-OFC-DCL-R001    // 주세신고서 출력
BITDA-BR-OFC-DMA-S001    // 신고서관리 목록
```

### 관리자 (CM-ADM)

```
BITDA-CM-ADM-DASH-D001   // 대시보드
BITDA-CM-ADM-COM-S001    // 회사 목록
BITDA-CM-ADM-COM-F001    // 회사 등록/수정 Sheet
BITDA-CM-ADM-COM-P001    // 회사 삭제 확인
BITDA-CM-ADM-USR-S001    // 사용자 목록
BITDA-CM-ADM-USR-F001    // 사용자 등록/수정 Sheet
BITDA-CM-ADM-USR-P001    // 사용자 삭제 확인
BITDA-CM-ADM-ROLE-S001   // 권한 목록
BITDA-CM-ADM-PERM-M001   // 권한 매트릭스
BITDA-CM-ADM-CPA-S001    // 세무사 목록
BITDA-CM-ADM-CPA-F001    // 세무사 등록/수정 Sheet
BITDA-CM-ADM-CPA-P001    // 세무사 삭제 확인
BITDA-CM-ADM-CMAP-M001   // 클라이언트 매핑
BITDA-CM-ADM-SRV-S001    // 서비스 설정
```

---

## 문서 활용 예시

> **BITDA-CM-PRD-WO-S001** 작업지시 목록에서 [신규등록] 클릭 시 **BITDA-CM-PRD-WO-F001** 작업지시 등록 화면으로 이동합니다. 원재료 선택 시 **BITDA-CM-MST-MATR-P001** 원재료 검색 팝업이 호출됩니다.

---

## 최종 업데이트

- 날짜: 2026-02-11
- 버전: 4.3.2
- 변경사항:
  - PRD 모듈에 FAC(공장/설비/통), SCH(생산지시현황표) 기능코드 추가
  - Notion 마스터 기능코드 DB와 동기화 완료
- 이전 버전:
  - 4.2.0 (2026-02-04): 공유 참조 파일로 통합, BR-OFC 최신화
- Notion 원본: https://www.notion.so/invigoworks/00-BITDA-2ce471f8dcff804abd94d6a09fa4f16b
