# What I decided and built — OJ recruitment dashboard

My own record of the design decisions and the work, for the interview.
Everything here is factual and checkable in the repo.

---

## 1. How the work was done

AI-assisted development. I designed the architecture, made every design decision, reviewed
the output and corrected it where it was wrong. The AI wrote most of the SQL, Python and
TMDL. I can explain every part of it.

**Why this is the honest framing:** the value I add is the data model and the business
logic, not typing CTEs. In under a week of evenings, AI let me spend my time on grain,
conformed dimensions, KPI definitions and governance instead of syntax. In a normal
engagement I would spend far more time polishing each script — see §5 on the technical debt
I accepted knowingly.

---

## 2. Design decisions I made

**The dataset and the story**

- **Rejected my own League of Legends warehouse** as the demo dataset — it has no commercial
  meaning for a recruitment panel. Chose synthetic recruitment data shaped like Oliver James,
  with real reference data (ECB exchange rates, gov.uk bank holidays, OJ's real office,
  industry and discipline lists).
- **Chose a real warehouse over "model a spreadsheet"** — generated source exports → DuckDB
  bronze → dbt silver → dbt gold star schema → Parquet → Power BI. Business logic lives in
  SQL in the warehouse, which is what the job spec asks for.
- **Deliberately did not build the cloud version.** Fabric is one architecture slide. I talk
  about Fabric from my actual job.

**The commercial quirk — rebates**

- Brought this in **from my own experience**: at my company the finance teams cannot agree
  whether a rebate belongs to the month of the credit note or the month of the original
  invoice. So I **modelled both** rather than picking one:
  - **Income (ledger)** — credit note counts in the month it was issued; ties to the GL.
  - **Income (attributed)** — credit note moved back to the original invoice's month.
  Both reconcile to the same all-time total, **£69,971,251.44**, but every fiscal year
  differs, because the fiscal year starts in April and refunds cross the year end.
- This is the point of the dashboard: **booked fee ≠ invoiced ≠ net fee income**. Worked
  example PL-000051 — £18,537.70 invoiced, −£9,268.85 credit note, £9,268.85 kept. Summing
  raw transactions would give £27,806.55, three times the truth.

