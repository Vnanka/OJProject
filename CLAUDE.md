# CLAUDE.md — OJ Project (Oliver James interview dashboard)

Working context for this folder. Read this first, then look at `data-rules.md`,
then ask what to work on.

---

## 1. The job

Vlad has a second-stage interview for **Senior BI Analyst (Microsoft Fabric)** at
**Oliver James**, a recruitment firm.

| | |
|---|---|
| **When** | Monday 21 September 2026, 1:00 PM |
| **Where** | Globe Building, 1 New Quay Street, Manchester, M3 4BN |
| **Task** | Build a Power BI dashboard on a dataset of his choosing, present it, then Q&A |
| **Q&A covers** | Data model, KPI logic, governance, scalability, stakeholders, productionising |

Full brief, job spec and company research: **`Misc/CLAUDE_1.md`** (the previous session's
handoff — still accurate, do not delete). Source documents, all in **`Misc/`** (Vlad moved
them there on 17 Sep to keep the root tidy): `1.pdf` (recruiter email),
`Senior BI Analyst - OJA (1).docx` (job spec), `Vladislavs Nanaks_CV_BI_D V4.docx` (CV).

**Time available.** He works full time Wed 16 – Fri 18 Sep, so only evenings.
Then the weekend. Roughly 20–25 usable hours in total, and some of that must go to the
presentation and rehearsal. **Scope discipline matters more than ambition.**

---

## 2. How to work with Vlad

- **Plain, simple English.** English is his second language. Explain like he is a junior
  data engineer: short sentences, no unexplained jargon. Name a concept, then define it
  in one line (grain, idempotent, conformed dimension, role-playing dimension).
- **One thing at a time, then stop and wait.** Propose, get agreement, then do it.
- **Show real command output.** Never claim something ran or worked without pasting it.
- **Never invent his work history.** CV facts only. Synthetic *demo* data is fine and is
  always labelled synthetic.
- **He owns Power BI.** It is his strongest skill — advise on what the model should
  expose, do not try to design the report for him.
- **He does not know DuckDB or dbt yet.** Both need a short, practical lesson when we
  reach them. He has a dbt project in `../lol-data-warehouse` but has not yet learned how
  it works. Bridge from what he knows: raw → staging → marts is bronze → silver → gold;
  a dbt model is a SELECT and dbt writes the CREATE around it; dbt tests are data quality
  gates that run *before* the report.
- The strict "Vlad types all the Python" rule belongs to the **lol-data-warehouse** repo.
  It does **not** apply here — there is no time. Here Claude writes the generator and the
  dbt models, explains them, and Vlad reviews. (Confirm with him if in doubt.)

---

## 3. Decisions already agreed (15 Sep 2026)

**Dataset.** Not League of Legends — no commercial meaning for a recruitment panel.
Synthetic recruitment data shaped like Oliver James, plus real reference data from public
APIs. The LoL warehouse is used as *evidence of how he works* in the Q&A only.

**Architecture ("Level B") — a small local warehouse:**

```
generated CSV exports        BRONZE           SILVER            GOLD               Power BI
+ real API data        ->  DuckDB raw.*  ->  dbt stg_* views ->  dim_/fact_ tables  ->  import
(two "source systems")     loaded as text     rename, cast       + dbt tests           Parquet
                                              standardise
```

- Business logic lives in **SQL in the warehouse**, not in Power Query. This matches the
  job spec ("consolidate SQL and business logic into governed datasets").
- Power BI reads **Parquet files** exported by dbt. Chosen over a DuckDB ODBC connection
  because it cannot fail on the day.
- Cloud (Fabric / Azure SQL) is **deliberately not built** — it is one architecture slide
  showing how this becomes production. He talks about Fabric from real job experience.

**Gold layer — 4 facts, 8 dimensions:**

| Fact | Grain |
|---|---|
| `fact_pipeline_event` | one candidate stage change (CV sent, interview, offer, placed, rejected, withdrawn) |
| `fact_placement` | one placement |
| `fact_fee_transaction` | one invoice **or** credit note |
| `fact_target` | one consultant per month (NFI target, GBP) — added 16 Sep for the manager level |

Dimensions: `dim_date`, `dim_consultant`, `dim_client`, `dim_vacancy` (includes
work arrangement + employment type), `dim_stage`, `dim_industry`, `dim_discipline`,
`dim_office`.

