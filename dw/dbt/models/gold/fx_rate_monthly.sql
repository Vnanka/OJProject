-- fx_rate_monthly.sql
-- -----------------------------------------------------------------------------
-- Gold helper: monthly average exchange rates.
-- Grain: one row per month and currency.
--
-- Money is converted to GBP with the AVERAGE rate of the document's month:
--     amount in GBP = amount in local currency / RatePerGbp
-- This is what finance teams do for reporting, and it solves a real gap in the
-- source: the ECB publishes nothing on weekends and holidays, so a Saturday
-- invoice has no daily rate - but it always has a monthly one.
--
-- GBP is added with a rate of 1.0 for every month. That is not a business rule,
-- it is the identity £1 = £1, and it lets every transaction (GBP included) be
-- converted with the same join.
--
-- RateDaysUsed = how many ECB publication days went into the average (audit).
-- -----------------------------------------------------------------------------

with daily as (

    select * from {{ ref('stg_fx_rates') }}

),

monthly as (

    select
        date_trunc('month', RateDate)::date     as MonthStartDate,
        CurrencyCode,
        avg(RatePerGbp)                         as RatePerGbp,
        count(*)                                as RateDaysUsed
    from daily
    group by 1, 2

),

gbp as (

    select distinct
        MonthStartDate,
        'GBP'                                   as CurrencyCode,
        1.0                                     as RatePerGbp
    from monthly

)

select
    MonthStartDate,
    year(MonthStartDate) * 100 + month(MonthStartDate)   as YearMonthKey,
    CurrencyCode,
    RatePerGbp,
    RateDaysUsed
from monthly

union all

select
    MonthStartDate,
    year(MonthStartDate) * 100 + month(MonthStartDate),
    CurrencyCode,
    RatePerGbp,
    null                                        -- no ECB rate needed for GBP
from gbp
