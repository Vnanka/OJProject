"""
generate_sources.py — create the synthetic source-system exports for the OJ demo warehouse.

Writes messy, source-shaped CSV files (NOT dims and facts) to dw/raw/:
    crm/       OpenCATS-shaped CRM export
    finance/   placements, invoices + credit notes, monthly targets
    security/  row-level security access list (fake example.com people)

Every rule comes from data-rules.md (v3). The random seed is fixed, so every run
produces identical files — safe to re-run.

All companies and people are fictional. Standard library only.

Usage:
    python dw/src/generate/generate_sources.py
"""

import csv
import random
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

SEED = 20260921
# "Record last modified" timestamps draw from their own generator, so adding
# them did not change any other value in the data.
MOD_RNG = random.Random(SEED + 1)
DW_ROOT = Path(__file__).resolve().parents[2]
RAW = DW_ROOT / "raw"

# The CRM "goes live" six months before reporting starts, so FY23/24 opens with a
# normal pipeline (placements invoice 1-3 months after they are made).
SIM_START = date(2022, 10, 1)
START = date(2023, 4, 1)      # reporting and targets start here (FY23/24)
END = date(2026, 9, 12)

# ---------------------------------------------------------------------------
# Reference data (data-rules.md §4)
# ---------------------------------------------------------------------------

# office: (country, region, currency, client city, teams, salary factor, symbol)
# salary factor = local-currency salary for a role paying £1 in Manchester
OFFICES = {
    "Manchester": ("GB", "UK & Ireland", "GBP", "Manchester", 4, 1.00, "£"),
    "London": ("GB", "UK & Ireland", "GBP", "London", 4, 1.20, "£"),
    "Dublin": ("IE", "UK & Ireland", "EUR", "Dublin", 2, 1.20, "€"),
    "Amsterdam": ("NL", "Europe", "EUR", "Amsterdam", 1, 1.25, "€"),
    "Brussels": ("BE", "Europe", "EUR", "Brussels", 1, 1.20, "€"),
    "Madrid": ("ES", "Europe", "EUR", "Madrid", 1, 0.90, "€"),
    "Paris": ("FR", "Europe", "EUR", "Paris", 2, 1.15, "€"),
    "Zurich": ("CH", "Europe", "CHF", "Zurich", 2, 1.75, "CHF "),
    "New York": ("US", "North America", "USD", "New York", 3, 1.75, "$"),
    "Charlotte": ("US", "North America", "USD", "Charlotte", 1, 1.45, "$"),
    "Hong Kong": ("HK", "APAC", "HKD", "Hong Kong", 1, 10.5, "HK$"),
    "Singapore": ("SG", "APAC", "SGD", "Singapore", 1, 1.85, "S$"),
    "Malaysia": ("MY", "APAC", "MYR", "Kuala Lumpur", 1, 2.60, "RM"),
}

# Finance's planning ("budget") rates, used only to set GBP targets.
# Actual NFI is converted later in dbt with real ECB rates.
PLANNING_FX = {"GBP": 1.0, "EUR": 1.16, "CHF": 1.10, "USD": 1.28,
               "HKD": 10.0, "SGD": 1.72, "MYR": 5.9}

COUNTRY_NAMES = {"GB": "United Kingdom", "IE": "Ireland", "NL": "Netherlands",
                 "BE": "Belgium", "ES": "Spain", "FR": "France", "CH": "Switzerland",
                 "US": "United States", "HK": "Hong Kong", "SG": "Singapore",
                 "MY": "Malaysia"}

LEGAL_SUFFIX = {"GB": "Ltd", "IE": "Ltd", "NL": "B.V.", "BE": "SA", "ES": "S.A.",
                "FR": "SAS", "CH": "AG", "US": "Inc.", "HK": "Limited",
                "SG": "Pte Ltd", "MY": "Sdn Bhd"}

# discipline: (UK salary low, UK salary high, short team name)
DISCIPLINES = {
    "Accountancy, Finance & Audit": (40000, 90000, "Finance"),
    "Actuarial": (55000, 120000, "Actuarial"),
    "Risk & Compliance": (45000, 95000, "Risk"),
    "Technology": (50000, 110000, "Technology"),
    "Transformation & Change": (50000, 100000, "Change"),
    "Underwriting, Broking & Claims": (40000, 95000, "Underwriting"),
    "Legal": (60000, 130000, "Legal"),
}
SCARCE_DISCIPLINES = {"Actuarial", "Legal"}
RELOCATION_OFFICES = {"Zurich", "Singapore", "Hong Kong", "New York"}

TITLES = {
    "Accountancy, Finance & Audit": ["Financial Controller", "Management Accountant",
                                     "Internal Auditor", "FP&A Analyst", "Tax Manager"],
    "Actuarial": ["Pricing Actuary", "Reserving Actuary", "Capital Modelling Actuary",
                  "Actuarial Analyst", "Head of Pricing"],
    "Risk & Compliance": ["Compliance Officer", "Financial Crime Analyst",
                          "Operational Risk Manager", "Credit Risk Analyst", "Head of Compliance"],
    "Technology": ["Data Engineer", "BI Developer", "Cloud Architect",
                   "Software Engineer", "Cyber Security Analyst"],
    "Transformation & Change": ["Business Analyst", "Project Manager", "Change Manager",
                                "Programme Director", "Product Owner"],
    "Underwriting, Broking & Claims": ["Property Underwriter", "Casualty Underwriter",
                                       "Claims Handler", "Account Executive", "Claims Manager"],
    "Legal": ["Commercial Lawyer", "In-house Counsel", "Regulatory Lawyer",
              "Paralegal", "Head of Legal"],
}

# Team disciplines for the two big offices are fixed; the rest are drawn at random.
FIXED_TEAM_DISCIPLINES = {
    "Manchester": ["Actuarial", "Accountancy, Finance & Audit",
                   "Underwriting, Broking & Claims", "Technology"],
    "London": ["Legal", "Risk & Compliance", "Transformation & Change", "Actuarial"],
}
PROBLEM_TEAM = "London Risk"  # story 1: high fall-off

