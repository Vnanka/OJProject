-- assert_every_transaction_has_fx_rate.sql
-- -----------------------------------------------------------------------------
-- Every invoice and credit note must find a monthly rate for its currency and
-- month. Without one, its GBP amount would silently become NULL and drop out of
-- every total. Returns the transactions with no rate; passes when empty.
-- -----------------------------------------------------------------------------

select t.DocumentNo, t.CurrencyCode, t.DocumentDate
from {{ ref('stg_Transactions') }} as t
left join {{ ref('dim_FxRateMonthly') }} as fx
    on  fx.CurrencyCode   = t.CurrencyCode
    and fx.MonthStartDate = date_trunc('month', t.DocumentDate)::date
where fx.RatePerGbp is null
