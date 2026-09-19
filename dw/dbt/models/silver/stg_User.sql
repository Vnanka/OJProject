-- stg_User.sql
-- -----------------------------------------------------------------------------
-- Silver: CRM users (consultants and team managers).
-- Grain: one row per UserId.
--
-- Silver rules: read ONE bronze table, then only rename, cast and standardise.
-- No joins, no business logic - that belongs in gold.
--
-- `cast` (not `try_cast`) on purpose: an ID or a date that cannot be converted
-- is broken data, and the build should FAIL loudly rather than turn it into a
-- silent NULL.
--
-- Naming standard (all silver models): PascalCase. IDs end in Id, dates in
-- Date, timestamps in At.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'crm_user') }}

)

select
    -- keys
    cast(user_id as integer)                    as UserId,
    cast(manager_user_id as integer)            as ManagerUserId,   -- NULL for managers

    -- descriptive
    first_name                                  as FirstName,
    last_name                                   as LastName,
    lower(email)                                as Email,
    title                                       as Title,
    team                                        as Team,
    office                                      as Office,

    -- dates: the CRM account is created on the consultant's first day
    cast(date_created as timestamp)::date       as StartDate,
    cast(date_left as timestamp)::date          as LeaveDate,       -- NULL = still employed

    -- standard audit column, same name in every silver model
    cast(date_modified as timestamp)            as ModifiedAt

from source