# industry: (share of clients, sub-sectors, name suffixes)
INDUSTRIES = {
    "Insurance": (0.32, ["General Insurance", "Life & Pensions", "Health"],
                  ["Insurance", "Mutual", "Assurance", "Underwriting", "Re"]),
    "Financial Services": (0.30, ["Banking", "Asset & Wealth Management", "Payments & Fintech"],
                           ["Bank", "Capital", "Asset Management", "Payments", "Wealth"]),
    "Commerce & Industry": (0.20, ["Technology", "Industrials", "Energy & Infrastructure", "Consumer"],
                            ["Industries", "Energy", "Technologies", "Group", "Retail"]),
    "Professional Services": (0.18, ["Consulting", "Legal & Advisory", "Actuarial Consulting"],
                              ["Consulting", "Advisory", "Partners", "Actuarial", "Solutions"]),
}
NAME_WORDS = ["Ashdown", "Brackley", "Calderwood", "Denholm", "Eastleigh", "Fernbrook",
              "Glenmoor", "Harlow", "Ivybridge", "Kestrel", "Larkspur", "Marlowe",
              "Northcote", "Oakhurst", "Pembury", "Quayside", "Redfern", "Stanwick",
              "Thornbury", "Upfield", "Valemont", "Westbrook", "Yarrow", "Aldwick",
              "Bexmoor", "Cresswell", "Dunmore", "Elmstead", "Foxley", "Greywell"]
NAME_MIDDLE = ["", "", "", "Bay", "Hill", "Park", "Bridge", "Gate", "Vale"]

FIRST_NAMES = ["Oliver", "Amelia", "Jack", "Isla", "Harry", "Ava", "George", "Mia", "Noah",
               "Grace", "Liam", "Sophie", "Lucas", "Emma", "Daniel", "Chloe", "Adam", "Ella",
               "Aoife", "Conor", "Sanne", "Daan", "Lucie", "Hugo", "Lucia", "Pablo", "Claire",
               "Louis", "Lena", "Jonas", "Ethan", "Madison", "Tyler", "Hannah", "Wei", "Mei",
               "Jun", "Aisha", "Arjun", "Nurul", "Farid", "Priya", "Tom", "Kate", "Sam"]
LAST_NAMES = ["Smith", "Jones", "Taylor", "Brown", "Walker", "Wright", "Hughes", "Clarke",
              "Murphy", "Byrne", "De Vries", "Jansen", "Peeters", "Martin", "Bernard",
              "Garcia", "Lopez", "Muller", "Keller", "Johnson", "Miller", "Davis", "Chan",
              "Wong", "Tan", "Lim", "Ng", "Rahman", "Ismail", "Patel", "Shah", "Evans",
              "Roberts", "Green", "Hall", "Wood", "Young", "King", "Scott", "Baker"]

# ---------------------------------------------------------------------------
# Business rules (data-rules.md §6)
# ---------------------------------------------------------------------------

# fiscal year start -> (CV->interview, interview->offer, offer->placed)
RATES = {2023: (0.338, 0.293, 0.817), 2024: (0.346, 0.287, 0.802),
         2025: (0.359, 0.298, 0.784), 2026: (0.364, 0.302, 0.768)}
# Input rates. Observed rates land lower because jobs fill up
# (story 5 observed ~44%, story 4 observed ~8%).
RELOCATION_OFFER_RATE = 0.53      # story 5
BIG_CLIENT_OFFER_RATE = 0.056     # story 4

# Jan..Dec
SEASONALITY = [1.25, 1.15, 1.10, 1.00, 1.00, 1.05, 0.95, 0.75, 1.20, 1.10, 1.00, 0.70]
SEASON_MEAN = sum(SEASONALITY) / 12

WORK_ARRANGEMENTS = [("Hybrid", 0.60), ("Office", 0.25), ("Remote", 0.15)]
# extra days on (interview gap, offer gap)
ARRANGEMENT_DELAY = {"Remote": (-2, -4), "Hybrid": (0, 0), "Office": (3, 6)}

FALL_OFF_BASE = 0.080
FALL_OFF_OFFICE_ONLY_MULT = 1.60  # story 2
FALL_OFF_PROBLEM_TEAM = 0.190     # story 1 (observed ~17.8%)
GUARANTEE_WEEKS = 12

SALARY_GROWTH = 0.04              # per year
TARGET_GROWTH = 0.05              # per fiscal year
TARGET_STRETCH = 1.02             # targets sit a little above normal output
TARGET_REBATE_ALLOWANCE = 0.94    # finance expects ~6% of fees to be refunded
MANAGER_OUTPUT = 0.70
MONTHLY_ATTRITION = 0.009
# NFI arrives ~3 months after activity, so new starters' targets ramp 3 months later
TARGET_RAMP_LAG_MONTHS = 3

# Tuning knobs, checked in the summary:
# - a settled consultant should land at ~10 placements a year
# - some interviewees never get an offer because the job fills first, so the
#   input offer rate is lifted to make the *observed* rate match the plan
EXPECTED_PLACEMENTS_PER_JOB = 0.64
OFFER_RATE_UPLIFT = 1.24

# CRM status codes (OpenCATS)
NO_STATUS, SUBMITTED, INTERVIEWING, OFFERED = 0, 400, 500, 600
NOT_IN_CONSIDERATION, CANDIDATE_DECLINED, CLIENT_DECLINED, PLACED = 650, 675, 700, 800
BAD_STATUS = 999
STATUS_LOOKUP = [(0, "No Status"), (100, "No Contact"), (200, "Contacted"),
                 (250, "Candidate Responded"), (300, "Qualifying"), (400, "Submitted"),
                 (500, "Interviewing"), (600, "Offered"), (650, "Not in Consideration"),
                 (675, "Candidate Declined"), (700, "Client Declined"), (800, "Placed")]


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def fy_start(d):
    return d.year if d.month >= 4 else d.year - 1


def months_between(a, b):
    return (b.year - a.year) * 12 + (b.month - a.month) + (b.day - a.day) / 30.0


def ramp(tenure_months):
    if tenure_months < 6:
        return 0.30
    if tenure_months < 12:
        return 0.70
    return 1.00


def weighted(options):
    r, acc = random.random(), 0.0
    for value, weight in options:
        acc += weight
        if r <= acc:
            return value
    return options[-1][0]


def crm_ts(d):
    """CRM (MySQL-style) timestamp text on a random working hour."""
    t = datetime(d.year, d.month, d.day, random.randint(8, 18),
                 random.randint(0, 59), random.randint(0, 59))
    return t.strftime("%Y-%m-%d %H:%M:%S")


def fin_date(d):
    """Finance system date text, UK style."""
    return d.strftime("%d/%m/%Y")


def mod_crm(d, max_days=0):
    """'Record last modified' for the CRM: same timestamp style as its other dates."""
    d = min(d + timedelta(days=MOD_RNG.randint(0, max_days)), END)
    return datetime(d.year, d.month, d.day, MOD_RNG.randint(8, 18),
                    MOD_RNG.randint(0, 59), MOD_RNG.randint(0, 59)).strftime("%Y-%m-%d %H:%M:%S")


