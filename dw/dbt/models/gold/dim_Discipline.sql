-- dim_Discipline.sql
-- -----------------------------------------------------------------------------
-- Gold: job disciplines. Grain: one row per discipline, plus -1 Unknown.
-- Key = the CRM's own DisciplineId. The ~30 jobs with a blank discipline point
-- at -1, so they show as "Unknown" instead of "(Blank)" and never drop out.
-- -----------------------------------------------------------------------------

-- Columns are renamed to the gold naming standard in one place at the end:
--   keys and numeric fact columns -> all lowercase (consultantkey, netamountgbp)
--   attributes people see         -> readable English ("Client Industry")
-- The logic above is untouched.

select
    DisciplineKey as disciplinekey,
    Discipline as "Discipline",
    ValidFrom as "Valid From",
    ValidTo as "Valid To"

from (

with disciplines as (

    select * from {{ ref('stg_Discipline') }}

)

select
    DisciplineId                                as DisciplineKey,
    Discipline,
    ValidFrom,
    ValidTo

from disciplines

union all

select -1, 'Unknown', null, null

) as renamed
