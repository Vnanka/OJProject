-- assert_ceo_sees_every_team.sql
-- -----------------------------------------------------------------------------
-- Access coverage: every team in dim_Consultant (including "Unknown") must be
-- visible to the CEO. If a new team appears in the CRM and nobody updates the
-- access list, its numbers would SILENTLY vanish from every report, the CEO's
-- included. This stops the build instead.
-- Returns the teams the CEO cannot see; passes when empty.
-- -----------------------------------------------------------------------------

select distinct c.Team
from {{ ref('dim_Consultant') }} as c
where c.Team not in (
    select Team
    from {{ ref('sec_UserTeam') }}
    where Email = 'ceo@example.com'
)
