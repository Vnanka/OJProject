-- stg_Company.sql
-- -----------------------------------------------------------------------------
-- Silver: clients from the CRM. Grain: one row per CompanyId.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'crm_company') }}

)

select
    cast(company_id as integer)                 as CompanyId,
    name                                        as CompanyName,
    city                                        as City,
    country                                     as CountryCode,     -- 2-letter code, e.g. GB
    cast(owner as integer)                      as OwnerUserId,     -- account owner
    industry                                    as Industry,
    sub_sector                                  as SubSector,
    cast(date_created as timestamp)             as CreatedAt,
    cast(date_modified as timestamp)            as ModifiedAt

from source
