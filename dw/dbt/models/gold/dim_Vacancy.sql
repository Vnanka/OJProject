-- dim_Vacancy.sql
-- -----------------------------------------------------------------------------
-- Gold: vacancies (job orders). Grain: one row per vacancy, plus -1.
-- Key = the CRM's JobOrderId.
--
-- Star schema: discipline is its own dimension, and the FACTS carry
-- DisciplineKey. Discipline is kept here as text for convenience; the ~30 blank
-- ones read 'Unknown', matching the -1 member of dim_Discipline.
--
-- Salary stays in the office's local currency (SalaryCurrency says which). It is
-- descriptive here; money that is reported (fees, NFI) is converted to GBP in
-- the facts.
-- -----------------------------------------------------------------------------

with jobs as (

    select * from {{ ref('stg_JobOrder') }}

),

offices as (

    select OfficeName, CurrencyCode from {{ ref('stg_Office') }}

)

select
    j.JobOrderId                                as VacancyKey,
    j.JobTitle,
    j.JobStatus,
    coalesce(j.Discipline, 'Unknown')           as Discipline,
    j.WorkArrangement,
    j.OwningOffice,
    j.City,
    j.CountryCode,
    j.Openings,
    j.SalaryText,
    j.SalaryMin,
    j.SalaryMax,
    o.CurrencyCode                              as SalaryCurrency,
    j.CreatedAt::date                           as CreatedDate,
    j.ExpectedStartDate

from jobs as j
left join offices as o
    on o.OfficeName = j.OwningOffice

union all

select -1, 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', null,
       null, null, null, null, null, null, null
