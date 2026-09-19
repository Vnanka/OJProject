-- sec_UserTeam.sql
-- -----------------------------------------------------------------------------
-- Gold: the row-level security access list. Grain: one row per email per team
-- that person may see. Neither a fact nor a dimension - prefix sec_.
--
-- Used by ONE dynamic RLS role in Power BI, with NO relationship to the model.
-- The role filters dim_Consultant:
--     [Team] IN CALCULATETABLE ( VALUES ( sec_UserTeam[Team] ),
--                                sec_UserTeam[Email] = USERPRINCIPALNAME () )
-- and the filter flows to all four facts through ConsultantKey.
--
-- Includes team "Unknown" for the CEO and CFO only: rows that can't be tied to a
-- team (e.g. orphan credit notes) point at consultant -1, whose team is
-- "Unknown". Without these rows nobody - not even the CEO - would see them, and
-- firm NFI would silently stop matching the ledger.
-- -----------------------------------------------------------------------------

select
    Email,
    Team,
    RoleDescription

from {{ ref('stg_UserTeam') }}
