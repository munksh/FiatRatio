-- fiat ratio — SQLite schema, version 2
--
-- What changed from v1, and why
--   * Payment methods are not accounts. SEB, Handelsbanken, Rocker, cash …
--     are a list (method) you pick from; the month's money is ONE pot that
--     the salary fills. Accounts are only where money is kept or owed:
--     savings, investments, pension, property, loans, and people.
--   * Shared ownership. Every amount is stored as YOUR PART, which is what
--     your budget and net worth need. Where something is shared, the whole
--     is kept beside it (amount_full, value_full, and my_share on the
--     account), so a 50 % house shows 5 M while counting 2.5 M.
--   * A month is a row (period) with a start date, not a calculation. It
--     can start on payday, on the 1st, or when the salary is entered.
--   * Context is a managed list, not free tags.
--   * Categories and buckets carry a key; the app translates keyed rows and
--     shows your own name where you renamed one.
--   * The two legs of a transfer may differ: SEK out, RUB in; your half out,
--     a whole shared payment in.
--   * Loans can have parts (lånedelar) and a rate history.
--   * Inköp is gone.
--
-- Conventions (unchanged)
--   Money is INTEGER minor units, signed from the account's point of view.
--   Dates are 'YYYY-MM-DD'. Every row has a uuid; updated_at on every write;
--   deleted_at is a tombstone. Nothing computed is stored.

PRAGMA foreign_keys = ON;

CREATE TABLE meta (
    key   TEXT PRIMARY KEY,
    value TEXT
);
-- schema_version, base_currency, language, period_mode
-- ('calendar' | 'payday' | 'salary'), payday_day, payday_rule
-- ('before' | 'after' | 'exact'), holiday_country ('SE'), created_at

CREATE TABLE person (
    id          INTEGER PRIMARY KEY,
    uuid        TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL UNIQUE,
    is_partner  INTEGER NOT NULL DEFAULT 0,
    notes       TEXT,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    deleted_at  TEXT
);

CREATE TABLE bucket (
    id           INTEGER PRIMARY KEY,
    uuid         TEXT NOT NULL UNIQUE,
    key          TEXT UNIQUE,             -- 'needs' … NULL for your own
    name         TEXT,                    -- NULL = the translation of key
    target_share REAL,
    target_kind  TEXT CHECK (target_kind IN ('max','min')),
    color        TEXT,
    sort         INTEGER NOT NULL DEFAULT 0,
    created_at   TEXT NOT NULL,
    updated_at   TEXT NOT NULL,
    deleted_at   TEXT,
    CHECK (key IS NOT NULL OR name IS NOT NULL)
);

-- kind 'neutral' is for rows that are neither spending nor income
-- (cash withdrawals, corrections).
CREATE TABLE category (
    id          INTEGER PRIMARY KEY,
    uuid        TEXT NOT NULL UNIQUE,
    key         TEXT UNIQUE,
    name        TEXT,
    kind        TEXT NOT NULL CHECK (kind IN ('expense','income','neutral')),
    parent_id   INTEGER REFERENCES category(id),
    bucket_id   INTEGER REFERENCES bucket(id),
    color       TEXT,
    sort        INTEGER NOT NULL DEFAULT 0,
    archived    INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    deleted_at  TEXT,
    origin_ref  TEXT,
    CHECK (key IS NOT NULL OR name IS NOT NULL)
);

-- How you paid: a list, not a place money lives.
CREATE TABLE method (
    id          INTEGER PRIMARY KEY,
    uuid        TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL UNIQUE,
    institution TEXT,
    archived    INTEGER NOT NULL DEFAULT 0,
    sort        INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    deleted_at  TEXT
);

-- The context list (Travel, Project, Social Club …), managed in settings.
CREATE TABLE context (
    id          INTEGER PRIMARY KEY,
    uuid        TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL UNIQUE,
    archived    INTEGER NOT NULL DEFAULT 0,
    sort        INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    deleted_at  TEXT
);

