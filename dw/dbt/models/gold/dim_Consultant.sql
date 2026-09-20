-- dim_Consultant.sql
-- -----------------------------------------------------------------------------
-- Gold: consultants and team managers. Grain: one row per user, plus -1.
-- Key = the CRM's own UserId.
--
-- This is where the derived attributes silver was not allowed to have live:
-- full name, manager name, IsManager, IsActive. They are derived from the data
-- itself, not from text rules:
--   IsManager = someone in the CRM reports to this user
--   IsActive  = no leave date
--
-- Team and Office here are the CURRENT ones (used for row-level security and the
-- Team -> Consultant hierarchy). The office at the time of each event sits on
-- the fact rows instead, so history is not rewritten when someone moves.
-- -----------------------------------------------------------------------------

-- Columns are renamed to the gold naming standard in one place at the end:
--   keys and numeric fact columns -> all lowercase (consultantkey, netamountgbp)
--   attributes people see         -> readable English ("Client Industry")
-- The logic above is untouched.

select
    ConsultantKey as consultantkey,
    ConsultantName as "Consultant Name",
    FirstName as "First Name",
    LastName as "Last Name",
    Email as "Email",
    Title as "Title",
    Team as "Team",
    Office as "Consultant Office",
    ManagerKey as managerkey,
    ManagerName as "Manager Name",
    IsManager as "Is Manager",
    StartDate as "Start Date",
    LeaveDate as "Leave Date",
    IsActive as "Is Active"

from (

with users as (

    select * from {{ ref('stg_User') }}

),

managers as (

    select distinct ManagerUserId from users where ManagerUserId is not null

)

select
    u.UserId                                    as ConsultantKey,
    u.FirstName || ' ' || u.LastName            as ConsultantName,
    u.FirstName,
    u.LastName,
    u.Email,                                    -- matches the RLS access list
    u.Title,
    u.Team,
    u.Office,
    u.ManagerUserId                             as ManagerKey,
    m.FirstName || ' ' || m.LastName            as ManagerName,
    u.UserId in (select ManagerUserId from managers) as IsManager,
    u.StartDate,
    u.LeaveDate,
    u.LeaveDate is null                         as IsActive

from users as u
left join users as m
    on m.UserId = u.ManagerUserId

union all

select -1, 'Unknown', 'Unknown', 'Unknown', null, 'Unknown', 'Unknown', 'Unknown',
       null, null, false, null, null, false

) as renamed
