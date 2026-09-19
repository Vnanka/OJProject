-- stg_BankHolidays.sql
-- -----------------------------------------------------------------------------
-- Silver: UK bank holidays from gov.uk. Grain: one row per Division + date.
--
-- Bronze holds the API response as ONE row of JSON text:
--     { "england-and-wales": { "events": [ {"title": ..., "date": ...}, ... ] },
--       "scotland":          { "events": [ ... ] },
--       "northern-ireland":  { "events": [ ... ] } }
--
-- We keep all three divisions. Which one applies (England & Wales, for the
-- Manchester and London offices) is decided in gold, in dim_Date.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'api_bank_holidays') }}

),

one_row_per_division as (

    select
        unnest(json_keys(content))              as division,
        content
    from source

),

one_row_per_holiday as (

    select
        division,
        unnest(cast(json_extract(content, '$."' || division || '".events') as json[])) as event
    from one_row_per_division

)

select
    division                                    as Division,
    cast(event ->> 'date' as date)              as HolidayDate,
    event ->> 'title'                           as HolidayName

from one_row_per_holiday
