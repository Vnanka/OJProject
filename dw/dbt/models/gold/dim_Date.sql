-- dim_Date.sql
-- -----------------------------------------------------------------------------
-- Gold: the calendar. Grain: one row per day, plus one "Unknown" row (-1).
--
-- ONE conformed date table for every fact (role-playing): each fact's main date
-- is the active relationship in Power BI, other dates are inactive and used with
-- USERELATIONSHIP() inside specific measures.
--
-- Built here, not with CALENDAR() in Power BI, so every report and every future
-- semantic model uses the same definition of "FY", "period" and "working day".
--
-- Decisions:
--   * Range 1 Apr 2022 - 31 Mar 2028: six whole fiscal years.
--   * Fiscal year starts 1 April. FY label = start and end year: FY26/27.
--   * ISO weeks: Monday start; week 1 is the week containing the first Thursday.
--   * Fiscal week 1 = the Monday-to-Sunday week that contains 1 April.
--   * Bank holidays: England & Wales (the Manchester and London offices).
--     Other countries' holidays are not modelled - a known limitation.
-- -----------------------------------------------------------------------------

with days as (

    select cast(unnest(generate_series(date '2022-04-01', date '2028-03-31', interval 1 day)) as date) as d

),

bank_holidays as (

    select HolidayDate, HolidayName
    from {{ ref('stg_BankHolidays') }}
    where Division = 'england-and-wales'

),

calendar as (

    select
        d,
        case when month(d) >= 4 then year(d) else year(d) - 1 end   as fy_start_year,
        (month(d) + 8) % 12 + 1                                       as fiscal_period   -- Apr = 1 ... Mar = 12
    from days

)

select
    -- key: a readable integer, 20260921
    cast(strftime(c.d, '%Y%m%d') as integer)                          as DateKey,
    c.d                                                               as Date,

    -- day
    isodow(c.d)                                                       as DayOfWeekNumber,     -- 1 = Monday
    dayname(c.d)                                                      as DayName,
    left(dayname(c.d), 3)                                             as DayNameShort,
    isodow(c.d) >= 6                                                  as IsWeekend,
    bh.HolidayDate is not null                                        as IsBankHoliday,
    bh.HolidayName                                                    as BankHolidayName,
    isodow(c.d) < 6 and bh.HolidayDate is null                        as IsWorkingDay,

    -- calendar
    year(c.d)                                                         as CalendarYear,
    quarter(c.d)                                                      as CalendarQuarterNumber,
    'Q' || quarter(c.d)                                               as CalendarQuarter,
    month(c.d)                                                        as MonthNumber,
    monthname(c.d)                                                    as MonthName,
    left(monthname(c.d), 3)                                           as MonthNameShort,
    strftime(c.d, '%b %Y')                                            as YearMonth,           -- Sep 2026
    year(c.d) * 100 + month(c.d)                                      as YearMonthKey,        -- 202609, sorts YearMonth
    date_trunc('month', c.d)::date                                    as MonthStartDate,
    datediff('day', date_trunc('week', date_trunc('month', c.d)), c.d) // 7 + 1
                                                                      as WeekOfMonth,         -- week 1 = the week containing the 1st

    -- ISO week
    isoyear(c.d)                                                      as IsoYear,
    week(c.d)                                                         as IsoWeekNumber,
    isoyear(c.d) || '-W' || lpad(cast(week(c.d) as varchar), 2, '0')  as IsoYearWeek,         -- 2026-W39, unique across years
    'W' || lpad(cast(week(c.d) as varchar), 2, '0')                   as IsoWeekName,         -- W39, for an axis inside one year
    date_trunc('week', c.d)::date                                     as WeekStartDate,       -- the Monday

    -- fiscal (year starts 1 April)
    c.fy_start_year                                                   as FiscalYearNumber,    -- 2026 for FY26/27
    'FY' || right(cast(c.fy_start_year as varchar), 2)
         || '/' || right(cast(c.fy_start_year + 1 as varchar), 2)     as FiscalYear,          -- FY26/27
    (c.fiscal_period - 1) // 3 + 1                                    as FiscalQuarterNumber,
    'FQ' || ((c.fiscal_period - 1) // 3 + 1)                          as FiscalQuarter,
    c.fiscal_period                                                   as FiscalPeriodNumber,
    'P' || lpad(cast(c.fiscal_period as varchar), 2, '0')             as FiscalPeriod,        -- P06
    c.fy_start_year * 100 + c.fiscal_period                           as FiscalYearPeriodKey, -- 202606, sorts periods
    datediff('day',
             date_trunc('week', make_date(c.fy_start_year, 4, 1)),
             c.d) // 7 + 1                                            as FiscalWeekNumber,
    'FW' || lpad(cast(datediff('day',
             date_trunc('week', make_date(c.fy_start_year, 4, 1)),
             c.d) // 7 + 1 as varchar), 2, '0')                       as FiscalWeekName,      -- FW01
    -- fiscal quarters and periods line up with calendar quarters and months
    -- (FQ1 = Apr-Jun, P01 = April), so their start dates are the calendar ones
    datediff('day', date_trunc('week', date_trunc('quarter', c.d)), c.d) // 7 + 1
                                                                      as FiscalWeekOfQuarter,
    datediff('day', date_trunc('week', date_trunc('month', c.d)), c.d) // 7 + 1
                                                                      as FiscalWeekOfPeriod,
    make_date(c.fy_start_year, 4, 1)                                  as FiscalYearStartDate

from calendar as c
left join bank_holidays as bh
    on bh.HolidayDate = c.d

union all

-- the Unknown member: facts with a missing date point here instead of at nothing
select
    -1, null, null, 'Unknown', 'Unk', null, null, null, null,                             -- day
    null, null, 'Unknown', null, 'Unknown', 'Unk', 'Unknown', null, null, null,           -- calendar
    null, null, 'Unknown', 'Unknown', null,                                               -- ISO week
    null, 'Unknown', null, 'Unknown', null, 'Unknown', null, null, 'Unknown', null, null, -- fiscal
    null
