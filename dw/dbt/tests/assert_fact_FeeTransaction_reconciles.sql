-- assert_fact_FeeTransaction_reconciles.sql
-- -----------------------------------------------------------------------------
-- Two reconciliations against silver, per currency:
--   * the number of documents must match (nothing lost, nothing duplicated)
--   * the local-currency TOTAL must match to the penny (the money itself)
-- This is the check a finance team trusts: "does the report add up to the
-- ledger?" Returns the currencies that don't match; passes when empty.
-- -----------------------------------------------------------------------------

with silver as (
    select CurrencyCode, count(*) as docs, sum(NetAmountLocal) as amount
    from {{ ref('stg_Transactions') }}
    group by CurrencyCode
),

gold as (
    -- gold uses the report naming standard: "Document Currency", netamountlocal
    select "Document Currency" as CurrencyCode,
           count(*) as docs,
           sum(netamountlocal) as amount
    from {{ ref('fact_FeeTransaction') }}
    group by "Document Currency"
)

select
    coalesce(s.CurrencyCode, g.CurrencyCode) as CurrencyCode,
    s.docs as silver_docs, g.docs as gold_docs,
    s.amount as silver_amount, g.amount as gold_amount
from silver as s
full outer join gold as g on g.CurrencyCode = s.CurrencyCode
where s.docs is distinct from g.docs
   or s.amount is distinct from g.amount