def mod_fin(d, max_days=0):
    """'Record last modified' for the finance system: UK date plus a time, no seconds."""
    d = min(d + timedelta(days=MOD_RNG.randint(0, max_days)), END)
    return datetime(d.year, d.month, d.day, MOD_RNG.randint(7, 20),
                    MOD_RNG.randint(0, 59)).strftime("%d/%m/%Y %H:%M")


def month_starts(a, b):
    m = date(a.year, a.month, 1)
    while m <= b:
        yield m
        m = date(m.year + (m.month == 12), m.month % 12 + 1, 1)


def month_end(m):
    nxt = date(m.year + (m.month == 12), m.month % 12 + 1, 1)
    return nxt - timedelta(days=1)


def random_day(a, b):
    return a + timedelta(days=random.randint(0, (b - a).days))


def write_csv(path, header, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    return len(rows)


# ---------------------------------------------------------------------------
# 1. Teams and users
# ---------------------------------------------------------------------------

def build_teams():
    teams = []
    for office, (_, region, *_rest) in OFFICES.items():
        n = OFFICES[office][4]
        if office in FIXED_TEAM_DISCIPLINES:
            discs = FIXED_TEAM_DISCIPLINES[office]
        else:
            discs = random.sample(list(DISCIPLINES), n)
        for disc in discs:
            start_size = random.randint(4, 6)
            teams.append({
                "name": f"{office} {DISCIPLINES[disc][2]}",
                "office": office, "region": region, "discipline": disc,
                "start_size": start_size, "end_size": start_size + random.randint(1, 3),
            })
    return teams


def build_users(teams):
    users, used_emails = [], set()

    def new_user(team, hired, is_manager):
        first, last = random.choice(FIRST_NAMES), random.choice(LAST_NAMES)
        base = f"{first}.{last}".lower().replace(" ", "")
        email, n = f"{base}@example.com", 2
        while email in used_emails:
            email, n = f"{base}{n}@example.com", n + 1
        used_emails.add(email)
        u = {"user_id": len(users) + 1, "first_name": first, "last_name": last,
             "email": email, "team": team["name"], "office": team["office"],
             "hired": hired, "left": None, "is_manager": is_manager,
             "level": random.uniform(8, 12), "manager_user_id": None}
        users.append(u)
        return u

    months = list(month_starts(SIM_START, END))
    for team in teams:
        mgr = new_user(team, SIM_START - timedelta(days=random.randint(3 * 365, 10 * 365)), True)
        team["manager"] = mgr
        members = [mgr]
        for _ in range(team["start_size"] - 1):
            # ~20% of the starting team is still ramping up
            days = random.randint(30, 360) if random.random() < 0.2 else random.randint(365, 2500)
            members.append(new_user(team, SIM_START - timedelta(days=days), False))

        for i, m in enumerate(months):
            m_end = min(month_end(m), END)
            for u in members:
                if u["left"] is None and not u["is_manager"] and u["hired"] < m \
                        and random.random() < MONTHLY_ATTRITION:
                    u["left"] = random_day(m, m_end)
            target = round(team["start_size"]
                           + (team["end_size"] - team["start_size"]) * i / (len(months) - 1))
            active = [u for u in members if u["left"] is None]
            for _ in range(max(0, target - len(active))):
                members.append(new_user(team, random_day(m, m_end), False))

        for u in members:
            if not u["is_manager"]:
                u["manager_user_id"] = mgr["user_id"]
    return users


def user_title(u):
    if u["is_manager"]:
        return "Team Manager"
    years = ((u["left"] or END) - u["hired"]).days / 365
    if years < 1:
        return "Associate Consultant"
    if years < 3:
        return "Consultant"
    if years < 5:
        return "Senior Consultant"
    return "Principal Consultant"


# ---------------------------------------------------------------------------
# 2. Companies
# ---------------------------------------------------------------------------

def build_companies(users):
    companies, names = [], set()
    total_teams = sum(o[4] for o in OFFICES.values())
    by_office = defaultdict(list)
    first_owner = {}
    for u in users:
        first_owner.setdefault(u["office"], u)

    for office, (country, _, _, city, n_teams, _, _) in OFFICES.items():
        n = round(1000 * n_teams / total_teams)
        for rank in range(1, n + 1):
            industry = weighted([(k, v[0]) for k, v in INDUSTRIES.items()])
            _, subs, suffixes = INDUSTRIES[industry]
            while True:
                parts = [random.choice(NAME_WORDS), random.choice(NAME_MIDDLE),
                         random.choice(suffixes), LEGAL_SUFFIX[country]]
                name = " ".join(p for p in parts if p)
                if name not in names:
                    names.add(name)
                    break
            c = {"company_id": len(companies) + 1, "name": name, "city": city,
                 "country": country, "office": office, "industry": industry,
                 "sub_sector": random.choice(subs),
                 "owner": first_owner[office]["user_id"],
                 "weight": 1 / rank ** 0.8, "first_job": None, "last_event": None}
            companies.append(c)
            by_office[office].append(c)
    return companies, by_office


# ---------------------------------------------------------------------------
# 3. Job orders
# ---------------------------------------------------------------------------

def salary_band(disc, office, created):
    lo, hi, _ = DISCIPLINES[disc]
    growth = (1 + SALARY_GROWTH) ** ((created - START).days / 365)
    factor = OFFICES[office][5] * growth
    base = random.uniform(lo, hi * 0.8)
    top = base * random.uniform(1.10, 1.25)
    return round(base * factor, -3), round(top * factor, -3)


def salary_text(lo, hi, office):
    """Free-text salary, the way consultants really type it (data-rules §3.1)."""
    currency, sym = OFFICES[office][2], OFFICES[office][6]
    mid = int(round((lo + hi) / 2, -3))
    r = random.random()
    if r < 0.35:
        return f"{sym}{int(lo // 1000)}k - {sym}{int(hi // 1000)}k"
    if r < 0.60:
        return str(mid)
    if r < 0.80:
        return f"{mid:,}"
    if r < 0.95:
        return f"{currency} {mid // 1000}k"
    return "Competitive"


def build_jobs(users, teams, companies_by_office):
    team_by_name = {t["name"]: t for t in teams}
    jobs = []
    for u in users:
        team = team_by_name[u["team"]]
        last_day = min(u["left"] or END, END)
        carry = random.random()
        for m in month_starts(max(u["hired"], SIM_START), last_day):
            a, b = max(m, u["hired"]), min(month_end(m), last_day)
            if a > b:
                continue
            share = ((b - a).days + 1) / ((month_end(m) - m).days + 1)
            tenure = months_between(u["hired"], a + (b - a) / 2)
            placements = (u["level"] * ramp(tenure) * (MANAGER_OUTPUT if u["is_manager"] else 1)
                          * SEASONALITY[m.month - 1] / SEASON_MEAN / 12 * share)
            # a steady flow of new jobs: carry the fraction over to next month
            carry += placements / EXPECTED_PLACEMENTS_PER_JOB
            n_jobs = int(carry)
            carry -= n_jobs
            for _ in range(n_jobs):
                created = random_day(a, b)
                disc = team["discipline"] if random.random() < 0.8 else random.choice(list(DISCIPLINES))
                pool = companies_by_office[u["office"]]
                company = random.choices(pool, weights=[c["weight"] for c in pool])[0]
                lo, hi = salary_band(disc, u["office"], created)
                title = random.choice(TITLES[disc])
                if random.random() < 0.3 and not title.startswith("Head"):
                    title = "Senior " + title
                jobs.append({
                    "created": created, "recruiter": u, "team": team, "company": company,
                    "office": u["office"], "discipline": disc, "title": title,
                    "salary_lo": lo, "salary_hi": hi,
                    "salary_text": salary_text(lo, hi, u["office"]),
                    "arrangement": weighted(WORK_ARRANGEMENTS),
                    "openings": weighted([(1, 0.85), (2, 0.12), (3, 0.03)]),
                    "placed": 0, "last_event": created,
                })
    jobs.sort(key=lambda j: j["created"])
    for i, j in enumerate(jobs, start=1):
        j["joborder_id"] = i
        c = j["company"]
        c["first_job"] = c["first_job"] or j["created"]
    return jobs


# ---------------------------------------------------------------------------
# 4. Submissions and candidates
# ---------------------------------------------------------------------------

def build_submissions(jobs):
    subs = []
    for j in jobs:
        for _ in range(random.randint(5, 11)):
            d = j["created"] + timedelta(days=random.randint(1, 14))
            if d <= END:
                subs.append({"job": j, "submitted": d})
    subs.sort(key=lambda s: s["submitted"])

    candidates = []          # {candidate_id, can_relocate, created}
    recent = []
    for s in subs:
        reuse = None
        if recent and random.random() < 0.22:
            reuse = random.choice(recent[-3000:])
        if reuse is None:
            reuse = {"candidate_id": len(candidates) + 1,
                     "can_relocate": 1 if random.random() < 0.30 else 0,
                     "created": s["submitted"] - timedelta(days=random.randint(0, 30)),
                     "sub_count": 0}
            candidates.append(reuse)
            recent.append(reuse)
        reuse["sub_count"] += 1
        s["candidate"] = reuse
        s["candidate_id"] = reuse["candidate_id"]
    return subs, candidates


def build_duplicates(subs, candidates, n_pairs=500):
    """Story: the same person entered twice. Later submissions use the new ID."""
    by_candidate = defaultdict(list)
    for s in subs:
        by_candidate[s["candidate_id"]].append(s)
    eligible = [c for c in candidates if c["sub_count"] >= 2]
    pairs = []
    for old in random.sample(eligible, n_pairs):
        later = by_candidate[old["candidate_id"]][1:]
        new = {"candidate_id": len(candidates) + 1, "can_relocate": old["can_relocate"],
               "created": later[0]["submitted"], "sub_count": len(later)}
        candidates.append(new)
        for s in later:
            s["candidate_id"] = new["candidate_id"]
        pairs.append((old["candidate_id"], new["candidate_id"]))
    return pairs


# ---------------------------------------------------------------------------
# 5. Pipeline outcomes -> status history
# ---------------------------------------------------------------------------

def run_pipeline(jobs, subs, big_client):
    events = []   # (date, candidate_id, joborder_id, from, to)
    placed_subs = []
    subs_by_job = defaultdict(list)
    for s in subs:
        subs_by_job[s["job"]["joborder_id"]].append(s)

    def exit_code(stage):
        if stage == OFFERED:
            return weighted([(CANDIDATE_DECLINED, 0.85), (CLIENT_DECLINED, 0.15)])
        return weighted([(CLIENT_DECLINED, 0.5), (NOT_IN_CONSIDERATION, 0.2),
                         (CANDIDATE_DECLINED, 0.3)])

    for j in jobs:
        delay_i, delay_o = ARRANGEMENT_DELAY[j["arrangement"]]
        scarce = 6 if j["discipline"] in SCARCE_DISCIPLINES else 0
        would_place = []
        for s in subs_by_job[j["joborder_id"]]:
            r1, r2, r3 = RATES[max(2023, fy_start(s["submitted"]))]
            if j["company"] is big_client:
                r2 = BIG_CLIENT_OFFER_RATE
            elif s["candidate"]["can_relocate"] and (
                    j["discipline"] in SCARCE_DISCIPLINES or j["office"] in RELOCATION_OFFICES):
                r2 = RELOCATION_OFFER_RATE
            r2 *= OFFER_RATE_UPLIFT

            path = [(s["submitted"], NO_STATUS, SUBMITTED)]
            d, stage = s["submitted"], SUBMITTED
            s["reached"] = {SUBMITTED}
            for nxt, rate, gap in [
                (INTERVIEWING, r1, random.randint(3, 10) + delay_i),
                (OFFERED, r2, random.randint(10, 35) + delay_o + scarce),
                (PLACED, r3, random.randint(2, 7)),
            ]:
                if random.random() >= rate:
                    break
                d = d + timedelta(days=max(1, gap))
                path.append((d, stage, nxt))
                stage = nxt

            s["path"] = path
            s["final_stage"] = stage
            if stage == PLACED:
                would_place.append(s)

        # Offers go out in date order. Once every opening is filled, the remaining
        # interviewees are turned down before they ever get an offer (position filled).
        def offer_day(s):
            return next((d for d, _, to in s["path"] if to == OFFERED), None)

        fills = []
        for s in sorted((s for s in subs_by_job[j["joborder_id"]] if offer_day(s)), key=offer_day):
            full_since = sorted(fills)[j["openings"] - 1] if len(fills) >= j["openings"] else None
            if full_since and offer_day(s) > full_since:
                s["path"] = [p for p in s["path"] if p[2] in (SUBMITTED, INTERVIEWING)]
                s["final_stage"] = "filled"
                exit_day = max(s["path"][-1][0], full_since) + timedelta(days=random.randint(1, 5))
                s["forced_exit"] = (exit_day, CLIENT_DECLINED)
            elif s["final_stage"] == PLACED:
                # the client waits for this answer, so the opening counts as taken
                # from the day the (accepted) offer was made
                fills.append(offer_day(s))

        # rare overlap: two offers accepted at almost the same time for one opening
        would_place = sorted((s for s in would_place if s["final_stage"] == PLACED),
                             key=lambda s: s["path"][-1][0])
        for s in would_place[j["openings"]:]:
            placed_day = s["path"][-1][0]
            s["path"] = s["path"][:-1] + [(placed_day, OFFERED, CLIENT_DECLINED)]
            s["final_stage"] = "capped"

        for s in subs_by_job[j["joborder_id"]]:
            for d, frm, to in s["path"]:
                if d <= END:
                    events.append((d, s["candidate_id"], j["joborder_id"], frm, to))
                    s["reached"].add(to)
                    j["last_event"] = max(j["last_event"], d)
                    if to == PLACED:
                        j["placed"] += 1
                        s["placed_on"] = d
                        placed_subs.append(s)
            if s["final_stage"] not in (PLACED, "capped"):
                last_day, last_stage = s["path"][-1][0], s["path"][-1][2]
                if "forced_exit" in s:
                    exit_day, code = s["forced_exit"]
                else:
                    exit_day = last_day + timedelta(days=random.randint(3, 14))
                    code = exit_code(last_stage)
                if exit_day <= END and last_day <= END:
                    events.append((exit_day, s["candidate_id"], j["joborder_id"], last_stage, code))
                    j["last_event"] = max(j["last_event"], exit_day)
    events.sort(key=lambda e: e[0])
    return events, placed_subs


# ---------------------------------------------------------------------------
# 6. Finance: placements, invoices, credit notes, targets
# ---------------------------------------------------------------------------

def build_finance(placed_subs):
    placements, transactions = [], []
    placed_subs.sort(key=lambda s: s["placed_on"])
    inv_no, crn_no = 100000, 200000
    for i, s in enumerate(placed_subs, start=1):
        j = s["job"]
        ref = f"PL-{i:06d}"
        start = s["placed_on"] + timedelta(days=random.randint(28, 84))
        salary = round(random.uniform(j["salary_lo"], j["salary_hi"]), -2)
        fee_pct = round(random.triangular(15, 25, 18.2), 1)
        fee = round(salary * fee_pct / 100, 2)

        if j["team"]["name"] == PROBLEM_TEAM:
            p_fall = FALL_OFF_PROBLEM_TEAM
        else:
            p_fall = FALL_OFF_BASE * (FALL_OFF_OFFICE_ONLY_MULT if j["arrangement"] == "Office" else 1)
        leave = None
        if random.random() < p_fall:
            week = random.choices(range(1, GUARANTEE_WEEKS + 1),
                                  weights=[12 - w // 2 for w in range(GUARANTEE_WEEKS)])[0]
            leave = start + timedelta(days=(week - 1) * 7 + random.randint(1, 7))
            if leave > END:
                leave = None

        p = {"placement_ref": ref, "sub": s, "start": start, "leave": leave,
             "salary": salary, "fee_pct": fee_pct, "fee": fee, "currency": OFFICES[j["office"]][2],
             "invoiced": None, "credited": 0.0}
        placements.append(p)

        inv_day = start + timedelta(days=random.randint(0, 7))
        if inv_day <= END:
            inv_no += 1
            transactions.append((f"INV-{inv_no}", "INV", ref, inv_day, fee, p["currency"]))
            p["invoiced"] = inv_day
            if leave:
                crn_day = leave + timedelta(days=random.randint(7, 21))
                weeks_worked = (leave - start).days // 7 + 1
                refund = 1.0 if weeks_worked <= 4 else 0.5 if weeks_worked <= 8 else 0.25
                if crn_day <= END:
                    crn_no += 1
                    amount = round(fee * refund, 2)
                    # credit notes are stored as POSITIVE amounts; doc_type gives the sign
                    transactions.append((f"CRN-{crn_no}", "CRN", ref, crn_day, amount, p["currency"]))
                    p["credited"] = amount
    return placements, transactions


def build_targets(users, teams):
    team_by_name = {t["name"]: t for t in teams}
    rows = []
    for u in users:
        team = team_by_name[u["team"]]
        lo, hi, _ = DISCIPLINES[team["discipline"]]
        office = OFFICES[u["office"]]
        uk_equivalent = office[5] / PLANNING_FX[office[2]]
        avg_salary = (lo + hi * 0.8) / 2 * 1.09 * uk_equivalent
        last_day = min(u["left"] or END, END)
        for m in month_starts(max(u["hired"], START), last_day):
            tenure = months_between(u["hired"], m + timedelta(days=14))
            fy_index = fy_start(m) - START.year
            yearly_placements = 10 * TARGET_STRETCH * ramp(tenure - TARGET_RAMP_LAG_MONTHS) * (
                MANAGER_OUTPUT if u["is_manager"] else 1)
            target = (yearly_placements * avg_salary * 0.194 * TARGET_REBATE_ALLOWANCE
                      * (1 + TARGET_GROWTH) ** fy_index
                      * SEASONALITY[m.month - 1] / (SEASON_MEAN * 12))
            rows.append((u["user_id"], m.strftime("%Y-%m"), int(round(target / 50) * 50)))
    return rows


# Values that USED to exist in the CRM dropdowns and were retired. No client or
# job uses them. They show why dimensions come from the lookup list, not from
# the distinct values found in transactions: these would otherwise vanish.
RETIRED_SUB_SECTORS = [("Insurance", "Reinsurance", date(2024, 3, 31))]
RETIRED_DISCIPLINES = [("Tax", date(2023, 9, 30))]
CRM_GO_LIVE_TS = "2022-10-01 09:00:00"


def build_crm_lookups():
    """The CRM's own dropdown lists for industry/sub-sector and discipline.
    valid_from = when the value was added; empty valid_to = still in use.
    Uses no randomness, so no other generated value changes."""
    industry_rows, sub_id = [], 0
    for industry_id, (industry, (_share, subs, _suffixes)) in enumerate(INDUSTRIES.items(), start=1):
        for sub in subs:
            sub_id += 1
            industry_rows.append((sub_id, sub, industry_id, industry, "2022-10-01", "", CRM_GO_LIVE_TS))
    industry_ids = {name: i for i, name in enumerate(INDUSTRIES, start=1)}
    for industry, sub, retired in RETIRED_SUB_SECTORS:
        sub_id += 1
        industry_rows.append((sub_id, sub, industry_ids[industry], industry, "2022-10-01",
                              retired.isoformat(), f"{retired.isoformat()} 17:00:00"))

    discipline_rows = [(i, d, "2022-10-01", "", CRM_GO_LIVE_TS)
                       for i, d in enumerate(DISCIPLINES, start=1)]
    for name, retired in RETIRED_DISCIPLINES:
        discipline_rows.append((len(discipline_rows) + 1, name, "2022-10-01",
                                retired.isoformat(), f"{retired.isoformat()} 17:00:00"))
    return industry_rows, discipline_rows


# The business definition of the funnel: which CRM status counts as which stage.
# status code: (funnel stage, stage order, stage type, exit by)
FUNNEL_STAGES = {
    0:   ("Not started", 0, "Start", ""),
    100: ("Pre-funnel", 0, "Pre-funnel", ""),
    200: ("Pre-funnel", 0, "Pre-funnel", ""),
    250: ("Pre-funnel", 0, "Pre-funnel", ""),
    300: ("Pre-funnel", 0, "Pre-funnel", ""),
    400: ("CV Sent", 1, "Progress", ""),
    500: ("Interview", 2, "Progress", ""),
    600: ("Offer", 3, "Progress", ""),
    800: ("Placed", 4, "Progress", ""),
    650: ("Rejected", 5, "Exit", "Agency"),
    700: ("Rejected", 5, "Exit", "Client"),
    675: ("Withdrawn", 6, "Exit", "Candidate"),
}


def build_funnel_stage_reference():
    """The funnel mapping the business maintains (BI team / sales operations).
    One row per CRM status code. Uses no randomness."""
    return [(code, *FUNNEL_STAGES[code], "2022-10-01 09:00:00") for code, _name in STATUS_LOOKUP]


# The order regions appear in on reports (UK first, as the head office region).
REGION_SORT_ORDER = {"UK & Ireland": 1, "Europe": 2, "North America": 3, "APAC": 4}


def build_office_reference():
    """The office list the business maintains: one row per office.
    Built from the same OFFICES table the synthetic data uses, so the two cannot
    drift apart. Uses no randomness, so no other generated value changes."""
    return [(office, city, country, COUNTRY_NAMES[country], region, REGION_SORT_ORDER[region],
             currency, "2022-10-01 09:00:00")
            for office, (country, region, currency, city, *_rest) in OFFICES.items()]


def build_security(teams):
    """The access list is reviewed periodically; last_updated is that review."""
    rows = []
    for exec_email in ["ceo@example.com", "cfo@example.com"]:
        rows += [(exec_email, t["name"], "Executive - all teams") for t in teams]
    for region in sorted({t["region"] for t in teams}):
        slug = region.lower().replace(" & ", ".").replace(" ", ".")
        rows += [(f"{slug}.director@example.com", t["name"], f"Regional Director - {region}")
                 for t in teams if t["region"] == region]
    for office in OFFICES:
        slug = office.lower().replace(" ", ".")
        rows += [(f"{slug}.director@example.com", t["name"], f"Office Director - {office}")
                 for t in teams if t["office"] == office]
    for t in teams:
        rows.append((t["manager"]["email"], t["name"], f"Team Manager - {t['name']}"))
    return rows


# ---------------------------------------------------------------------------
# 7. Planted data quality problems (data-rules.md §8)
# ---------------------------------------------------------------------------

def plant_problems(jobs, history_rows, placement_rows, transaction_rows):
    for j in random.sample(jobs, 30):
        j["discipline_out"] = ""                                  # problem 4
    exit_idx = [i for i, r in enumerate(history_rows) if r[5] in (650, 675, 700)]
    for i in random.sample(exit_idx, 20):
        r = list(history_rows[i])
        r[5] = BAD_STATUS                                         # problem 2
        history_rows[i] = tuple(r)
    for i, bad in zip(random.sample(range(len(placement_rows)), 3), ["", "", "0"]):
        r = list(placement_rows[i])
        r[9] = bad                                                # problem 5
        placement_rows[i] = tuple(r)
    for n in (1, 2):                                              # problem 3
        d = random_day(date(2025, 1, 1), date(2026, 6, 30))
        transaction_rows.append((f"CRN-29990{n}", "CRN", f"PL-09990{n}", fin_date(d),
                                 round(random.uniform(1500, 6000), 2), "GBP", mod_fin(d, 2)))


# ---------------------------------------------------------------------------
# 8. Summary — compare the generated data with data-rules.md
# ---------------------------------------------------------------------------

def summary(users, jobs, subs, placements, targets_rows, big_client, teams):
    print("\n=== Checks against data-rules.md ===")
    headcount = lambda d: sum(1 for u in users if u["hired"] <= d and (u["left"] is None or u["left"] > d))
    print(f"Headcount: {headcount(START)} on {START}, {headcount(END)} on {END}; "
          f"leavers: {sum(1 for u in users if u['left'])}")

    print("\nCohort conversion by fiscal year of CV sent (targets in brackets):")
    by_fy = defaultdict(Counter)
    for s in subs:
        c = by_fy[fy_start(s["submitted"])]
        c["sub"] += 1
        for stage in (INTERVIEWING, OFFERED, PLACED):
            c[stage] += stage in s["reached"]
    for fy in sorted(by_fy):
        c, (r1, r2, r3) = by_fy[fy], RATES[max(2023, fy)]
        label = " (run-in, before reporting starts)" if fy < 2023 else ""
        print(f"  FY{fy % 100}/{(fy + 1) % 100}{label}: CV->int {c[INTERVIEWING] / c['sub']:.1%} ({r1:.1%}) | "
              f"int->offer {c[OFFERED] / c[INTERVIEWING]:.1%} ({r2:.1%}) | "
              f"offer->placed {c[PLACED] / c[OFFERED]:.1%} ({r3:.1%})")

    mature = [j for j in jobs if j["created"] <= END - timedelta(days=120)]
    print(f"\nFill rate (jobs older than 120 days): {sum(j['placed'] > 0 for j in mature) / len(mature):.1%}")

    settled_years, settled_placements = 0.0, 0
    for u in users:
        if u["is_manager"]:
            continue
        settled_from = max(u["hired"] + timedelta(days=365), START)
        settled_to = min(u["left"] or END, END)
        if settled_to > settled_from:
            settled_years += (settled_to - settled_from).days / 365
    for p in placements:
        s = p["sub"]
        u = s["job"]["recruiter"]
        if not u["is_manager"] and (s["placed_on"] - u["hired"]).days >= 365:
            settled_placements += 1
    print(f"Placements per settled consultant per year: {settled_placements / settled_years:.1f} (target 8-12, avg 10)")

    measurable = [p for p in placements if p["start"] <= END - timedelta(weeks=GUARANTEE_WEEKS + 3)]
    def fall(ps):
        return sum(1 for p in ps if p["leave"]) / max(1, len(ps))
    team = lambda p: p["sub"]["job"]["team"]["name"]
    arr = lambda p: p["sub"]["job"]["arrangement"]
    print(f"Fall-off: overall {fall(measurable):.1%} (9.6%) | {PROBLEM_TEAM} "
          f"{fall([p for p in measurable if team(p) == PROBLEM_TEAM]):.1%} (17.8%) | "
          f"office-only {fall([p for p in measurable if arr(p) == 'Office']):.1%} | "
          f"others {fall([p for p in measurable if arr(p) != 'Office' and team(p) != PROBLEM_TEAM]):.1%}")

    ttf = defaultdict(list)
    for p in placements:
        s = p["sub"]
        offer_day = next(d for d, _, to in s["path"] if to == OFFERED)
        ttf[s["job"]["arrangement"]].append((offer_day - s["job"]["created"]).days)
    print("Time to offer (days): " + " | ".join(
        f"{k} {sum(v) / len(v):.1f}" for k, v in sorted(ttf.items())))

    bc = [s for s in subs if s["job"]["company"] is big_client]
    bi = sum(INTERVIEWING in s["reached"] for s in bc)
    bo = sum(OFFERED in s["reached"] for s in bc)
    print(f"Story 4 client: '{big_client['name']}' (London) - {len(bc)} CVs, {bi} interviews, "
          f"int->offer {bo / max(1, bi):.1%}")

    reloc = [s for s in subs if INTERVIEWING in s["reached"] and s["candidate"]["can_relocate"]
             and (s["job"]["discipline"] in SCARCE_DISCIPLINES or s["job"]["office"] in RELOCATION_OFFICES)]
    print(f"Story 5: relocatable candidates in scarce roles, int->offer "
          f"{sum(OFFERED in s['reached'] for s in reloc) / len(reloc):.1%} (44.1%)")

    # rough target check using planning FX (real ECB rates are applied later in dbt)
    nfi = defaultdict(float)
    for p in placements:
        if p["invoiced"]:
            u = p["sub"]["job"]["recruiter"]
            key = (u["user_id"], fy_start(p["invoiced"]))
            nfi[key] += (p["fee"] - p["credited"]) / PLANNING_FX[p["currency"]]
    tgt = defaultdict(float)
    for uid, month, value, *_modified in targets_rows:
        y, mth = int(month[:4]), int(month[5:])
        tgt[(uid, y if mth >= 4 else y - 1)] += value
    user_by_id = {u["user_id"]: u for u in users}

    def settled_full_year(key):
        u, fy = user_by_id[key[0]], key[1]
        fy_begin, fy_finish = date(fy, 4, 1), date(fy + 1, 3, 31)
        return ((fy_begin - u["hired"]).days >= 15 * 30
                and (u["left"] is None or u["left"] > fy_finish))

    full_fy = [k for k in tgt if k[1] in (2023, 2024, 2025) and tgt[k] > 20000]
    for label, keys in [("all consultant-years", full_fy),
                        ("settled, full year", [k for k in full_fy if settled_full_year(k)])]:
        ach = sorted(nfi[k] / tgt[k] for k in keys)
        q = lambda x: ach[int(x * (len(ach) - 1))]
        inside = sum(0.85 <= a <= 1.10 for a in ach) / len(ach)
        print(f"Target achievement, {label} (n={len(ach)}, planning FX): median {q(0.5):.0%}, "
              f"10th pct {q(0.1):.0%}, 90th pct {q(0.9):.0%}, within 85-110%: {inside:.0%}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    random.seed(SEED)

    teams = build_teams()
    users = build_users(teams)
    companies, companies_by_office = build_companies(users)
    big_client = companies_by_office["London"][0]  # story 4: London's biggest client
    jobs = build_jobs(users, teams, companies_by_office)
    subs, candidates = build_submissions(jobs)
    duplicate_pairs = build_duplicates(subs, candidates)
    events, placed_subs = run_pipeline(jobs, subs, big_client)
    placements, transactions = build_finance(placed_subs)
    target_rows = build_targets(users, teams)
    security_rows = [(email, team, role, mod_crm(date(2026, 9, 1), 5))
                     for email, team, role in build_security(teams)]
    # 19 Sep: the access list's owner grants the CEO and CFO the "Unknown" team -
    # records that can't be tied to a team (e.g. orphan credit notes). A fixed
    # timestamp, NOT MOD_RNG, so no other file's values shift.
    security_rows += [(email, "Unknown", "Executive - unassigned records", "2026-09-19 10:00:00")
                      for email in ("ceo@example.com", "cfo@example.com")]

    for c in companies:
        c["last_event"] = c["first_job"]
    for j in jobs:
        c = j["company"]
        c["last_event"] = max(c["last_event"], j["last_event"])

    # ---- shape everything as source-system rows ------------------------------
    # A user record is last touched when they leave; an active one at some point
    # after joining (a profile edit, a team move).
    user_rows = [(u["user_id"], u["first_name"], u["last_name"], u["email"], user_title(u),
                  crm_ts(u["hired"]), u["office"], u["team"], u["manager_user_id"] or "",
                  crm_ts(u["left"]) if u["left"] else "",
                  mod_crm(u["left"], 10) if u["left"]
                  else mod_crm(max(u["hired"], SIM_START), (END - max(u["hired"], SIM_START)).days))
                 for u in users]

    active_companies = [c for c in companies if c["first_job"]]
    company_rows = [(c["company_id"], c["name"], c["city"], c["country"], c["owner"],
                     crm_ts(c["first_job"] - timedelta(days=random.randint(10, 400))),
                     crm_ts(c["last_event"]), c["industry"], c["sub_sector"])
                    for c in active_companies]

    # A history row records something that happened, so it is never edited:
    # modified == the event timestamp.
    history_rows = []
    for i, (d, cid, jid, frm, to) in enumerate(events, start=1):
        ts = crm_ts(d)
        history_rows.append((i, cid, jid, ts, frm, to, ts))

    placement_rows = [(p["placement_ref"], p["sub"]["job"]["joborder_id"], p["sub"]["candidate_id"],
                       p["sub"]["job"]["recruiter"]["user_id"], p["sub"]["job"]["office"],
                       fin_date(p["sub"]["placed_on"]),
                       fin_date(p["start"]), fin_date(p["leave"]) if p["leave"] else "",
                       p["salary"], p["fee_pct"], p["currency"],
                       mod_fin(max(d for d in (p["sub"]["placed_on"], p["start"], p["leave"]) if d), 3))
                      for p in placements]
    # an invoice or credit note is posted a day or two after its document date
    transaction_rows = [(no, t, ref, fin_date(d), amt, cur, mod_fin(d, 2))
                        for no, t, ref, d, amt, cur in transactions]

    plant_problems(jobs, history_rows, placement_rows, transaction_rows)

    job_rows = []
    for j in jobs:
        if j["placed"] >= j["openings"]:
            status = "Full"
        elif j["created"] > END - timedelta(days=75):
            status = "Active"
        else:
            status = weighted([("Closed", 0.8), ("OnHold", 0.2)])
        owner = j["recruiter"]["user_id"] if random.random() < 0.7 else j["team"]["manager"]["user_id"]
        start_text = crm_ts(j["created"] + timedelta(days=60)) if random.random() < 0.7 else ""
        job_rows.append((j["joborder_id"], j["company"]["company_id"], j["recruiter"]["user_id"],
                         owner, j["title"], "H", j["salary_text"], status, j["company"]["city"],
                         j["company"]["country"], j["openings"], start_text, crm_ts(j["created"]),
                         crm_ts(j["last_event"]), j.get("discipline_out", j["discipline"]),
                         j["arrangement"], j["office"]))

    # A candidate record is last touched by their most recent pipeline event.
    last_seen = {}
    for d, cid, _jid, _frm, _to in events:
        if cid not in last_seen or d > last_seen[cid]:
            last_seen[cid] = d
    candidate_rows = [(c["candidate_id"], c["can_relocate"], crm_ts(c["created"]),
                       mod_crm(last_seen.get(c["candidate_id"], c["created"])))
                      for c in sorted(candidates, key=lambda c: c["candidate_id"])]

    created_by_id = {c["candidate_id"]: c["created"] for c in candidates}
    duplicate_rows = [(old, new, mod_crm(created_by_id[new])) for old, new in duplicate_pairs]

    status_rows = [(code, description, "2022-10-01 09:00:00")
                   for code, description in STATUS_LOOKUP]

    target_rows = [(uid, month, value,
                    mod_fin(date(int(month[:4]) if int(month[5:]) >= 4 else int(month[:4]) - 1, 4, 1), 20))
                   for uid, month, value in target_rows]

    # ---- write -----------------------------------------------------------------
    crm, fin, sec, ref = RAW / "crm", RAW / "finance", RAW / "security", RAW / "reference"
    industry_lookup, discipline_lookup = build_crm_lookups()
    counts = {
        "crm/user.csv": write_csv(crm / "user.csv", [
            "user_id", "first_name", "last_name", "email", "title", "date_created",
            "office", "team", "manager_user_id", "date_left", "date_modified"], user_rows),
        "crm/company.csv": write_csv(crm / "company.csv", [
            "company_id", "name", "city", "country", "owner", "date_created",
            "date_modified", "industry", "sub_sector"], company_rows),
        "crm/joborder.csv": write_csv(crm / "joborder.csv", [
            "joborder_id", "company_id", "recruiter", "owner", "title", "type", "salary",
            "status", "city", "country", "openings", "start_date", "date_created",
            "date_modified", "discipline", "work_arrangement", "owning_office"], job_rows),
        "crm/candidate.csv": write_csv(crm / "candidate.csv", [
            "candidate_id", "can_relocate", "date_created", "date_modified"], candidate_rows),
        "crm/candidate_duplicates.csv": write_csv(crm / "candidate_duplicates.csv", [
            "old_candidate_id", "new_candidate_id", "date_modified"], duplicate_rows),
        "crm/candidate_joborder_status.csv": write_csv(crm / "candidate_joborder_status.csv", [
            "candidate_joborder_status_id", "short_description", "date_modified"], status_rows),
        "crm/candidate_joborder_status_history.csv": write_csv(
            crm / "candidate_joborder_status_history.csv", [
                "candidate_joborder_status_history_id", "candidate_id", "joborder_id",
                "date", "status_from", "status_to", "date_modified"], history_rows),
        "finance/placements.csv": write_csv(fin / "placements.csv", [
            "placement_ref", "joborder_id", "candidate_id", "consultant_user_id",
            "booking_office", "date_placed", "start_date", "leave_date", "salary",
            "fee_pct", "currency", "modified_at"], placement_rows),
        "finance/transactions.csv": write_csv(fin / "transactions.csv", [
            "doc_no", "doc_type", "placement_ref", "doc_date", "net_amount", "currency",
            "modified_at"], transaction_rows),
        "finance/targets.csv": write_csv(fin / "targets.csv", [
            "user_id", "month", "target_nfi_gbp", "modified_at"], target_rows),
        "security/security_user_team.csv": write_csv(sec / "security_user_team.csv", [
            "user_email", "team", "role_description", "last_updated"], security_rows),
        "crm/industry.csv": write_csv(crm / "industry.csv", [
            "sub_sector_id", "sub_sector", "industry_id", "industry", "valid_from",
            "valid_to", "date_modified"], industry_lookup),
        "crm/discipline.csv": write_csv(crm / "discipline.csv", [
            "discipline_id", "discipline", "valid_from", "valid_to", "date_modified"],
            discipline_lookup),
        "reference/funnel_stage.csv": write_csv(ref / "funnel_stage.csv", [
            "status_code", "funnel_stage", "funnel_stage_order", "stage_type", "exit_by",
            "last_updated"], build_funnel_stage_reference()),
        "reference/office.csv": write_csv(ref / "office.csv", [
            "office_name", "city", "country_code", "country_name", "region",
            "region_sort_order", "currency_code", "last_updated"], build_office_reference()),
    }

    print(f"Wrote to {RAW}")
    for name, n in counts.items():
        print(f"  {name:<45} {n:>8,} rows")
    inv = sum(1 for t in transaction_rows if t[1] == "INV")
    print(f"  (transactions: {inv:,} invoices, {len(transaction_rows) - inv:,} credit notes; "
          f"teams: {len(teams)}; clients with jobs: {len(active_companies)})")

    summary(users, jobs, subs, placements, target_rows, big_client, teams)


if __name__ == "__main__":
    main()
