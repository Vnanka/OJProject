-- stg_status.sql
-- -----------------------------------------------------------------------------
-- Silver: the CRM's pipeline status lookup. Grain: one row per StatusCode.
--
-- Only the CRM's own codes and names. Which code counts as which FUNNEL STAGE
-- (e.g. 400 Submitted = "CV Sent") is a business definition, so that mapping
-- lives in gold, in dim_stage.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'crm_status') }}

)

select
    cast(candidate_joborder_status_id as integer) as StatusCode,
    short_description                             as StatusName,
    cast(date_modified as timestamp)              as ModifiedAt

from source
