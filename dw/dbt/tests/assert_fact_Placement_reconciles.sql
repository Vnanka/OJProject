-- assert_fact_Placement_reconciles.sql
-- -----------------------------------------------------------------------------
-- Row-count reconciliation: exactly one fact row per placement in silver.
-- Returns a row only when the counts differ; passes when empty.
-- -----------------------------------------------------------------------------

with expected as (select count(*) as n from {{ ref('stg_Placements') }}),
     actual   as (select count(*) as n from {{ ref('fact_Placement') }})

select expected.n as expected_rows, actual.n as fact_rows
from expected, actual
where expected.n <> actual.n
