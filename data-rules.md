# Data rules — OJ interview dashboard

**v3.1, 16 Sep 2026.** Agreed plan, now **generated** — see §11 for the files and the
checks of the real output against this plan.
This document says **what the generated data will contain and why**.

Everything below is **synthetic**, except the real sources listed in §2.

**History of changes**
- **v2:** the CRM export copies the shape of **OpenCATS**, a real open-source recruitment CRM
  (§3). Added `can_relocate` and candidate duplicates. Stages are number codes with a history
  log. Placements and fees live in a separate finance export.
- **v2.1:** realistic, non-round conversion rates that change by fiscal year, and a sixth
  story. Added the RLS access list and the report requirements for the gold layer.
- **v3:** middle-ground size (~150 consultants) with realistic output of **8–12 placements
  per settled consultant per year**. The report serves **executives and team managers**:
  teams now have managers, RLS works at **team level**, and there is a new **targets** file
  (§3.2, §6.8), which becomes a fourth fact. All review questions answered (§10).

---

## 1. Scope

| Item | Decision |
|---|---|
| Business | A recruitment agency shaped like Oliver James |
| Placement types | **Permanent only** (job type code `H` = Hire) |
| Date range | **1 Apr 2023 → 12 Sep 2026** for reporting (3 full fiscal years + part of FY26/27) |
| CRM go-live | **1 Oct 2022.** Data starts six months early so FY23/24 opens with a normal pipeline. Rows before 1 Apr 2023 are a run-in and are filtered out of reporting. |
| Fiscal year | Starts **1 April**. FY23/24, FY24/25, FY25/26, FY26/27 (partial) |
| Weeks | **ISO weeks**, Monday start |
| Reporting currency | **GBP**, converted from local currency using real ECB rates |
| Audiences | **Executives** (whole firm), **directors** (region/office), **team managers** (own team) |

---

## 2. Real data (not generated)

| Source | Used for | Notes |
|---|---|---|
| Frankfurter API (ECB rates) | Daily FX rates for GBP, EUR, USD, CHF, HKD, SGD, MYR | No rates on weekends/holidays → we use a **monthly average rate** |
| gov.uk bank holidays | UK working-day flags in `dim_date` | Enables time-to-fill in working days |
| oliverjames.com | The real list of 4 industries, 7 disciplines, 13 offices | Names only, no company data |
| OpenCATS schema (GitHub) | Table names, column names, status codes, value formats | Structure only — its demo data is too small to use |

---

## 3. Source files — what the exports look like

Two pretend source systems plus a BI-team file. The files are **raw exports**, not dims and
facts.

### 3.1 CRM export — copies the OpenCATS shape

Column names follow OpenCATS. Columns marked *(custom)* do not exist in OpenCATS; they are
the agency's own additions, kept as **plain columns** for simplicity.

| File | Columns |
|---|---|
| `user.csv` | `user_id, first_name, last_name, email, title, date_created, date_modified`, *(custom)* `office, team, manager_user_id, date_left` — `email` is a real OpenCATS column; fake `example.com` addresses that match the RLS access list |
| `company.csv` | `company_id, name, city, country, owner, date_created, date_modified`, *(custom)* `industry, sub_sector` |
| `joborder.csv` | `joborder_id, company_id, recruiter, owner, title, type, salary, status, city, country, openings, start_date, date_created, date_modified`, *(custom)* `discipline, work_arrangement, owning_office` |
| `candidate.csv` | `candidate_id, can_relocate, date_created, date_modified` — **nothing personal** (no names, emails, phones) |
| `candidate_duplicates.csv` | `old_candidate_id, new_candidate_id, date_modified` |
| `candidate_joborder_status.csv` | `candidate_joborder_status_id, short_description, date_modified` (the lookup in §4.4) |
| `candidate_joborder_status_history.csv` | `candidate_joborder_status_history_id, candidate_id, joborder_id, date, status_from, status_to, date_modified` |

How the values look (like a real CRM, not a clean table):

- IDs are **numbers**. `recruiter`, `owner` and `manager_user_id` are `user_id`s, not names.
- `manager_user_id` points to the team manager. Managers are users too (they also bill).
  Directors and execs have no manager in this file.
- `type` is a **code**: always `H` (Hire) here.
- `salary` is **free text**, in several styles: `£70k - £85k`, `70000`, `70,000`, `CHF 120k`, `Competitive`.
- `country` is a **2-letter code** (`GB`, `IE`, `CH`…).
- Dates are MySQL style: `2025-03-14 09:12:44`.
- The history log has **no consultant column**. Pipeline activity is credited to the job's
  `recruiter`.
