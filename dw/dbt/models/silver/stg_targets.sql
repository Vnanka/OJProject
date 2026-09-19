-- stg_targets.sql
-- -----------------------------------------------------------------------------
-- Silver: monthly NFI targets from the FINANCE system.
-- Grain: one row per UserId and month.
--
-- The source gives the month as text ('2025-03'). Turning it into a real date
-- (the first day of that month) lets gold join it to dim_date.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'fin_targets') }}

)

select
    cast(user_id as integer)                                          as UserId,
    strptime(month || '-01', '%Y-%m-%d')::date                        as TargetMonthDate,
    cast(target_nfi_gbp as decimal(18, 2))                            as TargetNfiGbp,
    strptime(modified_at, '%d/%m/%Y %H:%M')                           as ModifiedAt

from source
