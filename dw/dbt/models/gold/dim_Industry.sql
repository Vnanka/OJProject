-- dim_Industry.sql
-- -----------------------------------------------------------------------------
-- Gold: client industries. Grain: one row per sub-sector, plus -1 Unknown.
-- Holds the hierarchy Industry -> Sub-sector. Key = the CRM's own SubSectorId.
-- Built from the CRM's dropdown list, so members with no clients still exist.
-- -----------------------------------------------------------------------------

-- Columns are renamed to the gold naming standard in one place at the end:
--   keys and numeric fact columns -> all lowercase (consultantkey, netamountgbp)
--   attributes people see         -> readable English ("Client Industry")
-- The logic above is untouched.

select
    IndustryKey as industrykey,
    SubSector as "Sub-sector",
    Industry as "Industry",
    IndustrySortOrder as "Industry Sort Order",
    ValidFrom as "Valid From",
    ValidTo as "Valid To"

from (

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

) as renamed
