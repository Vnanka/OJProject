-- fact_Target.sql
-- -----------------------------------------------------------------------------
-- Gold fact: monthly NFI targets. Grain: one row per consultant per month.
--
-- A DIFFERENT GRAIN from the other facts: month, not day. So:
--   * DateKey is the 1st of the month. Filter by whole months (month / quarter /
--     year); a mid-month date range would miss the month's target.
--   * Only consultant, office and date apply. Targets are not set per client,
--     industry, discipline or vacancy, so those columns are deliberately absent
--     (not -1): splitting a target by industry would repeat the same total on
--     every row.
--
-- Office = the consultant's office. The targets file has no office of its own;
-- nobody changes office in this data, so current = historic (a known limitation).
-- ConsultantKey also carries row-level security: managers see their team's
-- targets only.
-- -----------------------------------------------------------------------------

-- Columns are renamed to the gold naming standard in one place at the end:
--   keys and numeric fact columns -> all lowercase (consultantkey, netamountgbp)
--   attributes people see         -> readable English ("Client Industry")
-- The logic above is untouched.

select
    ConsultantKey as consultantkey,
    OfficeKey as officekey,
    DateKey as datekey,
    TargetNfiGbp as targetnfigbp

from (

with targets as (

    select * from {{ ref('stg_Targets') }}

),

users       as (select UserId, Office   from {{ ref('stg_User') }}),
consultants as (select consultantkey as ConsultantKey    from {{ ref('dim_Consultant') }}),
offices     as (select officekey as OfficeKey, "Office Name" as OfficeName from {{ ref('dim_Office') }})

select
    coalesce(c.ConsultantKey, -1)                                  as ConsultantKey,
    coalesce(o.OfficeKey, -1)                                      as OfficeKey,
    cast(strftime(t.TargetMonthDate, '%Y%m%d') as integer)        as DateKey,      -- 1st of the month
    cast(t.TargetNfiGbp as decimal(18, 2))                        as TargetNfiGbp

from targets as t
left join consultants as c on c.ConsultantKey = t.UserId
left join users       as u on u.UserId        = t.UserId
left join offices     as o on o.OfficeName    = u.Office

) as renamed
