-- stg_Placements.sql
-- -----------------------------------------------------------------------------
-- Silver: placements from the FINANCE system. Grain: one row per PlacementRef.
--
-- Finance writes dates UK-style ('14/03/2025'), unlike the CRM. We state the
-- format explicitly with strptime, so a day can never be read as a month.
--
-- Money stays in LOCAL currency here. Conversion to GBP is business logic
-- (which rate? which date?) and happens in gold.
--
-- Duplicate candidates are merged the same way as in stg_StatusHistory, so
-- CRM and finance agree on who the candidate is.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'fin_placements') }}

),

duplicates as (

    select OldCandidateId, NewCandidateId from {{ ref('stg_CandidateDuplicates') }}

)

select
    -- keys
    s.placement_ref                                                   as PlacementRef,
    cast(s.joborder_id as integer)                                    as JobOrderId,
    coalesce(d.OldCandidateId, cast(s.candidate_id as integer))       as CandidateId,
    cast(s.candidate_id as integer)                                   as SourceCandidateId,
    cast(s.consultant_user_id as integer)                             as ConsultantUserId,
    s.booking_office                                                  as BookingOffice,

    -- dates (UK format in the source)
    strptime(s.date_placed, '%d/%m/%Y')::date                         as PlacedDate,
    strptime(s.start_date,  '%d/%m/%Y')::date                         as StartDate,
    strptime(s.leave_date,  '%d/%m/%Y')::date                         as LeaveDate,   -- NULL = stayed

    -- money, local currency
    cast(s.salary as decimal(18, 2))                                  as Salary,
    cast(s.fee_pct as decimal(5, 2))                                  as FeePct,      -- 3 bad rows planted
    s.currency                                                        as CurrencyCode,

    strptime(s.modified_at, '%d/%m/%Y %H:%M')                         as ModifiedAt

from source as s
left join duplicates as d
    on d.NewCandidateId = cast(s.candidate_id as integer)