- `owning_office` is the office that owns the job. Facts take their office from here, so a
  consultant moving office later does not change history.

**Every file carries a "record last modified" timestamp** (added 17 Sep), named the way each
system would name it: **`date_modified`** in the CRM, **`modified_at`** in finance,
**`last_updated`** in the access list. Silver standardises the name.

The values mean something rather than being noise:

| File | What sets it |
|---|---|
| `user` | leavers: a few days after leaving; active staff: some later profile edit |
| `candidate` | the date of that candidate's most recent pipeline event |
| `candidate_joborder_status_history` | **equal to the event date** — history rows are never edited |
| `candidate_joborder_status` | go-live date; a lookup table barely changes |
| `placements` | after the latest of placed / start / leave date |
| `transactions` | a day or two after the document date (when it was posted) |
| `targets` | when that fiscal year's budget was set |
| `security_user_team` | the last access review |

This makes an **incremental load** possible later: take only rows where the modified
timestamp is newer than the last run. It is not built (see §9), but the data supports it.

### 3.2 Finance export — our own design

OpenCATS has **no placements, fees, invoices or targets**. In a real agency these live in the
finance system, which is exactly why they are a separate export.

| File | Columns |
|---|---|
| `placements.csv` | `placement_ref, joborder_id, candidate_id, consultant_user_id, booking_office, date_placed, start_date, leave_date, salary, fee_pct, currency, modified_at` |
| `transactions.csv` | `doc_no, doc_type, placement_ref, doc_date, net_amount, currency, modified_at` |
| `targets.csv` | `user_id, month, target_nfi_gbp, modified_at` |

- `doc_type` is `INV` (invoice) or `CRN` (credit note). **Both are stored as positive
  amounts** — the sign comes from `doc_type`, so silver must make credit notes negative.
- Dates are UK style text: `14/03/2025`. **Different from the CRM on purpose.**
- `month` in the targets file is text like `2025-03` — a **month**, not a day (see §3.5).
- `salary` here is a clean number in local currency (finance needs it to calculate the fee).
- **CRM and finance join on `joborder_id + candidate_id`** — a realistic cross-system match.

### 3.3 API downloads

`fx_rates.json` (Frankfurter) and `bank_holidays.json` (gov.uk), stored exactly as received.

### 3.4 Access list for row-level security — maintained by the BI team

One small file that says **which person may see which team**. It drives **dynamic RLS**
(`USERPRINCIPALNAME()` in Power BI).

| File | Columns |
|---|---|
| `security_user_team.csv` | `user_email, team, role_description, last_updated` |

- **Fake people only**, on `example.com`. No real names.
- **One row per person per team.** People who see several teams get several rows. Execs
  who see everything get a row for **every** team. This keeps the DAX filter simple
  (no special "ALL" value to handle).

| Person | Teams they see | Rows |
|---|---|---|
| `ceo@example.com`, `cfo@example.com` | all 24 | 48 |
| 4 regional directors (UK & Ireland, Europe, North America, APAC) | all teams in their region | 24 |
| 13 office directors, e.g. `manchester.director@example.com` | all teams in their office | 24 |
| 24 team managers, e.g. `manager.team07@example.com` | their own team only | 24 |

About **120 rows**. In the demo, Power BI Desktop's **View as** switches between these people.

**Known limitation (Q&A point):** the filter uses each consultant's **current** team. If a
consultant changes team, their history moves with them. Fixing this needs SCD Type 2.

### 3.5 Report requirements that shape the gold layer

The planned report has three levels — **executive** pages, a **team manager** page and a
**consultant drillthrough** page — plus time series, **field parameters** to switch the
grouping, and **RLS**. It needs these from the model:

1. **Four facts:** `fact_pipeline_event`, `fact_placement`, `fact_fee_transaction`, and the
   new `fact_target` (one row per consultant per month).
2. **Every transaction fact carries the same dimension keys.** `fact_fee_transaction` gets
   the client, industry, discipline, vacancy, consultant and office keys **copied from its
   placement**. Without them, a visual that switches to "by Industry" would show the same
   total on every row.
3. **Every fact carries the consultant key**, so one RLS filter on the consultant/team
   dimension reaches every number in the report, including targets.
4. **`fact_target` is at a different grain (month, consultant only).** It has no industry,
   discipline or client. Target visuals must only use dimensions it is connected to —
   switching them to "by Industry" would repeat the same target on every row. Its date key
   points to the **first day of the month** in `dim_date`.
5. **Clean hierarchies** for drill-down: Region → Office → Team → Consultant ·
   Industry → Sub-sector · Fiscal year → Fiscal quarter → Fiscal period.

