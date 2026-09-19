-- assert_fee_pct_positive.sql
-- -----------------------------------------------------------------------------
-- A "singular" test: a plain SELECT that returns the BAD rows.
-- dbt runs it and the test passes only if it returns nothing.
--
-- A fee of 0% (or less) is not a real placement fee. The built-in not_null test
-- cannot catch this, because 0 is not NULL - so we write the rule ourselves.
-- Planted problem: 1 placement has FeePct = 0.
-- -----------------------------------------------------------------------------

{{ config(severity = 'warn') }}

select PlacementRef, FeePct
from {{ ref('stg_Placements') }}
where FeePct <= 0
