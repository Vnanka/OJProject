-- stg_office.sql
-- -----------------------------------------------------------------------------
-- Silver: the office reference list. Grain: one row per office.
--
-- The CRM only stores an office NAME on users and jobs. Country, region and
-- currency come from this list, which the business maintains. It enters the
-- warehouse the same way as every other source: file -> bronze -> silver.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'ref_office') }}

)

select
    office_name                                 as OfficeName,
    city                                        as City,
    country_code                                as CountryCode,
    country_name                                as CountryName,
    region                                      as Region,
    cast(region_sort_order as integer)          as RegionSortOrder,
    currency_code                               as CurrencyCode,
    cast(last_updated as timestamp)             as ModifiedAt

from source
