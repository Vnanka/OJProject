-- dim_Stage.sql
-- -----------------------------------------------------------------------------
-- Gold: pipeline stages. Grain: one row per CRM status code, plus -1.
-- Key = the CRM's own status code.
--
-- No business rules in this file. It joins two sources:
--   stg_Status        - the CRM's status codes and names
--   stg_FunnelStage  - the business's funnel definition (reference data)
-- A silver test guarantees every CRM status has a funnel mapping, so this
-- inner join cannot silently drop a status.
--
-- -1 "Unknown exit": the facts point here for ANY status code that is not in
-- the CRM lookup (today: the 20 rows with code 999).
-- -----------------------------------------------------------------------------

-- Columns are renamed to the gold naming standard in one place at the end:
--   keys and numeric fact columns -> all lowercase (consultantkey, netamountgbp)
--   attributes people see         -> readable English ("Client Industry")
-- The logic above is untouched.

select
    StageKey as stagekey,
    StatusName as "Status Name",
    FunnelStage as "Funnel Stage",
    FunnelStageOrder as "Funnel Stage Order",
    StageType as "Stage Type"

from (

with statuses as (

    select * from {{ ref('stg_Status') }}

),

funnel as (

    select * from {{ ref('stg_FunnelStage') }}

)

select
    s.StatusCode                                as StageKey,
    s.StatusName,
    f.FunnelStage,
    f.FunnelStageOrder,                         -- sort FunnelStage by this in Power BI
    f.StageType

from statuses as s
inner join funnel as f
    on f.StatusCode = s.StatusCode

union all

select -1, 'Unknown status', 'Unknown exit', 7, 'Exit'

) as renamed
