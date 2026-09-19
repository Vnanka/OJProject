-- fact_Application.sql
-- -----------------------------------------------------------------------------
-- Gold fact: one row per APPLICATION (one candidate on one vacancy).
-- Kimball "accumulating snapshot": the row records WHERE the application got to
-- and WHEN, filling in milestone dates as the process moves forward.
--
-- Agreed design (19 Sep):
--   * ApplicationId = candidate and vacancy combined into one big integer, so the
--     same application gets the same id on every rebuild.
--   * Milestones = the FIRST time each funnel stage was reached, i.e. the date the
--     application ENTERED the stage. (Interview meetings and reschedules live in
--     the CRM calendar, which is not modelled.)
--   * Milestones are found by the CRM's own status codes (Vlad's choice: they are
--     fixed system values, and it avoids a join just to filter on text):
--         400 Submitted = CV sent, 500 Interviewing, 600 Offered, 800 Placed.
--     An EXIT is any status that is not one of those four progress steps. That
--     is safe because an application's history always starts at 400, and it
--     means an unknown code (e.g. 999) still counts as an exit -> -1 in dim_Stage.
--   * Credit goes to the consultant working the job (CRM column `recruiter`); the
--     office is the job's office, fixed on the row at build time.
--   * All data from 1 Oct 2022 (CRM go-live) is kept.
--   * Star schema: every dimension key sits on the row; -1 = Unknown.
--
-- Active date for Power BI: SubmittedDateKey (cohort view). The other milestone
-- dates are inactive relationships, used with USERELATIONSHIP() for activity
-- counts ("interviews in October").
-- -----------------------------------------------------------------------------

with events as (

    select CandidateId, JobOrderId, StatusHistoryId, EventAt, StatusToCode
    from {{ ref('stg_StatusHistory') }}

),

milestones as (

    select
        CandidateId,
        JobOrderId,
        min(EventAt) filter (where StatusToCode = 400)                         as SubmittedAt,
        min(EventAt) filter (where StatusToCode = 500)                         as InterviewAt,
        min(EventAt) filter (where StatusToCode = 600)                         as OfferAt,
        min(EventAt) filter (where StatusToCode = 800)                         as PlacedAt,
        -- exit = any status that is not a progress step (includes unknown codes)
        min(EventAt) filter (where StatusToCode not in (400, 500, 600, 800))   as ExitAt
    from events
    group by CandidateId, JobOrderId

),

latest as (

    -- the most recent status of each application = its current stage
    select CandidateId, JobOrderId, StatusToCode as CurrentStatusCode
    from events
    qualify row_number() over (
        partition by CandidateId, JobOrderId
        order by EventAt desc, StatusHistoryId desc
    ) = 1

),

jobs as (

    select JobOrderId, CompanyId, RecruiterUserId, Discipline, OwningOffice
    from {{ ref('stg_JobOrder') }}

),

companies   as (select CompanyId, SubSector       from {{ ref('stg_Company') }}),
industries  as (select SubSectorId, SubSector     from {{ ref('stg_Industry') }}),
disciplines as (select DisciplineId, Discipline   from {{ ref('stg_Discipline') }}),
offices     as (select OfficeKey, OfficeName      from {{ ref('dim_Office') }}),
consultants as (select ConsultantKey              from {{ ref('dim_Consultant') }}),
stages      as (select StageKey                   from {{ ref('dim_Stage') }}),
candidates  as (select CandidateId, CanRelocate   from {{ ref('stg_Candidate') }})

select
    -- identifiers
    cast(m.CandidateId as bigint) * 100000 + m.JobOrderId                        as ApplicationId,
    m.CandidateId,

    -- dimension keys (-1 = Unknown)
    coalesce(j.JobOrderId, -1)                                                   as VacancyKey,
    coalesce(j.CompanyId, -1)                                                    as ClientKey,
    coalesce(i.SubSectorId, -1)                                                  as IndustryKey,
    coalesce(d.DisciplineId, -1)                                                 as DisciplineKey,
    coalesce(c.ConsultantKey, -1)                                                as ConsultantKey,
    coalesce(o.OfficeKey, -1)                                                    as OfficeKey,
    coalesce(st.StageKey, -1)                                                    as CurrentStageKey,

    -- milestone dates as dim_Date keys
    --   Submitted should always exist, so a missing one is a real unknown -> -1.
    --   The others are BLANK when the stage was never reached: nothing is missing,
    --   the event simply hasn't happened (-1 is only for genuinely unknown values).
    coalesce(cast(strftime(m.SubmittedAt, '%Y%m%d') as integer), -1)            as SubmittedDateKey,
    cast(strftime(m.InterviewAt, '%Y%m%d') as integer)                          as InterviewDateKey,
    cast(strftime(m.OfferAt,     '%Y%m%d') as integer)                          as OfferDateKey,
    cast(strftime(m.PlacedAt,    '%Y%m%d') as integer)                          as PlacedDateKey,
    cast(strftime(m.ExitAt,      '%Y%m%d') as integer)                          as ExitDateKey,

    -- reached flags as 0/1, so SUM() counts them
    cast(m.InterviewAt is not null as integer)                                   as ReachedInterview,
    cast(m.OfferAt     is not null as integer)                                   as ReachedOffer,
    cast(m.PlacedAt    is not null as integer)                                   as IsPlaced,
    cast(m.ExitAt      is not null as integer)                                   as IsExited,
    cast(m.PlacedAt is null and m.ExitAt is null as integer)                     as IsOpen,       -- still in progress

    -- speed, in days from the CV being sent (NULL = stage not reached)
    datediff('day', m.SubmittedAt, m.InterviewAt)                                as DaysToInterview,
    datediff('day', m.SubmittedAt, m.OfferAt)                                    as DaysToOffer,
    datediff('day', m.SubmittedAt, m.PlacedAt)                                   as DaysToPlaced,

    -- candidate attribute copied onto the fact (no candidate dimension, by design)
    cand.CanRelocate

from milestones as m
left join latest      as l    on l.CandidateId    = m.CandidateId
                             and l.JobOrderId     = m.JobOrderId
left join jobs        as j    on j.JobOrderId     = m.JobOrderId
left join companies   as co   on co.CompanyId     = j.CompanyId
left join industries  as i    on i.SubSector      = co.SubSector
left join disciplines as d    on d.Discipline     = j.Discipline
left join consultants as c    on c.ConsultantKey  = j.RecruiterUserId
left join offices     as o    on o.OfficeName     = j.OwningOffice
left join stages      as st   on st.StageKey      = l.CurrentStatusCode
left join candidates  as cand on cand.CandidateId = m.CandidateId
