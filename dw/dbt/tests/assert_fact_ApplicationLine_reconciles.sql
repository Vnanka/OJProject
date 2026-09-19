-- assert_fact_ApplicationLine_reconciles.sql
-- -----------------------------------------------------------------------------
-- The line fact must be the event log, complete and unchanged:
--   * the same number of rows as silver (nothing lost, nothing duplicated), and
--   * every application in the line fact must exist in the header fact.
-- Returns a row describing any failure; passes when empty.
-- -----------------------------------------------------------------------------

with silver as (
    select count(*) as n from {{ ref('stg_StatusHistory') }}
),

gold as (
    select count(*) as n from {{ ref('fact_ApplicationLine') }}
),

orphans as (
    select count(*) as n
    from {{ ref('fact_ApplicationLine') }} as l
    where not exists (
        select 1 from {{ ref('fact_Application') }} as a
        where a.ApplicationId = l.ApplicationId
    )
)

select silver.n as silver_rows, gold.n as gold_rows,
       orphans.n as lines_without_an_application
from silver, gold, orphans
where silver.n <> gold.n or orphans.n > 0
