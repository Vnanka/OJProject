# CLAUDE.md — OJ Project (Oliver James interview dashboard)

Working context for this folder. Read this first, then `data-rules.md` (v3.1, the data
plan), then ask what to work on.

---

## 1. The job

Second-stage interview for **Senior BI Analyst (Microsoft Fabric)** at **Oliver James**,
a recruitment firm.

| | |
|---|---|
| **When** | Monday 21 September 2026, 1:00 PM |
| **Where** | Globe Building, 1 New Quay Street, Manchester, M3 4BN |
| **Task** | Build a Power BI dashboard on a dataset of his choosing, present it, then Q&A |
| **Q&A covers** | Data model, KPI logic, governance, scalability, stakeholders, productionising |

Brief, job spec and company research: **`Misc/CLAUDE_1.md`** (previous session's handoff,
still accurate, do not delete). Source documents in **`Misc/`**: `1.pdf` (recruiter email),
`Senior BI Analyst - OJA (1).docx` (job spec), `Vladislavs Nanaks_CV_BI_D V4.docx` (CV).

---

## 2. How to work with Vlad

- **Plain, simple English.** English is his second language. Explain like he is a junior
  data engineer: short sentences, no unexplained jargon. Name a concept, then define it in
  one line (grain, idempotent, conformed dimension, role-playing dimension).
- **One thing at a time.** Propose → get agreement → do it. Show prerequisites and open
  decisions *before* building. He has stopped a build twice for skipping this.
- **Small bursts. "A couple" means about 5, not 20.** Build the smallest useful set, show it,
  extend on his word. Name what was left out and where it is written down. A big batch is
  either accepted blindly or mostly deleted — both waste his time, and he reviews everything.
- **Show real command output.** Never claim something ran or worked without pasting it.
- **Never invent his work history.** CV facts only. Synthetic *demo* data is fine and is
  always labelled synthetic.
- **He owns Power BI.** It is his strongest skill — advise on what the model should expose,
  do not design the report for him.
- **He is learning DuckDB and dbt here.** Bridge from what he knows: raw → staging → marts
  is bronze → silver → gold; a dbt model is a SELECT and dbt writes the CREATE around it;
  dbt tests are data quality gates that run *before* the report.
