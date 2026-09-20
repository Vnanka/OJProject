-- dim_Client.sql
-- -----------------------------------------------------------------------------
-- Gold: clients. Grain: one row per client, plus -1. Key = the CRM's CompanyId.
--
-- Star schema: industry is its own dimension, and the FACTS carry IndustryKey.
-- Industry and SubSector are kept here as plain text only for convenience
-- (e.g. a client detail table); they are not a relationship.
-- -----------------------------------------------------------------------------

-- Columns are renamed to the gold naming standard in one place at the end:
--   keys and numeric fact columns -> all lowercase (consultantkey, netamountgbp)
--   attributes people see         -> readable English ("Client Industry")
-- The logic above is untouched.

select
    ClientKey as clientkey,
    ClientName as "Client Name",
    City as "Client City",
    CountryCode as "Client Country",
    Industry as "Client Industry",
    SubSector as "Client Sub-sector",
    ClientSinceDate as "Client Since Date"

from (

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

) as renamed
