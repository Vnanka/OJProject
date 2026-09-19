-- assert_fact_Target_reconciles.sql
-- -----------------------------------------------------------------------------
-- Three checks in one: the fact must have
--   * the same number of rows as silver,
--   * the same total target (to the penny), and
--   * at most one row per consultant per month.
-- Returns a row describing any failure; passes when empty.
-- -----------------------------------------------------------------------------

with silver as (
    select count(*) as n, sum(TargetNfiGbp) as total from {{ ref('stg_Targets') }}
),

gold as (
    select count(*) as n, sum(TargetNfiGbp) as total from {{ ref('fact_Target') }}
),

dupes as (
    select count(*) as n from (
        select ConsultantKey, DateKey from {{ ref('fact_Target') }}
        group by ConsultantKey, DateKey having count(*) > 1
    )
)

select silver.n as silver_rows, gold.n as gold_rows,
       silver.total as silver_total, gold.total as gold_total,
       dupes.n as duplicated_consultant_months
from silver, gold, dupes
where silver.n <> gold.n or silver.total <> gold.total or dupes.n > 0