**Key design choices and why (these are the Q&A talking points):**

- **The quirk: rebates.** If a candidate leaves inside a 12-week guarantee period, a
  credit note refunds part of the fee. So booked fee != invoiced != **Net Fee Income**.
  NFI is how Oliver James actually reports growth.
- **`dim_date` is role-playing**: one table, extra dates use inactive relationships plus
  `USERELATIONSHIP()`. Built in dbt, not with `CALENDAR()`, so there is one source of truth.
  Fiscal year starts **1 April**; weeks are **ISO**, Monday start. Calendar + fiscal
  columns, UK bank holidays and working-day flags.
- **Industry and discipline are two separate dimensions.** Industry = what the client is
  (4 of them). Discipline = what the job is (7, and they repeat across all industries).
- **`office_key` sits on the fact rows**, recorded at the time of the event, so a
  consultant moving office does not rewrite history. Avoids needing SCD Type 2.
- **No candidate dimension** — not needed for these KPIs, and it is a GDPR point.
- **Perm only.** Contract/interim invoicing was cut as too much work.
- **Multi-currency with real ECB rates.** Conversion to GBP happens **in dbt**, so every
  report uses the same number. Frankfurter API (`api.frankfurter.dev/v1`, no key) covers
  all seven office currencies — verified working. It publishes nothing on weekends and
  holidays, so we use a **monthly average rate**, which is what finance teams do anyway.

**Source export shape (16 Sep 2026).** The CRM export copies the table/column names,
status codes and messy value formats of **OpenCATS** (open-source recruitment CRM).
Industry, discipline and work arrangement are **plain custom columns**. Vlad rejected
OpenCATS `extra_field` (EAV, key-value rows) as overcomplication; it is only a Q&A point.
Added `can_relocate` (flag copied onto fact rows) and `candidate_duplicates` (merged in
silver before counting). Placements and fees come from a separate finance export.
Full detail: `data-rules.md` v3.

**Report ideas (16 Sep 2026, not final).** 1–2 executive pages + a drillthrough detail page,
time series, KPI cards for conversion rates (cohort-based, non-round, change by fiscal year),
**field parameters** to switch the grouping (industry / office / discipline / team…).
**Two audiences:** executives (whole firm) and **team managers** (own team; consultant
ranking, NFI vs target, tenure-adjusted comparison), plus a consultant drillthrough.
**Row-level security** is a known gap from Vlad's first interview; he wants to show he has
learned it. Plan: **dynamic RLS at team level** with `USERPRINCIPALNAME()` and a fake
access list (`security_user_team.csv`, ~120 rows: execs → all teams, directors → their
region/office teams, managers → own team), demoed with Desktop "View as". Every fact
carries the consultant key so the filter reaches everything; transaction facts carry all
the same dimension keys so field parameters work. Known limit: current team only (no SCD2).

**Real data used:** ECB exchange rates, gov.uk bank holidays, and OJ's real industry,
discipline and office lists from their website. Everything transactional is generated.

---

## 4. Current state

- `data-rules.md` — **v3, agreed by Vlad (16 Sep). The data plan is complete.** Volumes, funnel rates,
  seasonality, fee and rebate rules, the six stories planted in the data, seven deliberate
  data quality problems, and what is out of scope. Section 10 records his answers; section 11 has
  the actual generated counts (214 users, 7,506 jobs, 145,619 history rows, 4,714 placements).
- **Raw data is generated (16 Sep).** Layout, agreed with Vlad: everything for the warehouse
  lives under `dw/`, data in `dw/raw/<source system>/`.
  ```
  dw/raw/crm/  finance/  security/  api/       9.7 MB, see data-rules.md §11
  dw/src/generate/generate_sources.py          synthetic CRM + finance + security (fixed seed)
  dw/src/extract/fetch_reference.py            real ECB rates + gov.uk bank holidays
  ```
  Both scripts are standard library only (they run with any Python 3.12). The generator prints checks of its output against data-rules.md; last run matched
  the plan (details in §11). CRM go-live is 1 Oct 2022 (six-month run-in before FY23/24).
- **Bronze loaded (17 Sep).** `dw/src/load/load_raw.py` creates `dw/warehouse/oj_dw.duckdb`
  (7.0 MB) and lands all 13 files in schema `raw` — **every column VARCHAR** (verified: 0
  non-text columns), CSVs via `read_csv(all_varchar=true)`, the two API files as one row of
  JSON text each via `read_text` (dbt parses them with `json_extract_string`). Table names
  keep the source visible: `crm_*`, `fin_*`, `sec_*`, `api_*`. Idempotent
  (`create or replace`), re-runs in seconds.
