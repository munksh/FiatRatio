#!/usr/bin/env python3
"""fiat ratio — native export/import, schema v2. Reference implementation and
specification by example for the app's C++ side.

    export_bundle(conn)               -> dict      (one JSON file)
    import_bundle(conn, bundle, mode) -> stats     mode 'replace' | 'merge'
    export_csv(conn, folder)          -> files     (spreadsheet-friendly)
    export_qif(conn, path)            -> file      (GnuCash, HomeBank, …)

Rows reference each other by uuid. Periods are keyed by their label
('2026-10'). Merge keeps the newer updated_at per row and carries tombstones.
"""
import csv, json, os, sqlite3, datetime as dt

FORMAT, VERSION = "fiat-ratio-bundle", 2

# table -> {fk column: target table}, in insert order
TABLES = {
    "person":       {},
    "bucket":       {},
    "category":     {"parent_id": "category", "bucket_id": "bucket"},
    "method":       {},
    "context":      {},
    "payee":        {"default_category_id": "category", "default_method_id": "method"},
    "account":      {"parent_id": "account", "person_id": "person", "bucket_id": "bucket", "shared_with_id": "person"},
    "account_rate": {"account_id": "account"},
    "schedule":     {"account_id": "account", "to_account_id": "account", "category_id": "category",
                     "method_id": "method", "payee_id": "payee"},
    "txn":          {"account_id": "account", "category_id": "category", "transfer_peer_id": "txn",
                     "parent_id": "txn", "method_id": "method", "context_id": "context", "payee_id": "payee",
                     "person_id": "person", "schedule_id": "schedule"},
    "valuation":    {"account_id": "account"},
    "budget":       {"bucket_id": "bucket", "category_id": "category"},
}
SELF_REFS = {("category", "parent_id"), ("account", "parent_id"), ("txn", "transfer_peer_id"), ("txn", "parent_id")}


