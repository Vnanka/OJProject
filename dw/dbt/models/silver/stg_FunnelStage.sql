-- stg_FunnelStage.sql
-- -----------------------------------------------------------------------------
-- Silver: the funnel mapping. Grain: one row per CRM status code.
--
-- The business definition of the funnel is REFERENCE DATA, maintained outside
-- the code, not a CASE statement: changing what counts as "an interview" is a
-- data change the business owns, not a code release.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'ref_funnel_stage') }}

)

select
    cast(status_code as integer)                as StatusCode,
    funnel_stage                                as FunnelStage,
    cast(funnel_stage_order as integer)         as FunnelStageOrder,
    stage_type                                  as StageType,
    cast(last_updated as timestamp)             as ModifiedAt

from source
