#include "bundle.h"

#include <QDateTime>
#include <QHash>
#include <QJsonArray>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QStringList>
#include <QVector>
#include <cmath>

namespace {

const char *FORMAT = "fiat-ratio-bundle";
const int VERSION = 2;

struct Fk { QString column; QString target; };
struct Table { QString name; QVector<Fk> fks; };

QVector<Table> tables()
{
    return {
        {"person", {}},
        {"bucket", {}},
        {"category", {{"parent_id", "category"}, {"bucket_id", "bucket"}}},
        {"method", {}},
        {"context", {}},
        {"payee", {{"default_category_id", "category"}, {"default_method_id", "method"}}},
        {"account", {{"parent_id", "account"}, {"person_id", "person"}, {"bucket_id", "bucket"}, {"shared_with_id", "person"}}},
        {"account_rate", {{"account_id", "account"}}},
        {"schedule", {{"account_id", "account"}, {"to_account_id", "account"}, {"category_id", "category"},
                      {"method_id", "method"}, {"payee_id", "payee"}}},
        {"txn", {{"account_id", "account"}, {"category_id", "category"}, {"transfer_peer_id", "txn"},
                 {"parent_id", "txn"}, {"method_id", "method"}, {"context_id", "context"}, {"payee_id", "payee"},
                 {"person_id", "person"}, {"schedule_id", "schedule"}}},
        {"valuation", {{"account_id", "account"}}},
        {"budget", {{"bucket_id", "bucket"}, {"category_id", "category"}}},
    };
}

bool selfRef(const QString &table, const QString &column)
{
    return (table == "category" && column == "parent_id") || (table == "account" && column == "parent_id")
        || (table == "txn" && (column == "transfer_peer_id" || column == "parent_id"));
}

QString stripId(const QString &column) { return column.left(column.length() - 3); }

QJsonValue toJson(const QVariant &v)
{
    switch (v.type()) {
    case QVariant::LongLong: case QVariant::Int: case QVariant::UInt: case QVariant::ULongLong:
        return QJsonValue(static_cast<double>(v.toLongLong()));
    case QVariant::Double:
        return QJsonValue(v.toDouble());
    default:
        return QJsonValue(v.toString());
    }
}

QVariant fromJson(const QJsonValue &v)
{
    if (v.isNull() || v.isUndefined())
        return QVariant();
    if (v.isBool())
        return QVariant(v.toBool() ? 1 : 0);
    if (v.isDouble()) {
        double d = v.toDouble();
        if (std::floor(d) == d && std::fabs(d) < 9.0e15)
            return QVariant(static_cast<qlonglong>(d));
        return QVariant(d);
    }
    return QVariant(v.toString());
}

QStringList columnsOf(QSqlDatabase &db, const QString &table)
{
    QStringList cols;
    QSqlQuery q(db);
    q.exec(QString("PRAGMA table_info(%1)").arg(table));
    while (q.next())
        cols << q.value(1).toString();
    return cols;
}

QHash<qlonglong, QString> uuidMap(QSqlDatabase &db, const QString &table)
{
    QHash<qlonglong, QString> m;
    QSqlQuery q(db);
    q.exec(QString("SELECT id, uuid FROM %1").arg(table));
    while (q.next())
        m.insert(q.value(0).toLongLong(), q.value(1).toString());
    return m;
}

QString nowIso()
{
    return QDateTime::currentDateTimeUtc().toString("yyyy-MM-ddTHH:mm:ssZ");
}

} // namespace

