-- assert_fact_Application_reconciles.sql
-- -----------------------------------------------------------------------------
-- Row-count reconciliation: one fact row per distinct candidate x job in the
-- silver event log. Fewer = applications were lost; more = a join duplicated
-- rows. Key tests can't see either - they only check the rows that ARE there.
-- Returns a row only when the counts differ; passes when empty.
-- -----------------------------------------------------------------------------

with expected as (
    select count(*) as n
    from (select distinct CandidateId, JobOrderId from {{ ref('stg_StatusHistory') }})
),

actual as (
    select count(*) as n from {{ ref('fact_Application') }}
)

select expected.n as expected_rows, actual.n as fact_rows
from expected, actual
where expected.n <> actual.n
