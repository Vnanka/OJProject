# CLAUDE.md — Oliver James: Senior BI Analyst, 2nd-stage interview prep

Context handoff for a new session. Everything below was established in a previous chat.
Read this first, then ask what to work on — don't assume the task.

---

## 1. The situation

Vlad (vladislavs.nanaks@gmail.com) has a **second-stage interview with Oliver James (OJA)**
for a **Senior BI Analyst (Microsoft Fabric)** role. First-stage feedback was very good.

| | |
|---|---|
| **Date / time** | Monday 21 September 2026, 1:00 PM |
| **Location** | Globe Building, 1 New Quay Street, Manchester, M3 4BN (OJ head office) |
| **Format** | Build a **Power BI dashboard** on a dataset of Vlad's choosing → present it → Q&A |
| **Recruiter** | Jamie MacMillan, Director, Insight Talent Partners (jamie.macmillan@insighttalentpartners.co.uk) |

**Important framing correction:** Oliver James is the **employer**, not the agency in this deal.
Insight Talent Partners is placing Vlad *into OJ's internal analytics function*. The job spec
document says "a well-established professional services organisation in central Manchester" —
that is OJ describing itself through its recruiter. So OJ's own business data (placements,
consultants, revenue) is the natural subject matter for the dashboard.

---

## 2. The exercise brief (from the recruiter's email)

Build a Power BI dashboard using a dataset of your choosing and present it. The discussion
afterwards covers **design choices, data model, stakeholder considerations, reporting approach,
and how you'd develop the solution further in a production environment.**

They will be equally interested in:

- How you approached the problem
- How you structured the data model
- Why you chose particular KPIs
- How you considered scalability and governance
- What business decisions the dashboard supports

### Recruiter's suggested dashboard topics (he recommends a recruitment-focused scenario)

1. **Recruitment Performance** — CV submissions, interviews arranged, offers, placements,
   consultant productivity, team performance, placement conversion rates, revenue by
   consultant/team, monthly trends. Demonstrates KPI creation, star schema, DAX, trend analysis,
   commercial reporting, exec dashboard design.
2. **Revenue & Forecasting** — revenue by consultant/sector, gross margin, forecast vs actual,
   pipeline value, expected placement revenue, monthly/quarterly forecasting.
3. **Operations** — vacancy ageing, time-to-fill, candidate pipeline status, SLA adherence,
   consultant workload, team capacity, regional performance.

### Q&A areas the recruiter expects

- **Data modelling** — why the model is structured that way; fact/dimension design; star schema
  principles; relationships and cardinality; performance; how it scales if data grows a lot.
- **KPI design & business logic** — why these KPIs; how calculations are defined; consistency
  across reports; what actions stakeholders take from the insight. *Explain commercial value,
  not just the calculation.*
- **Governance & reporting standards** — ensuring trust in data; validation and testing;
  consistency across dashboards; managing semantic models; enabling self-service without
  losing governance.
- **Stakeholder management** — difficult stakeholders, changing requirements, conflicting
  priorities, tight deadlines. Suggested framework: understand the business objective → assess
  impact and urgency → agree priorities → communicate trade-offs → keep stakeholders informed.

### Recruiter's read on what will impress

Microsoft Fabric experience; dimensional modelling and warehousing; governed, scalable
reporting solutions; defining reporting standards; translating stakeholder requirements into
practical BI products; measurable impact delivered. His closing advice: keep the dashboard
**clean, business-focused and commercially relevant**, then use the Q&A to show the depth of
modelling, Fabric and governance knowledge.

---

## 3. The role (from the job spec)

**Senior BI Analyst (Microsoft Fabric)** — £55–60k basic + 5% quarterly discretionary KPI bonus.
Hybrid, 3 days in office / 2 from home. Central Manchester. Reports into the Analytics Manager.

Core of the job: **consolidate disparate SQL scripts, datasets and reporting logic into governed,
reusable analytical assets** and push the organisation toward a Data & Analytics Centre of
Excellence.

**Responsibilities:** rationalise and optimise the existing Power BI estate (governance,
performance, maintainability); build in Fabric (Lakehouses, Warehouses, Pipelines, Dataflows);
create shared semantic models and reusable datasets; consolidate SQL/business logic into
governed datasets; establish data modelling standards and Power BI best practice; improve report
performance (models, DAX, refresh, source queries); data quality; collaborate with analysts and
data engineers; mentor juniors; contribute to the wider D&A strategy.

**Technical requirements:** strong Power BI / modelling / DAX; hands-on Fabric (or transferable
Snowflake / Databricks / Synapse); Lakehouse and warehouse concepts, medallion architecture,
pipelines, dataflows, dev/test/prod; strong SQL/T-SQL incl. query optimisation; shared semantic
models; dimensional modelling, relational DBs, ETL/ELT; requirements gathering.

**Desirable:** Fabric/Power BI certifications; Azure Data Factory, Synapse, Databricks, Purview,
REST APIs, CI/CD; Agile, Azure DevOps, Jira.