CREATE TABLE payee (
    id                  INTEGER PRIMARY KEY,
    uuid                TEXT NOT NULL UNIQUE,
    name                TEXT NOT NULL UNIQUE,
    default_category_id INTEGER REFERENCES category(id),
    default_method_id   INTEGER REFERENCES method(id),
    scope               TEXT CHECK (scope IN ('personal','business')),
    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL,
    deleted_at          TEXT
);

CREATE TABLE account (
    id              INTEGER PRIMARY KEY,
    uuid            TEXT NOT NULL UNIQUE,
    name            TEXT NOT NULL,
    kind            TEXT NOT NULL CHECK (kind IN (
                        'pot',                                -- the month's money
                        'savings','investment','pension','crypto',
                        'property','vehicle','possessions','deposit',
                        'loan','mortgage','credit',
                        'person')),                           -- owed to / by someone
    parent_id       INTEGER REFERENCES account(id),          -- loan parts, sub-pots
    person_id       INTEGER REFERENCES person(id),           -- kind = 'person', or the lender
    institution     TEXT,
    currency        TEXT NOT NULL DEFAULT 'SEK',
    on_budget       INTEGER NOT NULL DEFAULT 0,
    balance_source  TEXT NOT NULL DEFAULT 'ledger' CHECK (balance_source IN ('ledger','valuation')),
    bucket_id       INTEGER REFERENCES bucket(id),
    my_share        REAL NOT NULL DEFAULT 1.0,               -- 0..1
    shared_with_id  INTEGER REFERENCES person(id),
    partner_mirrors INTEGER NOT NULL DEFAULT 0,              -- partner puts in what I put in
    opening_date    TEXT,
    opening_balance INTEGER NOT NULL DEFAULT 0,              -- my part
    opening_full    INTEGER,                                 -- the whole, when shared
    term_months     INTEGER,
    goal_amount     INTEGER,
    goal_date       TEXT,
    closed_date     TEXT,
    in_net_worth    INTEGER NOT NULL DEFAULT 1,
    scope           TEXT NOT NULL DEFAULT 'personal' CHECK (scope IN ('personal','business')),
    color           TEXT,
    sort            INTEGER NOT NULL DEFAULT 0,
    notes           TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL,
    deleted_at      TEXT,
    origin_ref      TEXT
);

-- Variable rates: one row per change. Projections use the latest.
CREATE TABLE account_rate (
    id          INTEGER PRIMARY KEY,
    uuid        TEXT NOT NULL UNIQUE,
    account_id  INTEGER NOT NULL REFERENCES account(id),
    from_date   TEXT NOT NULL,
    rate        REAL NOT NULL,                -- percent per year
    fixed_until TEXT,                         -- bunden ränta
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    deleted_at  TEXT
);

-- A budget month. id is the label ('2026-10'); start_date is when it began.
CREATE TABLE period (
    id            TEXT PRIMARY KEY,           -- 'YYYY-MM'
    start_date    TEXT NOT NULL,
    anchor_txn_id INTEGER REFERENCES txn(id), -- the salary that opened it
    closed        INTEGER NOT NULL DEFAULT 0,
    notes         TEXT,
    updated_at    TEXT NOT NULL
);

