-- assert_fact_Application_offer_has_interview.sql
-- -----------------------------------------------------------------------------
-- Funnel order check: nobody should get an offer without an interview.
-- A row here means a skipped CRM step or a logic error. Warning, not error.
-- -----------------------------------------------------------------------------

{{ config(severity = 'warn') }}

select ApplicationId, ReachedInterview, ReachedOffer
from {{ ref('fact_Application') }}
where ReachedOffer = 1 and ReachedInterview = 0