- **Modified timestamps added (17 Sep, Vlad's request).** Every source file now has a
  "record last modified" column — `date_modified` (CRM), `modified_at` (finance),
  `last_updated` (security) — with meaningful values (see `data-rules.md` §3.1). Purpose:
  realism now, and a possible incremental load later. Added with a **separate random
  generator**, so every other value in the data is byte-identical (verified against a
  backup). Vlad re-ran the generator and the bronze load himself.
- **dbt project skeleton created (17 Sep, ~22:40).** `dw/dbt/` holds `dbt_project.yml`
  (profile `oj_dw`; `models/silver` → views, `models/gold` → tables), `profiles.yml`
  (duckdb, `../warehouse/oj_dw.duckdb`, 4 threads) and `models/silver/sources.yml`
  (all 13 bronze tables declared under source `raw`, with descriptions).
  `dbt debug --profiles-dir .` → **All checks passed** (run by both Claude and Vlad).
  dbt writes to schema `main`; bronze stays in `raw`.
  Commands must run from `dw/dbt` with the venv active:
  `..\..\.venv\Scripts\Activate.ps1`, then `dbt build --profiles-dir .`
- **Column naming standard (Vlad's decision, 18 Sep): PascalCase, no underscores**, for all
  silver and gold columns: `UserId`, `StartDate`, `ModifiedAt`. IDs end in `Id`, dates in
  `Date`, timestamps in `At`; gold surrogate keys end in `Key`. Model/file names stay dbt
  snake_case (`stg_user`, `dim_consultant`). DuckDB preserves the casing (verified), so
  Power BI will show these names as written.
- **Silver rules:** one bronze table per model; only rename, cast, standardise; no joins, no
  business logic (no derived flags like `IsManager`/`IsActive` — those go to gold). Use
  `cast` for IDs and dates so bad data fails the build loudly; `try_cast` only where bad
  values are expected (free-text salary) and then count the NULLs with a test. Every model
  starts `with source as (select * from {{ source(...) }})`. The audit column is always
  renamed to `ModifiedAt`.
- **Silver built (18 Sep): 13 views + `schema.yml` + 1 singular test.** `dbt build` →
  **PASS=43 WARN=6 ERROR=0**. The 6 warnings are exactly the planted problems: Discipline
  blank 30, status 999 on 20 rows, FeePct blank 2 + zero 1 (`tests/assert_fee_pct_positive.sql`),
  orphan credit notes 2, unparseable salary ('Competitive') 356. Planted problems use
  `severity: warn` (reported, pipeline continues, gold decides how to show them); broken
  assumptions are `error`. Tests use dbt 1.12 syntax: `data_tests:` with `arguments:` /
  `config:`.
  Key silver logic: `stg_joborder` parses free-text salary into `SalaryMin`/`SalaryMax`
  (local currency, keeps `SalaryText`); `stg_transactions` makes credit notes **negative**
  (`NetAmountLocal`); `stg_fx_rates` unpacks the JSON to 6,054 rows (1,009 days × 6
  currencies, `RatePerGbp`); `stg_bank_holidays` keeps all 3 divisions; finance dates parsed
  with explicit `strptime('%d/%m/%Y')`. Money stays in local currency — GBP conversion and
  the monthly average rate are gold.
  **One agreed exception to "no joins in silver":** applying the CRM's own duplicate-merge
  list (`stg_candidate_duplicates`) in `stg_candidate` (drops merged records: 46,934 →
  46,434), `stg_status_history` and `stg_placements` (`CandidateId` = merged,
  `SourceCandidateId` = as recorded). Claude flagged this to Vlad as the one bend of the rule.
  Funnel-stage mapping of status codes is **gold** (`dim_stage`), not silver.
- **Gold started (18–19 Sep). `dim_date` built** (table, tests pass): 1 Apr 2022 – 31 Mar
  2028 (2,192 days, 6 fiscal years) + `-1` Unknown row; `DateKey` = yyyymmdd int; England &
  Wales bank holidays (51) and `IsWorkingDay` (253 in FY25/26); calendar, ISO week
  (`IsoWeekNumber` 14, `IsoWeekName` W14, `IsoYearWeek` 2026-W14) and fiscal columns
  (`FiscalYear` FY26/27, `FiscalPeriod` P01, `FiscalQuarter` FQ1, `FiscalWeekNumber`/`Name`
  FW01, `FiscalWeekOfQuarter`, `FiscalWeekOfPeriod`, `WeekOfMonth`). Week 1 of a
  period/quarter = the Mon–Sun week containing its 1st day, so boundary weeks split (e.g.
  30–31 Mar 2026 = P12 week 6 / FW53). Sort-by columns for Power BI: MonthName→MonthNumber,
  YearMonth→YearMonthKey, FiscalPeriod→FiscalYearPeriodKey. Vlad rejected a 4-4-5 calendar
  (5-week periods distort period-on-period stats) — agreed calendar months suit a business
  that invoices and sets targets monthly. Gold tests are `error` severity.
- **No dbt seeds — one ingestion path for everything (Vlad's decision, 19 Sep).** Claude
  proposed a seed CSV for office attributes; Vlad rejected it as technical debt and
  fragmentation. Reference data the business maintains is a **source file** like any other:
  `dw/raw/reference/office.csv` (13 rows: office, city, country code/name, region, currency,
  `last_updated`) → bronze `raw.ref_office` (prefix `ref_`) → silver `stg_office` → gold.
  The generator writes it from its own `OFFICES` table (no randomness; the other 13 raw files
  were verified byte-identical by md5). New tests: `stg_office` unique/not-null, currency in
  the ECB list, and **every user's office exists in the office list** (relationships).
  Bronze now has 14 tables. Also fixed a Claude bug from 17 Sep: the generator's summary
  crashed after the `modified_at` change (targets rows got a 4th value); data files were
  unaffected because they are written before the summary.
- **CRM lookup tables added (19 Sep, Vlad's idea incl. valid dates).** `dw/raw/crm/industry.csv`
  (14 rows: `sub_sector_id, sub_sector, industry_id, industry, valid_from, valid_to,
  date_modified`) and `dw/raw/crm/discipline.csv` (8 rows: `discipline_id, discipline,
  valid_from, valid_to, date_modified`). Empty `valid_to` = still in use (arrives as NULL).
  All in-use values valid from go-live 2022-10-01. One retired value each — sub-sector
  "Reinsurance" (to 2024-03-31), discipline "Tax" (to 2023-09-30) — used by no record.
  **Vlad: keep them for realism only, build NOTHING around them** (no logic, flags, tests or
  story); in gold they are ordinary rows with ValidFrom/ValidTo passed through. Written by the
  generator without randomness; the other 14 raw files verified byte-identical by md5.
  **Done (19 Sep):** added to `load_raw.py` (bronze now **16 tables**, 104 columns, all
  VARCHAR), full bronze reload, silver `stg_industry` (SubSectorId, SubSector, IndustryId,
  Industry, ValidFrom, ValidTo) and `stg_discipline` (DisciplineId, Discipline, ValidFrom,
  ValidTo), tests that every client sub-sector and every non-blank job discipline exists in
  the lists. Full `dbt build`: **PASS=67 WARN=6 ERROR=0 (73)** — same 6 planted warnings.
  Silver now has **16 views**. Gold dims must be built FROM these lookups (and
  `stg_office`), not from distinct fact values.
- **No business-mapping CASE statements in SQL (Vlad's rule, 19 Sep).** Mappings such as
  "status code → funnel stage" are reference data: a source file → bronze → silver → joined
  in gold. `CASE` only when absolutely necessary. Applied: `reference/funnel_stage.csv`
  (12 rows: status_code, funnel_stage, funnel_stage_order, stage_type, exit_by,
  last_updated) → `raw.ref_funnel_stage` → `stg_funnel_stage` → `dim_stage` (now a plain
  inner join of `stg_status` + `stg_funnel_stage`, plus the `-1` "Unknown exit" row). New
  silver test: every CRM status code has a funnel mapping. Output identical to the old CASE
  version. Bronze now **17 tables**. Calendar arithmetic in `dim_date` (fiscal year, weeks)
  is computation, not a business mapping, so it stays SQL — Vlad agrees, noting date
  logic varies by company and a downloadable calendar template would also be valid; building
  it in SQL here was his choice to try something new. `dim_office` fixed too:
  `region_sort_order` added to `reference/office.csv` (only that file changed, other 16
  verified identical) → `stg_office.RegionSortOrder` → `dim_office` (no CASE left).
- **Gold dims built (19 Sep):** `dim_date`, `dim_office` (generated OfficeKey via
  row_number over name), `dim_industry` (key = SubSectorId), `dim_discipline` (key =
  DisciplineId), `dim_stage` (key = status code). All have `-1` Unknown rows; all tests pass.
- **Star, not snowflake (agreed 19 Sep).** Facts carry EVERY dimension key directly; dims do
  not point at each other in the Power BI model. When a fact is built, gold joins it to e.g.
  the vacancy to pick up that vacancy's `DisciplineKey` and stores it on the fact row (Vlad's
  description). `dim_client` / `dim_vacancy` keep industry/discipline NAMES as plain text for
  convenience only. Reasons: Power BI filters flow one step; field parameters need direct
  relationships; the lookup cost is paid once at build time.
- **All 8 dimensions built (19 Sep).** `dim_consultant` (key UserId; ConsultantName,
  ManagerKey/ManagerName, `IsManager` = someone reports to them → 24 = one per team,
  `IsActive` = no leave date → 164, matches generator headcount; current Team/Office for RLS
  and the Team→Consultant hierarchy), `dim_client` (key CompanyId; Industry/SubSector as
  text only), `dim_vacancy` (key JobOrderId; blank discipline → 'Unknown'; salary in local
  currency + `SalaryCurrency` from the office list; `JobTypeCode` left as raw 'H' — a label
  would need a CRM job-type lookup, not a CASE; proposed to leave as a Q&A mention). All
  gold tests pass.
- **`fx_rate_monthly` built (19 Sep).** Gold helper table: one row per month × currency
  (343 = 49 months × 7 currencies), `RatePerGbp` = average of the ECB daily rates in the
  month, `RateDaysUsed` for audit, plus GBP = 1.0 every month (identity, so all currencies
  convert with one join). Conversion rule for the facts: **GBP = local / RatePerGbp**, using
  the month of the document date. Tests: not_null, `tests/assert_fx_rate_monthly_unique.sql`,
  and `tests/assert_every_transaction_has_fx_rate.sql` (all 4,903 transactions have a rate).
  Hand-checked: EUR Mar 2023 = 1.1339 from 23 days. Edge months: Sep 2022 = 1 day (no
  transactions then), Sep 2026 = month-to-date.
- **Not built yet:** FX monthly rate, the 4
  facts, security table, Parquet export, Power BI.
- **Q&A talking points collected so far** (use in presentation prep):
  - *Fix the cause, not only the symptom* (Vlad's own point, 18 Sep): find the data owner,
    ask for validation at entry (salary as min/max number fields + currency dropdown). The
    pipeline still defends itself because history is already dirty, vendor CRMs change
    slowly, and tests are how the problem is found. Test results grouped by team = a data
    quality report to take to the owner. Frame as partnership, not blame — in Vlad's
    words: a free-text salary box *sets people up to make mistakes*; it is a system design
    problem, not the consultant's fault.
  - *`not_null`/`unique` catch broken data; reasonableness tests catch wrong data*: e.g.
    `'£92,5k'` parses to 925,000 — plausible-looking, passes every test. Fix: range checks
    (SalaryMin ≤ SalaryMax, salary within a band per discipline).
  - *warn vs error tests*: known source problems warn and continue; broken assumptions stop
    the build.
  - *Candidate duplicates* (checked in OpenCATS source, `lib/Candidates.php`): the CRM fills
    `candidate_duplicates` **automatically** on save (`checkDuplicity`: same first + last
    name AND one of middle name / phone / email / city+address). A user then clicks Merge
    (moves activities, attachments, calendar to the old id, deletes the row) or "Remove
    duplicity warning" (different people, deletes the row). So in real OpenCATS the table
    holds **unreviewed suspects**, not confirmed merges. Our generator only makes true
    duplicates and silver auto-merges them — a simplification to state openly. Real options:
    trust the CRM rule, or merge only reviewed pairs and report the rest. Real fix is at the
    source: block the save instead of warning afterwards.
  - *Bronze all text*: one place decides types; guessing is silent and can change between
    files (day/month swap).
  - *dim_date: arithmetic vs business rules* (19 Sep): date logic varies by company, and a
    finance-owned calendar or a downloadable template is a valid source (Vlad built it in SQL
    to learn). Refinement: the arithmetic (ISO weeks, day counts) belongs in SQL, but two
    business rules sit inside it — fiscal year starts in April (`month(d) >= 4`) and England &
    Wales holidays. Q&A line: "I computed the calendar for simplicity, but the fiscal-year
    start and the holiday region are business rules. In production I'd take them from
    finance's official calendar or from configuration." (A 4-4-5 calendar can't be derived
    by formula at all — it must be ingested.) Not changing it now.
  - *Handling NULLs and unknowns is the crucial governance point* (Vlad, 19 Sep): every
    dimension has a `-1` Unknown member; facts map missing or unmatched keys to `-1`, so no
    row disappears from a visual or shows as "(Blank)", and totals always reconcile.
    `dim_stage`'s `-1` catches ANY unmapped status code, not just today's 999. Mappings
    live in reference data, not CASE statements.
  - *Storage maintenance* (19 Sep): repeated `create or replace` loads grew `oj_dw.duckdb` to
    33.5 MB for ~10 MB of data (unused space is not reclaimed). Vlad chose NOT to fix it now
    (no time). Production equivalent: a scheduled maintenance job — in Fabric, `OPTIMIZE`
    (compact small files) and `VACUUM` (remove old versions) on Delta tables.
  - *Don't derive dimensions from fact values* (Vlad's principle, 19 Sep): a dimension built
    from DISTINCT values in transactions loses members with no activity yet and turns typos
    into new members. First find the source system's own lookup table — in OpenCATS that is
    `extra_field_settings` (field type DROPDOWN, allowed values in `extra_field_options`).
    Derive from facts only as a last resort. Claude had missed this for industry and
    discipline; Vlad caught it.
  - *Rebate timing — model both, don't force one* (from Vlad's real job, 18 Sep: at his
    company finance departments can't agree whether rebates belong to the credit note's
    month or the original invoice's). Refinements: in the GL a credit note is *linked* to
    the original invoice but *posted* in the period it is issued (closed months aren't
    reopened); and it does NOT always net out within the year — FY starts 1 April, so a
    Feb invoice with an April credit note crosses the year-end. Design: two named,
    documented measures that reconcile to the same all-time total: **NFI** (credit note in
    its issue month — finance/CFO, ties to the ledger) and **NFI (attributed)** (credit note
    moved to the original invoice month — managers judging consultants). Vlad may tell the
    work story himself; don't embellish it.
- **Handling the planted problems in gold (18 Sep, after Vlad's "investigate cold" exercise).**
  Silver stays as-is (problems remain visible; tests report them). Decisions for gold:
  - Blank discipline → **`-1` "Unknown"** row in `dim_discipline` — agreed ("known practice").
  - Status 999 → **"Unknown exit"** in `dim_stage` — agreed.
  - Orphan credit notes (`CRN-299901/2`, −£10,422.65, refs `PL-099901/2` outside the real
    range) → **a `-1` "Unknown" member**, kept in firm totals so NFI reconciles to the
    ledger — Vlad: "this is what we do in our business". **He wants to discuss the details
    when we build it — raise it, don't just implement it.** Note: our plan has no placement
    *dimension* (placement is a fact), so this likely means `-1` keys on those fee rows.
  - Missing/zero fee % (PL-000819, PL-001882, PL-002652 — all invoiced, implied 19.0 / 21.5 /
    21.2%) → proposed: take fee % from the invoice + flag. **Deferred by Vlad to when we
    build `fact_placement`** — raise it then, with the 3 rows on screen. Affects booked fee
    only, not NFI.
  - dbt test thresholds (`warn_if`/`error_if`) → **rejected** as overcomplication.
  Every dimension gets a `-1` Unknown row (agreed practice).
- **Role-playing dates: option A agreed (18 Sep).** One conformed `dim_date`, each fact's
  main date active, other dates inactive + `USERELATIONSHIP()` inside specific measures.
  Vlad asked about loading the date table twice (Tabular Editor alias style); rejected for
  now because the exec page needs ONE timeline/slicer across NFI, placements and funnel,
  and "NFI attributed" is a measure decision, not a filter. Switch to a named copy
  ("Original Invoice Date") only if finance asks to slice by that date — the key is
  already in the fact, so it is additive. Q&A line prepared.
- **Gold design decision (18 Sep, agreed):** `fact_fee_transaction` carries
  `DocumentDateKey` (active relationship) and `OriginalInvoiceDateKey` (inactive, used via
  `USERELATIONSHIP()` for NFI attributed). Worked example for the demo: PL-000051 — salary
  £94,100 × 19.7% = invoice £18,537.70 (1 Feb 2023), left after 29 days (week 5 → 50%),
  credit note −£9,268.85 (15 Mar 2023), NFI £9,268.85; summing bronze would give
  £27,806.55 (3× the truth).
- **dbt lesson done (17 Sep):** model = a SELECT dbt wraps; `ref()`/`source()` build the
  dependency graph (Vlad can explain why a hardcoded table name breaks lineage, run order
  and selection); view vs table per folder; tests declared in YAML run inside `dbt build`.
- **Root layout (17 Sep):** `CLAUDE.md`, `data-rules.md`, `requirements.txt`, `.venv/`,
  `dw/`, `Misc/` (specs, CV, recruiter email, old handoff), `.vscode/settings.json` (points
  VS Code and the dbt Power User extension at `.venv`). Vlad keeps the root tidy —
  put new files in the right subfolder, not the root.
- **venv:** `OJ Project/.venv` (Python 3.12.10), created by Vlad on 17 Sep with
  `requirements.txt` installed — duckdb 1.5.5, dbt-core 1.12.3, dbt-duckdb 1.11.0, all
  verified present and absent from global Python. Ignore the "dbt 1.12.5 available" notice:
  versions are pinned on purpose this close to the interview. Vlad works in **VS Code** with a PowerShell terminal; if
  `Activate.ps1` is blocked, use `.venv\Scripts\python.exe` directly — do not change the
  execution policy.
- `OJ Project` is **not a git repo** yet. Do not `git init` without asking.
- Windows console here uses a Cyrillic code page: printing `£`/`€` from Python fails unless
  `PYTHONIOENCODING=utf-8` is set. The files are UTF-8 and fine.

---

## 5. Next steps, in order

1. ~~Vlad reviews `data-rules.md`~~ — done, v3 agreed.
2. ~~Generate the raw source exports~~ — done 16 Sep (`dw/raw/`).
3. ~~venv, packages, DuckDB lesson, bronze load~~ — all done 17 Sep.
4. ~~dbt lesson + project skeleton~~ — done 17 Sep. Next: silver (`stg_*`), then gold
   (dim_date, dims, facts, tests).
5. Export gold to Parquet, build the Power BI model and measures (Vlad leads).
6. Dashboard pages — small, clean, commercial.
7. Presentation: ~10 minutes, plus the Fabric production slide and Q&A practice.

**Power BI build method (decided 17 Sep).** **PBIP format** — Vlad creates the empty project
in Desktop (so the folder structure is Desktop's own, not guessed), then Claude writes the
TMDL/M text: tables over the gold Parquet files, relationships, hidden keys, measures and
the RLS role. Vlad builds the visuals. Tabular Editor 3 was rejected (licence). Claude
cannot click in Desktop — only text files.

**Plan agreed for Fri 18 Sep evening:** work through the data side **together** (Vlad
declined an unattended build): silver models, then gold + tests + Parquet export, then
start Power BI if time allows. Vlad expects the Power BI model itself to be quick
("select sources, one-to-many relationships, hide keys").

**Status at Thu 17 Sep, ~23:00 (Vlad wrapped up).** Done today: venv + packages, DuckDB
lesson, bronze load, modified timestamps, full `load_raw.py` walkthrough, dbt lesson, dbt
skeleton passing `dbt debug`. **Still behind on the star schema** — no silver or gold models
exist yet, and Power BI has not started.

Time left: Fri evening ~3h, Sat ~10h, Sun ~8h, Mon morning ~3h (rehearsal only). Remaining
work estimated at 14–20h, so it fits with little slack. **The critical path is Power BI,
not the warehouse.**

Cut list if Saturday evening looks tight, in this order: (1) field parameters → fixed
visuals, (2) drillthrough page → a detail table, (3) manager page → mention verbally but
keep `fact_target` in the model, (4) stories 5 and 6 → leave them in the data only.
**Never cut:** RLS, the NFI/rebate logic, the star schema, the Fabric production slide.

**Hard rule on time:** if the dashboard is not being built by Saturday, cut scope, not
rehearsal. Monday morning is for rehearsal only — no new building.