QJsonObject Bundle::exportBundle(QSqlDatabase &db, bool includeArchive, const QString &appVersion)
{
    QHash<QString, QHash<qlonglong, QString>> uuidOf;
    for (const Table &t : tables())
        uuidOf.insert(t.name, uuidMap(db, t.name));

    QJsonObject out;
    for (const Table &t : tables()) {
        QHash<QString, QString> fkTarget;
        for (const Fk &f : t.fks)
            fkTarget.insert(f.column, f.target);
        QJsonArray arr;
        QSqlQuery q(db);
        q.exec(QString("SELECT * FROM %1 ORDER BY rowid").arg(t.name));
        QSqlRecord rec = q.record();
        while (q.next()) {
            QJsonObject row;
            for (int i = 0; i < rec.count(); ++i) {
                const QString col = rec.fieldName(i);
                const QVariant v = q.value(i);
                if (col == "id" || v.isNull())
                    continue;
                if (fkTarget.contains(col)) {
                    const QString u = uuidOf[fkTarget[col]].value(v.toLongLong());
                    if (!u.isEmpty())
                        row.insert(stripId(col), u);
                } else {
                    row.insert(col, toJson(v));
                }
            }
            arr.append(row);
        }
        out.insert(t.name, arr);
    }
    QJsonArray periods;
    QSqlQuery p(db);
    p.exec("SELECT id, start_date, anchor_txn_id, closed, notes, updated_at FROM period ORDER BY id");
    while (p.next()) {
        QJsonObject row;
        row.insert("id", p.value(0).toString());
        row.insert("start_date", p.value(1).toString());
        if (!p.value(2).isNull())
            row.insert("anchor_txn", uuidOf["txn"].value(p.value(2).toLongLong()));
        row.insert("closed", static_cast<double>(p.value(3).toInt()));
        if (!p.value(4).isNull())
            row.insert("notes", p.value(4).toString());
        row.insert("updated_at", p.value(5).toString());
        periods.append(row);
    }
    out.insert("period", periods);

    QJsonObject meta;
    QSqlQuery m(db);
    m.exec("SELECT key, value FROM meta ORDER BY key");
    while (m.next())
        meta.insert(m.value(0).toString(), m.value(1).toString());

    QJsonObject bundle;
    bundle.insert("format", QString(FORMAT));
    bundle.insert("version", VERSION);
    bundle.insert("app_version", appVersion);
    bundle.insert("exported_at", nowIso());
    bundle.insert("meta", meta);
    bundle.insert("tables", out);
    if (includeArchive) {
        QJsonArray archive;
        QSqlQuery a(db);
        a.exec("SELECT origin_ref, source_table, raw_json, imported_at FROM import_archive ORDER BY origin_ref");
        while (a.next()) {
            QJsonObject row;
            row.insert("origin_ref", a.value(0).toString());
            row.insert("source_table", a.value(1).toString());
            row.insert("raw_json", a.value(2).toString());
            row.insert("imported_at", a.value(3).toString());
            archive.append(row);
        }
        bundle.insert("import_archive", archive);
    }
    return bundle;
}

