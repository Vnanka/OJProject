-- dim_discipline.sql
-- -----------------------------------------------------------------------------
-- Gold: job disciplines. Grain: one row per discipline, plus -1 Unknown.
-- Key = the CRM's own DisciplineId. The ~30 jobs with a blank discipline point
-- at -1, so they show as "Unknown" instead of "(Blank)" and never drop out.
-- -----------------------------------------------------------------------------

with disciplines as (

    select * from {{ ref('stg_discipline') }}

)

select
    DisciplineId                                as DisciplineKey,
    Discipline,
    ValidFrom,
    ValidTo

from disciplines

union all

select -1, 'Unknown', null, null