CREATE TABLE schedule (
    id             INTEGER PRIMARY KEY,
    uuid           TEXT NOT NULL UNIQUE,
    name           TEXT NOT NULL,
    kind           TEXT NOT NULL CHECK (kind IN ('expense','income','transfer')),
    account_id     INTEGER NOT NULL REFERENCES account(id),
    to_account_id  INTEGER REFERENCES account(id),
    category_id    INTEGER REFERENCES category(id),
    method_id      INTEGER REFERENCES method(id),
    payee_id       INTEGER REFERENCES payee(id),
    amount         INTEGER NOT NULL,          -- my part
    amount_full    INTEGER,
    freq           TEXT NOT NULL CHECK (freq IN ('weekly','monthly','quarterly','yearly')),
    every          INTEGER NOT NULL DEFAULT 1,
    day            INTEGER,
    start_date     TEXT NOT NULL,
    end_date       TEXT,
    active         INTEGER NOT NULL DEFAULT 1,
    is_salary      INTEGER NOT NULL DEFAULT 0, -- opens a new period when it arrives
    month          INTEGER,                    -- yearly/quarterly: which month it falls in
    remind_days    INTEGER,                    -- calendar reminder this many days before
    planned_until  TEXT,                       -- last date already written out as planned rows
    notes          TEXT,
    created_at     TEXT NOT NULL,
    updated_at     TEXT NOT NULL,
    deleted_at     TEXT
);

CREATE TABLE txn (
    id               INTEGER PRIMARY KEY,
    uuid             TEXT NOT NULL UNIQUE,
    account_id       INTEGER NOT NULL REFERENCES account(id),
    date             TEXT NOT NULL,
    period_id        TEXT NOT NULL REFERENCES period(id),
    amount           INTEGER NOT NULL,        -- my part, account currency, signed
    amount_full      INTEGER,                 -- the whole price when shared
    status           TEXT NOT NULL DEFAULT 'cleared'
                         CHECK (status IN ('planned','cleared','reconciled')),
    category_id      INTEGER REFERENCES category(id),
    transfer_peer_id INTEGER REFERENCES txn(id),
    parent_id        INTEGER REFERENCES txn(id),
    method_id        INTEGER REFERENCES method(id),
    context_id       INTEGER REFERENCES context(id),
    payee_id         INTEGER REFERENCES payee(id),
    person_id        INTEGER REFERENCES person(id),  -- shared with / paid by
    description      TEXT,
    notes            TEXT,
    scope            TEXT NOT NULL DEFAULT 'personal' CHECK (scope IN ('personal','business')),
    cadence          TEXT CHECK (cadence IN ('one_time','daily','frequent','monthly','quarterly','yearly')),
    is_salary        INTEGER NOT NULL DEFAULT 0,
    schedule_id      INTEGER REFERENCES schedule(id),
    created_at       TEXT NOT NULL,
    updated_at       TEXT NOT NULL,
    deleted_at       TEXT,
    origin           TEXT NOT NULL DEFAULT 'manual',
    origin_ref       TEXT
);
CREATE INDEX txn_account_date ON txn(account_id, date);
CREATE INDEX txn_period       ON txn(period_id);
CREATE INDEX txn_category     ON txn(category_id);
CREATE INDEX txn_parent       ON txn(parent_id);
CREATE UNIQUE INDEX txn_origin ON txn(origin_ref) WHERE origin_ref IS NOT NULL;
-- "Plan next month" / "Plan the coming year" can run twice without doubling anything.
CREATE UNIQUE INDEX txn_schedule_date ON txn(schedule_id, date) WHERE schedule_id IS NOT NULL AND parent_id IS NULL;

CREATE TABLE valuation (
    id          INTEGER PRIMARY KEY,
    uuid        TEXT NOT NULL UNIQUE,
    account_id  INTEGER NOT NULL REFERENCES account(id),
    date        TEXT NOT NULL,
    value       INTEGER NOT NULL,      -- my part, account currency
    value_full  INTEGER,               -- the whole, when shared
    value_base  INTEGER NOT NULL,      -- my part in base currency
    contributed INTEGER,               -- my part put in so far, base currency
    note        TEXT,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    deleted_at  TEXT,
    origin_ref  TEXT
);
CREATE INDEX valuation_account_date ON valuation(account_id, date);

