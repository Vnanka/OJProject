-- stg_StatusHistory.sql
-- -----------------------------------------------------------------------------
-- Silver: the pipeline event log. Grain: one row per status change.
--
-- Duplicate candidates are merged here (the one allowed join in silver):
--   CandidateId        = the real person, after merging duplicates
--   SourceCandidateId  = the id exactly as the CRM recorded it (kept for audit)
--
-- Status code 999 appears on a few rows and is NOT in the lookup - a planted
-- problem. It is kept here unchanged; a test flags it, and gold decides how to
-- show it.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'crm_status_history') }}

),

duplicates as (

    select OldCandidateId, NewCandidateId from {{ ref('stg_CandidateDuplicates') }}

)

select
    cast(s.candidate_joborder_status_history_id as integer)          as StatusHistoryId,
    coalesce(d.OldCandidateId, cast(s.candidate_id as integer))       as CandidateId,
    cast(s.candidate_id as integer)                                   as SourceCandidateId,
    cast(s.joborder_id as integer)                                    as JobOrderId,
    cast(s."date" as timestamp)                                       as EventAt,
    cast(s.status_from as integer)                                    as StatusFromCode,
    cast(s.status_to as integer)                                      as StatusToCode,
    cast(s.date_modified as timestamp)                                as ModifiedAt

from source as s
left join duplicates as d
    on d.NewCandidateId = cast(s.candidate_id as integer)
