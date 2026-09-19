-- assert_fx_rate_monthly_unique.sql
-- -----------------------------------------------------------------------------
-- Each currency must have exactly ONE rate per month. A duplicate would double
-- every converted amount in that month when facts join to it.
-- Returns the duplicated month + currency pairs; passes when empty.
-- -----------------------------------------------------------------------------

select YearMonthKey, CurrencyCode, count(*) as rows_found
from {{ ref('dim_FxRateMonthly') }}
group by YearMonthKey, CurrencyCode
having count(*) > 1