---

## 4. Reference data

### 4.1 Offices (13, from OJ's website)

| Office | Country | Region | Currency |
|---|---|---|---|
| Manchester, London | GB | UK & Ireland | GBP |
| Dublin | IE | UK & Ireland | EUR |
| Amsterdam, Brussels, Madrid, Paris | NL / BE / ES / FR | Europe | EUR |
| Zurich | CH | Europe | CHF |
| New York, Charlotte | US | North America | USD |
| Hong Kong | HK | APAC | HKD |
| Singapore | SG | APAC | SGD |
| Malaysia | MY | APAC | MYR |

Office sizes are **uneven, like a real firm**: Manchester and London are the biggest
(~30 consultants each), then the European offices and New York, with Charlotte and Malaysia
the smallest.

### 4.2 Industries (4) and sub-sectors

- **Insurance** — General Insurance, Life & Pensions, Health
- **Financial Services** — Banking, Asset & Wealth Management, Payments & Fintech
- **Commerce & Industry** — Technology, Industrials, Energy & Infrastructure, Consumer
- **Professional Services** — Consulting, Legal & Advisory, Actuarial Consulting

### 4.3 Disciplines (7)

Accountancy, Finance & Audit · Actuarial · Risk & Compliance · Technology ·
Transformation & Change · Underwriting, Broking & Claims · Legal

### 4.4 Status codes (from OpenCATS) and how they map to our funnel

| Code | OpenCATS status | Our funnel stage | Generated? |
|---|---|---|---|
| 0 | No Status | — (start of history) | yes, as `status_from` only |
| 100 / 200 / 250 / 300 | No Contact / Contacted / Candidate Responded / Qualifying | — (before the funnel) | no — keeps volume down |
| 400 | Submitted | **CV Sent** | yes |
| 500 | Interviewing | **Interview** | yes |
| 600 | Offered | **Offer** | yes |
| 800 | Placed | **Placed** | yes |
| 650 | Not in Consideration | **Rejected** (by the agency) | yes |
| 700 | Client Declined | **Rejected** (by the client) | yes |
| 675 | Candidate Declined | **Withdrawn** | yes |

This mapping lives in dbt, so every report uses **one agreed definition** of each stage.

---

## 5. Volumes

Actual counts from the generator (16 Sep 2026). They include the six-month run-in.

| Table | Planned | **Actual** |
|---|---|---|
| Users (consultants + managers) | ~150 + leavers | **214** (120 on 1 Apr 2023 → 164 on 12 Sep 2026; 50 leavers) |
| Teams | ~24 | **24** |
| Companies (clients) | ~1,000 | **964** |
| Job orders (vacancies) | ~8,000 | **7,506** |
| Candidates | ~40,000 | **46,934** |
| Candidate duplicate pairs | ~500 | **500** |
| Status history rows | ~120,000 | **145,619** |
| Placements | ~3,900 | **4,714** |
| Invoices | ~3,900 | **4,489** |
| Credit notes | ~375 | **414** (incl. 2 planted orphans) |
| Targets (consultant × month) | ~5,800 | **6,143** |
| Security access rows | ~120 | **120** |

Placements are higher than planned mainly because of the run-in period and the higher fill
rate. Still small for DuckDB and Power BI — the raw folder is 9.7 MB.

---

## 6. Business rules

### 6.1 Funnel conversion

Target rates per fiscal year. They are deliberately **not round numbers**, and they move a
little each year so a KPI card can show a change versus last year.

| Step | FY23/24 | FY24/25 | FY25/26 | FY26/27 (YTD) |
|---|---|---|---|---|
| Submitted (CV Sent) → Interviewing | 33.8% | 34.6% | 35.9% | 36.4% |
| Interviewing → Offered | 29.3% | 28.7% | 29.8% | 30.2% |
| Offered → Placed | 81.7% | 80.2% | 78.4% | 76.8% |

- CV → interview **improves** over time (better CV quality).
- Offer → placed **declines** over time (more counter-offers). See story 6 in §7.
- These are targets for the generator. Because it is random, the real numbers will land
  close to them, not exactly on them — which is what real data looks like.
- **Definition (cohort-based):** of the candidates submitted in a period, the share that
  reached the next stage at any later date. The most recent months will look lower because
  those candidates have not finished the process yet — a real reporting issue to mention.

Result: about **60% of vacancies get filled** (measured on jobs older than 120 days).
Candidates who don't progress end as Client Declined (50%), Not in Consideration (20%) or
Candidate Declined (30%).

### 6.2 Seasonality and growth