CREATE TABLE budget (
    id          INTEGER PRIMARY KEY,
    uuid        TEXT NOT NULL UNIQUE,
    period_id   TEXT REFERENCES period(id),     -- NULL = every month
    bucket_id   INTEGER REFERENCES bucket(id),
    category_id INTEGER REFERENCES category(id),
    amount      INTEGER NOT NULL,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    deleted_at  TEXT,
    CHECK ((bucket_id IS NULL) <> (category_id IS NULL))
);

CREATE TABLE import_archive (
    origin_ref   TEXT PRIMARY KEY,
    source_table TEXT NOT NULL,
    raw_json     TEXT NOT NULL,
    imported_at  TEXT NOT NULL
);

-- ---------------------------------------------------------------- views

-- Rows that carry meaning on their own: split parents drop out.
CREATE VIEW v_line AS
SELECT t.*, c.kind AS category_kind, c.bucket_id AS category_bucket_id,
       a.kind AS account_kind, a.on_budget
FROM txn t
JOIN account a ON a.id = t.account_id
LEFT JOIN category c ON c.id = t.category_id
WHERE t.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM txn ch WHERE ch.parent_id = t.id AND ch.deleted_at IS NULL);

CREATE VIEW v_ledger_balance AS
SELECT a.id AS account_id,
       a.opening_balance + IFNULL((SELECT SUM(t.amount) FROM txn t
                                   WHERE t.account_id = a.id AND t.parent_id IS NULL
                                     AND t.deleted_at IS NULL AND t.status <> 'planned'), 0) AS balance
FROM account a WHERE a.deleted_at IS NULL;

CREATE VIEW v_latest_valuation AS
SELECT v.* FROM valuation v
WHERE v.deleted_at IS NULL
  AND v.date = (SELECT MAX(v2.date) FROM valuation v2
                WHERE v2.account_id = v.account_id AND v2.deleted_at IS NULL)
  AND v.id = (SELECT MAX(v3.id) FROM valuation v3
              WHERE v3.account_id = v.account_id AND v3.deleted_at IS NULL AND v3.date = v.date);

-- My part of every account, in base currency.
CREATE VIEW v_account_value AS
SELECT a.id AS account_id, a.name, a.kind, a.my_share,
       CASE a.balance_source
            WHEN 'valuation' THEN IFNULL((SELECT value_base FROM v_latest_valuation lv WHERE lv.account_id = a.id), 0)
            ELSE (SELECT balance FROM v_ledger_balance lb WHERE lb.account_id = a.id)
       END AS value_mine
FROM account a
WHERE a.deleted_at IS NULL AND a.in_net_worth = 1 AND a.closed_date IS NULL;

CREATE VIEW v_net_worth AS
SELECT SUM(CASE WHEN value_mine > 0 THEN value_mine ELSE 0 END) AS assets,
       -SUM(CASE WHEN value_mine < 0 THEN value_mine ELSE 0 END) AS debts,
       SUM(value_mine) AS net
FROM v_account_value;

-- Where the month's money went: spending from the pot by bucket, plus money
-- moved out of the pot into accounts that carry a bucket.
CREATE VIEW v_period_bucket AS
SELECT l.period_id, l.status, l.category_bucket_id AS bucket_id, -SUM(l.amount) AS amount
FROM v_line l
WHERE l.on_budget = 1 AND (l.category_kind = 'expense'
      OR (l.category_id IS NULL AND l.transfer_peer_id IS NULL AND l.amount < 0))
GROUP BY 1, 2, 3
UNION ALL
SELECT l.period_id, l.status, dest.bucket_id, -SUM(l.amount)
FROM v_line l
JOIN txn peer ON peer.id = l.transfer_peer_id
JOIN account dest ON dest.id = peer.account_id
WHERE l.on_budget = 1 AND dest.on_budget = 0 AND dest.bucket_id IS NOT NULL
  -- money back from savings nets against saving; money borrowed is not un-spending
  AND (l.amount < 0 OR dest.kind IN ('savings','investment','pension','crypto','deposit'))
GROUP BY 1, 2, 3;