def now():
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def rows(conn, table, order="rowid"):
    cur = conn.execute(f"SELECT * FROM {table} ORDER BY {order}")
    cols = [c[0] for c in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def export_bundle(conn, include_archive=False, app_version="0.0.0-dev"):
    uuid_of = {t: dict(conn.execute(f"SELECT id, uuid FROM {t}")) for t in TABLES}
    tables = {}
    for t, fks in TABLES.items():
        out = []
        for r in rows(conn, t):
            r.pop("id")
            for col, target in fks.items():
                v = r.pop(col)
                r[col[:-3]] = uuid_of[target].get(v) if v is not None else None
            out.append({k: v for k, v in r.items() if v is not None})
        tables[t] = out
    periods = []
    for p in rows(conn, "period", "id"):
        a = p.pop("anchor_txn_id")
        p["anchor_txn"] = uuid_of["txn"].get(a) if a else None
        periods.append({k: v for k, v in p.items() if v is not None})
    tables["period"] = periods
    b = {"format": FORMAT, "version": VERSION, "app_version": app_version, "exported_at": now(),
         "meta": dict(conn.execute("SELECT key, value FROM meta ORDER BY key")), "tables": tables}
    if include_archive:
        b["import_archive"] = rows(conn, "import_archive", "origin_ref")
    return b


def import_bundle(conn, bundle, mode="replace"):
    if bundle.get("format") != FORMAT:
        raise ValueError("Not a fiat ratio bundle")
    if bundle.get("version", 0) > VERSION:
        raise ValueError(f"Bundle version {bundle['version']} is newer than this app ({VERSION})")
    stats = {"inserted": 0, "updated": 0, "skipped": 0}
    cur = conn.cursor()
    cur.execute("PRAGMA foreign_keys = OFF")
    if mode == "replace":
        for t in ["import_archive", "period", *reversed(list(TABLES)), "meta"]:
            cur.execute(f"DELETE FROM {t}")
    for k, v in bundle.get("meta", {}).items():
        cur.execute("INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", (k, v))
    for p in bundle["tables"].get("period", []):
        old = cur.execute("SELECT updated_at FROM period WHERE id = ?", (p["id"],)).fetchone()
        if old and (p.get("updated_at") or "") <= (old[0] or ""):
            continue
        cur.execute("INSERT OR REPLACE INTO period (id, start_date, anchor_txn_id, closed, notes, updated_at) "
                    "VALUES (?, ?, NULL, ?, ?, ?)", (p["id"], p["start_date"], p.get("closed", 0), p.get("notes"), p["updated_at"]))
    id_of = {t: {u: i for i, u in cur.execute(f"SELECT id, uuid FROM {t}")} for t in TABLES}
    pending = []
    for t, fks in TABLES.items():
        cols = [c[1] for c in cur.execute(f"PRAGMA table_info({t})")]
        for row in bundle["tables"].get(t, []):
            rec = dict(row)
            for col, target in fks.items():
                ref = rec.pop(col[:-3], None)
                if (t, col) in SELF_REFS:
                    if ref:
                        pending.append((t, col, rec["uuid"], ref))
                    rec[col] = None
                else:
                    rec[col] = id_of[target].get(ref) if ref else None
            rec = {k: v for k, v in rec.items() if k in cols}
            ex = id_of[t].get(rec["uuid"])
            if ex is not None:
                old = cur.execute(f"SELECT updated_at FROM {t} WHERE id = ?", (ex,)).fetchone()[0]
                if (rec.get("updated_at") or "") <= (old or ""):
                    stats["skipped"] += 1
                    continue
                keys = [k for k in rec if (t, k) not in SELF_REFS]
                cur.execute(f"UPDATE {t} SET {', '.join(k + ' = ?' for k in keys)} WHERE id = ?",
                            [rec[k] for k in keys] + [ex])
                stats["updated"] += 1
            else:
                cur.execute(f"INSERT INTO {t} ({', '.join(rec)}) VALUES ({', '.join('?' * len(rec))})", list(rec.values()))
                id_of[t][rec["uuid"]] = cur.lastrowid
                stats["inserted"] += 1
    for t, col, uuid, ref in pending:
        cur.execute(f"UPDATE {t} SET {col} = ? WHERE uuid = ?", (id_of[t].get(ref), uuid))
    for p in bundle["tables"].get("period", []):
        if p.get("anchor_txn"):
            cur.execute("UPDATE period SET anchor_txn_id = ? WHERE id = ?", (id_of["txn"].get(p["anchor_txn"]), p["id"]))
    for a in bundle.get("import_archive", []):
        cur.execute("INSERT OR REPLACE INTO import_archive VALUES (?, ?, ?, ?)",
                    (a["origin_ref"], a["source_table"], a["raw_json"], a["imported_at"]))
    cur.execute("PRAGMA foreign_keys = ON")
    bad = cur.execute("PRAGMA foreign_key_check").fetchall()
    if bad:
        raise ValueError(f"Bundle left {len(bad)} dangling references, e.g. {bad[0]}")
    conn.commit()
    return stats


# ------------------------------------------------------------------ CSV and QIF
def _m(v):
    return "" if v is None else f"{v / 100:.2f}"


def label(conn, lang="en"):
    """Display names: the user's own name, else the translation of the key."""
    std = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "i18n", "standard.json"), encoding="utf-8"))
    cats = {i: (n or std["categories"].get(k, {}).get(lang) or k) for i, k, n in conn.execute("SELECT id, key, name FROM category")}
    bks = {i: (n or std["buckets"].get(k, {}).get(lang) or k) for i, k, n in conn.execute("SELECT id, key, name FROM bucket")}
    return cats, bks


