# Code Structure Mapping

> 프로젝트 앱 폴더 구조와 화면코드 매핑 규칙

---

## 화면코드 구조

```
BITDA-[도메인]-[모듈]-[기능]-[화면유형][순번]
```

**예시**: `BITDA-BR-MST-MATR-S001`
- BR: 주류 도메인
- MST: 기준정보 모듈
- MATR: 원재료 기능
- S001: 일반화면 001

---

## 1. 앱 폴더 → 도메인 코드 매핑

| 앱 폴더 경로 | 도메인 코드 | 도메인명 | 설명 |
|-------------|------------|---------|------|
| `apps/admin` | CM | Common | 슈퍼어드민 관리자 |
| `apps/liquor` | BR | Brewery | 주류 제조 ERP |
| `apps/manufacturing` | CM | Common | 일반 제조업 ERP |
| `apps/tax-office` | BR | Brewery | 세무사사무소 (주류 관련) |
| `apps/preview` | - | - | 프리뷰용 (화면코드 제외) |

### 도메인 코드 전체 목록

| 코드 | 원어 | 한글 | 설명 |
|------|------|------|------|
| CM | Common | 공통 | 전 산업군 공통 기능 |
| BR | Brewery | 주류 | 주류 제조 특화 |
| PH | Pharmaceutical | 제약 | 제약 제조 특화 (예정) |
| FD | Food | 식품 | 식품 제조 특화 (예정) |

---

## 2. 모듈 폴더 → 모듈 코드 매핑

### 2.1 liquor / manufacturing 앱

| 폴더 경로 | 모듈 코드 | 모듈명 | 설명 |
|----------|----------|-------|------|
| `settings/master-data` | MST | 기준정보 | 제품, 원재료, 거래처, 창고 |
| `settings/system` | SYS | 시스템관리 | 회사정보, 사용자, 권한 |
| `production` | PRD | 생산관리 | 작업지시, 작업내역, 공정 |
| `inventory` | INV | 재고관리 | 재고현황, 입출고 |
| `cost` | CST | 원가관리 | 결산, 수불부, 구매, 판매 |
| `liquor-tax` | TAX | 주세관리 | 주세신고, 기초자료 |
| `document` | DOC | 문서관리 | 증명서, 검사, 증빙 |

### 2.2 tax-office 앱

| 폴더 경로 | 모듈 코드 | 모듈명 | 설명 |
|----------|----------|-------|------|
| `declaration` | OFC | 세무사사무소 | 신고관리 |
| `declaration/dcl01` | OFC-DCL01 | 주세신고 | 분기별 주세신고 |
| `payment` | OFC-PMA | 납부서관리 | 납부서 목록/출력 |

### 2.3 admin 앱

| 폴더 경로 | 모듈 코드 | 모듈명 | 설명 |
|----------|----------|-------|------|
| `users` | ADM | 관리자 | 사용자 관리 |
| `companies` | ADM | 관리자 | 회사 관리 |
| `roles` | ADM | 관리자 | 권한 관리 |
| `dashboard` | ADM | 관리자 | 대시보드 |

### 모듈 코드 전체 목록

| 코드 | 원어 | 한글 | 설명 |
|------|------|------|------|
| MST | Master Data | 기준정보 | 제품, 원재료, 거래처, 창고 등 |
| SYS | System | 시스템관리 | 직원, 계정정보, 회사정보, 권한 |
| CST | Cost | 원가관리 | 결산, 수불부, 구매, 판매 |
| PRD | Production | 생산관리 | 작업지시, 작업내역, 공정 |
| INV | Inventory | 재고관리 | 재고현황, 입출고, 환입/폐기(BR) |
| TAX | Tax | 주세신고 | 주세신고 관련 전체 |
| OFC | Office | 세무사사무소 | 세무사용 신고서/납부서 관리 |
| HAC | Haccp | 식품안전관리 | HACCP 기준 관리, 점검·검사 |
| ADM | Admin | 관리자 | 슈퍼어드민 페이지 |

---

## 3. 기능 폴더 → 기능 코드 매핑

### 3.0 INV (재고관리) 기능

| 폴더명 | 기능 코드 | 기능명 | 설명 |
|--------|----------|-------|------|
| `status` | STS | 재고현황 | 품목별, 창고별, Lot, 일일변동 |
| `production-incoming` | PIN | 생산입고 | 생산 완료 후 입고 |
| `purchase` | PUR | 구매입고 | 발주/구매 입고 |
| `disposal` | DSP | 폐기 | 폐기 처리 |
| `redemption` | RDM | 환입 | 환입 처리 |
| `movement` | MOV | 재고이동 | 창고 간 이동 |
| `misc-incoming` | MIN | 기타입고 | 기타 입고 |
| `misc-outgoing` | MOT | 기타출고 | 기타 출고 |
| `adjustment` | ADJ | 재고조정 | 재고 수량 조정 |