- Claude writes the code here and explains it; Vlad reviews and decides. (The "Vlad types
  all the Python" rule belongs to the **lol-data-warehouse** repo, not this one.)
- Keep the root tidy — new files go in the right subfolder.

---

## 3. The design

**Dataset.** Not League of Legends (no commercial meaning for a recruitment panel).
Synthetic recruitment data shaped like Oliver James, plus real reference data from public
APIs. The LoL warehouse is Q&A evidence of how he works, nothing more.

**Architecture — a small local warehouse:**

```
generated CSV exports     BRONZE          SILVER           GOLD              Power BI
+ real API data       -> DuckDB raw.* -> dbt stg_* views -> dim_/fact_ tables -> import
(two "source systems")   loaded as text   rename, cast      + dbt tests          Parquet
                                          standardise
```

- Business logic lives in **SQL in the warehouse**, not Power Query — matches the job spec
  ("consolidate SQL and business logic into governed datasets").
- Power BI reads **Parquet files** written by `export_parquet.py`. Chosen over a live DuckDB
  connection because a file cannot fail on the day.
- Cloud (Fabric / Azure SQL) is **deliberately not built** — one architecture slide shows how
  this becomes production. He talks about Fabric from real job experience.

**Gold: 5 facts, 8 dimensions, 1 security table, 1 FX helper.**

| Fact | Grain |
|---|---|
| `fact_Application` | one application (candidate × vacancy) — accumulating snapshot |
| `fact_ApplicationLine` | one status change — the event log |
| `fact_Placement` | one placement |
| `fact_FeeTransaction` | one invoice **or** credit note |
| `fact_Target` | one consultant per month (NFI target, GBP) |

Dimensions: `dim_Date`, `dim_Consultant`, `dim_Client`, `dim_Vacancy`, `dim_Stage`,
`dim_Industry`, `dim_Discipline`, `dim_Office`. Plus `dim_FxRateMonthly` (helper, not
exported) and `sec_UserTeam` (RLS access list).

**Key design choices:**

- **The quirk: rebates.** A candidate leaving inside the 12-week guarantee triggers a credit
  note refunding part of the fee. So booked fee ≠ invoiced ≠ **Net Fee Income**. NFI is how
  Oliver James actually reports growth.
- **`dim_Date` is role-playing**: one conformed table; each fact's main date is the active
  relationship, other dates are inactive + `USERELATIONSHIP()`. Fiscal year starts **1 April**;
  ISO weeks, Monday start. Built in dbt, not `CALENDAR()`, so there is one source of truth.
- **Star, not snowflake.** Facts carry EVERY dimension key directly; dims never point at each
  other. Reasons: filters flow one step, field parameters need direct relationships, the
  lookup cost is paid once at build time. `dim_Client`/`dim_Vacancy` keep industry and
  discipline NAMES as text for convenience only.
- **Industry ≠ discipline.** Industry = what the client is; discipline = what the job is
  (they repeat across all industries). Two separate dimensions.
- **`OfficeKey` sits on fact rows**, fixed at build time, so a consultant moving office does
  not rewrite history. Avoids SCD Type 2.
- **No candidate dimension** — not needed for these KPIs, and it is a GDPR point.
- **Perm only.** Contract/interim invoicing cut as too much work.
- **Multi-currency with real ECB rates.** GBP conversion happens **in dbt**, so every report
  uses the same number. Frankfurter API (`api.frankfurter.dev/v1`, no key) covers all seven
  office currencies. No weekend/holiday rates, so we use a **monthly average** — what finance
  teams do anyway. Rule: **GBP = local ÷ RatePerGbp**, at the month of the document date.

**Source shape.** The CRM export copies the table/column names, status codes and messy value
formats of **OpenCATS** (open-source recruitment CRM). Industry, discipline and work
arrangement are plain custom columns — Vlad rejected OpenCATS `extra_field` (EAV) as
overcomplication (Q&A point only). Placements, fees and targets come from a separate finance
export. Real data used: ECB rates, gov.uk bank holidays, and OJ's real industry, discipline
and office lists. Everything transactional is generated. Full detail: `data-rules.md`.

**Report plan (not final).** 1–2 executive pages + a drillthrough detail page; time series;
KPI cards for cohort conversion rates; **field parameters** to switch the grouping
(industry / office / discipline / team). **Two audiences:** executives (whole firm) and team
managers (own team, consultant ranking, NFI vs target). **Row-level security** was a known
gap from his first interview and he wants to show he has learned it: dynamic RLS at team
level, demoed with Desktop "View as".

---

## 4. Standards and rules

**Naming.** Models: **lowercase layer prefix + PascalCase** (`stg_JobOrder`, `dim_Date`,
`fact_Application`). **Bronze keeps source-shaped names** (`raw.crm_user`) because it mirrors
the source systems. Silver columns are **PascalCase** (`UserId`, `StartDate`, `ModifiedAt`).
Singular tests keep `assert_*`.

**Gold column standard (Vlad's decision, 20 Sep) — set in the WAREHOUSE, never in a report:**

- **Keys and numeric fact columns** (what measures are built on) → **all lowercase, no
  separator**: `consultantkey`, `applicationid`, `netamountgbp`, `reachedinterview`.
- **Attributes people see** → **readable English with spaces**: `Client Industry`,
  `Office Name`, `Fiscal Year`, `Work Arrangement`.
- **Duplicated concepts are disambiguated here**, not in the report: `Client Industry` vs
  `Industry`; `Client City` / `Office City` / `Vacancy City`; `Vacancy Discipline` vs
  `Discipline`; `Consultant Office` vs `Office Name`; `Office Currency` /
  `Placement Currency` / `Document Currency`.
- **Why in gold:** with several reports on one warehouse, renaming in each model means every
  author invents their own names and the standard dies. One name, defined once, inherited by
  everyone. (Q&A point.)
- **How it is applied:** each gold model keeps its original SQL and gets a **rename layer at
  the end** — `select OfficeKey as officekey, OfficeName as "Office Name" ... from ( <original
  model> ) as renamed`. Done 20 Sep across all 14 exported models.
  **Known simplification (accepted, no time):** the *inside* of each model still uses
  PascalCase, because silver feeds it. The standard is applied at the output of gold only;
  nothing downstream sees the inner names. `dim_FxRateMonthly` is also left PascalCase — it is
  a build-time helper and is not exported.
- dbt tests on a column whose name has a space need **`quote: true`** in `schema.yml`.

**Bronze.** Every column VARCHAR. One place decides types (silver); a loader that guesses too
would be a second source of truth that can disagree. `create or replace` = idempotent.

**Silver.** One bronze table per model; rename, cast, standardise only. No joins, no business
logic, no derived flags. `cast` for IDs and dates so bad data fails loudly; `try_cast` only
where bad values are expected (free-text salary), then count the NULLs with a test. Every
model starts `with source as (select * from {{ source(...) }})`. Audit column always
`ModifiedAt`. **One agreed exception to "no joins":** applying the CRM's own duplicate-merge
list in `stg_Candidate`, `stg_StatusHistory` and `stg_Placements`.

**Tests.** Planted source problems → `severity: warn` (reported, pipeline continues, gold
decides how to show them). Broken assumptions → `error`. Gold tests are all `error`. dbt 1.12
syntax: `data_tests:` with `arguments:` / `config:`. Test thresholds (`warn_if`/`error_if`)
were rejected as overcomplication.

**Vlad's rules (he corrected Claude on each of these):**

- **No dbt seeds — one ingestion path for everything.** Reference data the business maintains
  is a source file like any other: file → bronze → silver → gold. Seeds are technical debt
  and fragmentation.
- **Don't derive dimensions from fact values.** A dimension built from DISTINCT transaction
  values loses members with no activity and turns typos into members. Find the source
  system's own lookup table first (in OpenCATS: `extra_field_settings` / `extra_field_options`).
- **No business-mapping CASE statements.** Mappings like "status code → funnel stage" are
  reference data, not code. `CASE` only when unavoidable. (Calendar arithmetic is computation,
  not a business mapping, so it stays SQL. Fixed CRM system codes in a filter are fine.)
- **Never change a source to fit the model.** Bronze lands the source exactly as delivered;
  silver CHOOSES which columns to use.
- **Blank vs `-1`.** `-1` "Unknown" ONLY for a value that should exist but is missing or
  unrecognised. An event that simply HASN'T HAPPENED is **blank (NULL)** — "that's how most
  CRMs work". Every dimension has a `-1` row.
- **Don't patch data to make the numbers match.** Report it, investigate the cause, fix at
  the source — not in the model.

---

## 5. What is built

**Everything through to Parquet. Gold is complete.** Verified by a full rebuild from deleted
warehouse on 19 Sep: `dbt build` → **32 models, 160 tests, PASS=186 WARN=6 ERROR=0** in 3.4s.
The 6 warnings are exactly the planted problems.

```
dw/raw/<source>/                14 MB, 17 files: crm, finance, security, reference, api
dw/src/generate/generate_sources.py   synthetic CRM + finance + security (fixed seed)
dw/src/extract/fetch_reference.py     real ECB rates + gov.uk bank holidays
dw/src/load/load_raw.py               bronze: 17 tables, all VARCHAR
dw/dbt/                               17 silver views, 15 gold tables, 11 singular tests
dw/src/export/export_parquet.py       14 Parquet files for Power BI
dw/export/parquet/                    4.0 MB, 232,110 rows (gitignored)
```

**Pipeline, in order** (each step idempotent; nothing runs automatically):

```
python dw/src/load/load_raw.py
cd dw/dbt && dbt build --profiles-dir .
python dw/src/export/export_parquet.py
```

`dbt build` does **not** refresh the Parquet files — that trap is worth remembering. Do not
run `fetch_reference.py` before the interview: it pulls live rates and would change every GBP
figure. `generate_sources.py` is reproducible (fixed seed; all 17 files verified md5-identical
after a regeneration).

**Verified numbers** (end-to-end audit, 19 Sep, 90 checks, all passed):

- Row counts match at every layer. Only intentional drop: 46,934 → 46,434 candidates
  (500 merged duplicates).
- Money reconciles **CSV → silver → gold → Parquet** to the penny in all 7 currencies.
  All-time NFI **£69,971,251.44**.
- CRM and finance agree: **4,714 placed applications = 4,714 placements**.
- No dimension key is ever NULL in any fact. Unknown (`-1`) usage: Application 244,
  ApplicationLine 560, Placement 20, FeeTransaction 26, Target 0.
- All fact dates land inside `dim_Date`.

**The gold tables:**

- **`dim_Date`** — 1 Apr 2022 – 31 Mar 2028 (2,192 days + `-1`). `DateKey` = yyyymmdd int.
  England & Wales bank holidays, `IsWorkingDay`, ISO week columns, fiscal columns
  (`FiscalYear` FY26/27, `FiscalPeriod` P01, `FiscalQuarter` FQ1, `FiscalWeekNumber`,
  `FiscalWeekOfQuarter`, `FiscalWeekOfPeriod`). Week 1 of a period/quarter = the Mon–Sun week
  containing its 1st day, so boundary weeks split. Sort-by columns for Power BI:
  MonthName→MonthNumber, YearMonth→YearMonthKey, FiscalPeriod→FiscalYearPeriodKey. Vlad
  rejected a 4-4-5 calendar (5-week periods distort period-on-period stats).
- **`dim_Office`** (generated key), **`dim_Industry`** (key = SubSectorId),
  **`dim_Discipline`** (key = DisciplineId), **`dim_Stage`** (key = status code; a plain join
  of `stg_Status` + `stg_FunnelStage`; `-1` = "Unknown exit", catches ANY unmapped code).
- **`dim_Consultant`** (key UserId; ManagerKey/Name; `IsManager` 24 = one per team;
  `IsActive` 164 = matches generator headcount; current Team/Office for RLS).
- **`dim_Client`** (key CompanyId), **`dim_Vacancy`** (key JobOrderId; blank discipline →
  'Unknown'; salary in local currency + `SalaryCurrency`).
- **`dim_FxRateMonthly`** — 343 rows (49 months × 7 currencies), `RatePerGbp` = monthly
  average of ECB daily rates, `RateDaysUsed` for audit, GBP = 1.0 so one join covers every
  currency. Not exported to Power BI (conversion already done in dbt).
- **`fact_Application`** — 59,678 rows. Milestones = FIRST time each stage was reached, found
  by fixed CRM status codes (400 Submitted / 500 Interviewing / 600 Offered / 800 Placed);
  exit = any other code, so 999 still counts as an exit. `ApplicationId` = candidate × 100000
  + job as bigint, stable across rebuilds. Milestone dates blank when not reached. Credit to
  the job's `recruiter`; office from the job. All data from CRM go-live 1 Oct 2022 is kept —
  FY22/23 is a partial 6-month year, label it when comparing. Cohort rates match the
  generator (CV→interview 33.8 / 35.3 / 35.9% for FY23/24–25/26). 595 open, 20 unknown exits.
- **`fact_ApplicationLine`** — 145,619 rows, one status change. Key = the CRM's own
  `StatusHistoryId`. `dim_Stage` plays two roles: `StatusToKey` active, `StatusFromKey`
  inactive (`status_from` = 0 on a first event, and `dim_Stage` already has a 0 "No Status"
  member). `DaysInPreviousStage` via `lag`, blank on the first event (59,678 blanks = one per
  application). `ApplicationId` is a plain column — **no fact-to-fact relationship**.
- **`fact_Placement`** — 4,714 rows from finance. Consultant and office from finance (matched
  CRM 100%). `PlacedDateKey` active; Start/Leave inactive and blank when not happened. Money
  all **DECIMAL(18,2)** at the monthly rate of the placed month. `IsFallOff` = leave date
  recorded (finance only records leaves inside the guarantee), 415 fall-offs. `DaysToFill`
  avg 37.5. The 3 missing/zero fee % rows are **not patched**.
- **`fact_FeeTransaction`** — 4,903 rows (4,489 INV + 414 CRN). Signed `NetAmountLocal` /
  `NetAmountGbp` at the rate of the document's own month. `DocumentDateKey` active (ledger
  NFI); `OriginalInvoiceDateKey` inactive (attributed NFI). Keys taken from `fact_Placement`
  so a document and its placement always agree. The 2 orphan credit notes are kept with all
  placement-based keys `-1`.
- **`fact_Target`** — 6,143 rows (211 consultants, Apr 2023 – Sep 2026), month grain,
  `DateKey` = 1st of month. Office = consultant's current office (targets file has none).
  **No client/industry/discipline/vacancy columns** by design. Firm NFI vs target: FY23/24
  98.0%, FY24/25 98.3%, FY25/26 95.8%, FY26/27 100.7% — the last is month-to-date against a
  full-month target, so exclude or label MTD. Filter targets by whole months only.
- **`sec_UserTeam`** — 122 rows, one per email × team. **No relationship in Power BI.** One
  dynamic RLS role filters `dim_Consultant`:
  `[Team] IN CALCULATETABLE(VALUES(sec_UserTeam[Team]), sec_UserTeam[Email] = USERPRINCIPALNAME())`,
  flowing to all 5 facts via ConsultantKey. CEO and CFO also see team "Unknown" (so refunds
  that can't be tied to a team stay in firm totals); directors and managers do not. Demo
  scopes: CEO/CFO 25 teams, Manchester director 4, manager `lucas.taylor@example.com` 1.
  Demo via Desktop → Modeling → View as → Other user. Other dims' *lists* are not filtered,
  only the numbers — normal.

**The planted problems and how gold shows them** (all still present after rebuild):

| Problem | Count | Handling |
|---|---|---|
| Blank discipline on jobs | 30 | `-1` "Unknown" in `dim_Discipline` |
| Unparseable salary ('Competitive') | 356 | `try_cast` → NULL, counted by a test |
| Status code 999 | 20 | `-1` "Unknown exit" in `dim_Stage` |
| Blank / zero fee % | 2 / 1 | left as recorded, reported, **not patched** |
| Orphan credit notes (−£10,422.65) | 2 | kept with `-1` keys so NFI ties to the ledger |
| Duplicate candidates | 500 | merged in silver before counting |

---

## 6. Q&A talking points

**Governance and data quality**

- **Handling NULLs and unknowns is the crucial point.** Every dimension has a `-1` member;
  facts map missing or unmatched keys to it, so no row disappears from a visual, nothing
  shows as "(Blank)", and totals always reconcile.
- **Fix the cause, not only the symptom.** Find the data owner; ask for validation at entry
  (salary as min/max number fields + currency dropdown). The pipeline still defends itself,
  because history is already dirty, vendor CRMs change slowly, and tests are how the problem
  gets found. Test results grouped by team = a data quality report to take to the owner.
  Frame as partnership, not blame: a free-text salary box *sets people up to make mistakes*.
- **`not_null`/`unique` catch broken data; reasonableness tests catch wrong data.** `'£92,5k'`
  parses to 925,000 — plausible, passes every test. Fix: range checks (SalaryMin ≤ SalaryMax,
  salary within a band per discipline).
- **warn vs error.** Known source problems warn and continue; broken assumptions stop the build.
- **Don't patch data to make numbers match.** The 3 bad fee % rows could be back-filled from
  their invoices; Vlad chose to leave them and investigate first.
- **Bronze all text — Vlad's argument, in his words (21 Sep, rehearsed):** *"In bronze I load
  everything as VARCHAR to avoid any interpretation by the system — including variations in
  date format. In silver I assign data types explicitly, to get consistency and to enforce
  data quality. The regex in `stg_JobOrder` strips the variations people type into the salary
  box — 'k' for thousands, a min–max range, thousands separators. And arguably, if something
  like this happens, I would go to the source system and improve the input itself: on the job
  advert form, two fields for salary min and max, with input rules so only numbers can be
  typed."*
  **Vlad's own caveat, and the stronger version of the answer (21 Sep):** he does not accept
  all-text landing as a universal rule — *"personally I would rely on a system and not load
  everything as varchar; maybe it is useful in the scope of this project."* Claude proposed
  the pattern; Vlad is right that it is source-dependent. The defensible line is the
  conditional one, not the dogmatic one:
  > *"The sources here are CSV exports, which carry no types — so something has to infer
  > them, and I'd rather that decision be explicit and in one place than implicit in a
  > loader. If the source were a database or a Delta table with a schema, I'd take the
  > source's types; re-deriving them would be pointless work."*
  Worth it for schemaless files (CSV, third-party exports you don't control); unnecessary
  ceremony for a database, Parquet/Delta, or an API with a real schema.
  **This is a supporting detail, not a headline.** Only raise it if asked "why is bronze all
  text?" The headline is the rebate/NFI logic and the star schema.
  Concrete example if needed: `03/04/2026` is 3 April in the UK and 4 March in the US; a
  guessing loader can guess differently on two files and nobody notices. Our finance dates
  are parsed with an explicit `strptime('%d/%m/%Y')`. Cost of the pattern: an extra cast
  layer and more code. Screenshot evidence: `raw.crm_joborder` (17 columns, all VARCHAR) next
  to `dw/dbt/models/silver/stg_JobOrder.sql`.
- **Candidate duplicates** (checked in OpenCATS source, `lib/Candidates.php`): the CRM fills
  `candidate_duplicates` automatically on save (same first + last name AND one of middle name
  / phone / email / city+address). A user then clicks Merge or "Remove duplicity warning". So
  in real OpenCATS the table holds **unreviewed suspects**, not confirmed merges. Our
  generator makes only true duplicates and silver auto-merges them — a simplification to
  state openly. Real fix is at the source: block the save instead of warning afterwards.

**Modelling**

- **Rebate timing — model both, don't force one** (from Vlad's real job, where finance
  departments can't agree). In the GL a credit note is *linked* to the original invoice but
  *posted* in the period it is issued (closed months aren't reopened), and it does not always
  net out within the year — FY starts 1 April, so a Feb invoice with an April credit note
  crosses the year-end. Two named measures that reconcile to the same all-time total:
  **NFI** (credit note in its issue month — finance/CFO, ties to the ledger) and **NFI
  (attributed)** (moved to the original invoice month — managers judging consultants).

  | FY | Ledger | Attributed | Diff |
  |---|---:|---:|---:|
  | FY22/23 | 3,475,563.70 | 3,361,320.13 | 114,243.57 |
  | FY23/24 | 16,023,436.75 | 15,988,244.23 | 35,192.52 |
  | FY24/25 | 17,967,823.00 | 18,058,307.98 | −90,484.98 |
  | FY25/26 | 20,614,741.49 | 20,551,425.18 | 63,316.31 |
  | FY26/27 | 11,889,686.50 | 12,022,376.57 | −132,690.07 |
  | **All time** | **69,971,251.44** | **69,971,251.44** | **0.00** |

  Every year differs; the total ties to the penny.
- **Worked example for the demo: PL-000051.** Salary £94,100 × 19.7% = invoice £18,537.70
  (1 Feb 2023); candidate left after 29 days (week 5 → 50%); credit note −£9,268.85
  (15 Mar 2023); NFI £9,268.85. Summing bronze would give £27,806.55 — 3× the truth.
- **Role-playing dates: one conformed `dim_Date`** (option A). Vlad asked about loading the
  date table twice (Tabular Editor alias style); rejected because the exec page needs ONE
  timeline across NFI, placements and funnel, and "NFI attributed" is a measure decision, not
  a filter. Switch to a named copy only if finance asks to slice by that date — the key is
  already on the fact, so it is additive.
- **Header + line, two grains.** `fact_Application` answers cohort questions ("how many
  reached interview?"); `fact_ApplicationLine` answers activity and speed questions. Only the
  line fact can show **where the pipeline slows down**: avg days in the stage being left —
  Submitted 7.9, **Interviewing 14.2**, Offered 5.3.
- **`dim_Date`: arithmetic vs business rules.** ISO weeks and day counts are computation and
  belong in SQL, but two business rules sit inside: fiscal year starts in April, and the
  holiday region is England & Wales. Line: *"I computed the calendar for simplicity, but the
  fiscal-year start and holiday region are business rules — in production I'd take them from
  finance's official calendar or from configuration."* A 4-4-5 calendar can't be derived by
  formula at all; it must be ingested.
- **Fall-off maturity bias:** 8.8% over ALL placements vs 9.6% over matured ones. Recent
  placements are still inside the 12-week window, so recent months always look better than
  they will end up.

**Engineering and production**

- **No orchestrator here, deliberately.** Locally these are three idempotent steps run in
  order. In Fabric this is a **Data Pipeline**: scheduled, each activity depending on the one
  before, so if `dbt build` fails the export never runs and the report keeps yesterday's good
  data instead of getting bad data. Plus alerting on failure and a dev/test/prod split.
- **Why CSV in raw and not Parquet?** You don't choose a source system's format; `dw/raw/` is
  the landing layer, the files exactly as delivered. Parquet is typed, so writing raw as
  Parquet would force type decisions at landing — the guessing we designed out.
- **In Fabric, every table is Delta Lake** = Parquet files + a `_delta_log`. The log gives
  ACID transactions, time travel, and updates/deletes, which plain Parquet cannot. Warehouse
  = T-SQL only, files hidden; Lakehouse = `Files/` for landing + `Tables/` for Delta. Power BI
  can then use **Direct Lake** (reads the Parquet straight into the model, no refresh).
  The layers don't change — only the storage format and the engine.
- **Reproducibility.** Fixed seed: regenerating all 17 source files gives byte-identical
  output (md5-verified). The whole warehouse rebuilds from deleted in 3.4 seconds.
- **Storage maintenance.** Repeated `create or replace` grew the DuckDB file to 33.5 MB for
  ~10 MB of data; a fresh rebuild is 11.0 MB (unused space is not reclaimed). Production
  equivalent: a scheduled maintenance job — in Fabric, `OPTIMIZE` (compact small files) and
  `VACUUM` (remove old versions) on Delta tables.
- **Parquet decimals.** `SalaryGbp` shows as INT64 in the raw Parquet schema — that is the
  *physical* type; Parquet stores an exact decimal as an integer plus a DECIMAL(18,2)
  annotation. Reading it back gives DECIMAL(18,2). Nothing is lost to floating point.

---

## 7. Current state — the build is FINISHED (early Mon 21 Sep, ~02:00)

**Everything is built and verified. What remains is the presentation and rehearsal.**

**The report: `OJ Report/` (PBIP), three pages.**

| Page | Question it answers | Visuals |
|---|---|---|
| **Performance** | Are we growing, and are we on plan? | 5 KPI cards (Income · Income vs Target % · Placements · CV to Interview % · Avg Days to Fill), Income vs target combo by fiscal period, metric trend over time, 4 pipeline charts (office/team/consultant, industry, discipline, work arrangement), 4 slicers |
| **Team & Consultant** | Who is performing, who needs help? | consultant table vs target, avg days in stage (bottleneck), days to fill by team, income vs target by period, 3 cards. **Demo RLS here.** |
| **Detail** | Show me the actual applications | drillthrough, 20-column table: the job → candidate → responsible consultant → measures |

**20 measures, all used** (audited). Naming is business language, set in the warehouse:
`CVs Sent`, `Reached Interview`, `Reached Offer`, `Placed`, `Did Not Progress`, `Open`,
`Income`, `Target Income`, `Income vs Target %`, `Placements`, `CV to Interview %`,
`% of CVs Sent`, `Avg Days to Fill`, `Avg Days in Stage`, `Fall-off Rate`,
`Avg Days to Interview/Offer/Placed`, `Selected Metric`, `Matches Metric`.

**`Metric` field parameter** drives every pipeline chart from one slicer (6 measures).
`Selected Metric` / `Matches Metric` read it with `SELECTEDVALUE('Metric'[Metric Order])`.
**Gotcha:** a field parameter's label column is a COMPOSITE KEY (grouped by its Fields
column) — `SELECTEDVALUE` on the label raises a composite-key error. Switch on the Order
column instead; it also survives renaming the labels.

**RLS BUILT AND VERIFIED.** Role `Team Access` on `dim_Consultant`:
`[Team] IN CALCULATETABLE(VALUES(sec_UserTeam[Team]), sec_UserTeam[Email] = USERPRINCIPALNAME())`.
Proven by evaluating the same filter per user: CEO 25 teams £69,971,251 · UK & Ireland
director 10 teams £25,799,378 · Manchester director 4 teams £8,455,367 · manager
`lucas.taylor@example.com` 1 team £2,581,276. Each level a clean subset of the one above.
Desktop's own impersonation (`EffectiveUserName`) does NOT work here — the emails are
synthetic and Windows rejects them; demo with **Modeling → View as → Other user**.

**Model polished for defensibility (Vlad's call):** every fact's numeric columns and keys are
hidden, so **the only way to get a number is through a named measure** (strong governance
line). Deleted the unused `Grouping` field parameter and the orphaned `Metric Date` measure;
hid `sec_UserTeam` entirely and the `_Measures[Value]` dummy column. Unused *dimension*
attributes are fine and defensible — a dimension exists so people can answer tomorrow's
question without a model change.

**Theme:** `OJ Report/theme/OliverJames.json` — OJ website colours, fonts 16/10/8
(titles/values/legends), drop shadow. **Lesson:** theme property names must match exactly
what Desktop writes. Format one visual by hand, read its JSON, copy it into the theme.
(`dropShadow` needs `shadowDistance`, which is easy to miss.)

**`my-contribution.md`** — the record of Vlad's decisions, the work he did, the technical
debt accepted knowingly, and the "how long would this take normally" estimate (5–8 weeks of
effort vs ~25–30 hours). Written 21 Sep.

**Working with the Power BI MCP plugin (`powerbi-authoring`)** — used heavily on 20–21 Sep:
- `ConnectFolder` opens the PBIP semantic model offline; `ExportToTmdlFolder` saves. A
  successful parse is itself a test that Desktop will open the file.
- With Desktop OPEN, `ListLocalInstances` + `Connect` gives a live connection and **DAX
  queries** — that is how every measure was verified against the warehouse before Vlad saw it.
- **DAX does not run on an offline folder connection.**
- **ONE WRITER AT A TIME.** Desktop rewrites every file on save. Measures created in the live
  model are lost if Desktop closes without saving. Edit files only with Desktop closed.
- **Rename does NOT cascade.** Renaming a measure leaves `[OldName]` inside dependent measures
  AND breaks every visual that referenced it. After any rename, grep the model *and* the
  report. (Caught this twice: NFI → Income, Applications → CVs Sent.)
- A VS Code window with a `.tmdl` open can lock the folder and fail an export.
- Validation scripts live in Claude's scratchpad: `check_model.py` (structure, table-vs-Parquet
  columns, relationship integrity against real data, hygiene) and `usage.py` (what the report
  actually uses). Both currently clean.

**Preserving Vlad's work:** he edits positions, sizes and slicer formatting in Desktop.
Any file edit must touch **names only** — never the `position` block or `visualContainerObjects`
he has set. Snapshot positions before and diff after; it has been verified each time.

**→ The Sunday work plan was `dashboard-plan.md` (now largely done).**

**Power BI model BUILT (late 19 / early 20 Sep).** PBIP project at `OJ Report/` (Vlad created
it in Desktop; Claude wrote the TMDL). State, validated end to end:
- **14 tables** over the Parquet files, each matching its file column for column. M query:
  `Parquet.Document(File.Contents("<abs path>"))`.
- **35 relationships, 33 active + 2 inactive** (`fact_FeeTransaction.OriginalInvoiceDateKey`
  → attributed NFI; `fact_ApplicationLine.StatusFromKey` → the bottleneck chart). All
  many-to-one, single direction. **Checked against the real data: every dim key unique and
  not null, ZERO orphan fact rows** — no blank rows in any visual.
- Date relationships deliberately cut from 11 to 6 (**Vlad's rule, 19 Sep: build only what we
  use**). `fact_Application` = SubmittedDateKey only (cohort); activity comes from
  `fact_ApplicationLine.EventDateKey`. Dropped columns stay in the tables, so adding one back
  is a one-line change.
- **55 key columns hidden**; `summarizeBy: none` on all keys, durations and percentages —
  only money and 0/1 flags are summable, each marked `SummarizationSetBy = User` so Desktop
  stops re-guessing.
- **Money is Fixed Decimal end to end.** A TMDL-only edit reverts on refresh, because the
  mashup delivers the Parquet decimal as a double. Fix that holds: a `Currency.Type` step in
  the M query (`fact_FeeTransaction`, `fact_Placement`, `fact_Target`, `dim_Vacancy`).
- **Auto date/time OFF** (`__PBI_TimeIntelligenceEnabled = 0`, 7 hidden tables + their
  variations and relationships removed). Q&A line: one conformed `dim_Date` with the fiscal
  calendar; auto date/time would add a hidden calendar-year table per date column = a second
  version of the truth.
- Validation script (Claude's scratchpad `check_model.py`): structure, table-vs-Parquet
  columns, relationship integrity against real data, hygiene. **Currently 0 failures,
  0 warnings.**

**Editing TMDL by hand — three traps learned the hard way (19–20 Sep):**
1. **Desktop is the authority.** It rewrites every file on save and normalises syntax
   (`isHidden: true` → bare `isHidden`). Only edit with Desktop closed, and re-read files
   afterwards rather than trusting an earlier read.
2. **Never insert a property without checking it exists.** Claude added a second
   `formatString` to 10 columns; TMDL forbids duplicates and **Desktop refused to open the
   whole project** (`DuplicatedProperty`). Always scan every object for repeated properties
   before saying a file is ready.
3. **Auto-detected relationships are guesses.** Desktop invented
   `fact_Application.PlacedDateKey → dim_Date` — plausible and wrong (it must be
   `SubmittedDateKey`). Worth turning off "Autodetect new relationships after data is loaded".

**Still to do: ONLY the presentation and rehearsal.** No more building — the interview is at
1:00 PM on Mon 21 Sep.

**The story the dashboard tells** (real, from the data — use it as the spine of the talk):

| | FY23/24 | FY24/25 | FY25/26 |
|---|---|---|---|
| Income | £16.0m | £18.0m | £20.6m |
| vs Target | 98.0% | 98.3% | **95.8%** |
| CVs sent | 13,978 | 14,811 | 16,639 |
| CV→Interview | 33.8% | 35.3% | 35.9% |
| Days to fill | 37.5 | 38.0 | 37.9 |

> *"Income grows 13% a year, but by putting more CVs in the top of the funnel, not by
> converting better. Conversion is flat, time-to-fill is flat, and the gap to target is
> widening. Growth is coming from volume, not efficiency."*

Then the operational follow-up, which only the line fact can answer: **an application waits
14.2 days at interview stage against 7.9 at CV review.** That is where the time goes.

Other numbers ready to quote: 91% of applications do not place (normal — 1 in 12 CVs becomes
a placement); 2 applications are both placed and exited (merged duplicate candidates — good
answer if someone adds Placed + Did Not Progress + Open and gets 2 too many).

**Waiting for Vlad's "go": a document of HIS input** — what he decided and contributed, for
the presentation. Ask first: Markdown in the repo, or Word? Source material: §4's rules
(every one of them is a Claude correction he caught), his judgement calls (rebate timing from
his real job, rejecting 4-4-5, rejecting EAV, rejecting seeds, scope cuts, `-1` unknowns,
"investigate before patching"), and his insistence on understanding each piece. Only facts
from the project and his CV — never embellish.

**Presentation cautions (Claude's honest assessment, Vlad asked for it):**

1. Be open that AI wrote much of the code: "I designed and decided; AI sped up the
   implementation; I reviewed and can explain every part." Anything he can't yet explain:
   practise it or leave it out.
2. The data is synthetic and the six stories were **planted** — present them as "patterns I
   built in to show the dashboard can surface them", never as discoveries.
3. The dashboard must be excellent — the panel sees it first; the warehouse is the Q&A
   strength.

**Time left: Mon 21 Sep morning only. Interview 1:00 PM.** Nothing on the old cut list was
cut — field parameters, the drillthrough page, the manager page and RLS all got built.
**Do not build anything else.** If Claude proposes a model or report change this morning,
push back: the remaining hours belong to rehearsal.

**Uncommitted at 02:00 Mon:** 19 files (the model polish, the page rename, deleted
`Grouping.tmdl`, `my-contribution.md`). Vlad commits and pushes himself.

---

## 8. Environment

- **venv:** `OJ Project/.venv` (Python 3.12.10) — duckdb 1.5.5, dbt-core 1.12.3,
  dbt-duckdb 1.11.0. Versions are pinned on purpose this close to the interview; ignore the
  "dbt 1.12.5 available" notice. Vlad works in **VS Code** with a PowerShell terminal; if
  `Activate.ps1` is blocked use `.venv\Scripts\python.exe` directly — **do not change the
  execution policy**.
- **dbt commands** run from `dw/dbt` with `--profiles-dir .`. dbt writes to schema `main`;
  bronze stays in `raw`.
- **Root layout:** `CLAUDE.md`, `data-rules.md`, `requirements.txt`, `.venv/`, `dw/`, `Misc/`,
  `.vscode/settings.json` (points VS Code and the dbt Power User extension at `.venv`).
- **Git:** private repo **https://github.com/Vnanka/OJProject**, branch `main`. `.gitignore`
  excludes `.venv/`, the `.duckdb` warehouse, `dw/export/`, dbt `target/`/`logs/`/`.user.yml`,
  and `Misc/*` except `Misc/CLAUDE_1.md` — **CV, recruiter email and job spec never go to
  GitHub, even private**. `dw/raw/` IS committed (Vlad's choice). **Commit only when Vlad
  asks; he pushes himself.** LF→CRLF warnings are harmless. Git on Windows
  (`core.ignorecase=true`) misses capital-only renames: fix with `git rm -r --cached <dir>`
  then `git add <dir>`.
- Windows console here uses a Cyrillic code page: printing `£`/`€` from Python fails unless
  `PYTHONUTF8=1` is set. The files themselves are UTF-8 and fine.
