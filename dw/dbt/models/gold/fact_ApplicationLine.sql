-- fact_ApplicationLine.sql
-- -----------------------------------------------------------------------------
-- Gold fact: one row per STATUS CHANGE (the event log). The "line" half of the
-- header/line pair - fact_Application is the header, one row per application.
-- Kimball calls this a transaction fact: every row is one thing that happened.
--
-- Why both facts exist:
--   fact_Application answers "how many applications reached interview?" (cohort)
--   fact_ApplicationLine answers "how much activity happened in October?" and
--   "where does the pipeline slow down?" - questions the header cannot answer,
--   because the header keeps only the FIRST time each stage was reached.
--
-- Agreed design (19 Sep):
--   * Key = the CRM's own StatusHistoryId. Already unique, so nothing invented.
--   * ApplicationId is a PLAIN COLUMN, not a relationship: in Power BI the two
--     facts are never joined to each other, only to the shared dimensions.
--   * dim_Stage plays two roles, like dim_Date does for the milestone dates:
--       StatusToKey   = the stage moved INTO   (active relationship)
--       StatusFromKey = the stage moved OUT OF (inactive, USERELATIONSHIP)
--     status_from is 0 on the first event of an application, and dim_Stage
--     already has a 0 "No Status" member, so it joins without a -1.
--   * Every dimension key is copied onto the row (star schema), using the same
--     joins as fact_Application, so field parameters work on both facts.
--   * DaysInPreviousStage = days since the previous event of the same
--     application. Blank on the first event: there is no previous stage, and
--     that is "hasn't happened", not "unknown".
-- -----------------------------------------------------------------------------

-- Columns are renamed to the gold naming standard in one place at the end:
--   keys and numeric fact columns -> all lowercase (consultantkey, netamountgbp)
--   attributes people see         -> readable English ("Client Industry")
-- The logic above is untouched.

select
    ApplicationLineId as applicationlineid,
    ApplicationId as applicationid,
    CandidateId as candidateid,
    VacancyKey as vacancykey,
    ClientKey as clientkey,
    IndustryKey as industrykey,
    DisciplineKey as disciplinekey,
    ConsultantKey as consultantkey,
    OfficeKey as officekey,
    StatusToKey as statustokey,
    StatusFromKey as statusfromkey,
    EventDateKey as eventdatekey,
    EventAt as "Event At",
    DaysInPreviousStage as daysinpreviousstage

from (

with events as (

    select
        StatusHistoryId,
        CandidateId,
        JobOrderId,
        EventAt,
        StatusFromCode,
        StatusToCode,
        -- the previous event of the SAME application, in time order
        lag(EventAt) over (
            partition by CandidateId, JobOrderId
            order by EventAt, StatusHistoryId
        ) as PreviousEventAt
    from {{ ref('stg_StatusHistory') }}

),

jobs as (

    select JobOrderId, CompanyId, RecruiterUserId, Discipline, OwningOffice
    from {{ ref('stg_JobOrder') }}

),

companies   as (select CompanyId, SubSector     from {{ ref('stg_Company') }}),
industries  as (select SubSectorId, SubSector   from {{ ref('stg_Industry') }}),
disciplines as (select DisciplineId, Discipline from {{ ref('stg_Discipline') }}),
offices     as (select officekey as OfficeKey, "Office Name" as OfficeName    from {{ ref('dim_Office') }}),
consultants as (select consultantkey as ConsultantKey            from {{ ref('dim_Consultant') }}),
stages      as (select stagekey as StageKey                 from {{ ref('dim_Stage') }})

select
    -- identifiers
    e.StatusHistoryId                                                as ApplicationLineId,
    cast(e.CandidateId as bigint) * 100000 + e.JobOrderId            as ApplicationId,
    e.CandidateId,

    -- dimension keys (-1 = Unknown)
    coalesce(j.JobOrderId, -1)                                       as VacancyKey,
    coalesce(j.CompanyId, -1)                                        as ClientKey,
    coalesce(i.SubSectorId, -1)                                      as IndustryKey,
    coalesce(d.DisciplineId, -1)                                     as DisciplineKey,
    coalesce(c.ConsultantKey, -1)                                    as ConsultantKey,
    coalesce(o.OfficeKey, -1)                                        as OfficeKey,

    -- dim_Stage twice: where the application went, and where it came from
    coalesce(sto.StageKey, -1)                                       as StatusToKey,
    coalesce(sfrom.StageKey, -1)                                     as StatusFromKey,

    -- when it happened
    cast(strftime(e.EventAt, '%Y%m%d') as integer)                   as EventDateKey,
    e.EventAt,

    -- how long the application sat in the stage it has just left
    -- (blank on the first event: there was no previous stage)
    datediff('day', e.PreviousEventAt, e.EventAt)                    as DaysInPreviousStage

from events as e
left join jobs        as j     on j.JobOrderId    = e.JobOrderId
left join companies   as co    on co.CompanyId    = j.CompanyId
left join industries  as i     on i.SubSector     = co.SubSector
left join disciplines as d     on d.Discipline    = j.Discipline
left join consultants as c     on c.ConsultantKey = j.RecruiterUserId
left join offices     as o     on o.OfficeName    = j.OwningOffice
left join stages      as sto   on sto.StageKey    = e.StatusToCode
left join stages      as sfrom on sfrom.StageKey  = e.StatusFromCode

) as renamed