### 3.0a TAX (주세관리) 기능

| 폴더명 | 기능 코드 | 기능명 | 설명 |
|--------|----------|-------|------|
| `declaration` | DCL | 신고서 | 주세 신고서 |
| `basic-data` | BAS | 기초자료 | 주세 기초자료 |

### 3.0b DOC (문서관리) 기능

| 폴더명 | 기능 코드 | 기능명 | 설명 |
|--------|----------|-------|------|
| `health-cert` | HCR | 건강진단서 | 건강진단서 관리 |
| `inspection-item` | INI | 검사항목 | 검사항목 관리 |
| `inspection-report` | INR | 검사성적서 | 검사 성적서 |
| `evidence` | EVD | 증빙 | 증빙 자료 관리 |

### 3.1 MST (기준정보) 기능

| 폴더명 | 기능 코드 | 기능명 | 설명 |
|--------|----------|-------|------|
| `materials` | MATR | 원재료 | 원재료 관리 |
| `products` | ITEM | 제품 | 제품 관리 |
| `partners` | CUS | 거래처 | 거래처 관리 |
| `warehouses` | WHS | 창고 | 창고 관리 |

### 3.2 SYS (시스템관리) 기능

| 폴더명 | 기능 코드 | 기능명 | 설명 |
|--------|----------|-------|------|
| `company` | COM | 회사정보 | 회사 정보 관리 |
| `users` | USER | 사용자 | 사용자 관리 |
| `roles` | AUTH | 권한관리 | 권한 설정 |
| `notifications` | NTF | 알림설정 | 알림 설정 |

### 3.3 ADM (관리자) 기능

| 폴더명 | 기능 코드 | 기능명 | 설명 |
|--------|----------|-------|------|
| `dashboard` | DASH | 대시보드 | 관리자 대시보드 |
| `companies` | COM | 회사관리 | 회사 목록/등록/수정/삭제 |
| `users` | USR | 사용자관리 | 사용자 목록/등록/수정/삭제 |
| `roles` | ROLE | 권한관리 | 권한 목록 |
| `permissions` | PERM | 권한매트릭스 | 권한별 기능 접근 설정 |

### 3.4 OFC (세무사사무소) 기능

| 폴더명 | 기능 코드 | 기능명 | 설명 |
|--------|----------|-------|------|
| `dashboard` | DASH | 대시보드 | 세무사 대시보드 |
| `clients` | CLI | 거래처관리 | 담당 거래처 관리 |
| `settings` | SET | 설정 | 사무소 설정 |
| `payment` | PMA | 납부서관리 | 납부서 관리 |
| `ledger` | LED | 주류수불상황표 | 주류 입출고 현황 |
| `release` | REL | 주류반출명세서 | 주류 반출 내역 |
| `declaration` | DCL | 주세신고서 | 주세 신고서 |
| `declaration-mgmt` | DMA | 신고서관리 | 신고서 이력 관리 |

---

## 4. 화면유형 → 파일 패턴 매핑

| 화면유형 코드 | 원어 | 한글 | 파일 패턴 |
|-------------|------|------|----------|
| S | Screen | 일반화면 | `page.tsx`, `*Table.tsx` |
| F | Form | 등록/수정 | `*Sheet.tsx` |
| P | Popup | 팝업/모달 | `*Dialog.tsx` |
| R | Report | 리포트 | `*Report.tsx` |
| D | Dashboard | 대시보드 | `Dashboard.tsx` |
| M | Matrix | 매트릭스 | `*Matrix.tsx` |

---

## 5. 경로 → 화면코드 변환 예시

### 예시 1: 원재료 관리

```
Source Path: apps/liquor/src/settings/master-data/materials/page.tsx

분석:
- App: liquor → BR (주류)
- Module: settings/master-data → MST (기준정보)
- Feature: materials → MATR (원재료)
- File: page.tsx → S (일반화면)

결과 화면코드: BITDA-BR-MST-MATR-S001
```

### 예시 2: 사용자 관리 (admin)

```
Source Path: apps/admin/src/users/page.tsx

분석:
- App: admin → CM (공통)
- Module: users (admin 내) → ADM (관리자)
- Feature: users → USR (사용자관리)
- File: page.tsx → S (일반화면)

결과 화면코드: BITDA-CM-ADM-USR-S001
```

### 예시 3: 주세신고 상세

```
Source Path: apps/tax-office/src/declaration/dcl01/[declarationId]/page.tsx

분석:
- App: tax-office → BR (주류)
- Module: declaration → OFC (세무사사무소)
- Feature: dcl01 → DCL01 (주세신고)
- File: page.tsx (상세) → S002 (상세화면)

결과 화면코드: BITDA-BR-OFC-DCL01-S002
```