QVariantMap Bundle::importBundle(QSqlDatabase &db, const QJsonObject &bundle, const QString &mode)
{
    QVariantMap stats;
    if (bundle.value("format").toString() != FORMAT) {
        stats.insert("error", "not-a-bundle");
        return stats;
    }
    if (bundle.value("version").toInt() > VERSION) {
        stats.insert("error", "newer-version");
        return stats;
    }
    int inserted = 0, updated = 0, skipped = 0;
    QSqlQuery q(db);
    q.exec("PRAGMA foreign_keys = OFF");
    db.transaction();

    const QJsonObject tbl = bundle.value("tables").toObject();
    if (mode == "replace") {
        QStringList wipe = {"import_archive", "period"};
        QVector<Table> ts = tables();
        for (int i = ts.size() - 1; i >= 0; --i)
            wipe << ts[i].name;
        wipe << "meta";
        for (const QString &t : wipe)
            q.exec(QString("DELETE FROM %1").arg(t));
    }
    const QJsonObject meta = bundle.value("meta").toObject();
    for (auto it = meta.begin(); it != meta.end(); ++it) {
        q.prepare("INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)");
        q.addBindValue(it.key());
        q.addBindValue(it.value().toString());
        q.exec();
    }
    for (const QJsonValue &pv : tbl.value("period").toArray()) {
        const QJsonObject p = pv.toObject();
        q.prepare("SELECT updated_at FROM period WHERE id = ?");
        q.addBindValue(p.value("id").toString());
        q.exec();
        if (q.next() && p.value("updated_at").toString() <= q.value(0).toString())
            continue;
        q.prepare("INSERT OR REPLACE INTO period (id, start_date, anchor_txn_id, closed, notes, updated_at) VALUES (?, ?, NULL, ?, ?, ?)");
        q.addBindValue(p.value("id").toString());
        q.addBindValue(p.value("start_date").toString());
        q.addBindValue(p.value("closed").toInt());
        q.addBindValue(fromJson(p.value("notes")));
        q.addBindValue(p.value("updated_at").toString());
        q.exec();
    }

    QHash<QString, QHash<QString, qlonglong>> idOf;
    for (const Table &t : tables()) {
        QHash<QString, qlonglong> m;
        QSqlQuery s(db);
        s.exec(QString("SELECT id, uuid FROM %1").arg(t.name));
        while (s.next())
            m.insert(s.value(1).toString(), s.value(0).toLongLong());
        idOf.insert(t.name, m);
    }

    struct Pending { QString table, column, uuid, ref; };
    QVector<Pending> pending;
    for (const Table &t : tables()) {
        const QSet<QString> cols = QSet<QString>::fromList(columnsOf(db, t.name));
        for (const QJsonValue &rv : tbl.value(t.name).toArray()) {
            QJsonObject row = rv.toObject();
            QVariantMap rec;
            for (const Fk &f : t.fks) {
                const QString ref = row.take(stripId(f.column)).toString();
                if (selfRef(t.name, f.column)) {
                    if (!ref.isEmpty())
                        pending.append({t.name, f.column, row.value("uuid").toString(), ref});
                    rec.insert(f.column, QVariant());
                } else {
                    rec.insert(f.column, ref.isEmpty() || !idOf[f.target].contains(ref) ? QVariant() : QVariant(idOf[f.target].value(ref)));
                }
            }
            for (auto it = row.begin(); it != row.end(); ++it)
                if (cols.contains(it.key()) && it.key() != "id")
                    rec.insert(it.key(), fromJson(it.value()));
            const QString uuid = rec.value("uuid").toString();
            const bool exists = idOf[t.name].contains(uuid);
            QStringList keys = rec.keys();
            if (exists) {
                const qlonglong id = idOf[t.name].value(uuid);
                q.prepare(QString("SELECT updated_at FROM %1 WHERE id = ?").arg(t.name));
                q.addBindValue(id);
                q.exec();
                const QString old = q.next() ? q.value(0).toString() : QString();
                if (rec.value("updated_at").toString() <= old) {
                    ++skipped;
                    continue;
                }
                QStringList sets;
                QVariantList vals;
                for (const QString &k : keys) {
                    if (selfRef(t.name, k))
                        continue;
                    sets << k + " = ?";
                    vals << rec.value(k);
                }
                q.prepare(QString("UPDATE %1 SET %2 WHERE id = ?").arg(t.name, sets.join(", ")));
                for (const QVariant &v : vals)
                    q.addBindValue(v);
                q.addBindValue(id);
                q.exec();
                ++updated;
            } else {
                QStringList marks;
                for (int i = 0; i < keys.size(); ++i)
                    marks << "?";
                q.prepare(QString("INSERT INTO %1 (%2) VALUES (%3)").arg(t.name, keys.join(", "), marks.join(", ")));
                for (const QString &k : keys)
                    q.addBindValue(rec.value(k));
                if (!q.exec()) {
                    db.rollback();
                    QSqlQuery(db).exec("PRAGMA foreign_keys = ON");
                    stats.insert("error", QString("%1: %2").arg(t.name, q.lastError().text()));
                    return stats;
                }
                idOf[t.name].insert(uuid, q.lastInsertId().toLongLong());
                ++inserted;
            }
        }
    }
    for (const Pending &p : pending) {
        q.prepare(QString("UPDATE %1 SET %2 = ? WHERE uuid = ?").arg(p.table, p.column));
        q.addBindValue(idOf[p.table].contains(p.ref) ? QVariant(idOf[p.table].value(p.ref)) : QVariant());
        q.addBindValue(p.uuid);
        q.exec();
    }
    for (const QJsonValue &pv : tbl.value("period").toArray()) {
        const QJsonObject p = pv.toObject();
        const QString ref = p.value("anchor_txn").toString();
        if (ref.isEmpty() || !idOf["txn"].contains(ref))
            continue;
        q.prepare("UPDATE period SET anchor_txn_id = ? WHERE id = ?");
        q.addBindValue(idOf["txn"].value(ref));
        q.addBindValue(p.value("id").toString());
        q.exec();
    }
    for (const QJsonValue &av : bundle.value("import_archive").toArray()) {
        const QJsonObject a = av.toObject();
        q.prepare("INSERT OR REPLACE INTO import_archive VALUES (?, ?, ?, ?)");
        q.addBindValue(a.value("origin_ref").toString());
        q.addBindValue(a.value("source_table").toString());
        q.addBindValue(a.value("raw_json").toString());
        q.addBindValue(a.value("imported_at").toString());
        q.exec();
    }
    QSqlQuery check(db);
    check.exec("PRAGMA foreign_key_check");
    if (check.next()) {
        db.rollback();
        QSqlQuery(db).exec("PRAGMA foreign_keys = ON");
        stats.insert("error", QString("dangling reference in %1").arg(check.value(0).toString()));
        return stats;
    }
    db.commit();
    QSqlQuery(db).exec("PRAGMA foreign_keys = ON");
    stats.insert("inserted", inserted);
    stats.insert("updated", updated);
    stats.insert("skipped", skipped);
    return stats;
}
