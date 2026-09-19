-- stg_transactions.sql
-- -----------------------------------------------------------------------------
-- Silver: invoices and credit notes from the FINANCE system.
-- Grain: one row per DocumentNo.
--
-- The trap in this source: finance exports EVERY amount as a positive number,
-- and the sign is carried by the document type. Summing the raw column would
-- ADD refunds to revenue instead of taking them away.
-- So silver gives the amount its real sign:
--     INV (invoice)      ->  +amount
--     CRN (credit note)  ->  -amount
-- After this, sum(NetAmountLocal) is simply the net fee, in local currency.
-- -----------------------------------------------------------------------------

with source as (

    select * from {{ source('raw', 'fin_transactions') }}

)

select
    doc_no                                                            as DocumentNo,
    doc_type                                                          as DocumentType,  -- INV / CRN
    placement_ref                                                     as PlacementRef,  -- 2 orphans planted
    strptime(doc_date, '%d/%m/%Y')::date                              as DocumentDate,
    case doc_type
        when 'CRN' then -cast(net_amount as decimal(18, 2))
        else             cast(net_amount as decimal(18, 2))
    end                                                               as NetAmountLocal,
    currency                                                          as CurrencyCode,
    strptime(modified_at, '%d/%m/%Y %H:%M')                           as ModifiedAt

from source
