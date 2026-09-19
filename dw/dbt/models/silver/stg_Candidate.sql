-- stg_Candidate.sql
-- -----------------------------------------------------------------------------
-- Silver: candidates. Grain: one row per REAL person (CandidateId).
--
-- The one allowed join in silver: applying the CRM's own duplicate-merge list.
-- Records that were merged into an older record are dropped here, so each
-- person appears once. This is cleaning, not business logic.
--
-- No personal data exists in the source by design (GDPR) - only the id, the
-- relocation flag and dates.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'crm_candidate') }}

),

duplicates as (

    select NewCandidateId from {{ ref('stg_CandidateDuplicates') }}

)

select
    cast(candidate_id as integer)               as CandidateId,
    cast(can_relocate as boolean)               as CanRelocate,      -- '1' / '0' -> true / false
    cast(date_created as timestamp)             as CreatedAt,
    cast(date_modified as timestamp)            as ModifiedAt

from source
where cast(candidate_id as integer) not in (select NewCandidateId from duplicates)