- Monthly index: Jan 1.25, Feb 1.15, Mar 1.10, Apr 1.00, May 1.00, Jun 1.05,
  Jul 0.95, **Aug 0.75**, **Sep 1.20**, Oct 1.10, Nov 1.00, **Dec 0.70**
- Growth comes mainly from **hiring**: headcount rises from ~120 to ~160 consultants.

### 6.3 Salaries and fees

- Salary bands per discipline, e.g. Actuarial £55k–£120k, Legal £60k–£130k,
  Accountancy £40k–£90k. Non-UK offices are scaled by a country factor and expressed
  **in local currency**.
- **Fee = salary × fee %**, where fee % is 15–25% (average ≈ 19.4%).
- Invoice is dated **0–7 days after the candidate's start date**, payment terms **30 days**.

### 6.4 Rebates (the quirk)

Guarantee period: **12 weeks**. If the candidate leaves inside it, a **credit note** is raised.

| Candidate leaves | Refund |
|---|---|
| Weeks 0–4 | 100% of the fee |
| Weeks 5–8 | 50% |
| Weeks 9–12 | 25% |

- Overall fall-off rate: **9.6%** of placements
- The credit note is dated **1–3 weeks after the leave date**, so it often lands in a
  **later month than the invoice**. This is what makes NFI different from invoiced revenue.

### 6.5 Time-to-fill

Average **38 calendar days** from job order created to offer, varying by:

| Factor | Effect |
|---|---|
| Remote roles | faster (~32 days) |
| Hybrid roles | average (~36 days) |
| Office-only roles | slower (~45 days) |
| Actuarial and Legal | slower than average (scarce candidates) |

### 6.6 Consultant output and ramp-up

A **settled** consultant makes **8–12 placements a year (average 10)**. Each consultant gets
their own personal level inside that range, so a team has stronger and weaker performers.

| Tenure | Output (share of their settled level) |
|---|---|
| 0–6 months | 30% |
| 6–12 months | 70% |
| 12+ months | 100% |

Team managers bill too, at about **70%** of a normal consultant (part of their time goes on
managing).

### 6.7 Candidates who can relocate

- **30%** of candidates have `can_relocate = 1`.
- For **Actuarial and Legal** roles, and for **Zurich, Singapore, Hong Kong and New York**,
  relocatable candidates convert Interviewing → Offered more often (about 44.1% instead of
  the normal ~29%).
- The flag is copied onto the fact rows at the time of the event, so no candidate dimension
  is needed.

### 6.8 Targets

- One **monthly NFI target in GBP** per consultant, set centrally by finance.
- A settled consultant's yearly target is set a little **above** what they usually achieve,
  and split across months using the **same seasonality index** as §6.2 (so August and
  December targets are lower).
- New starters get the **same ramp-up** as §6.6 (30% / 70% / 100% of a full target).
- Targets rise about **8% per fiscal year**.
- Target starts in the month a consultant joins and stops in the month they leave.
- Targets include a **6% allowance for rebates**, because finance expects some fees to be
  refunded.
- Result for settled consultants: **median ~95% of target**, with a wide spread (10th
  percentile ~63%, 90th ~133%). Recruitment output is naturally uneven — which is exactly
  why a manager page needs to show it.

---

## 7. Patterns deliberately hidden in the data

These are the stories to find on the dashboard. Each has a decision attached.

1. **One team has high placements but high fall-off (17.8% vs 9.6%).** Their NFI is far below
   their booked fee. → *Decision: review that team's client quality and offer process.*
2. **Office-only roles fill slower and fall off more.** → *Decision: advise clients that
   insisting on 5 days in the office costs them time and increases the risk.*
3. **New consultants produce little for ~7 months.** → *Decision: hiring plans must allow
   for ramp-up, and the trebling target needs hires made early.*
4. **One large client interviews a lot but rarely offers.** → *Decision: consultant time is
   being wasted; renegotiate or step back from that client.*
5. **Relocatable candidates fill the scarce roles.** → *Decision: build and maintain a
   relocatable talent pool for Actuarial, Legal and the hard-to-fill offices.*
6. **More offers are being lost at the last step** (offer → placed falls from 81.7% to
   76.8%). → *Decision: prepare candidates for counter-offers earlier in the process.*

The team in story 1 will also look **fine on placements vs target but poor on NFI vs
target** — a good example for the manager page of why NFI, not placements, is the number
to judge.

---

## 8. Data quality problems planted on purpose

Each one is caught or handled in silver, so the tests have something real to find.