**Modelling rules I set (each one corrected the AI's first attempt)**

| Rule | What it replaced |
|---|---|
| **No dbt seeds — one ingestion path.** Reference data is a source file like any other. | A seed CSV, which is technical debt and fragmentation. |
| **Don't derive dimensions from fact values.** Find the source system's own lookup table. | Dimensions built from `DISTINCT` transaction values, which lose members with no activity and turn typos into members. |
| **No business-mapping CASE statements.** "Status code → funnel stage" is reference data. | A `CASE` block buried in SQL. |
| **Never change a source to fit the model.** Bronze lands what the business sends; silver chooses what to use. | Deleting a column from the source file because the model did not need it. |
| **Blank vs `-1`.** `-1` only for a value that should exist but is missing; an event that has not happened is blank. | `-1` used for both, which makes "never interviewed" look like "unknown". |
| **Don't patch data to make numbers match.** Report it, find the cause, fix at source. | Back-filling three missing fee percentages from their invoices. |
| **Build only what we use.** | 11 date relationships when 6 are used. |
| **Naming standards belong in the warehouse, not the report.** | Renaming columns inside Power BI, which dies the moment a second report exists. |

**Structure**

- **Star, not snowflake.** Every fact carries every dimension key directly. Filters travel one
  step, field parameters need direct relationships, and the lookup cost is paid once at build
  time.
- **Header and line facts**, after I rejected the first design: `fact_Application` (one row per
  application, an accumulating snapshot with milestone dates) and `fact_ApplicationLine` (one
  row per status change, the event log). No relationship between them — both join the same
  dimensions. This is what lets the report answer *"where does the pipeline slow down?"*:
  interview stage averages **14.2 days** against 7.9 for CV review.
- **Role-playing date dimension** — one conformed `dim_Date`, other dates inactive and used
  with `USERELATIONSHIP` inside specific measures.
- **Rejected a 4-4-5 calendar**: five-week periods distort period-on-period comparison, and
  this business invoices and sets targets monthly. Fiscal year starts 1 April; ISO weeks.
- **`OfficeKey` recorded on the fact row** at build time, so a consultant moving office does
  not rewrite history — avoids SCD Type 2.
- **No candidate dimension** — not needed for these KPIs, and it keeps personal data out of
  the model. GDPR by design.
- **Rejected the OpenCATS `extra_field` pattern** (key-value rows) as overcomplication for a
  demo, while knowing what it is and why the CRM does it.
- **Kept all data from CRM go-live** (1 Oct 2022) rather than hiding the thin first months.
  FY22/23 is a partial six-month year and is labelled as such.

**Governance**

- **Every dimension has a `-1` "Unknown" member**, and facts map missing or unmatched keys to
  it. Nothing disappears from a visual, nothing shows as "(Blank)", totals always reconcile.
- **Two orphan credit notes (−£10,422.65)** are kept with `-1` keys so net fee income still
  ties to the ledger, and **only the CEO and CFO can see that "Unknown" team** — directors and
  managers should not see refunds that are not theirs.
- **Deliberately planted seven data quality problems** and decided how each is handled: blank
  discipline, an unmapped status code, unparseable free-text salary, missing fee percentages,
  orphan credit notes, duplicate candidates.
- **Tests are quality gates, not decoration.** Known source problems warn and continue; broken
  assumptions stop the build. 186 tests pass, 6 warn — the 6 are the planted problems.
- **Fix the cause, not the symptom.** A free-text salary box *sets people up to make mistakes*.
  The pipeline defends itself because history is already dirty, but the real fix is validation
  at entry, and the test results are the evidence to take to the data owner.

**Security**

- **Dynamic row-level security** at team level, which was a gap in my first interview.
  The access list is a **source file the BI team owns** and goes through the same
  bronze → silver → gold pipeline as everything else.
- One role filters `dim_Consultant` and flows to all five facts through the consultant key.
  Verified: CEO sees 25 teams and £69,971,251; a regional director 10 teams and £25,799,378;
  an office director 4 teams and £8,455,367; a team manager 1 team and £2,581,276.
- A **test fails the build if a team exists that nobody can see** — that is how the CEO/CFO
  gap was found in the first place.

**Report design**

- Two field parameters: one switching the **metric**, one that switched the **grouping**.
  I removed the second once each chart had its own fixed axis — unused objects are questions
  you cannot answer.
- Asked for a measure that expresses any chosen metric as a **share of CVs sent**, so the
  trend shows conversion over time rather than volume.
- Set the column naming standard **in gold** so every future report inherits it.
- Audited the finished model and removed everything unused.

---

## 3. What I built or ran myself

- Created the Python virtual environment and installed the pinned package set.
- Ran the generator, the bronze load and `dbt build` myself; read the output and the test
  results.
- Created the git repository, committed and pushed to GitHub.
- Created the Power BI project, built every visual, the slicers, the theme, the drillthrough
  page, and all formatting.
- Reviewed every model and every design decision before it was applied — and reversed several.

---

## 4. Numbers I can stand behind

| | |
|---|---|
| Warehouse | 17 bronze tables, 17 silver views, 15 gold tables |
| Tests | 186 pass, 6 warn (the planted problems), 0 errors |
| Rebuild from nothing | 3.4 seconds, byte-identical output (fixed seed, md5-verified) |
| Reconciliation | money ties CSV → silver → gold → Parquet to the penny in 7 currencies |
| Cross-system check | 4,714 placed applications = 4,714 finance placements |
| Semantic model | 14 tables, 35 relationships, 0 orphan fact rows, 20 measures |

---

## 5. Technical debt I accepted knowingly

Being straight about this is stronger than pretending it does not exist.

- **The gold naming standard is applied as a rename layer at the end of each model**, not
  throughout. The inside of each model still uses the silver naming. In a normal engagement
  I would rewrite the bodies.
- **No orchestration.** Three idempotent steps run by hand. Production would be a scheduled
  Fabric pipeline where a failed test stops the export, so the report keeps yesterday's good
  data instead of receiving bad data.
- **No CI/CD, no dev/test/prod split, no incremental loading.** The data is small enough to
  rebuild fully in seconds; at scale I would add incremental models and deployment pipelines.
- **The duplicate-candidate merge is simplified.** Real OpenCATS puts *unreviewed suspects* in
  that table; we treat them as confirmed merges. Stated openly rather than hidden.
- **Storage maintenance not done** — repeated rebuilds grow the DuckDB file. In Fabric this is
  `OPTIMIZE` and `VACUUM` on a schedule.
- **`dim_FxRateMonthly` is not renamed to the standard** — it is a build-time helper that
  never reaches a report.

---

## 6. How long this would take normally

Rough estimate for one BI developer doing this properly in a working environment,
with reviews and stakeholder cycles: **five to eight weeks of effort**, and longer elapsed.

| Workstream | Working days |
|---|---|
| Requirements, KPI definitions, agreeing the rebate rules with finance | 3–5 |
| Source analysis, access, extracts | 2–4 |
| Ingestion and bronze | 1–2 |
| Silver: 17 models plus tests | 3–5 |
| Gold: 8 dimensions, 5 facts, FX, security, tests | 5–8 |
| Reference data and lookups | 1 |
| End-to-end reconciliation and audit | 1–2 |
| Semantic model: relationships, naming, hierarchies, measures, RLS | 3–5 |
| Report pages, theme, drillthrough | 3–5 |
| Documentation and handover | 1–2 |
| **Total** | **23–39 days** |

This was built in roughly **25–30 hours** across four weekday evenings and a weekend.

The compression is real, but it is honest to say why: no source-system access to negotiate,
no stakeholder review cycles, no change requests, and the technical debt in §5 that a real
engagement would pay down. What did *not* get compressed is the thinking — grain, conformed
dimensions, the rebate logic, the unknown-member strategy, the security model. That is where
I spent my time, and it is the part that matters.
