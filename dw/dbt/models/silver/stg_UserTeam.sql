-- stg_UserTeam.sql
-- -----------------------------------------------------------------------------
-- Silver: the row-level security access list. Grain: one row per Email + Team.
--
-- Email is lower-cased so the RLS match in Power BI never depends on how
-- someone typed their address.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'sec_user_team') }}

)

select
    lower(user_email)                                                 as Email,
    team                                                              as Team,
    role_description                                                  as RoleDescription,
    cast(last_updated as timestamp)                                   as ModifiedAt

from source