| # | Problem | How it is caught / handled |
|---|---|---|
| 1 | ~500 candidates entered twice (listed in `candidate_duplicates.csv`) | Silver replaces every new ID with the old ID **before** counting; a test checks no duplicate IDs remain |
| 2 | A few history rows use status code `999`, which is not in the lookup | `relationships` test |
| 3 | 2 credit notes pointing at a placement that doesn't exist | `relationships` test |
| 4 | ~30 job orders with a blank discipline | `not_null` test, shown as "Unknown" |
| 5 | 3 placements with a missing or zero fee % | `not_null` / range test |
| 6 | Salary as free text in five styles, some not a number (`Competitive`) | Parsed in silver; unparseable values become NULL and are counted by a test |
| 7 | Dates in three formats (CRM `2025-03-14 09:12:44`, finance `14/03/2025`, targets `2025-03`) | Cast in silver, in one place |

---

## 9. Out of scope (deliberately, for the Q&A)

These are named as things a production build would add, not oversights:

- **Custom fields stored as rows** (OpenCATS `extra_field`, an EAV design). Real CRMs do this;
  we used plain columns to save time. In production it is one pivot model in dbt.
- **Team history (SCD Type 2)** — RLS and team reporting use the current team only.
- Pre-submission statuses (No Contact → Qualifying) — exist in the lookup, not generated
- Contract and interim placements (timesheets, monthly margin invoicing)
- Candidate personal data — not needed for these KPIs, and a GDPR risk
- Consultant-level security (a consultant seeing only their own numbers)
- **Incremental loads.** Bronze is a full reload (`create or replace`), which is right at
  this size. Every file now carries a modified timestamp (§3.1), so the switch to
  "load only what changed" is possible without touching the source exports.
- Forecasting future NFI from the open pipeline
- Orchestration, scheduling and alerting

---

## 10. Review answers (16 Sep 2026)

1. **Volumes:** middle ground — ~150 consultants, 8–12 placements per settled consultant
   per year. Conversion rates: realistic, non-round, changing by fiscal year. ✅
2. **Rebate rule:** 12-week guarantee with the 100% / 50% / 25% sliding scale. ✅
3. **Stories:** keep all six in the data. Choose 3–4 for the presentation later. ✅
4. **Cuts:** nothing cut from the data. If time runs short, cut in dbt/Power BI instead. ✅
5. **Audiences:** executives and team managers — team managers, team-level RLS and a targets
   fact added. ✅

**Status: data plan complete.**

---

## 11. Generated files (16 Sep 2026)

```
dw/raw/crm/        user, company, joborder, candidate, candidate_duplicates,
                   candidate_joborder_status, candidate_joborder_status_history
dw/raw/finance/    placements, transactions, targets
dw/raw/security/   security_user_team
dw/raw/api/        fx_rates.json (ECB, 1,009 days), bank_holidays.json (gov.uk, 2019–2028)
```

How to rebuild (fixed random seed, so the output is identical every time):

```bash
python dw/src/generate/generate_sources.py    # synthetic CRM, finance, security
python dw/src/extract/fetch_reference.py      # real FX rates and bank holidays
```

The generator prints a check of the data against this document. Result of the last run:

| Check | Plan | Actual |
|---|---|---|
| CV → interview (FY23/24, FY24/25, FY25/26) | 33.8 / 34.6 / 35.9% | 33.8 / 35.3 / 35.9% |
| Interview → offer | 29.3 / 28.7 / 29.8% | 29.3 / 28.2 / 29.3% |
| Offer → placed | 81.7 / 80.2 / 78.4% | 79.8 / 79.6 / 78.9% |
| FY26/27 (still in progress) | — | lower, because recent candidates have not finished yet |
| Placements per settled consultant per year | 8–12 | 11.0 |
| Fall-off overall / London Risk | 9.6% / 17.8% | 9.4% / 17.3% |
| Fall-off office-only vs other roles | higher | 13.3% vs 7.7% |
| Time to offer: remote / hybrid / office | ~32 / ~36 / ~45 days | 29.8 / 36.5 / 45.1 |
| Story 4 client int → offer ("Marlowe Retail Ltd", London) | ~8% | 6.6% |
| Story 5 relocatable int → offer | 44.1% | 43.6% |
| Target achievement, settled consultants (median) | a little below 100% | 95% |
| Planted problems: status 999 / blank discipline / bad fee % / orphan credit notes | 20 / 30 / 3 / 2 | 20 / 30 / 3 / 2 |

Two generator details worth knowing:
- The offer rates fed into the generator are slightly higher than the plan, because once a
  job fills, the remaining interviewees never get an offer. The *observed* rates match the plan.
- Windows consoles using a non-UTF-8 code page cannot print `£`/`€`. The files are UTF-8
  and are fine; set `PYTHONIOENCODING=utf-8` when printing them.
