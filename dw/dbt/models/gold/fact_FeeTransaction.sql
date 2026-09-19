-- fact_FeeTransaction.sql
-- -----------------------------------------------------------------------------
-- Gold fact: the money. One row per finance document - an invoice (INV) or a
-- credit note (CRN). SUM(NetAmountGbp) = NFI, Net Fee Income: invoices minus
-- refunds, the fee money the agency actually keeps.
--
-- Agreed design (19 Sep):
--   * Amounts are signed (credit notes negative, done in silver), in local
--     currency and GBP at the monthly average rate of the DOCUMENT's own month.
--     (A refund converted at a later month's rate won't exactly cancel its share
--     of the invoice - that difference is a real FX gain/loss, as in a ledger.)
--   * Two dates for the two NFI views:
--       DocumentDateKey         active   - when the document was issued
--                                          (NFI, matches the finance ledger)
--       OriginalInvoiceDateKey  inactive - the date of the invoice it belongs to
--                                          (NFI attributed, via USERELATIONSHIP)
--     For an invoice both are its own date; for a credit note the second is its
--     placement's invoice date.
--   * Dimension keys come from fact_Placement, so a document and its placement
--     always point at exactly the same consultant, client, office, etc.
--   * ORPHANS: a document whose placement doesn't exist (2 credit notes today)
--     is KEPT, so firm-level NFI still matches the ledger. Its keys become -1
--     (joined to "Unknown" in every dimension), and OriginalInvoiceDateKey is -1
--     too: a refund SHOULD have an original invoice, so it is missing, not
--     "hasn't happened". In row-level security only the CEO and CFO can see the
--     "Unknown" team, so they see the full ledger total and managers don't see
--     refunds that aren't theirs.
-- -----------------------------------------------------------------------------

with documents as (

    select * from {{ ref('stg_Transactions') }}

),

invoices as (

    -- each placement's invoice date: "the original invoice" of its credit notes
    select PlacementRef, DocumentDate as InvoiceDate
    from documents
    where DocumentType = 'INV'

),

placements as (

    select PlacementRef, ApplicationId, VacancyKey, ClientKey, IndustryKey,
           DisciplineKey, ConsultantKey, OfficeKey
    from {{ ref('fact_Placement') }}

),

fx as (

    select MonthStartDate, CurrencyCode, RatePerGbp from {{ ref('dim_FxRateMonthly') }}

)

select
    -- identifiers
    t.DocumentNo,
    t.DocumentType,                                                              -- INV / CRN
    t.PlacementRef,
    p.ApplicationId,                                                             -- blank for orphans

    -- dimension keys, from the placement (-1 = Unknown: orphan documents)
    coalesce(p.VacancyKey, -1)                                                   as VacancyKey,
    coalesce(p.ClientKey, -1)                                                    as ClientKey,
    coalesce(p.IndustryKey, -1)                                                  as IndustryKey,
    coalesce(p.DisciplineKey, -1)                                                as DisciplineKey,
    coalesce(p.ConsultantKey, -1)                                                as ConsultantKey,
    coalesce(p.OfficeKey, -1)                                                    as OfficeKey,

    -- dates
    cast(strftime(t.DocumentDate, '%Y%m%d') as integer)                         as DocumentDateKey,
    coalesce(cast(strftime(inv.InvoiceDate, '%Y%m%d') as integer), -1)         as OriginalInvoiceDateKey,

    -- money: local currency (signed) and GBP at the document month's rate
    t.CurrencyCode,
    t.NetAmountLocal,
    cast(t.NetAmountLocal / fx.RatePerGbp as decimal(18, 2))                    as NetAmountGbp

from documents as t
left join placements as p   on p.PlacementRef  = t.PlacementRef
left join invoices   as inv on inv.PlacementRef = t.PlacementRef
left join fx                on fx.CurrencyCode   = t.CurrencyCode
                           and fx.MonthStartDate = date_trunc('month', t.DocumentDate)::date