### 예시 4: 거래처 등록 Sheet

```
Source Path: apps/liquor/src/settings/master-data/partners/components/PartnerSheet.tsx

분석:
- App: liquor → BR (주류)
- Module: settings/master-data → MST (기준정보)
- Feature: partners → CUS (거래처)
- File: *Sheet.tsx → F (등록/수정)

결과 화면코드: BITDA-BR-MST-CUS-F001
```

---

## 6. 검증 규칙

### 6.1 필수 검증 항목

1. **도메인 일치**: 앱 폴더와 도메인 코드 일치 여부
2. **모듈 일치**: 모듈 폴더와 모듈 코드 일치 여부
3. **기능 일치**: 기능 폴더와 기능 코드 일치 여부
4. **화면유형 일치**: 파일 패턴과 화면유형 코드 일치 여부

### 6.2 검증 오류 유형

| 오류 유형 | 설명 | 예시 |
|----------|------|------|
| DOMAIN_MISMATCH | 도메인 코드 불일치 | liquor 앱인데 CM 도메인 |
| MODULE_MISMATCH | 모듈 코드 불일치 | master-data 폴더인데 SYS 모듈 |
| FEATURE_MISMATCH | 기능 코드 불일치 | materials 폴더인데 ITEM 코드 |
| TYPE_MISMATCH | 화면유형 불일치 | *Sheet.tsx인데 S 타입 |
| UNKNOWN_PATH | 매핑되지 않은 경로 | 새로운 폴더 구조 |

### 6.3 검증 예외 사항

- `preview` 앱은 화면코드 검증 제외
- `components` 폴더 내 공통 컴포넌트는 개별 화면코드 불필요
- `shared`, `lib`, `utils` 등 유틸리티 폴더는 검증 제외

---

## 7. 현재 프로젝트 폴더 구조

### apps/liquor (BR - 주류)

```
apps/liquor/src/
├── settings/
│   ├── master-data/           → MST (기준정보)
│   │   ├── materials/         → MATR (원재료)
│   │   ├── products/          → ITEM (제품)
│   │   ├── partners/          → CUS (거래처)
│   │   └── warehouses/        → WHS (창고)
│   └── system/                → SYS (시스템관리)
│       ├── company/           → COM (회사정보)
│       ├── users/             → USER (사용자)
│       ├── roles/             → AUTH (권한)
│       └── notifications/     → NTF (알림)
├── inventory/                 → INV (재고관리)
│   ├── status/                → STS (재고현황)
│   ├── production-incoming/   → PIN (생산입고)
│   ├── purchase/              → PUR (구매입고)
│   ├── disposal/              → DSP (폐기)
│   ├── redemption/            → RDM (환입)
│   ├── movement/              → MOV (재고이동)
│   ├── misc-incoming/         → MIN (기타입고)
│   ├── misc-outgoing/         → MOT (기타출고)
│   └── adjustment/            → ADJ (재고조정)
├── liquor-tax/                → TAX (주세관리)
│   ├── declaration/           → DCL (신고서)
│   └── basic-data/            → BAS (기초자료)
├── document/                  → DOC (문서관리)
│   ├── health-cert/           → HCR (건강진단서)
│   ├── inspection-item/       → INI (검사항목)
│   ├── inspection-report/     → INR (검사성적서)
│   └── evidence/              → EVD (증빙)
└── components/
    └── layout/
```

### apps/admin (CM - 공통)

```
apps/admin/src/
├── users/                     → ADM-USR (사용자관리)
├── companies/                 → ADM-COM (회사관리)
├── pages/                     → 페이지 라우팅
└── components/
    └── layouts/
```

### apps/tax-office (BR - 주류)

```
apps/tax-office/src/
├── declaration/               → OFC (세무사사무소)
│   └── dcl01/                 → DCL01 (주세신고)
│       └── [declarationId]/   → 상세 페이지
├── payment/                   → PMA (납부서관리)
└── components/
    └── layout/
```

### apps/manufacturing (CM - 공통)

```
apps/manufacturing/src/
├── settings/
│   ├── master-data/           → MST (기준정보)
│   │   ├── materials/         → MATR
│   │   ├── products/          → ITEM
│   │   ├── partners/          → CUS
│   │   └── warehouses/        → WHS
│   └── system/                → SYS (시스템관리)
│       ├── company/           → COM
│       ├── users/             → USER
│       ├── roles/             → AUTH
│       └── notifications/     → NTF
└── components/
    └── layout/
```

---

## 최종 업데이트

- 날짜: 2026-02-09
- 버전: 1.1.0
- 변경사항: INV(재고), TAX(주세), DOC(문서) 모듈 매핑 추가
- 작성자: Claude Code
