-- assert_fact_Application_placed_has_offer.sql
-- -----------------------------------------------------------------------------
-- Funnel order check: nobody can be placed without having had an offer.
-- A row here means either the CRM skipped a step (a data-entry gap) or the fact
-- logic is wrong. Warning, because real CRMs do sometimes skip steps.
-- -----------------------------------------------------------------------------

{{ config(severity = 'warn') }}

select ApplicationId, ReachedOffer, IsPlaced
from {{ ref('fact_Application') }}
where IsPlaced = 1 and ReachedOffer = 0
