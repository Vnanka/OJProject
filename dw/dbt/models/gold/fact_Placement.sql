-- fact_Placement.sql
-- -----------------------------------------------------------------------------
-- Gold fact: one row per PLACEMENT (one filled position), from the finance
-- system - the system of record for fees.
--
-- Agreed design (19 Sep):
--   * Identifier: PlacementRef, plus ApplicationId (same formula as
--     fact_Application) to match a placement to its application. The two facts
--     are NOT related in Power BI; both connect to the same dimensions.
--   * Consultant and office come from FINANCE (who the revenue is booked to).
--     They matched the CRM on all 4,714 placements on 19 Sep.
--   * Other keys (vacancy, client, industry, discipline) come through the job.
--   * Dates: PlacedDateKey is the active date. StartDateKey / LeaveDateKey are
--     inactive, and BLANK when the event hasn't happened (never -1: nothing is
--     missing, the candidate simply hasn't left).
--   * Money: salary, fee % and booked fee (salary x fee %) in local currency AND
--     in GBP, converted at the monthly average rate of the month it was placed.
--   * Fee %: exactly what finance recorded. The 3 blank / zero values are NOT
--     patched - they are reported by the silver tests and investigated with the
--     data owner first (Vlad: don't fix data just to make the numbers match).
--     Their booked fee is therefore blank (or 0 for the 0% one).
--   * IsFallOff: finance records a leave date only when the candidate left
--     inside the guarantee period, so a recorded leave date = a fall-off.
--   * DaysToFill: vacancy opened -> first offer on this application.
-- -----------------------------------------------------------------------------

with placements as (

    select * from {{ ref('stg_Placements') }}

),

offers as (

    -- the first offer on each application (time-to-fill ends here)
    select CandidateId, JobOrderId, min(EventAt) as OfferAt
    from {{ ref('stg_StatusHistory') }}
    where StatusToCode = 600
    group by CandidateId, JobOrderId

),

jobs as (

    select JobOrderId, CompanyId, Discipline, CreatedAt
    from {{ ref('stg_JobOrder') }}

),

fx          as (select MonthStartDate, CurrencyCode, RatePerGbp from {{ ref('dim_FxRateMonthly') }}),
companies   as (select CompanyId, SubSector       from {{ ref('stg_Company') }}),
industries  as (select SubSectorId, SubSector     from {{ ref('stg_Industry') }}),
disciplines as (select DisciplineId, Discipline   from {{ ref('stg_Discipline') }}),
offices     as (select OfficeKey, OfficeName      from {{ ref('dim_Office') }}),
consultants as (select ConsultantKey              from {{ ref('dim_Consultant') }}),
candidates  as (select CandidateId, CanRelocate   from {{ ref('stg_Candidate') }})

select
    -- identifiers
    p.PlacementRef,
    cast(p.CandidateId as bigint) * 100000 + p.JobOrderId                        as ApplicationId,
    p.CandidateId,

    -- dimension keys (-1 = Unknown)
    coalesce(j.JobOrderId, -1)                                                   as VacancyKey,
    coalesce(j.CompanyId, -1)                                                    as ClientKey,
    coalesce(i.SubSectorId, -1)                                                  as IndustryKey,
    coalesce(d.DisciplineId, -1)                                                 as DisciplineKey,
    coalesce(c.ConsultantKey, -1)                                                as ConsultantKey,
    coalesce(o.OfficeKey, -1)                                                    as OfficeKey,

    -- dates (Start / Leave are blank when they haven't happened)
    coalesce(cast(strftime(p.PlacedDate, '%Y%m%d') as integer), -1)             as PlacedDateKey,
    cast(strftime(p.StartDate, '%Y%m%d') as integer)                            as StartDateKey,
    cast(strftime(p.LeaveDate, '%Y%m%d') as integer)                            as LeaveDateKey,

    -- money: local currency, as finance recorded it
    p.CurrencyCode,
    p.Salary                                                                     as SalaryLocal,
    p.FeePct,
    cast(p.Salary * p.FeePct / 100 as decimal(18, 2))                            as BookedFeeLocal,

    -- money: GBP, at the monthly average rate of the placed month.
    -- Cast to decimal: money must be exact, never floating point.
    cast(p.Salary / fx.RatePerGbp as decimal(18, 2))                             as SalaryGbp,
    cast(p.Salary * p.FeePct / 100 / fx.RatePerGbp as decimal(18, 2))           as BookedFeeGbp,

    -- fall-off and speed
    cast(p.LeaveDate is not null as integer)                                     as IsFallOff,
    datediff('day', p.StartDate, p.LeaveDate) // 7 + 1                           as WeeksWorked,     -- blank if no fall-off
    datediff('day', j.CreatedAt, ofr.OfferAt)                                    as DaysToFill,

    -- candidate attribute copied onto the fact (no candidate dimension, by design)
    cand.CanRelocate

from placements as p
left join jobs        as j    on j.JobOrderId     = p.JobOrderId
left join companies   as co   on co.CompanyId     = j.CompanyId
left join industries  as i    on i.SubSector      = co.SubSector
left join disciplines as d    on d.Discipline     = j.Discipline
left join consultants as c    on c.ConsultantKey  = p.ConsultantUserId
left join offices     as o    on o.OfficeName     = p.BookingOffice
left join candidates  as cand on cand.CandidateId = p.CandidateId
left join offers      as ofr  on ofr.CandidateId  = p.CandidateId
                             and ofr.JobOrderId   = p.JobOrderId
left join fx                  on fx.CurrencyCode   = p.CurrencyCode
                             and fx.MonthStartDate = date_trunc('month', p.PlacedDate)::date