FLAT = """
SELECT t.id, t.uuid, t.date, t.period_id, a.name, t.amount, t.amount_full, a.currency, t.status,
       CASE WHEN t.transfer_peer_id IS NOT NULL THEN 'transfer' WHEN c.kind = 'income' THEN 'income'
            WHEN c.kind = 'neutral' THEN 'neutral' WHEN t.amount > 0 AND c.kind = 'expense' THEN 'refund'
            WHEN c.kind = 'expense' THEN 'expense' ELSE '' END,
       t.category_id, c.bucket_id, pa.name, m.name, x.name, p.name, pe.name, t.description, t.notes, t.scope, t.cadence,
       par.uuid
FROM txn t JOIN account a ON a.id = t.account_id
LEFT JOIN category c ON c.id = t.category_id
LEFT JOIN txn peer ON peer.id = t.transfer_peer_id LEFT JOIN account pa ON pa.id = peer.account_id
LEFT JOIN method m ON m.id = t.method_id LEFT JOIN context x ON x.id = t.context_id
LEFT JOIN payee p ON p.id = t.payee_id LEFT JOIN person pe ON pe.id = t.person_id
LEFT JOIN txn par ON par.id = t.parent_id
WHERE t.deleted_at IS NULL ORDER BY t.date, t.id"""

FLAT_HEAD = ["uuid", "date", "period", "account", "amount", "amount_full", "currency", "status", "type", "category",
             "bucket", "transfer_account", "method", "context", "payee", "person", "description", "notes", "scope",
             "cadence", "split_parent"]


def export_csv(conn, folder, lang="en"):
    os.makedirs(folder, exist_ok=True)
    cats, bks = label(conn, lang)
    files = []
    p = os.path.join(folder, "transactions.csv")
    with open(p, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(FLAT_HEAD)
        for r in conn.execute(FLAT):
            r = list(r)
            out = [r[1], r[2], r[3], r[4], _m(r[5]), _m(r[6]), r[7], r[8], r[9], cats.get(r[10], ""),
                   bks.get(r[11], ""), *r[12:]]
            w.writerow(["" if v is None else v for v in out])
    files.append(p)
    for t in ["account", "category", "bucket", "valuation", "method", "context", "person", "schedule", "period"]:
        p = os.path.join(folder, f"{t}.csv")
        rs = rows(conn, t)
        with open(p, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            if rs:
                w.writerow(rs[0].keys())
                w.writerows([["" if v is None else v for v in r.values()] for r in rs])
        files.append(p)
    return files


def export_qif(conn, path, lang="en"):
    """QIF: the oldest format nearly every finance program still reads."""
    cats, _ = label(conn, lang)
    accounts = rows(conn, "account", "sort")
    qtype = {"pot": "Bank", "savings": "Bank", "investment": "Invst", "pension": "Invst", "crypto": "Invst",
             "loan": "Oth L", "mortgage": "Oth L", "credit": "CCard", "person": "Oth A"}
    names = {a["id"]: a["name"] for a in accounts}
    with open(path, "w", encoding="utf-8") as f:
        for a in accounts:
            ts = conn.execute("SELECT date, amount, description, category_id, transfer_peer_id, notes FROM txn "
                              "WHERE account_id = ? AND parent_id IS NULL AND deleted_at IS NULL ORDER BY date, id",
                              (a["id"],)).fetchall()
            if not ts:
                continue
            f.write(f"!Account\nN{a['name']}\nT{qtype.get(a['kind'], 'Oth A')}\n^\n!Type:{qtype.get(a['kind'], 'Oth A')}\n")
            for d, amt, desc, cat, peer, notes in ts:
                f.write(f"D{d}\nT{amt / 100:.2f}\nP{desc or ''}\n")
                if peer:
                    other = conn.execute("SELECT account_id FROM txn WHERE id = ?", (peer,)).fetchone()[0]
                    f.write(f"L[{names[other]}]\n")
                elif cat:
                    f.write(f"L{cats.get(cat, '')}\n")
                if notes:
                    f.write(f"M{notes.splitlines()[0]}\n")
                f.write("^\n")
    return path


def new_db(path, schema_path):
    if os.path.exists(path):
        os.remove(path)
    conn = sqlite3.connect(path)
    conn.executescript(open(schema_path, encoding="utf-8").read())
    return conn


def canonical(bundle):
    b = json.loads(json.dumps(bundle))
    b.pop("exported_at", None)
    return json.dumps(b, sort_keys=True, ensure_ascii=False)
