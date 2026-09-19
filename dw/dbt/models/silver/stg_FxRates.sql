-- stg_FxRates.sql
-- -----------------------------------------------------------------------------
-- Silver: daily ECB exchange rates. Grain: one row per RateDate + CurrencyCode.
--
-- Bronze holds the whole API response as ONE row of JSON text:
--     { "base": "GBP",
--       "rates": { "2023-04-03": { "EUR": 1.1391, "USD": 1.2382, ... },
--                  "2023-04-04": { ... }, ... } }
--
-- We unpack it in three steps:
--     1. read "rates" as a map of  date -> (currency -> rate)
--     2. one row per date          (unnest the outer map)
--     3. one row per currency      (unnest the inner map)
--
-- RatePerGbp = how many units of that currency one pound buys.
-- No rows exist for weekends or ECB holidays - that is the source, not a bug.
-- Averaging to a monthly rate is a business rule, so it happens in gold.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'api_fx_rates') }}

),

rates_map as (

    select cast(json_extract(content, '$.rates') as map(varchar, map(varchar, double))) as rates
    from source

),

one_row_per_day as (

    select unnest(map_entries(rates)) as day_entry
    from rates_map

),

one_row_per_currency as (

    select
        day_entry.key                           as rate_date,
        unnest(map_entries(day_entry.value))    as currency_entry
    from one_row_per_day

)

select
    cast(rate_date as date)                     as RateDate,
    currency_entry.key                          as CurrencyCode,
    currency_entry.value                        as RatePerGbp

from one_row_per_currency
