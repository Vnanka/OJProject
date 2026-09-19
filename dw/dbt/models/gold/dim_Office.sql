-- dim_Office.sql
-- -----------------------------------------------------------------------------
-- Gold: offices. Grain: one row per office, plus the -1 Unknown row.
-- Built from the office reference list, not from values found in the facts.
-- Every attribute, including the region sort order, comes from that list.
--
-- The source has no ID (only the office name), so the warehouse generates the
-- key. row_number() over the name is stable while the list is stable; adding a
-- new office can renumber the others, which is fine for a full-rebuild model
-- (facts and dimension are rebuilt together) - an incremental model would need
-- a permanent key instead.
-- -----------------------------------------------------------------------------

with offices as (

    select * from {{ ref('stg_Office') }}

)

select
    cast(row_number() over (order by OfficeName) as integer)  as OfficeKey,
    OfficeName,
    City,
    CountryCode,
    CountryName,
    Region,
    RegionSortOrder,                                              -- sort Region by this in Power BI
    CurrencyCode

from offices

union all

select -1, 'Unknown', 'Unknown', null, 'Unknown', 'Unknown', 99, null
