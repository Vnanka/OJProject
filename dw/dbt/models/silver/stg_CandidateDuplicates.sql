-- stg_CandidateDuplicates.sql
-- -----------------------------------------------------------------------------
-- Silver: the CRM's list of candidate records that are the same person.
-- Grain: one row per duplicate (NewCandidateId).
--
-- The OLD id is the record we keep. Every model that carries a candidate id
-- replaces a NEW id with its OLD id, so one person is counted once.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'crm_candidate_duplicates') }}

)

select
    cast(old_candidate_id as integer)           as OldCandidateId,   -- keep this one
    cast(new_candidate_id as integer)           as NewCandidateId,   -- merged into the old one
    cast(date_modified as timestamp)            as ModifiedAt

from source
