-- dim_Client.sql
-- -----------------------------------------------------------------------------
-- Gold: clients. Grain: one row per client, plus -1. Key = the CRM's CompanyId.
--
-- Star schema: industry is its own dimension, and the FACTS carry IndustryKey.
-- Industry and SubSector are kept here as plain text only for convenience
-- (e.g. a client detail table); they are not a relationship.
-- -----------------------------------------------------------------------------

with companies as (

    select * from {{ ref('stg_Company') }}

)

select
    CompanyId                                   as ClientKey,
    CompanyName                                 as ClientName,
    City,
    CountryCode,
    Industry,
    SubSector,
    CreatedAt::date                             as ClientSinceDate

from companies

union all

select -1, 'Unknown', 'Unknown', null, 'Unknown', 'Unknown', null
