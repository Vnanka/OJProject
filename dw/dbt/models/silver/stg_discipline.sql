-- stg_discipline.sql
-- -----------------------------------------------------------------------------
-- Silver: the CRM's discipline dropdown list. Grain: one row per DisciplineId.
-- ValidTo NULL = still offered in the CRM dropdown.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'crm_discipline') }}

)

select
    cast(discipline_id as integer)              as DisciplineId,
    discipline                                  as Discipline,
    cast(valid_from as date)                    as ValidFrom,
    cast(valid_to as date)                      as ValidTo,
    cast(date_modified as timestamp)            as ModifiedAt

from source
