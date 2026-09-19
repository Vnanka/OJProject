# Dashboard plan — Sunday 20 September 2026

Interview: **Monday 21 Sep, 1:00 PM.** Today is the only build day. Monday morning is
rehearsal only — no new building.

**Start here:** step 1 below. Claude writes the TMDL, you check it in Desktop.

---

## Where the model is now

Done and verified: 14 tables over Parquet, 35 relationships (2 inactive), 55 keys hidden,
money is Fixed Decimal, auto date/time off. No measures yet, no RLS role, no visuals.

---

## The order of work

| # | Step | Time | Who |
|---|---|---|---|
| 1 | Sort-by columns | 15 min | Claude |
| 2 | Core measures | 45 min | Claude |
| 3 | RLS role + test it | 30 min | Claude writes, Vlad tests |
| 4 | **Page 1 — Executive** | 2.5 h | **Vlad** |
| 5 | **Page 2 — Manager** | 1.5 h | **Vlad** |
| 6 | Detail table | 30 min | Vlad |
| 7 | Presentation + rehearsal | 2 h | Vlad |

Steps 1–3 are quick and unblock everything else. **If it gets late, cut steps 5 and 6
before cutting step 7.** A rehearsed 2-page demo beats an unrehearsed 4-page one.

---

## Step 1 — sort-by columns (blocking)

Without these every chart sorts alphabetically: April, August, December.

| Column | Sorts by |
|---|---|
| `dim_Date[MonthName]` | MonthNumber |
| `dim_Date[YearMonth]` | YearMonthKey |
| `dim_Date[FiscalPeriod]` | FiscalYearPeriodKey |
| `dim_Date[FiscalQuarter]` | FiscalQuarterNumber |
| `dim_Office[Region]` | RegionSortOrder |
| `dim_Industry[Industry]` | IndustrySortOrder |
| `dim_Stage[FunnelStage]` | FunnelStageOrder |

---

## Step 2 — the measures

A measures table (`_Measures`) so they don't sit inside a fact table.

**Money**
- `NFI` = `SUM(fact_FeeTransaction[NetAmountGbp])`
- `NFI (attributed)` = same, with `USERELATIONSHIP(fact_FeeTransaction[OriginalInvoiceDateKey], dim_Date[DateKey])`
- `Booked Fee` = `SUM(fact_Placement[BookedFeeGbp])`
- `Avg Fee %` = `DIVIDE(SUM(BookedFeeGbp), SUM(SalaryGbp))` — weighted, NOT an average of FeePct

**Volume**
- `Placements` = `COUNTROWS(fact_Placement)`
- `Applications` = `COUNTROWS(fact_Application)`
- `Reached Interview` / `Reached Offer` = `SUM(...)` of the flags

**Conversion (cohort — by the date the CV was sent)**
- `CV to Interview %` = `DIVIDE([Reached Interview], [Applications])`
- `Interview to Offer %`, `Offer to Placed %`

**Speed and quality**
- `Avg Days to Fill` = `AVERAGE(fact_Placement[DaysToFill])`
- `Fall-off Rate` = `DIVIDE(SUM(fact_Placement[IsFallOff]), [Placements])`
- `Avg Days in Stage` = `AVERAGE(fact_ApplicationLine[DaysInPreviousStage])` with
  `USERELATIONSHIP(StatusFromKey, dim_Stage[StageKey])` — the bottleneck chart

**Target**
- `Target NFI` = `SUM(fact_Target[TargetNfiGbp])`
- `NFI vs Target %` = `DIVIDE([NFI], [Target NFI])`

Format everything at the measure: money `£#,0`, percentages `0.0%`.

---

## Step 3 — RLS

One role, `Team Access`, filtering `dim_Consultant`:

```
[Team] IN CALCULATETABLE(VALUES(sec_UserTeam[Team]),
                         sec_UserTeam[Email] = USERPRINCIPALNAME())
```

Test with **Modeling → View as → Other user**:

| Email | Should see |
|---|---|
| `ceo@example.com` | 25 teams, all numbers, NFI £69,971,251.44 |
| a Manchester director | 4 teams |
| `lucas.taylor@example.com` | 1 team |

Also hide the whole `sec_UserTeam` table from the field list.

---

## Step 4 — Page 1, Executive (the page that gets seen first)

One fiscal-year slicer + one office/industry slicer at the top, applying to everything.

**KPI cards:** NFI · Placements · CV to Interview % · NFI vs Target %

**Visuals:**
1. **NFI by fiscal period** — line or column, by `FiscalPeriod`. The headline trend.
2. **NFI by office** (or industry) — bar, sorted descending.
3. **Funnel** — Applications → Reached Interview → Reached Offer → Placements.
4. **Top 10 clients by NFI** — table with NFI and Placements.

Keep it to four visuals plus cards. Clean beats crowded.

**Label FY22/23 as partial** wherever fiscal years are compared — it is 6 months only.

---

## Step 5 — Page 2, Manager

- **Consultant ranking**: table of Consultant · NFI · Target · NFI vs Target % · Placements,
  sorted by NFI. Conditional formatting on the % column.
- **NFI vs Target by month** — column + line.
- This is the page you demo RLS on: show it as the CEO, then as one manager.

---

## Step 6 — Detail table

A simple table: Placement Ref · Client · Consultant · Placed Date · Booked Fee · Fall-off.
Replaces the drillthrough page that was cut.

---

## Step 7 — Presentation (~10 minutes)

1. **The business question** — recruitment firm, NFI is how they measure growth. (1 min)
2. **The dashboard** — demo, not slides. Exec page, then manager page, then RLS. (4 min)
3. **The rebate story** — PL-000051: invoice £18,537.70, credit note −£9,268.85, NFI
   £9,268.85. Summing raw data gives £27,806.55, three times the truth. Then the ledger vs
   attributed table: every year differs, all-time ties to the penny. (2 min)
4. **The architecture** — bronze/silver/gold, tests as quality gates. (1.5 min)
5. **Production in Fabric** — Delta tables, Data Pipeline orchestration, Direct Lake,
   dev/test/prod, CI/CD. (1.5 min)

**Say plainly:** the data is synthetic, the patterns were built in deliberately, and AI wrote
much of the code — "I designed and decided, I reviewed, and I can explain every part."

---

## Cut list, in order

1. Field parameters → fixed visuals **(already cut)**
2. Drillthrough page → detail table **(already cut)**
3. Page 2 Manager → mention it verbally, keep `fact_Target` in the model
4. Stories 5 and 6 → leave them in the data only

**Never cut:** RLS, the NFI/rebate logic, the star schema, the Fabric slide, the rehearsal.