**Benefits (for reference):** pension matched to 4.5%, Vitality private medical/optical/dental,
4× life assurance, 23 days holiday rising to 25, buy/sell 3 days, festive close-down not deducted,
company events, extended lunch for gym, cycle to work, eye test + £50 glasses, competitive
maternity.

### Vlad's background (as characterised by the recruiter)

Building reporting solutions on **Microsoft Fabric**, designing **dimensional models**,
implementing **reporting standards**, warehousing, requirements gathering across multiple business
functions, governed reporting environments. Ask Vlad to confirm/expand specifics (tools, scale,
measurable impact) before writing any STAR stories — don't invent achievements.

---

## 4. Company intel on Oliver James (researched, sourced)

- Specialist recruitment firm, **founded Manchester 2002** by **Oliver Castle and James Rogers**
  (the company name is the two founders' first names). Both still co-CEOs and majority shareholders.
- Sectors: financial services, insurance, commerce & industry, professional services.
  Disciplines: accountancy/finance/audit, **actuarial**, risk & compliance, technology,
  transformation & change, underwriting/broking/claims. Perm and contract.
- ~12–14 offices: Manchester, London, Amsterdam, Brussels, Dublin, Madrid, Paris, Zurich,
  New York, Charlotte, Hong Kong, Singapore, Malaysia. Roughly 600–700 staff.
- Marketing stats: 86% client retention YoY, 9.1/10 client satisfaction.
- **Soho Square Capital** took a **minority stake in Jan 2022** at ~£220.5m revenue; stated goal
  to **treble the business in five years** (so 2027 is the target year).
- **£351m global turnover in 2023**; net fee income grew **20%+ p.a. FY19–FY23**.
- **Nov 2024:** refinanced with **H.I.G. Bayside Capital**; Soho Square retained its stake and
  board seat. CFO: **Graeme Edwards**. Soho Square director on the board: **David Steel**.
- Glassdoor ~**4.4/5** (670 reviews), 96% CEO approval. Strong internal-promotion culture —
  60% of staff promoted last year, 80% of Country Directors started their careers at OJ.
  Common criticism: long hours, high-intensity sales floor.

**Why this matters for the dashboard narrative:** a PE-backed firm scaling headcount aggressively
toward a trebling target cares about consultant ramp-up time, revenue per head, desk
productivity, client retention and forecast accuracy. Frame KPIs against those commercial
pressures rather than as generic recruitment metrics.

Sources: oliverjames.com; soho-sq.com (2022 investment, 2024 refinancing announcements);
Glassdoor.

---

## 5. What Vlad may want built (nothing chosen yet)

He was offered these and hasn't picked — **ask before starting**:

- **Synthetic dataset + star schema** — realistic recruitment CSVs (fact_placement,
  fact_activity/funnel, dim_consultant, dim_client, dim_sector/discipline, dim_date, dim_vacancy),
  a few years of believable seasonality, plus model diagram and relationship/cardinality decisions,
  ready to load into Power BI Desktop.
- **DAX measure set + KPI definitions** — conversion rates, time-to-fill, NFI/GP per consultant,
  time intelligence, with written business rationale for each so every number is defensible.
- **Presentation structure** — ~10-minute narrative: problem framing, stakeholders, decisions the
  dashboard supports, then how it'd be productionised on Fabric (medallion, dev/test/prod,
  deployment pipelines, shared semantic model, RLS, refresh strategy).
- **Q&A drilling** — answers to the areas in §2 plus harder follow-ups the recruiter didn't list
  (e.g. composite models, incremental refresh, Direct Lake vs Import, semantic model sprawl,
  certified/promoted datasets, Purview lineage, CI/CD for Power BI via Fabric deployment
  pipelines or Azure DevOps).

### Working principles agreed so far

- The dashboard is the ticket to the conversation; the **model and governance story behind it**
  is what wins the role. Build something deliberately **small and clean**, not sprawling.
- Pick a **recruitment/OJ-shaped scenario** so the exercise doubles as evidence he's thought about
  the industry he's joining.
- Every KPI needs a "so what" — the decision a named stakeholder (Country Director, team manager,
  CFO) would take from it.
- Don't fabricate Vlad's work history. Synthetic *demo* data is fine and should be clearly
  labelled as synthetic in the presentation.

---

## 6. Files

The two source documents live in the previous session's uploads:

- `1.pdf` — the recruiter's brief email (Jamie MacMillan, 15 Sept 2026)
- `Senior BI Analyst - OJA 1.docx` — the job spec

If they aren't attached in the new session, ask Vlad to re-attach or point to them on his machine.
Deliverables (CSVs, DAX files, presentation notes) should be written to a folder Vlad connects,
or delivered into the chat if no folder is connected.

---

## 7. First move in the new session

Confirm with Vlad: (a) which dashboard scenario, (b) whether he has real or sample data he'd
rather use, (c) what to build first. Then work. Deadline is Monday 21 September 2026, 1:00 PM.
