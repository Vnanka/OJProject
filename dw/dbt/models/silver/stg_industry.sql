-- stg_industry.sql
-- -----------------------------------------------------------------------------
-- Silver: the CRM's industry dropdown list. Grain: one row per SubSectorId.
--
-- Each row is a sub-sector and carries the industry it belongs to, so the list
-- is also the industry -> sub-sector hierarchy.
-- ValidTo NULL = still offered in the CRM dropdown.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'crm_industry') }}

)

select
    cast(sub_sector_id as integer)              as SubSectorId,
    sub_sector                                  as SubSector,
    cast(industry_id as integer)                as IndustryId,
    industry                                    as Industry,
    cast(valid_from as date)                    as ValidFrom,
    cast(valid_to as date)                      as ValidTo,
    cast(date_modified as timestamp)            as ModifiedAt

from source
