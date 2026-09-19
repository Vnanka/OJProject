-- stg_joborder.sql
-- -----------------------------------------------------------------------------
-- Silver: vacancies from the CRM. Grain: one row per JobOrderId.
--
-- The interesting part is SALARY. Consultants type it as free text:
--     '£70k - £85k'   '74000'   '154,000'   'CHF 120k'   'Competitive'
-- We keep the original text (SalaryText) and parse it into SalaryMin and
-- SalaryMax, in the office's LOCAL currency:
--     1. remove thousand separators          '154,000'     -> '154000'
--     2. pull out every number, with its k   '£70k - £85k' -> ['70k', '85k']
--     3. 'k' means thousands                 ['70k', '85k'] -> [70000, 85000]
--     4. min and max of that list            one number -> min = max
-- Text with no number ('Competitive') gives NULL. That is expected, and a
-- test counts it (warn), rather than a silent guess.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'crm_joborder') }}

),

salary_parsed as (

    select
        *,
        list_transform(
            regexp_extract_all(replace(salary, ',', ''), '\d+k?'),
            x -> cast(rtrim(x, 'k') as decimal(18, 2))
                 * case when x like '%k' then 1000 else 1 end
        ) as salary_numbers
    from source

)

select
    -- keys
    cast(joborder_id as integer)                as JobOrderId,
    cast(company_id as integer)                 as CompanyId,
    cast(recruiter as integer)                  as RecruiterUserId,  -- the consultant working the job
    cast(owner as integer)                      as OwnerUserId,

    -- descriptive
    title                                       as JobTitle,
    type                                        as JobTypeCode,      -- 'H' = perm hire
    status                                      as JobStatus,
    discipline                                  as Discipline,       -- ~30 are NULL (planted problem)
    work_arrangement                            as WorkArrangement,
    owning_office                               as OwningOffice,
    city                                        as City,
    country                                     as CountryCode,
    cast(openings as integer)                   as Openings,

    -- salary: original text kept for audit, parsed values in local currency
    salary                                      as SalaryText,
    list_min(salary_numbers)                    as SalaryMin,
    list_max(salary_numbers)                    as SalaryMax,

    -- dates
    cast(start_date as timestamp)::date         as ExpectedStartDate,
    cast(date_created as timestamp)             as CreatedAt,
    cast(date_modified as timestamp)            as ModifiedAt

from salary_parsed
