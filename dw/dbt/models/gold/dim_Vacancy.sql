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

-- Columns are renamed to the gold naming standard in one place at the end:
--   keys and numeric fact columns -> all lowercase (consultantkey, netamountgbp)
--   attributes people see         -> readable English ("Client Industry")
-- The logic above is untouched.

select
    VacancyKey as vacancykey,
    JobTitle as "Job Title",
    JobStatus as "Job Status",
    Discipline as "Vacancy Discipline",
    WorkArrangement as "Work Arrangement",
    OwningOffice as "Vacancy Owning Office",
    City as "Vacancy City",
    CountryCode as "Vacancy Country",
    Openings as "Openings",
    SalaryText as "Salary Text",
    SalaryMin as "Salary Min",
    SalaryMax as "Salary Max",
    SalaryCurrency as "Salary Currency",
    CreatedDate as "Created Date",
    ExpectedStartDate as "Expected Start Date"

from (

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

) as renamed
