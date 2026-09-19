-- dim_Industry.sql
-- -----------------------------------------------------------------------------
-- Gold: client industries. Grain: one row per sub-sector, plus -1 Unknown.
-- Holds the hierarchy Industry -> Sub-sector. Key = the CRM's own SubSectorId.
-- Built from the CRM's dropdown list, so members with no clients still exist.
-- -----------------------------------------------------------------------------

with industries as (

    select * from {{ ref('stg_Industry') }}

)

select
    SubSectorId                                 as IndustryKey,
    SubSector,
    Industry,
    IndustryId                                  as IndustrySortOrder,   -- sort Industry by this in Power BI
    ValidFrom,
    ValidTo

from industries

union all

select -1, 'Unknown', 'Unknown', 99, null, null
