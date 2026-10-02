#include "store.h"
#include <QMap>
#include "bundle.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QLocale>
#include <QSettings>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QStandardPaths>
#include <QTextStream>
#include <QUuid>

#include <algorithm>
#include <functional>

namespace {

const char *REAL_DB = "fiatratio.sqlite";
const int SCHEMA_VERSION = 2;
const char *DEMO_DB = "fiatratio-demo.sqlite";

QString newUuid()
{
    return QUuid::createUuid().toString().mid(1, 36);
}

QString nowIso()
{
    return QDateTime::currentDateTimeUtc().toString("yyyy-MM-ddTHH:mm:ssZ");
}

QString iso(const QDate &d)
{
    return d.toString(Qt::ISODate);
}

QDate fromIso(const QVariant &v)
{
    return QDate::fromString(v.toString(), Qt::ISODate);
}

const QStringList LISTS = {"method", "context", "person"};

const QMap<QString, QString> BUCKET_COLORS = {
    {"needs", "#406EB3"}, {"wants", "#A34E72"}, {"exceptional", "#A76C12"},
    {"technical", "#7F5BA6"}, {"savings", "#009180"}};

const QStringList BUCKET_ORDER = {"needs", "wants", "exceptional", "technical", "savings"};

const QStringList SAVED_KINDS = {"savings", "investment", "pension", "crypto", "deposit"};
const QStringList VALUED_KINDS = {"investment", "pension", "crypto", "property", "vehicle", "possessions"};
const QStringList DEBT_KINDS = {"loan", "mortgage", "credit"};

QString csvField(const QVariant &v)
{
    QString s = v.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n'))
        s = "\"" + s.replace("\"", "\"\"") + "\"";
    return s;
}

QString money(qlonglong minor)
{
    return QString::number(minor / 100.0, 'f', 2);
}

QString freqOf(const QString &repeat)
{
    if (repeat == "m") return QStringLiteral("monthly");
    if (repeat == "q") return QStringLiteral("quarterly");
    if (repeat == "y") return QStringLiteral("yearly");
    return repeat;
}

} // namespace

Store::Store(const QString &schemaPath, const QString &standardPath, const QString &language, QObject *parent)
    : QObject(parent), m_schemaPath(schemaPath), m_language(language)
{
    QFile f(standardPath);
    if (f.open(QIODevice::ReadOnly))
        m_standard = QJsonDocument::fromJson(f.readAll()).object();
}

bool Store::open()
{
    // A practice run that was never finished is thrown away at the next start.
    QFile::remove(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/" + DEMO_DB);
    const bool ok = openFile(REAL_DB);
    if (ok && isSetUp())
        autoPlan();
    return ok;
}

bool Store::openFile(const QString &fileName)
{
    if (m_db.isOpen())
        m_db.close();
    m_db = QSqlDatabase();
    if (QSqlDatabase::contains(QSqlDatabase::defaultConnection))
        QSqlDatabase::removeDatabase(QSqlDatabase::defaultConnection);
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    m_db = QSqlDatabase::addDatabase("QSQLITE");
    m_db.setDatabaseName(dir + "/" + fileName);
    if (!m_db.open()) {
        m_error = m_db.lastError().text();
        return false;
    }
    exec("PRAGMA foreign_keys = ON");
    if (!scalar("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'meta'").isValid())
        return runSchema();
    return migrate(fileName);
}

// Brings an older database up to the current schema, one step at a time.
// A copy of the file is kept first. A database from a *newer* app is never
// touched: the app refuses to open it rather than guess.
bool Store::migrate(const QString &fileName)
{
    const QVariant v = scalar("SELECT value FROM meta WHERE key = 'schema_version'");
    if (!v.isValid())
        return true;                        // set-up not done yet, nothing to carry over
    int have = v.toInt();
    if (have > SCHEMA_VERSION) {
        m_error = "newer-schema";
        return false;
    }
    if (have == SCHEMA_VERSION)
        return true;

    const QString path = m_db.databaseName();
    m_db.close();
    QFile::remove(path + ".before-v" + QString::number(have));
    QFile::copy(path, path + ".before-v" + QString::number(have));
    if (!m_db.open()) {
        m_error = m_db.lastError().text();
        return false;
    }
    exec("PRAGMA foreign_keys = ON");

    // Each step takes version N to N+1. Add the next one here when the schema
    // changes, and raise SCHEMA_VERSION (and the value in setupFresh) to match:
    //   case 2: exec("ALTER TABLE ..."); break;
    m_db.transaction();
    while (have < SCHEMA_VERSION) {
        switch (have) {
        default:
            break;
        }
        ++have;
    }
    exec("INSERT OR REPLACE INTO meta VALUES ('schema_version', ?)", {QString::number(have)});
    m_db.commit();
    Q_UNUSED(fileName)
    return true;
}

bool Store::runSchema()
{
    QFile f(m_schemaPath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        m_error = "schema.sql missing";
        return false;
    }
    QStringList lines;
    for (const QString &line : QString::fromUtf8(f.readAll()).split('\n')) {
        const int c = line.indexOf("--");
        lines << (c >= 0 ? line.left(c) : line);
    }
    m_db.transaction();
    for (const QString &stmt : lines.join('\n').split(';')) {
        if (stmt.trimmed().isEmpty())
            continue;
        QSqlQuery q(m_db);
        if (!q.exec(stmt)) {
            m_error = q.lastError().text();
            m_db.rollback();
            return false;
        }
    }
    m_db.commit();
    return true;
}

// ------------------------------------------------------------------ sql helpers
QVariantList Store::rows(const QString &sql, const QVariantList &binds)
{
    QVariantList out;
    QSqlQuery q(m_db);
    q.prepare(sql);
    for (const QVariant &b : binds)
        q.addBindValue(b);
    if (!q.exec()) {
        m_error = q.lastError().text() + " / " + sql.left(80);
        return out;
    }
    const QSqlRecord rec = q.record();
    while (q.next()) {
        QVariantMap row;
        for (int i = 0; i < rec.count(); ++i)
            row.insert(rec.fieldName(i), q.value(i));
        out << row;
    }
    return out;
}

QVariant Store::scalar(const QString &sql, const QVariantList &binds)
{
    QSqlQuery q(m_db);
    q.prepare(sql);
    for (const QVariant &b : binds)
        q.addBindValue(b);
    if (q.exec() && q.next())
        return q.value(0);
    return QVariant();
}

bool Store::exec(const QString &sql, const QVariantList &binds)
{
    QSqlQuery q(m_db);
    q.prepare(sql);
    for (const QVariant &b : binds)
        q.addBindValue(b);
    if (!q.exec()) {
        m_error = q.lastError().text() + " / " + sql.left(80);
        return false;
    }
    return true;
}

int Store::insert(const QString &table, const QVariantMap &recIn)
{
    QVariantMap rec = recIn;
    if (!rec.contains("uuid") && table != "period" && table != "meta")
        rec.insert("uuid", newUuid());
    const QString now = nowIso();
    if (table != "meta" && table != "period") {
        rec.insert("created_at", now);
        rec.insert("updated_at", now);
    }
    QStringList keys = rec.keys(), marks;
    for (int i = 0; i < keys.size(); ++i)
        marks << "?";
    QSqlQuery q(m_db);
    q.prepare(QString("INSERT INTO %1 (%2) VALUES (%3)").arg(table, keys.join(", "), marks.join(", ")));
    for (const QString &k : keys)
        q.addBindValue(rec.value(k));
    if (!q.exec()) {
        m_error = q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

void Store::touch()
{
    ++m_revision;
    emit changed();
}

// ------------------------------------------------------------------ names
QString Store::categoryName(const QString &key, const QString &name) const
{
    if (!name.isEmpty())
        return name;
    const QJsonObject c = m_standard.value("categories").toObject().value(key).toObject();
    const QString s = c.value(m_language).toString();
    return s.isEmpty() ? c.value("en").toString(key) : s;
}

QString Store::bucketName(const QString &key, const QString &name) const
{
    if (!name.isEmpty())
        return name;
    const QJsonObject b = m_standard.value("buckets").toObject().value(key).toObject();
    const QString s = b.value(m_language).toString();
    return s.isEmpty() ? b.value("en").toString(key) : s;
}

// ------------------------------------------------------------------ settings
bool Store::isSetUp()
{
    return scalar("SELECT COUNT(*) FROM account WHERE kind = 'pot' AND deleted_at IS NULL").toInt() > 0;
}

QString Store::languageSetting() const
{
    return QSettings().value("language").toString();
}

void Store::setLanguage(const QString &code)
{
    QSettings().setValue("language", code);
    emit languageSettingChanged();
}

QString Store::setting(const QString &key, const QString &fallback)
{
    const QVariant v = scalar("SELECT value FROM meta WHERE key = ?", {key});
    // "payday" was a third way to start a month. It is gone: the salary starts it,
    // and payday is only the guess until it arrives.
    if (key == "period_mode" && v.isValid() && v.toString() == "payday")
        return QStringLiteral("salary");
    return v.isValid() ? v.toString() : fallback;
}

void Store::setSetting(const QString &key, const QString &value)
{
    exec("INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", {key, value});
    touch();
}

QString Store::localeCurrency() const
{
    const QString c = QLocale::system().currencySymbol(QLocale::CurrencyIsoCode);
    return c.length() == 3 ? c : QStringLiteral("SEK");
}

int Store::keyedCategory(const QString &key)
{
    const QVariant id = scalar("SELECT id FROM category WHERE key = ?", {key});
    if (id.isValid())
        return id.toInt();
    const QJsonObject c = m_standard.value("categories").toObject().value(key).toObject();
    if (c.isEmpty())
        return -1;
    QVariantMap rec;
    rec.insert("key", key);
    rec.insert("kind", c.value("kind").toString());
    const QString parent = c.value("parent").toString();
    if (!parent.isEmpty())
        rec.insert("parent_id", keyedCategory(parent));
    const QString bucket = c.value("bucket").toString();
    if (!bucket.isEmpty())
        rec.insert("bucket_id", scalar("SELECT id FROM bucket WHERE key = ?", {bucket}));
    rec.insert("sort", scalar("SELECT COUNT(*) FROM category").toInt());
    return insert("category", rec);
}

void Store::setupFresh(const QVariantMap &o)
{
    m_db.transaction();
    exec("INSERT OR REPLACE INTO meta VALUES ('schema_version', ?)", {QString::number(SCHEMA_VERSION)});
    for (const QString &k : {QStringLiteral("base_currency"), QStringLiteral("period_mode"), QStringLiteral("payday_day")})
        exec("INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", {k, o.value(k).toString()});
    exec("INSERT OR REPLACE INTO meta VALUES ('payday_rule', 'before')");
    for (int i = 0; i < BUCKET_ORDER.size(); ++i) {
        if (scalar("SELECT id FROM bucket WHERE key = ?", {BUCKET_ORDER[i]}).isValid())
            continue;
        QVariantMap b;
        b.insert("key", BUCKET_ORDER[i]);
        b.insert("color", BUCKET_COLORS.value(BUCKET_ORDER[i]));
        b.insert("sort", i);
        insert("bucket", b);
    }
    if (o.value("standard_categories").toBool()) {
        for (const QString &key : m_standard.value("categories").toObject().keys())
            keyedCategory(key);
    } else {
        for (const QString &key : {QStringLiteral("salary"), QStringLiteral("other_income"), QStringLiteral("correction"),
                                   QStringLiteral("food"), QStringLiteral("home"), QStringLiteral("transport"),
                                   QStringLiteral("leisure"), QStringLiteral("loan_interest")})
            keyedCategory(key);
    }
    QVariantMap pot;
    pot.insert("name", QStringLiteral("The month's money"));
    pot.insert("kind", "pot");
    pot.insert("on_budget", 1);
    pot.insert("in_net_worth", 0);
    pot.insert("currency", o.value("base_currency"));
    pot.insert("opening_date", today());
    insert("account", pot);
    for (const QVariant &m : o.value("methods").toList())
        addListItem("method", m.toString());
    m_db.commit();
    currentPeriod();
    autoPlan();
    touch();
}

// ------------------------------------------------------------------ practice run
void Store::setCoachStep(int step)
{
    if (step == m_coach)
        return;
    m_coach = step;
    emit demoChanged();
}

void Store::startDemo()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    m_db.close();
    QFile::remove(dir + "/" + DEMO_DB);
    openFile(DEMO_DB);
    seedDemo();
    m_demo = true;
    m_coach = 0;
    emit demoChanged();
    touch();
}

void Store::endDemo()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    m_db.close();
    QFile::remove(dir + "/" + DEMO_DB);
    openFile(REAL_DB);
    m_demo = false;
    m_coach = -1;
    emit demoChanged();
    touch();
}

void Store::seedDemo()
{
    auto T = [](const char *s) { return QCoreApplication::translate("Demo", s); };
    QVariantMap setup;
    setup.insert("base_currency", localeCurrency());
    setup.insert("period_mode", "salary");
    setup.insert("payday_day", "25");
    setup.insert("standard_categories", true);
    setup.insert("methods", QVariantList{QCoreApplication::translate("Demo", "Card"), QCoreApplication::translate("Demo", "Swish"), QCoreApplication::translate("Demo", "Cash")});
    setupFresh(setup);

    const int alex = addListItem("person", "Alex");
    addListItem("person", "Kim");

    QVariantMap a;
    a = {{"name", QCoreApplication::translate("Demo", "Buffer")}, {"kind", "savings"}, {"openingWhole", 1840000}};
    const int buffer = addAccount(a);
    a = {{"name", QCoreApplication::translate("Demo", "Funds")}, {"kind", "investment"}, {"openingWhole", 4230000}};
    addAccount(a);
    a = {{"name", QCoreApplication::translate("Demo", "Home")}, {"kind", "property"}, {"openingWhole", 320000000LL}, {"myShare", 0.5}, {"sharedWithId", alex}};
    addAccount(a);
    a = {{"name", QCoreApplication::translate("Demo", "Mortgage")}, {"kind", "mortgage"}, {"openingWhole", 240000000LL}, {"myShare", 0.5}, {"sharedWithId", alex}};
    addRate(addAccount(a), 3.4);
    a = {{"name", QCoreApplication::translate("Demo", "Student loan")}, {"kind", "loan"}, {"openingWhole", 8600000}};
    addAccount(a);

    const QDate now = QDate::currentDate();
    const QString start = iso(now.addMonths(-3));
    struct Rep { const char *name; const char *cat; qlonglong amount; const char *freq; int day; int monthOffset; };
    const Rep reps[] = {
        {QT_TRANSLATE_NOOP("Demo", "Rent"), "rent", 980000, "m", 25, 0},
        {QT_TRANSLATE_NOOP("Demo", "Electricity"), "housing", 25000, "m", 12, 0},
        {QT_TRANSLATE_NOOP("Demo", "Broadband"), "computer_phone", 39900, "m", 1, 0},
        {QT_TRANSLATE_NOOP("Demo", "Mobile"), "computer_phone", 19900, "m", 5, 0},
        {QT_TRANSLATE_NOOP("Demo", "Gym"), "sports", 34900, "m", 15, 0},
        {QT_TRANSLATE_NOOP("Demo", "Car insurance"), "insurance", 126000, "q", 20, 0},
        {QT_TRANSLATE_NOOP("Demo", "Home insurance"), "insurance", 145000, "y", 15, 1}};
    for (const Rep &r : reps) {
        QVariantMap s;
        s.insert("name", T(r.name));
        s.insert("kind", "expense");
        s.insert("amount", r.amount);
        s.insert("freq", freqOf(r.freq));
        s.insert("day", r.day);
        s.insert("month", now.addMonths(r.monthOffset).month());
        s.insert("startDate", start);
        s.insert("categoryId", keyedCategory(r.cat));
        addSchedule(s);
    }
    QVariantMap move = {{"name", QCoreApplication::translate("Demo", "To the buffer")}, {"kind", "transfer"}, {"amount", 200000}, {"freq", "monthly"},
                        {"day", 26}, {"startDate", start}, {"toAccountId", buffer}};
    addSchedule(move);

    // Three earlier months, so looking back has something to look at.
    const QString cur = currentPeriod();
    const int buf = buffer;
    for (int k = 3; k >= 1; --k) {
        const QDate s0 = fromIso(periodInfo(shiftPeriod(cur, -k)).value("start"));
        struct Row { const char *type; qlonglong amount; int day; const char *desc; const char *cat; };
        const Row past[] = {
            {"income", 3200000, 0, QT_TRANSLATE_NOOP("Demo", "Salary"), "salary"},
            {"expense", 980000, 0, QT_TRANSLATE_NOOP("Demo", "Rent"), "rent"},
            {"expense", 21000 + k * 4000, 17, QT_TRANSLATE_NOOP("Demo", "Electricity"), "housing"},
            {"expense", 39900, 6, QT_TRANSLATE_NOOP("Demo", "Broadband"), "computer_phone"},
            {"expense", 19900, 10, QT_TRANSLATE_NOOP("Demo", "Mobile"), "computer_phone"},
            {"expense", 34900, 20, QT_TRANSLATE_NOOP("Demo", "Gym"), "sports"},
            {"expense", 58000 + k * 3500, 5, QT_TRANSLATE_NOOP("Demo", "Grocery shop"), "groceries"},
            {"expense", 61000 - k * 2500, 19, QT_TRANSLATE_NOOP("Demo", "Grocery shop"), "groceries"},
            {"expense", 32000 + k * 6000, 12, QT_TRANSLATE_NOOP("Demo", "Restaurant"), "restaurant"},
            {"expense", k == 2 ? 89000 : 14900, 15, QT_TRANSLATE_NOOP("Demo", "Clothes"), "clothes"},
            {"move", 200000, 1, QT_TRANSLATE_NOOP("Demo", "To the buffer"), ""}};
        for (const Row &r : past) {
            QVariantMap t;
            t.insert("type", r.type);
            t.insert("amount", r.amount);
            t.insert("date", iso(s0.addDays(r.day)));
            t.insert("description", T(r.desc));
            if (QString(r.cat).length() > 0)
                t.insert("categoryId", keyedCategory(r.cat));
            if (QString(r.type) == "move")
                t.insert("toAccountId", buf);
            insertTxn(t, 0);
        }
    }

    const QDate first = fromIso(periodInfo(currentPeriod()).value("start"));
    QVariantMap pay = {{"type", "income"}, {"amount", 3200000}, {"date", iso(first)}, {"description", QCoreApplication::translate("Demo", "Salary")},
                       {"categoryId", keyedCategory("salary")}, {"isSalary", true}};
    addTransaction(pay);
    exec("DELETE FROM meta WHERE key = 'planned_through'");
    autoPlan();
    exec("UPDATE txn SET status = 'cleared' WHERE status = 'planned' AND date <= ?", {today()});

    auto within = [&](int daysAfterStart) {
        const QDate d = first.addDays(daysAfterStart);
        return iso(d > now ? now : d);
    };
    const int card = scalar("SELECT id FROM method ORDER BY id LIMIT 1").toInt();
    QVariantMap t;
    t = {{"type", "expense"}, {"amount", 64200}, {"date", within(10)}, {"description", QCoreApplication::translate("Demo", "Grocery shop")},
         {"categoryId", keyedCategory("groceries")}, {"methodId", card}};
    addTransaction(t);
    t = {{"type", "expense"}, {"amount", 42000}, {"amountFull", 84000}, {"date", within(7)}, {"description", QCoreApplication::translate("Demo", "Dinner")},
         {"categoryId", keyedCategory("restaurant")}, {"methodId", card}, {"personId", alex}};
    addTransaction(t);
    t = {{"type", "expense"}, {"amount", 4500}, {"date", within(12)}, {"description", QCoreApplication::translate("Demo", "Coffee")},
         {"categoryId", keyedCategory("fika")}, {"methodId", card}};
    addTransaction(t);
}

// ------------------------------------------------------------------ months
QString Store::today() const
{
    return iso(QDate::currentDate());
}

QString Store::yesterday() const
{
    return iso(QDate::currentDate().addDays(-1));
}

QDate Store::predictedStart(const QString &periodId)
{
    const QDate first(periodId.left(4).toInt(), periodId.mid(5, 2).toInt(), 1);
    if (setting("period_mode", "calendar") == "calendar")
        return first;
    const int day = setting("payday_day", "25").toInt();
    const QDate prev = first.addMonths(-1);
    QDate d(prev.year(), prev.month(), qMin(day, prev.daysInMonth()));
    while (d.dayOfWeek() > 5)
        d = d.addDays(-1);
    return d;
}

QString Store::ensurePeriod(const QString &periodId, const QDate &start)
{
    if (!scalar("SELECT id FROM period WHERE id = ?", {periodId}).isValid()) {
        const QDate s = start.isValid() ? start : predictedStart(periodId);
        exec("INSERT INTO period (id, start_date, closed, updated_at) VALUES (?, ?, 0, ?)", {periodId, iso(s), nowIso()});
    }
    return periodId;
}

QString Store::shiftPeriod(const QString &periodId, int months)
{
    const QDate d(periodId.left(4).toInt(), periodId.mid(5, 2).toInt(), 1);
    return d.addMonths(months).toString("yyyy-MM");
}

QString Store::periodFor(const QString &isoDate)
{
    const QDate d = QDate::fromString(isoDate, Qt::ISODate);
    const QVariant p = scalar("SELECT id FROM period WHERE start_date <= ? ORDER BY start_date DESC LIMIT 1", {isoDate});
    if (!p.isValid()) {
        QString id = d.toString("yyyy-MM");
        if (predictedStart(shiftPeriod(id, 1)) <= d)
            id = shiftPeriod(id, 1);
        return ensurePeriod(id);
    }
    QString id = p.toString();
    for (;;) {
        const QString next = shiftPeriod(id, 1);
        const QVariant ns = scalar("SELECT start_date FROM period WHERE id = ?", {next});
        const QDate nextStart = ns.isValid() ? fromIso(ns) : predictedStart(next);
        if (nextStart > d)
            return id;
        id = ensurePeriod(next, nextStart);
    }
}

QString Store::currentPeriod()
{
    return periodFor(today());
}

QString Store::openSalaryPeriod(const QDate &date, int anchorTxn)
{
    const QString id = date.addDays(15).toString("yyyy-MM");
    const QString prev = shiftPeriod(id, -1);
    if (scalar("SELECT id FROM period WHERE id = ?", {id}).isValid())
        exec("UPDATE period SET start_date = ?, anchor_txn_id = ?, updated_at = ? WHERE id = ?", {iso(date), anchorTxn, nowIso(), id});
    else
        exec("INSERT INTO period (id, start_date, anchor_txn_id, closed, updated_at) VALUES (?, ?, ?, 0, ?)",
             {id, iso(date), anchorTxn, nowIso()});
    // Rows dated from the salary on belong to the new month, planned ones included.
    exec("UPDATE txn SET period_id = ?, updated_at = ? WHERE period_id = ? AND date >= ? AND deleted_at IS NULL "
         "AND origin IN ('manual', 'schedule')", {id, nowIso(), prev, iso(date)});
    return id;
}

QVariantMap Store::periodInfo(const QString &periodId)
{
    ensurePeriod(periodId);
    const QDate start = fromIso(scalar("SELECT start_date FROM period WHERE id = ?", {periodId}));
    const QString next = shiftPeriod(periodId, 1);
    const QVariant ns = scalar("SELECT start_date FROM period WHERE id = ?", {next});
    const QDate nextStart = ns.isValid() ? fromIso(ns) : predictedStart(next);
    const QDate now = QDate::currentDate();
    QVariantMap m;
    m.insert("id", periodId);
    m.insert("year", periodId.left(4).toInt());
    m.insert("month", periodId.mid(5, 2).toInt());
    m.insert("start", iso(start));
    m.insert("end", iso(nextStart.addDays(-1)));
    m.insert("days", start.daysTo(nextStart));
    m.insert("day", qBound<qint64>(0, start.daysTo(now) + 1, start.daysTo(nextStart)));
    m.insert("daysLeft", qMax<qint64>(0, now.daysTo(nextStart)));
    m.insert("current", start <= now && now < nextStart);
    m.insert("future", start > now);
    return m;
}

QVariantMap Store::summary(const QString &periodId)
{
    QVariantMap spent, planned;
    qlonglong spentTotal = 0, plannedTotal = 0;
    for (const QVariant &v : rows("SELECT IFNULL(b.key, b.name) AS bucket, vb.status, SUM(vb.amount) AS amount FROM v_period_bucket vb "
                                  "LEFT JOIN bucket b ON b.id = vb.bucket_id WHERE vb.period_id = ? GROUP BY 1, 2", {periodId})) {
        const QVariantMap r = v.toMap();
        const QString key = r.value("bucket").isNull() ? QStringLiteral("uncategorised") : r.value("bucket").toString();
        const qlonglong a = r.value("amount").toLongLong();
        if (r.value("status").toString() == "planned") {
            planned.insert(key, planned.value(key).toLongLong() + a);
            plannedTotal += a;
        } else {
            spent.insert(key, spent.value(key).toLongLong() + a);
            spentTotal += a;
        }
    }
    const qlonglong income = scalar("SELECT IFNULL(SUM(l.amount), 0) FROM v_line l JOIN category c ON c.id = l.category_id "
                                    "WHERE l.period_id = ? AND c.kind = 'income' AND l.on_budget = 1 AND l.status <> 'planned'",
                                    {periodId}).toLongLong();
    const qlonglong plannedIncome = scalar("SELECT IFNULL(SUM(l.amount), 0) FROM v_line l JOIN category c ON c.id = l.category_id "
                                           "WHERE l.period_id = ? AND c.kind = 'income' AND l.on_budget = 1 AND l.status = 'planned'",
                                           {periodId}).toLongLong();
    QVariantMap m;
    m.insert("income", income);
    m.insert("plannedIncome", plannedIncome);
    m.insert("spent", spent);
    m.insert("planned", planned);
    m.insert("spentTotal", spentTotal);
    m.insert("plannedTotal", plannedTotal);
    m.insert("left", income - spentTotal - plannedTotal);
    return m;
}

// Planned rows of the month's money, with what each one is: the pot leg of a
// move carries the move's other end, and its schedule.
QVariantList Store::plannedItems(const QString &periodId)
{
    QVariantList out;
    for (const QVariant &v : rows(
             "SELECT t.id, t.date, t.description, t.amount, t.amount_full, t.status, IFNULL(t.schedule_id, peer.schedule_id) AS schedule_id, "
             "t.cadence, c.key AS ckey, c.name AS cname, pa.name AS other, pa.kind AS other_kind "
             "FROM txn t JOIN account a ON a.id = t.account_id LEFT JOIN category c ON c.id = t.category_id "
             "LEFT JOIN txn peer ON peer.id = t.transfer_peer_id LEFT JOIN account pa ON pa.id = peer.account_id "
             "WHERE t.period_id = ? AND t.status = 'planned' AND a.kind = 'pot' "
             "AND t.deleted_at IS NULL AND t.parent_id IS NULL ORDER BY t.date, t.id", {periodId})) {
        QVariantMap r = v.toMap();
        r.insert("category", r.value("ckey").toString().isEmpty() && r.value("cname").toString().isEmpty()
                 ? QString() : categoryName(r.value("ckey").toString(), r.value("cname").toString()));
        r.insert("repeats", !r.value("schedule_id").isNull() && r.value("schedule_id").toInt() > 0);
        r.insert("shared", !r.value("amount_full").isNull() && r.value("amount_full").toLongLong() != 0);
        r.insert("isMove", !r.value("other").toString().isEmpty());
        out << r;
    }
    return out;
}

// Quarterly and yearly rows due within a month after this one ends.
QVariantList Store::upcoming(const QString &periodId)
{
    const QDate end = fromIso(periodInfo(periodId).value("end"));
    QVariantList out;
    for (const QVariant &v : rows(
             "SELECT t.id, t.date, t.description, t.amount FROM txn t JOIN account a ON a.id = t.account_id "
             "WHERE t.status = 'planned' AND a.kind = 'pot' AND t.deleted_at IS NULL AND t.parent_id IS NULL "
             "AND t.cadence IN ('quarterly', 'yearly') AND t.date > ? AND t.date <= ? ORDER BY t.date",
             {iso(end), iso(end.addDays(30))}))
        out << v;
    return out;
}

QVariantList Store::transactions(const QString &periodId, bool includePlanned, int limit)
{
    QVariantList out;
    QString sql =
        "SELECT t.id, t.date, t.description, t.amount, t.amount_full, t.status, t.is_salary, "
        "IFNULL(t.schedule_id, peer.schedule_id) AS schedule_id, "
        "c.key AS ckey, c.name AS cname, c.kind AS ckind, b.key AS bucket, m.name AS method, x.name AS context, "
        "pe.name AS person, pa.name AS other, pa.kind AS other_kind FROM txn t JOIN account a ON a.id = t.account_id "
        "LEFT JOIN category c ON c.id = t.category_id LEFT JOIN bucket b ON b.id = c.bucket_id "
        "LEFT JOIN method m ON m.id = t.method_id LEFT JOIN context x ON x.id = t.context_id "
        "LEFT JOIN person pe ON pe.id = t.person_id "
        "LEFT JOIN txn peer ON peer.id = t.transfer_peer_id LEFT JOIN account pa ON pa.id = peer.account_id "
        "WHERE t.period_id = ? AND a.kind = 'pot' AND t.deleted_at IS NULL AND t.parent_id IS NULL ";
    if (!includePlanned)
        sql += "AND t.status <> 'planned' ";
    sql += "ORDER BY t.date DESC, t.id DESC";
    if (limit > 0)
        sql += QString(" LIMIT %1").arg(limit);
    for (const QVariant &v : rows(sql, {periodId})) {
        QVariantMap r = v.toMap();
        r.insert("category", r.value("ckey").toString().isEmpty() && r.value("cname").toString().isEmpty()
                 ? QString() : categoryName(r.value("ckey").toString(), r.value("cname").toString()));
        r.insert("repeats", !r.value("schedule_id").isNull() && r.value("schedule_id").toInt() > 0);
        r.insert("shared", !r.value("amount_full").isNull() && r.value("amount_full").toLongLong() != 0);
        r.insert("isMove", !r.value("other").toString().isEmpty());
        out << r;
    }
    return out;
}

int Store::transactionCount(const QString &periodId)
{
    return scalar("SELECT COUNT(*) FROM txn t JOIN account a ON a.id = t.account_id WHERE t.period_id = ? AND a.kind = 'pot' "
                  "AND t.deleted_at IS NULL AND t.parent_id IS NULL AND t.status <> 'planned'", {periodId}).toInt();
}

// ------------------------------------------------------------------ transactions
int Store::potId()
{
    return scalar("SELECT id FROM account WHERE kind = 'pot' AND deleted_at IS NULL ORDER BY id LIMIT 1").toInt();
}

// One expense, income or move. Amounts are your part, positive; the sign comes
// from the kind. A move has two legs; 0 as an account means the month's money.
int Store::insertTxn(const QVariantMap &t, int scheduleId)
{
    const QString type = t.value("type").toString();
    const qlonglong amount = t.value("amount").toLongLong();
    const qlonglong full = t.value("amountFull").toLongLong();
    const QString date = t.value("date").toString().isEmpty() ? today() : t.value("date").toString();
    const QString status = t.contains("status") ? t.value("status").toString()
                         : (date > today() ? QStringLiteral("planned") : QStringLiteral("cleared"));
    if (amount <= 0)
        return -1;
    const int pot = potId();
    QVariantMap rec;
    rec.insert("date", date);
    rec.insert("period_id", periodFor(date));
    rec.insert("status", status);
    rec.insert("description", t.value("description").toString().trimmed());
    rec.insert("origin", t.value("origin").toString().isEmpty() ? QStringLiteral("manual") : t.value("origin").toString());
    if (!t.value("notes").toString().isEmpty())
        rec.insert("notes", t.value("notes"));
    if (scheduleId > 0) {
        rec.insert("schedule_id", scheduleId);
        if (t.contains("cadence"))
            rec.insert("cadence", t.value("cadence"));
    }
    if (t.value("personId").toInt() > 0)
        rec.insert("person_id", t.value("personId").toInt());

    if (type == "move") {
        const int from = t.value("fromAccountId").toInt() > 0 ? t.value("fromAccountId").toInt() : pot;
        const int to = t.value("toAccountId").toInt() > 0 ? t.value("toAccountId").toInt() : pot;
        if (from == to)
            return -1;
        QVariantMap out = rec;
        out.insert("account_id", from);
        out.insert("amount", -amount);
        if (full > amount)
            out.insert("amount_full", -full);
        const int id = insert("txn", out);
        if (id <= 0)
            return -1;
        QVariantMap in = rec;
        in.remove("schedule_id");
        in.insert("account_id", to);
        const qlonglong arrived = t.value("amountIn").toLongLong() > 0 ? t.value("amountIn").toLongLong() : amount;
        in.insert("amount", arrived);
        if (full > amount)
            in.insert("amount_full", full);
        const int pid = insert("txn", in);
        exec("UPDATE txn SET transfer_peer_id = ? WHERE id = ?", {pid, id});
        exec("UPDATE txn SET transfer_peer_id = ? WHERE id = ?", {id, pid});
        return id;
    }

    rec.insert("account_id", pot);
    rec.insert("amount", type == "income" ? amount : -amount);
    if (full > amount)
        rec.insert("amount_full", type == "income" ? full : -full);
    for (const QString &k : {QStringLiteral("categoryId"), QStringLiteral("methodId"), QStringLiteral("contextId")}) {
        const int v = t.value(k).toInt();
        if (v > 0) {
            QString col = k;
            col.replace("Id", "_id");
            rec.insert(col, v);
        }
    }
    const bool salary = t.value("isSalary").toBool() && type == "income" && setting("period_mode") == "salary";
    rec.insert("is_salary", salary ? 1 : 0);
    const int id = insert("txn", rec);
    if (id > 0 && salary && status == "cleared")
        exec("UPDATE txn SET period_id = ? WHERE id = ?", {openSalaryPeriod(QDate::fromString(date, Qt::ISODate), id), id});
    return id;
}

int Store::scheduleFromTxn(const QVariantMap &t, const QString &repeat)
{
    const QString type = t.value("type").toString();
    const QDate date = t.value("date").toString().isEmpty() ? QDate::currentDate() : QDate::fromString(t.value("date").toString(), Qt::ISODate);
    QVariantMap s;
    s.insert("name", t.value("description").toString().trimmed());
    s.insert("kind", type == "move" ? "transfer" : type);
    s.insert("amount", t.value("amount"));
    s.insert("amountFull", t.value("amountFull"));
    s.insert("freq", freqOf(repeat));
    s.insert("day", date.day());
    s.insert("month", date.month());
    s.insert("startDate", iso(date));
    s.insert("endDate", t.value("lastDate"));
    s.insert("categoryId", t.value("categoryId"));
    s.insert("methodId", t.value("methodId"));
    s.insert("fromAccountId", t.value("fromAccountId"));
    s.insert("toAccountId", t.value("toAccountId"));
    s.insert("isSalary", t.value("isSalary"));
    s.insert("noPlan", true);
    return addSchedule(s);
}

int Store::addTransaction(const QVariantMap &t)
{
    m_db.transaction();
    int scheduleId = 0;
    const QString repeat = t.value("repeat").toString();
    if (!repeat.isEmpty() && repeat != "no")
        scheduleId = scheduleFromTxn(t, repeat);
    QVariantMap tt = t;
    if (scheduleId > 0)
        tt.insert("cadence", freqOf(repeat));
    const int id = insertTxn(tt, scheduleId);
    if (id < 0) {
        m_db.rollback();
        return -1;
    }
    const QString desc = t.value("description").toString().trimmed();
    if (!desc.isEmpty() && t.value("type").toString() != "move") {
        const QVariant cat = t.value("categoryId").toInt() > 0 ? t.value("categoryId") : QVariant();
        const QVariant meth = t.value("methodId").toInt() > 0 ? t.value("methodId") : QVariant();
        if (scalar("SELECT id FROM payee WHERE name = ?", {desc}).isValid())
            exec("UPDATE payee SET default_category_id = ?, default_method_id = ?, updated_at = ? WHERE name = ?",
                 {cat, meth, nowIso(), desc});
        else {
            QVariantMap p;
            p.insert("name", desc);
            p.insert("default_category_id", cat);
            p.insert("default_method_id", meth);
            insert("payee", p);
        }
    }
    m_db.commit();
    if (scheduleId > 0)
        autoPlan();
    touch();
    return id;
}

QVariantMap Store::transaction(int txnId)
{
    QVariantMap m;
    const QVariantList r = rows("SELECT t.*, a.kind AS account_kind, peer.account_id AS peer_account, pa.kind AS peer_kind, "
                                "peer.amount AS peer_amount, c.kind AS category_kind, c.key AS ckey, c.name AS cname "
                                "FROM txn t JOIN account a ON a.id = t.account_id LEFT JOIN txn peer ON peer.id = t.transfer_peer_id "
                                "LEFT JOIN account pa ON pa.id = peer.account_id LEFT JOIN category c ON c.id = t.category_id "
                                "WHERE t.id = ?", {txnId});
    if (r.isEmpty())
        return m;
    const QVariantMap t = r.first().toMap();
    const qlonglong amount = t.value("amount").toLongLong();
    const bool move = !t.value("transfer_peer_id").isNull() && t.value("transfer_peer_id").toInt() > 0;
    QString type = move ? QStringLiteral("move") : (amount > 0 ? QStringLiteral("income") : QStringLiteral("expense"));
    if (!move && t.value("category_kind").toString() == "expense")
        type = QStringLiteral("expense");
    m.insert("id", txnId);
    m.insert("type", type);
    m.insert("amount", qAbs(amount));
    m.insert("amountFull", t.value("amount_full").isNull() ? 0 : qAbs(t.value("amount_full").toLongLong()));
    m.insert("date", t.value("date"));
    m.insert("description", t.value("description"));
    m.insert("categoryId", t.value("category_id").toInt());
    m.insert("categoryLabel", t.value("ckey").toString().isEmpty() && t.value("cname").toString().isEmpty()
             ? QString() : categoryName(t.value("ckey").toString(), t.value("cname").toString()));
    m.insert("methodId", t.value("method_id").toInt());
    m.insert("contextId", t.value("context_id").toInt());
    m.insert("personId", t.value("person_id").toInt());
    m.insert("status", t.value("status"));
    m.insert("scheduleId", t.value("schedule_id").toInt());
    m.insert("isSalary", t.value("is_salary").toInt() == 1);
    m.insert("notes", t.value("notes"));
    if (move) {
        const bool outgoing = amount < 0;
        const int self = t.value("account_kind").toString() == "pot" ? 0 : t.value("account_id").toInt();
        const int other = t.value("peer_kind").toString() == "pot" ? 0 : t.value("peer_account").toInt();
        m.insert("fromAccountId", outgoing ? self : other);
        m.insert("toAccountId", outgoing ? other : self);
        const qlonglong in = qAbs(outgoing ? t.value("peer_amount").toLongLong() : amount);
        m.insert("amountIn", in);
        if (!outgoing)
            m.insert("amount", qAbs(t.value("peer_amount").toLongLong()));
    }
    return m;
}

void Store::deleteTxnPair(int txnId)
{
    const QVariant peer = scalar("SELECT transfer_peer_id FROM txn WHERE id = ?", {txnId});
    exec("UPDATE txn SET deleted_at = ?, updated_at = ? WHERE id = ? OR id = ?", {nowIso(), nowIso(), txnId, peer});
}

bool Store::updateTransaction(int txnId, const QVariantMap &t)
{
    const QVariantMap old = transaction(txnId);
    if (old.isEmpty())
        return false;
    const QString type = t.value("type").toString();
    m_db.transaction();
    if (type == "move" || old.value("type").toString() == "move") {
        deleteTxnPair(txnId);
        QVariantMap tt = t;
        tt.insert("status", old.value("status"));
        const int id = insertTxn(tt, old.value("scheduleId").toInt());
        m_db.commit();
        touch();
        return id > 0;
    }
    const qlonglong amount = t.value("amount").toLongLong();
    const qlonglong full = t.value("amountFull").toLongLong();
    if (amount <= 0) {
        m_db.rollback();
        return false;
    }
    const QString date = t.value("date").toString().isEmpty() ? old.value("date").toString() : t.value("date").toString();
    auto idOrNull = [&](const char *k) { return t.value(k).toInt() > 0 ? QVariant(t.value(k).toInt()) : QVariant(); };
    exec("UPDATE txn SET amount = ?, amount_full = ?, date = ?, period_id = ?, description = ?, category_id = ?, method_id = ?, "
         "context_id = ?, person_id = ?, notes = ?, updated_at = ? WHERE id = ?",
         {type == "income" ? amount : -amount,
          full > amount ? QVariant(type == "income" ? full : -full) : QVariant(),
          date, periodFor(date), t.value("description").toString().trimmed(), idOrNull("categoryId"), idOrNull("methodId"),
          idOrNull("contextId"), idOrNull("personId"),
          t.value("notes").toString().isEmpty() ? QVariant() : t.value("notes"), nowIso(), txnId});
    m_db.commit();
    touch();
    return true;
}

// A planned row happened: what it really cost, when, and how it was paid.
void Store::confirmPlanned(int txnId, const QVariantMap &c)
{
    const QVariantList r = rows("SELECT amount, transfer_peer_id, schedule_id, date FROM txn WHERE id = ?", {txnId});
    if (r.isEmpty())
        return;
    const QVariantMap t = r.first().toMap();
    const qlonglong sign = t.value("amount").toLongLong() < 0 ? -1 : 1;
    const qlonglong mine = c.value("amount").toLongLong();
    const qlonglong full = c.value("amountFull").toLongLong();
    const QString date = c.value("date").toString().isEmpty() ? today() : c.value("date").toString();
    const QVariant peer = t.value("transfer_peer_id");
    QVariant scheduleId = t.value("schedule_id");
    if (scheduleId.isNull() && !peer.isNull())
        scheduleId = scalar("SELECT schedule_id FROM txn WHERE id = ?", {peer});
    m_db.transaction();
    exec("UPDATE txn SET amount = ?, amount_full = ?, date = ?, period_id = ?, status = 'cleared', method_id = IFNULL(?, method_id), "
         "updated_at = ? WHERE id = ?",
         {sign * mine, full > mine ? QVariant(sign * full) : QVariant(), date, periodFor(date),
          c.value("methodId").toInt() > 0 ? QVariant(c.value("methodId").toInt()) : QVariant(), nowIso(), txnId});
    if (!peer.isNull())
        exec("UPDATE txn SET amount = ?, amount_full = ?, date = ?, period_id = ?, status = 'cleared', updated_at = ? WHERE id = ?",
             {-sign * mine, full > mine ? QVariant(-sign * full) : QVariant(), date, periodFor(date), nowIso(), peer});
    if (c.value("forward").toBool() && !scheduleId.isNull()) {
        exec("UPDATE schedule SET amount = ?, amount_full = ?, updated_at = ? WHERE id = ?",
             {mine, full > mine ? QVariant(full) : QVariant(), nowIso(), scheduleId});
        for (const QVariant &v : rows("SELECT id, amount, transfer_peer_id FROM txn WHERE schedule_id = ? AND status = 'planned' "
                                      "AND deleted_at IS NULL", {scheduleId})) {
            const QVariantMap p = v.toMap();
            const qlonglong s = p.value("amount").toLongLong() < 0 ? -1 : 1;
            exec("UPDATE txn SET amount = ?, amount_full = ?, updated_at = ? WHERE id = ?",
                 {s * mine, full > mine ? QVariant(s * full) : QVariant(), nowIso(), p.value("id")});
            if (!p.value("transfer_peer_id").isNull())
                exec("UPDATE txn SET amount = ?, amount_full = ?, updated_at = ? WHERE id = ?",
                     {-s * mine, full > mine ? QVariant(-s * full) : QVariant(), nowIso(), p.value("transfer_peer_id")});
        }
    }
    m_db.commit();
    touch();
}

void Store::setCleared(int txnId, bool cleared)
{
    exec("UPDATE txn SET status = ?, updated_at = ? WHERE id = ? OR transfer_peer_id = ?",
         {cleared ? "cleared" : "planned", nowIso(), txnId, txnId});
    touch();
}

void Store::deleteTransaction(int txnId)
{
    deleteTxnPair(txnId);
    touch();
}

QVariantMap Store::lastFor(const QString &description)
{
    QVariantMap m;
    const QVariantList p = rows("SELECT default_category_id AS categoryId, default_method_id AS methodId FROM payee WHERE name = ?",
                                {description.trimmed()});
    if (!p.isEmpty())
        m = p.first().toMap();
    const QVariantList last = rows("SELECT amount, amount_full, person_id, method_id, context_id FROM txn "
                                   "WHERE description = ? AND deleted_at IS NULL AND status <> 'planned' "
                                   "ORDER BY date DESC, id DESC LIMIT 1", {description.trimmed()});
    if (!last.isEmpty()) {
        const QVariantMap l = last.first().toMap();
        // The same place again: how it was paid and the context follow, if the place has no default of its own.
        if (m.value("methodId").toInt() <= 0 && l.value("method_id").toInt() > 0)
            m.insert("methodId", l.value("method_id").toInt());
        if (l.value("context_id").toInt() > 0)
            m.insert("contextId", l.value("context_id").toInt());
        m.insert("split", !l.value("amount_full").isNull());
        if (!l.value("amount_full").isNull() && l.value("amount_full").toLongLong() != 0)
            m.insert("share", qRound(100.0 * l.value("amount").toDouble() / l.value("amount_full").toDouble()));
        m.insert("personId", l.value("person_id").toInt());
    }
    if (m.value("categoryId").toInt() > 0)
        m.insert("categoryLabel", categoryInfo(m.value("categoryId").toInt()).value("label"));
    return m;
}

// The way to pay used most among the last ten expenses. A tie goes to the one
// that was used most recently. Archived ways to pay never come back.
int Store::usualMethod()
{
    const QVariantList r = rows(
        "SELECT t.method_id FROM txn t JOIN method m ON m.id = t.method_id AND m.archived = 0 AND m.deleted_at IS NULL "
        "WHERE t.deleted_at IS NULL AND t.status <> 'planned' AND t.parent_id IS NULL AND t.transfer_peer_id IS NULL "
        "AND t.amount < 0 ORDER BY t.date DESC, t.id DESC LIMIT 10");
    QHash<int, int> n;
    int best = 0, bestN = 0;
    for (const QVariant &v : r) {
        const int id = v.toMap().value("method_id").toInt();
        if (++n[id] > bestN) {
            bestN = n[id];
            best = id;
        }
    }
    return best;
}

// Rows this month that were saved without a category, to sort later.
int Store::unsortedCount(const QString &periodId)
{
    return scalar("SELECT COUNT(*) FROM txn t JOIN account a ON a.id = t.account_id WHERE t.period_id = ? AND a.kind = 'pot' "
                  "AND t.deleted_at IS NULL AND t.parent_id IS NULL AND t.status <> 'planned' AND t.category_id IS NULL "
                  "AND t.transfer_peer_id IS NULL", {periodId}).toInt();
}

// ------------------------------------------------------------------ repeating
QVariantList Store::schedules()
{
    QVariantList out;
    const QDate now = QDate::currentDate();
    for (const QVariant &v : rows(
             "SELECT s.*, c.key AS ckey, c.name AS cname, fa.name AS from_name, fa.kind AS from_kind, "
             "ta.name AS to_name, ta.kind AS to_kind, m.name AS method "
             "FROM schedule s JOIN account fa ON fa.id = s.account_id LEFT JOIN category c ON c.id = s.category_id "
             "LEFT JOIN account ta ON ta.id = s.to_account_id LEFT JOIN method m ON m.id = s.method_id "
             "WHERE s.deleted_at IS NULL AND (s.end_date IS NULL OR s.end_date >= ?) "
             "AND (s.to_account_id IS NULL OR ta.closed_date IS NULL) AND fa.closed_date IS NULL "
             "ORDER BY CASE s.freq WHEN 'weekly' THEN 0 WHEN 'monthly' THEN 1 WHEN 'quarterly' THEN 2 ELSE 3 END, "
             "IFNULL(s.month, 0), IFNULL(s.day, 0), s.name", {today()})) {
        QVariantMap r = v.toMap();
        r.insert("category", r.value("ckey").toString().isEmpty() && r.value("cname").toString().isEmpty()
                 ? QString() : categoryName(r.value("ckey").toString(), r.value("cname").toString()));
        const QList<QDate> next = scheduleDates(r, now, now.addDays(400));
        r.insert("next", next.isEmpty() ? QString() : iso(next.first()));
        out << r;
    }
    return out;
}

QVariantMap Store::schedule(int id)
{
    const QVariantList r = rows("SELECT s.*, c.key AS ckey, c.name AS cname, fa.kind AS from_kind, ta.kind AS to_kind "
                                "FROM schedule s JOIN account fa ON fa.id = s.account_id LEFT JOIN category c ON c.id = s.category_id "
                                "LEFT JOIN account ta ON ta.id = s.to_account_id WHERE s.id = ?", {id});
    if (r.isEmpty())
        return QVariantMap();
    QVariantMap s = r.first().toMap();
    s.insert("categoryLabel", s.value("ckey").toString().isEmpty() && s.value("cname").toString().isEmpty()
             ? QString() : categoryName(s.value("ckey").toString(), s.value("cname").toString()));
    s.insert("fromAccountId", s.value("from_kind").toString() == "pot" ? 0 : s.value("account_id").toInt());
    s.insert("toAccountId", s.value("to_kind").toString() == "pot" || s.value("to_account_id").isNull() ? 0 : s.value("to_account_id").toInt());
    return s;
}

int Store::addSchedule(const QVariantMap &s)
{
    const QString kind = s.value("kind").toString();
    const qlonglong amount = s.value("amount").toLongLong();
    const qlonglong full = s.value("amountFull").toLongLong();
    if (amount <= 0)
        return -1;
    const int pot = potId();
    const QDate start = QDate::fromString(s.value("startDate").toString(), Qt::ISODate);
    const QDate first = start.isValid() ? start : QDate::currentDate();
    const QString freq = s.value("freq").toString();
    QVariantMap rec;
    rec.insert("name", s.value("name").toString().trimmed().isEmpty() ? QStringLiteral("–") : s.value("name").toString().trimmed());
    rec.insert("kind", kind);
    rec.insert("account_id", kind == "transfer" && s.value("fromAccountId").toInt() > 0 ? s.value("fromAccountId").toInt() : pot);
    rec.insert("amount", amount);
    if (full > amount)
        rec.insert("amount_full", full);
    rec.insert("freq", freq);
    rec.insert("every", 1);
    rec.insert("start_date", iso(first));
    rec.insert("day", s.value("day").toInt() > 0 ? s.value("day").toInt() : first.day());
    if (freq == "yearly" || freq == "quarterly")
        rec.insert("month", s.value("month").toInt() > 0 ? s.value("month").toInt() : first.month());
    if (!s.value("endDate").toString().isEmpty())
        rec.insert("end_date", s.value("endDate").toString());
    if (kind == "transfer")
        rec.insert("to_account_id", s.value("toAccountId").toInt() > 0 ? s.value("toAccountId").toInt() : pot);
    else if (s.value("categoryId").toInt() > 0)
        rec.insert("category_id", s.value("categoryId").toInt());
    if (s.value("methodId").toInt() > 0 && kind == "expense")
        rec.insert("method_id", s.value("methodId").toInt());
    rec.insert("active", 1);
    rec.insert("is_salary", s.value("isSalary").toBool() ? 1 : 0);
    const int id = insert("schedule", rec);
    if (!s.value("noPlan").toBool()) {
        autoPlan();
        touch();
    }
    return id;
}

void Store::updateSchedule(int id, const QVariantMap &s)
{
    const QVariantMap old = schedule(id);
    if (old.isEmpty())
        return;
    const qlonglong amount = s.value("amount").toLongLong() > 0 ? s.value("amount").toLongLong() : old.value("amount").toLongLong();
    const qlonglong full = s.value("amountFull").toLongLong();
    const QString freq = s.value("freq").toString().isEmpty() ? old.value("freq").toString() : s.value("freq").toString();
    exec("UPDATE schedule SET name = ?, amount = ?, amount_full = ?, freq = ?, day = ?, month = ?, category_id = ?, method_id = ?, "
         "end_date = ?, updated_at = ? WHERE id = ?",
         {s.value("name").toString().trimmed().isEmpty() ? old.value("name") : s.value("name").toString().trimmed(),
          amount, full > amount ? QVariant(full) : QVariant(), freq,
          s.value("day").toInt() > 0 ? s.value("day").toInt() : old.value("day").toInt(),
          (freq == "yearly" || freq == "quarterly") ? QVariant(s.value("month").toInt() > 0 ? s.value("month").toInt() : old.value("month").toInt()) : QVariant(),
          s.contains("categoryId") ? (s.value("categoryId").toInt() > 0 ? QVariant(s.value("categoryId").toInt()) : QVariant()) : old.value("category_id"),
          s.contains("methodId") ? (s.value("methodId").toInt() > 0 ? QVariant(s.value("methodId").toInt()) : QVariant()) : old.value("method_id"),
          s.value("endDate").toString().isEmpty() ? QVariant() : s.value("endDate"), nowIso(), id});
    // What is still only planned is written again from the new rule.
    dropFuturePlanned(id, QDate::currentDate().addDays(-1));
    autoPlan();
    touch();
}

void Store::setScheduleActive(int id, bool active)
{
    exec("UPDATE schedule SET active = ?, updated_at = ? WHERE id = ?", {active ? 1 : 0, nowIso(), id});
    if (active)
        autoPlan();
    else
        dropFuturePlanned(id, QDate::currentDate().addDays(-1));
    touch();
}

void Store::endScheduleAfter(int id, const QString &isoDate)
{
    exec("UPDATE schedule SET end_date = ?, updated_at = ? WHERE id = ?", {isoDate, nowIso(), id});
    dropFuturePlanned(id, QDate::fromString(isoDate, Qt::ISODate));
    touch();
}

void Store::deleteSchedule(int id)
{
    exec("UPDATE schedule SET deleted_at = ?, updated_at = ? WHERE id = ?", {nowIso(), nowIso(), id});
    dropFuturePlanned(id, QDate(1900, 1, 1));
    touch();
}

// Planned rows of a schedule after a date, gone for good so they can be written again.
void Store::dropFuturePlanned(int scheduleId, const QDate &after)
{
    for (const QVariant &v : rows("SELECT id, transfer_peer_id FROM txn WHERE schedule_id = ? AND status = 'planned' AND date > ?",
                                  {scheduleId, iso(after)})) {
        const QVariantMap r = v.toMap();
        exec("UPDATE txn SET transfer_peer_id = NULL WHERE id = ? OR id = ?", {r.value("id"), r.value("transfer_peer_id")});
        exec("DELETE FROM txn WHERE id = ? OR id = ?", {r.value("id"), r.value("transfer_peer_id")});
    }
}

QList<QDate> Store::scheduleDates(const QVariantMap &s, const QDate &from, const QDate &to)
{
    QList<QDate> out;
    const QDate first = fromIso(s.value("start_date"));
    const QDate last = fromIso(s.value("end_date"));
    const QString freq = s.value("freq").toString();
    const int every = qMax(1, s.value("every").toInt());
    if (!first.isValid())
        return out;
    auto keep = [&](const QDate &d) {
        return d >= from && d <= to && d >= first && (!last.isValid() || d <= last);
    };
    if (freq == "weekly") {
        QDate d = first;
        while (d < from)
            d = d.addDays(7 * every);
        for (; d <= to; d = d.addDays(7 * every))
            if (keep(d))
                out << d;
        return out;
    }
    const int step = freq == "monthly" ? every : freq == "quarterly" ? 3 * every : 12 * every;
    const int anchorMonth = (freq != "monthly" && s.value("month").toInt() > 0) ? s.value("month").toInt() : first.month();
    const int anchor = first.year() * 12 + anchorMonth - 1;
    const int day = s.value("day").toInt() > 0 ? s.value("day").toInt() : first.day();
    for (QDate m(from.year(), from.month(), 1); m <= to; m = m.addMonths(1)) {
        const int diff = m.year() * 12 + m.month() - 1 - anchor;
        if (((diff % step) + step) % step != 0)
            continue;
        const QDate d(m.year(), m.month(), qMin(day, m.daysInMonth()));
        if (keep(d))
            out << d;
    }
    return out;
}

int Store::writePlanned(const QVariantMap &s, const QDate &date)
{
    // Once written, never again for that date: also not when it was skipped.
    if (scalar("SELECT id FROM txn WHERE schedule_id = ? AND date = ? AND parent_id IS NULL", {s.value("id"), iso(date)}).isValid())
        return 0;
    const QString kind = s.value("kind").toString();
    QVariantMap t;
    t.insert("type", kind == "transfer" ? "move" : kind);
    t.insert("amount", s.value("amount"));
    t.insert("amountFull", s.value("amount_full"));
    t.insert("date", iso(date));
    t.insert("status", "planned");
    t.insert("description", s.value("name"));
    t.insert("categoryId", s.value("category_id"));
    t.insert("methodId", s.value("method_id"));
    t.insert("cadence", s.value("freq"));
    t.insert("origin", "schedule");
    if (kind == "transfer") {
        const int pot = potId();
        t.insert("fromAccountId", s.value("account_id").toInt() == pot ? 0 : s.value("account_id").toInt());
        t.insert("toAccountId", s.value("to_account_id").toInt() == pot ? 0 : s.value("to_account_id").toInt());
    }
    return insertTxn(t, s.value("id").toInt()) > 0 ? 1 : 0;
}

int Store::planInto(const QString &periodId, bool onlyRare, const QDate &notBefore)
{
    const QVariantMap info = periodInfo(periodId);
    QDate from = fromIso(info.value("start"));
    if (notBefore.isValid() && notBefore > from)
        from = notBefore;
    const QDate to = fromIso(info.value("end"));
    const QString rare = onlyRare ? QStringLiteral(" AND freq IN ('quarterly','yearly')") : QString();
    int created = 0;
    for (const QVariant &v : rows("SELECT * FROM schedule WHERE active = 1 AND deleted_at IS NULL" + rare)) {
        const QVariantMap s = v.toMap();
        for (const QDate &d : scheduleDates(s, from, to))
            created += writePlanned(s, d);
    }
    return created;
}

// Everything switched on is written ahead as planned rows: the rest of this
// month and every month up to "plan_months" ahead (a year unless the settings
// say otherwise), of every kind, so a monthly bill is there in each of them
// until it is ended. A month seen for the first time gets all its dates; later,
// in the same month, only what is still to come. It runs at every start, so the
// horizon keeps rolling.
int Store::autoPlan()
{
    if (!isSetUp())
        return 0;
    const QString now = currentPeriod();
    const QString through = setting("planned_through");
    const int ahead = qBound(2, setting("plan_months", "12").toInt(), 36);
    m_db.transaction();
    int n = planInto(now, false, through.isEmpty() || through < now ? QDate() : QDate::currentDate());
    for (int i = 1; i <= ahead; ++i)
        n += planInto(shiftPeriod(now, i), false, QDate());
    const QString next = shiftPeriod(now, 1);
    if (through.isEmpty() || through < next)
        exec("INSERT OR REPLACE INTO meta (key, value) VALUES ('planned_through', ?)", {next});
    m_db.commit();
    return n;
}

// ------------------------------------------------------------------ categories and lists
QVariantList Store::buckets()
{
    QVariantList out;
    for (const QVariant &v : rows("SELECT id, key, name, color FROM bucket WHERE deleted_at IS NULL ORDER BY sort")) {
        QVariantMap r = v.toMap();
        r.insert("label", bucketName(r.value("key").toString(), r.value("name").toString()));
        out << r;
    }
    return out;
}

QVariantList Store::categories(const QString &kind)
{
    // A tree of any depth (Leisure › Hobbies › Photo), each level sorted by its
    // shown name, flattened depth-first with depth and the top-level group.
    QHash<int, QVariantMap> byId;
    QMultiHash<int, int> childrenOf;      // parent id (0 = root) -> child ids
    for (const QVariant &v : rows("SELECT c.id, c.key, c.name, c.parent_id, b.key AS bucket, b.id AS bucket_id FROM category c "
                                  "LEFT JOIN bucket b ON b.id = c.bucket_id WHERE c.kind = ? AND c.archived = 0 "
                                  "AND c.deleted_at IS NULL", {kind})) {
        QVariantMap r = v.toMap();
        r.insert("label", categoryName(r.value("key").toString(), r.value("name").toString()));
        byId.insert(r.value("id").toInt(), r);
    }
    for (auto it = byId.constBegin(); it != byId.constEnd(); ++it) {
        const int parent = it.value().value("parent_id").toInt();
        childrenOf.insert(byId.contains(parent) ? parent : 0, it.key());
    }
    QVariantList out;
    std::function<void(int, int, const QString &)> walk = [&](int parent, int depth, const QString &group) {
        QList<int> ids = childrenOf.values(parent);
        std::sort(ids.begin(), ids.end(), [&](int a, int b) {
            return QString::localeAwareCompare(byId[a].value("label").toString(), byId[b].value("label").toString()) < 0;
        });
        for (int id : ids) {
            QVariantMap r = byId.value(id);
            const QString g = depth == 0 ? r.value("label").toString() : group;
            r.insert("depth", depth);
            r.insert("group", g);
            out << r;
            if (depth < 8)
                walk(id, depth + 1, g);
        }
    };
    walk(0, 0, QString());
    return out;
}

int Store::addCategory(const QString &name, const QString &kind, int bucketId, int parentId)
{
    QVariantMap rec;
    rec.insert("name", name.trimmed());
    rec.insert("kind", kind);
    if (bucketId > 0)
        rec.insert("bucket_id", bucketId);
    if (parentId > 0)
        rec.insert("parent_id", parentId);
    rec.insert("sort", 900);
    const int id = insert("category", rec);
    touch();
    return id;
}

void Store::renameCategory(int id, const QString &name)
{
    exec("UPDATE category SET name = ?, updated_at = ? WHERE id = ?", {name.trimmed().isEmpty() ? QVariant() : name.trimmed(), nowIso(), id});
    touch();
}

void Store::setCategoryBucket(int id, int bucketId)
{
    exec("UPDATE category SET bucket_id = ?, updated_at = ? WHERE id = ?", {bucketId > 0 ? QVariant(bucketId) : QVariant(), nowIso(), id});
    touch();
}

void Store::archiveCategory(int id)
{
    exec("UPDATE category SET archived = 1, updated_at = ? WHERE id = ?", {nowIso(), id});
    touch();
}

QVariantList Store::list(const QString &table)
{
    if (!LISTS.contains(table))
        return QVariantList();
    const QString archived = table == "person" ? QString() : QStringLiteral(" AND archived = 0");
    const QString order = table == "person" ? QStringLiteral("name") : QStringLiteral("sort, name");
    return rows(QString("SELECT id, name FROM %1 WHERE deleted_at IS NULL%2 ORDER BY %3").arg(table, archived, order));
}

int Store::addListItem(const QString &table, const QString &name)
{
    if (!LISTS.contains(table) || name.trimmed().isEmpty())
        return -1;
    const QVariant existing = scalar(QString("SELECT id FROM %1 WHERE name = ?").arg(table), {name.trimmed()});
    if (existing.isValid()) {
        if (table != "person")
            exec(QString("UPDATE %1 SET archived = 0, deleted_at = NULL, updated_at = ? WHERE id = ?").arg(table), {nowIso(), existing});
        touch();
        return existing.toInt();
    }
    QVariantMap rec;
    rec.insert("name", name.trimmed());
    if (table != "person")
        rec.insert("sort", scalar(QString("SELECT COUNT(*) FROM %1").arg(table)).toInt());
    const int id = insert(table, rec);
    touch();
    return id;
}

void Store::renameListItem(const QString &table, int id, const QString &name)
{
    if (!LISTS.contains(table) || name.trimmed().isEmpty())
        return;
    exec(QString("UPDATE %1 SET name = ?, updated_at = ? WHERE id = ?").arg(table), {name.trimmed(), nowIso(), id});
    touch();
}

void Store::archiveListItem(const QString &table, int id)
{
    if (table == "method" || table == "context")
        exec(QString("UPDATE %1 SET archived = 1, updated_at = ? WHERE id = ?").arg(table), {nowIso(), id});
    touch();
}

QVariantMap Store::categoryInfo(int id)
{
    QVariantMap m;
    const QVariantList r = rows("SELECT c.id, c.key, c.name, c.kind, b.key AS bkey, b.name AS bname FROM category c "
                                "LEFT JOIN bucket b ON b.id = c.bucket_id WHERE c.id = ?", {id});
    if (r.isEmpty())
        return m;
    const QVariantMap c = r.first().toMap();
    m.insert("id", id);
    m.insert("kind", c.value("kind"));
    m.insert("key", c.value("key"));
    m.insert("label", categoryName(c.value("key").toString(), c.value("name").toString()));
    m.insert("bucket", c.value("bkey"));
    m.insert("bucketLabel", c.value("bkey").toString().isEmpty() && c.value("bname").toString().isEmpty()
             ? QString() : bucketName(c.value("bkey").toString(), c.value("bname").toString()));
    return m;
}

// ------------------------------------------------------------------ what you have and what you owe
QVariantList Store::accounts()
{
    QVariantList out;
    for (const QVariant &v : rows(
             "SELECT a.id, a.name, a.kind, a.currency, a.my_share, a.balance_source, a.in_net_worth, a.shared_with_id, p.name AS shared_with, "
             "CASE a.balance_source WHEN 'valuation' THEN IFNULL((SELECT value_base FROM v_latest_valuation lv WHERE lv.account_id = a.id), 0) "
             "ELSE (SELECT balance FROM v_ledger_balance lb WHERE lb.account_id = a.id) END AS value, "
             "(SELECT date FROM v_latest_valuation lv WHERE lv.account_id = a.id) AS value_date, "
             "(SELECT rate FROM account_rate r WHERE r.account_id = a.id AND r.deleted_at IS NULL ORDER BY r.from_date DESC, r.id DESC LIMIT 1) AS rate "
             "FROM account a LEFT JOIN person p ON p.id = a.shared_with_id "
             "WHERE a.deleted_at IS NULL AND a.closed_date IS NULL AND a.kind <> 'pot' ORDER BY a.sort, a.name")) {
        QVariantMap r = v.toMap();
        const double share = r.value("my_share").toDouble();
        if (share > 0 && share < 1)
            r.insert("whole", qRound64(r.value("value").toLongLong() / share));
        out << r;
    }
    return out;
}

QVariantMap Store::account(int id)
{
    for (const QVariant &v : accounts())
        if (v.toMap().value("id").toInt() == id)
            return v.toMap();
    return QVariantMap();
}

QVariantList Store::accountTransactions(int id, int limit)
{
    return rows(QString("SELECT t.id, t.date, t.description, t.origin, t.amount, t.amount_full, t.status, pa.name AS other, pa.kind AS other_kind "
                        "FROM txn t LEFT JOIN txn peer ON peer.id = t.transfer_peer_id LEFT JOIN account pa ON pa.id = peer.account_id "
                        "WHERE t.account_id = ? AND t.deleted_at IS NULL AND t.parent_id IS NULL "
                        "ORDER BY t.date DESC, t.id DESC LIMIT %1").arg(qMax(1, limit)), {id});
}

// For a person: positive means they owe you, negative that you owe them.
int Store::addAccount(const QVariantMap &a)
{
    const QString kind = a.value("kind").toString();
    const double share = a.value("myShare").toDouble() > 0 ? a.value("myShare").toDouble() : 1.0;
    const qlonglong whole = a.value("openingWhole").toLongLong();
    QVariantMap rec;
    rec.insert("name", a.value("name").toString().trimmed());
    rec.insert("kind", kind);
    rec.insert("currency", a.value("currency").toString().isEmpty() ? setting("base_currency", "SEK") : a.value("currency"));
    rec.insert("balance_source", VALUED_KINDS.contains(kind) ? "valuation" : "ledger");
    rec.insert("my_share", share);
    rec.insert("opening_date", a.value("openingDate").toString().isEmpty() ? today() : a.value("openingDate").toString());
    const qlonglong mine = qRound64(whole * share);
    if (!VALUED_KINDS.contains(kind)) {
        const bool owed = DEBT_KINDS.contains(kind);
        rec.insert("opening_balance", owed ? -qAbs(mine) : mine);
        if (share < 1)
            rec.insert("opening_full", owed ? -qAbs(whole) : whole);
    }
    if (share < 1 && a.value("sharedWithId").toInt() > 0)
        rec.insert("shared_with_id", a.value("sharedWithId").toInt());
    if (kind == "person" && a.value("personId").toInt() > 0)
        rec.insert("person_id", a.value("personId").toInt());
    if (SAVED_KINDS.contains(kind))
        rec.insert("bucket_id", scalar("SELECT id FROM bucket WHERE key = 'savings'"));
    else if (DEBT_KINDS.contains(kind) || kind == "person")
        rec.insert("bucket_id", scalar("SELECT id FROM bucket WHERE key = 'needs'"));
    rec.insert("sort", scalar("SELECT COUNT(*) FROM account").toInt());
    const int id = insert("account", rec);
    if (VALUED_KINDS.contains(kind) && whole != 0)
        addValuation(id, whole, today());
    touch();
    return id;
}

// A new loan or credit, the way a person knows it: how much, together or not,
// where the money went, the rate and the amortisation. The rest follows.
int Store::addLoan(const QVariantMap &l)
{
    const QString kind = l.value("kind").toString();
    const double share = l.value("myShare").toDouble() > 0 ? l.value("myShare").toDouble() : 1.0;
    const qlonglong whole = qAbs(l.value("whole").toLongLong());
    const qlonglong mine = qRound64(whole * share);
    const QString where = l.value("where").toString();
    if (whole <= 0)
        return -1;
    QVariantMap a;
    a.insert("name", l.value("name"));
    a.insert("kind", kind);
    a.insert("myShare", share);
    a.insert("sharedWithId", l.value("sharedWithId"));
    a.insert("openingWhole", where == "in" ? 0 : (kind == "person" ? -whole : whole));
    const int id = addAccount(a);
    if (id <= 0)
        return -1;
    if (where == "in") {
        QVariantMap t;
        t.insert("type", "move");
        t.insert("amount", mine);
        t.insert("amountFull", share < 1 ? whole : 0);
        t.insert("fromAccountId", id);
        t.insert("toAccountId", 0);
        t.insert("description", l.value("name"));
        insertTxn(t, 0);
    }
    const double rate = l.value("rate").toDouble();
    if (rate > 0)
        addRate(id, rate);
    const int day = l.value("day").toInt() > 0 ? l.value("day").toInt() : 27;
    const qlonglong amortWhole = l.value("amortWhole").toLongLong();
    if (amortWhole > 0) {
        QVariantMap s;
        s.insert("name", l.value("amortName"));
        s.insert("kind", "transfer");
        s.insert("amount", qRound64(amortWhole * share));
        s.insert("amountFull", share < 1 ? amortWhole : 0);
        s.insert("freq", "monthly");
        s.insert("day", day);
        s.insert("toAccountId", id);
        s.insert("noPlan", true);
        addSchedule(s);
    }
    const qlonglong interest = qRound64(mine * rate / 100.0 / 12.0);
    if (interest > 0) {
        QVariantMap s;
        s.insert("name", l.value("interestName"));
        s.insert("kind", "expense");
        s.insert("amount", interest);
        s.insert("amountFull", share < 1 ? qRound64(whole * rate / 100.0 / 12.0) : 0);
        s.insert("freq", "monthly");
        s.insert("day", day);
        s.insert("categoryId", keyedCategory(kind == "mortgage" ? "mortgage_interest" : "loan_interest"));
        s.insert("noPlan", true);
        addSchedule(s);
    }
    autoPlan();
    touch();
    return id;
}

// The app has drifted from the real balance of a savings account or a loan. One
// row on that account closes the gap. It has no category and no peer, so it is
// neither income, spending nor saving. For a debt, the figure is what is owed.
bool Store::correctBalance(int accountId, qlonglong trueWhole)
{
    const QVariantMap a = account(accountId);
    const QString kind = a.value("kind").toString();
    if (a.isEmpty() || a.value("balance_source").toString() != "ledger" || kind == "person")
        return false;
    const double share = a.value("my_share").toDouble();
    const qlonglong mine = qRound64(trueWhole * (share > 0 ? share : 1.0));
    const qlonglong target = DEBT_KINDS.contains(kind) ? -qAbs(mine) : mine;
    const qlonglong delta = target - a.value("value").toLongLong();
    if (delta == 0)
        return false;
    const QString date = today();
    QVariantMap rec;
    rec.insert("account_id", accountId);
    rec.insert("date", date);
    rec.insert("period_id", periodFor(date));
    rec.insert("status", QStringLiteral("cleared"));
    rec.insert("amount", delta);
    rec.insert("description", QString());
    rec.insert("origin", QStringLiteral("correction"));
    const bool ok = insert("txn", rec) > 0;
    touch();
    return ok;
}

void Store::addValuation(int accountId, qlonglong wholeValue, const QString &isoDate)
{
    const double share = scalar("SELECT my_share FROM account WHERE id = ?", {accountId}).toDouble();
    QVariantMap rec;
    rec.insert("account_id", accountId);
    rec.insert("date", isoDate.isEmpty() ? today() : isoDate);
    const qlonglong mine = qRound64(wholeValue * (share > 0 ? share : 1.0));
    rec.insert("value", mine);
    rec.insert("value_base", mine);
    if (share > 0 && share < 1)
        rec.insert("value_full", wholeValue);
    insert("valuation", rec);
    touch();
}

void Store::addRate(int accountId, double rate)
{
    QVariantMap rec;
    rec.insert("account_id", accountId);
    rec.insert("from_date", today());
    rec.insert("rate", rate);
    insert("account_rate", rec);
    touch();
}

void Store::closeAccount(int id)
{
    exec("UPDATE account SET closed_date = ?, updated_at = ? WHERE id = ? AND kind <> 'pot'", {today(), nowIso(), id});
    exec("UPDATE schedule SET end_date = ?, updated_at = ? WHERE (account_id = ? OR to_account_id = ?) AND deleted_at IS NULL",
         {today(), nowIso(), id, id});
    touch();
}

QVariantMap Store::netWorth()
{
    const QVariantList r = rows("SELECT IFNULL(assets, 0) AS assets, IFNULL(debts, 0) AS debts, IFNULL(net, 0) AS net FROM v_net_worth");
    return r.isEmpty() ? QVariantMap() : r.first().toMap();
}

QVariantList Store::netWorthSeries(int months)
{
    QVariantList out;
    const QDate now = QDate::currentDate();
    const QString sql =
        "SELECT IFNULL(SUM(CASE a.balance_source WHEN 'valuation' THEN "
        "  IFNULL((SELECT v.value_base FROM valuation v WHERE v.account_id = a.id AND v.deleted_at IS NULL AND v.date <= ? "
        "          ORDER BY v.date DESC, v.id DESC LIMIT 1), 0) "
        "ELSE a.opening_balance + IFNULL((SELECT SUM(t.amount) FROM txn t WHERE t.account_id = a.id AND t.parent_id IS NULL "
        "          AND t.deleted_at IS NULL AND t.status <> 'planned' AND t.date <= ?), 0) END), 0) "
        "FROM account a WHERE a.deleted_at IS NULL AND a.in_net_worth = 1 "
        "AND (a.opening_date IS NULL OR a.opening_date <= ?) AND (a.closed_date IS NULL OR a.closed_date > ?)";
    for (int i = months - 1; i >= 0; --i) {
        const QDate m = now.addMonths(-i);
        const QDate d = i == 0 ? now : QDate(m.year(), m.month(), m.daysInMonth());
        QVariantMap p;
        p.insert("date", iso(d));
        p.insert("net", scalar(sql, {iso(d), iso(d), iso(d), iso(d)}).toLongLong());
        out << p;
    }
    return out;
}

// ------------------------------------------------------------------ looking back
QVariantList Store::history(int months)
{
    const QString last = currentPeriod();
    const QString first = shiftPeriod(last, 1 - months);
    QMap<QString, QVariantMap> byPeriod;
    for (int i = 0; i < months; ++i) {
        QVariantMap m;
        m.insert("id", shiftPeriod(first, i));
        m.insert("income", 0);
        m.insert("total", 0);
        m.insert("buckets", QVariantMap());
        byPeriod.insert(m.value("id").toString(), m);
    }
    for (const QVariant &v : rows("SELECT vb.period_id, IFNULL(b.key, b.name) AS bucket, SUM(vb.amount) AS amount FROM v_period_bucket vb "
                                  "LEFT JOIN bucket b ON b.id = vb.bucket_id WHERE vb.period_id BETWEEN ? AND ? "
                                  "AND vb.status <> 'planned' GROUP BY 1, 2", {first, last})) {
        const QVariantMap r = v.toMap();
        QVariantMap &m = byPeriod[r.value("period_id").toString()];
        QVariantMap b = m.value("buckets").toMap();
        const QString key = r.value("bucket").isNull() ? QStringLiteral("uncategorised") : r.value("bucket").toString();
        b.insert(key, b.value(key).toLongLong() + r.value("amount").toLongLong());
        m.insert("buckets", b);
        m.insert("total", m.value("total").toLongLong() + r.value("amount").toLongLong());
    }
    for (const QVariant &v : rows("SELECT l.period_id, SUM(l.amount) AS amount FROM v_line l JOIN category c ON c.id = l.category_id "
                                  "WHERE l.period_id BETWEEN ? AND ? AND c.kind = 'income' AND l.on_budget = 1 "
                                  "AND l.status <> 'planned' GROUP BY 1", {first, last})) {
        const QVariantMap r = v.toMap();
        byPeriod[r.value("period_id").toString()].insert("income", r.value("amount").toLongLong());
    }
    QVariantList out;
    for (const QVariantMap &m : byPeriod)
        out << m;
    return out;
}

// One stretch of months: where the money came from and where it went, each
// category beside its usual level (the twelve months before, scaled to the stretch).
QVariantMap Store::analysis(const QString &fromPeriod, const QString &toPeriod)
{
    QVariantMap out;
    const int n = qMax(1, (toPeriod.left(4).toInt() - fromPeriod.left(4).toInt()) * 12
                          + toPeriod.mid(5, 2).toInt() - fromPeriod.mid(5, 2).toInt() + 1);
    const QString baseFrom = shiftPeriod(fromPeriod, -12), baseTo = shiftPeriod(fromPeriod, -1);
    out.insert("months", n);

    out.insert("income", scalar("SELECT IFNULL(SUM(l.amount), 0) FROM v_line l JOIN category c ON c.id = l.category_id "
                                "WHERE l.period_id BETWEEN ? AND ? AND c.kind = 'income' AND l.on_budget = 1 AND l.status <> 'planned'",
                                {fromPeriod, toPeriod}).toLongLong());
    QVariantMap buckets;
    qlonglong total = 0;
    for (const QVariant &v : rows("SELECT IFNULL(b.key, b.name) AS bucket, SUM(vb.amount) AS amount FROM v_period_bucket vb "
                                  "LEFT JOIN bucket b ON b.id = vb.bucket_id WHERE vb.period_id BETWEEN ? AND ? AND vb.status <> 'planned' "
                                  "GROUP BY 1", {fromPeriod, toPeriod})) {
        const QVariantMap r = v.toMap();
        const QString key = r.value("bucket").isNull() ? QStringLiteral("uncategorised") : r.value("bucket").toString();
        buckets.insert(key, r.value("amount").toLongLong());
        total += r.value("amount").toLongLong();
    }
    out.insert("buckets", buckets);
    out.insert("total", total);
    out.insert("saved", buckets.value("savings").toLongLong());
    // Paid off on loans and credit: it is a need, not saving, and it is not a category either.
    out.insert("repaid", scalar("SELECT IFNULL(-SUM(l.amount), 0) FROM v_line l JOIN txn peer ON peer.id = l.transfer_peer_id "
                                "JOIN account dest ON dest.id = peer.account_id WHERE l.period_id BETWEEN ? AND ? AND l.on_budget = 1 "
                                "AND dest.on_budget = 0 AND dest.bucket_id IS NOT NULL AND l.status <> 'planned' AND l.amount < 0 "
                                "AND dest.kind IN ('mortgage','loan','credit','person')", {fromPeriod, toPeriod}).toLongLong());

    const QString tree =
        "WITH RECURSIVE up(id, root) AS (SELECT id, id FROM category WHERE parent_id IS NULL "
        "  UNION ALL SELECT c.id, up.root FROM category c JOIN up ON c.parent_id = up.id) ";
    QHash<int, qlonglong> before;
    for (const QVariant &v : rows(tree + "SELECT up.root AS id, SUM(-l.amount) AS amount FROM v_line l JOIN up ON up.id = l.category_id "
                                  "JOIN category c ON c.id = l.category_id WHERE l.period_id BETWEEN ? AND ? AND l.on_budget = 1 "
                                  "AND c.kind = 'expense' AND l.status <> 'planned' GROUP BY up.root", {baseFrom, baseTo}))
        before.insert(v.toMap().value("id").toInt(), v.toMap().value("amount").toLongLong());
    const int baseMonths = qMax(1, scalar("SELECT COUNT(DISTINCT l.period_id) FROM v_line l WHERE l.period_id BETWEEN ? AND ? "
                                          "AND l.on_budget = 1", {baseFrom, baseTo}).toInt());
    QVariantList cats;
    for (const QVariant &v : rows(tree + "SELECT top.id, top.key, top.name, b.key AS bucket, SUM(-l.amount) AS amount, COUNT(*) AS n "
                                  "FROM v_line l JOIN up ON up.id = l.category_id JOIN category c ON c.id = l.category_id "
                                  "JOIN category top ON top.id = up.root LEFT JOIN bucket b ON b.id = top.bucket_id "
                                  "WHERE l.period_id BETWEEN ? AND ? AND l.on_budget = 1 AND c.kind = 'expense' AND l.status <> 'planned' "
                                  "GROUP BY top.id ORDER BY 5 DESC", {fromPeriod, toPeriod})) {
        QVariantMap r = v.toMap();
        r.insert("label", categoryName(r.value("key").toString(), r.value("name").toString()));
        r.insert("usual", qRound64(before.value(r.value("id").toInt()) * double(n) / baseMonths));
        cats << r;
    }
    out.insert("categories", cats);
    out.insert("hasBaseline", !before.isEmpty());

    QVariantList places;
    for (const QVariant &v : rows("SELECT TRIM(IFNULL(NULLIF(l.description, ''), '–')) AS name, SUM(-l.amount) AS amount, COUNT(*) AS n "
                                  "FROM v_line l JOIN category c ON c.id = l.category_id WHERE l.period_id BETWEEN ? AND ? "
                                  "AND l.on_budget = 1 AND c.kind = 'expense' AND l.status <> 'planned' "
                                  "GROUP BY 1 ORDER BY 2 DESC LIMIT 8", {fromPeriod, toPeriod}))
        places << v;
    out.insert("places", places);

    const QVariantList shared = rows("SELECT IFNULL(SUM(-l.amount), 0) AS mine, IFNULL(SUM(-l.amount_full), 0) AS whole, COUNT(*) AS n "
                                     "FROM v_line l JOIN category c ON c.id = l.category_id WHERE l.period_id BETWEEN ? AND ? "
                                     "AND l.on_budget = 1 AND c.kind = 'expense' AND l.status <> 'planned' AND l.amount_full IS NOT NULL",
                                     {fromPeriod, toPeriod});
    out.insert("shared", shared.isEmpty() ? QVariant() : shared.first());
    return out;
}

// ------------------------------------------------------------------ taking a total apart
// A bucket or a category split into its parts, so a total can be opened. The
// parts add up to the total, and use the same rules as v_period_bucket.
//   kind "bucket":   ref is the bucket key. Parts are top-level categories (only
//                    what fell in this bucket), and the accounts money was moved to.
//   kind "category": ref is the category id. Parts are its sub-categories, plus
//                    what was entered on the category itself. bucketKey narrows it
//                    to one bucket, when we came here from a bucket.
//   kind "debt":     ref is ignored. Parts are the loans and credits paid off.
// Each part: kind (category, account, none), id, label, amount, n, hasChildren,
// own, sub (paying off, saved), bucket (the main one), buckets (all of them).
static const char *DEBT_SQL = "'mortgage','loan','credit','person'";
static const char *SAVE_KINDS = "'savings','investment','pension','crypto','deposit'";

QVariantMap Store::breakdown(const QString &kind, const QString &ref, const QString &fromPeriod, const QString &toPeriod,
                             const QString &bucketKey)
{
    QVariantMap out;
    QVariantList parts;
    qlonglong total = 0;
    int rowCount = 0;
    const QString bucketExpr = QStringLiteral("IFNULL(b.key, IFNULL(b.name, 'uncategorised'))");

    auto accountParts = [&](const QString &where, const QVariantList &extra) {
        QVariantList binds = {fromPeriod, toPeriod};
        binds << extra;
        for (const QVariant &v : rows(
                 "SELECT dest.id AS id, dest.name AS name, dest.kind AS akind, IFNULL(b.key, 'uncategorised') AS bkey, "
                 "-SUM(l.amount) AS amount, COUNT(*) AS n "
                 "FROM v_line l JOIN txn peer ON peer.id = l.transfer_peer_id JOIN account dest ON dest.id = peer.account_id "
                 "JOIN bucket b ON b.id = dest.bucket_id WHERE l.period_id BETWEEN ? AND ? AND l.on_budget = 1 "
                 "AND dest.on_budget = 0 AND l.status <> 'planned' " + where + " GROUP BY dest.id ORDER BY 5 DESC", binds)) {
            QVariantMap r = v.toMap();
            if (r.value("amount").toLongLong() == 0)
                continue;
            QVariantMap p;
            p.insert("kind", "account");
            p.insert("id", r.value("id"));
            p.insert("label", r.value("name"));
            p.insert("amount", r.value("amount"));
            p.insert("n", r.value("n"));
            p.insert("hasChildren", false);
            const bool debt = QString(DEBT_SQL).contains("'" + r.value("akind").toString() + "'");
            p.insert("sub", debt ? "paying off" : "saved");
            p.insert("bucket", r.value("bkey"));
            parts << p;
        }
    };

    if (kind == "bucket") {
        const QVariantList bl = rows("SELECT key, name FROM bucket WHERE (key = ? OR name = ?) AND deleted_at IS NULL", {ref, ref});
        out.insert("title", ref == "uncategorised" ? QString() : (bl.isEmpty() ? ref
                   : bucketName(bl.first().toMap().value("key").toString(), bl.first().toMap().value("name").toString())));
        const QString tree =
            "WITH RECURSIVE up(id, root) AS (SELECT id, id FROM category WHERE parent_id IS NULL "
            "UNION ALL SELECT c.id, up.root FROM category c JOIN up ON c.parent_id = up.id) ";
        for (const QVariant &v : rows(
                 tree + "SELECT IFNULL(up.root, 0) AS id, top.key AS ckey, top.name AS cname, SUM(-l.amount) AS amount, COUNT(*) AS n, "
                 "(SELECT COUNT(*) FROM category ch WHERE ch.parent_id = top.id AND ch.deleted_at IS NULL) AS kids "
                 "FROM v_line l LEFT JOIN up ON up.id = l.category_id LEFT JOIN category top ON top.id = up.root "
                 "LEFT JOIN bucket b ON b.id = l.category_bucket_id "
                 "WHERE l.period_id BETWEEN ? AND ? AND l.on_budget = 1 AND l.status <> 'planned' "
                 "AND (l.category_kind = 'expense' OR (l.category_id IS NULL AND l.transfer_peer_id IS NULL AND l.amount < 0)) "
                 "AND " + bucketExpr + " = ? GROUP BY IFNULL(up.root, 0) ORDER BY 4 DESC", {fromPeriod, toPeriod, ref})) {
            const QVariantMap r = v.toMap();
            if (r.value("amount").toLongLong() == 0)
                continue;
            QVariantMap p;
            p.insert("kind", r.value("id").toInt() > 0 ? "category" : "none");
            p.insert("id", r.value("id"));
            p.insert("label", r.value("id").toInt() > 0 ? categoryName(r.value("ckey").toString(), r.value("cname").toString()) : QString());
            p.insert("amount", r.value("amount"));
            p.insert("n", r.value("n"));
            p.insert("hasChildren", r.value("kids").toInt() > 0);
            p.insert("bucket", ref);
            parts << p;
        }
        accountParts("AND " + bucketExpr + " = ? AND (l.amount < 0 OR dest.kind IN (" + SAVE_KINDS + "))", {ref});
    } else if (kind == "debt") {
        accountParts("AND l.amount < 0 AND dest.kind IN (" + QString(DEBT_SQL) + ")", {});
    } else {
        const int id = ref.toInt();
        const QVariantMap info = categoryInfo(id);
        out.insert("title", info.value("label"));
        out.insert("categoryId", id);
        const QString narrow = bucketKey.isEmpty() ? QString() : " AND " + bucketExpr + " = ?";
        QVariantList binds = {id, fromPeriod, toPeriod};
        if (!bucketKey.isEmpty())
            binds << bucketKey;
        QMap<int, QVariantMap> byPart;
        QMap<int, bool> isOwn;
        auto take = [&](const QVariantList &list, bool own) {
            for (const QVariant &v : list) {
                const QVariantMap r = v.toMap();
                const int pid = r.value("id").toInt();
                QVariantMap &p = byPart[pid];
                QVariantMap bk = p.value("buckets").toMap();
                const QString key = r.value("bucket").toString();
                bk.insert(key, bk.value(key).toLongLong() + r.value("amount").toLongLong());
                p.insert("buckets", bk);
                p.insert("amount", p.value("amount").toLongLong() + r.value("amount").toLongLong());
                p.insert("n", p.value("n").toInt() + r.value("n").toInt());
                isOwn[pid] = own;
            }
        };
        take(rows("WITH RECURSIVE up(id, part) AS (SELECT id, id FROM category WHERE parent_id = ? "
                  "UNION ALL SELECT c.id, up.part FROM category c JOIN up ON c.parent_id = up.id) "
                  "SELECT up.part AS id, " + bucketExpr + " AS bucket, SUM(-l.amount) AS amount, COUNT(*) AS n FROM v_line l "
                  "JOIN up ON up.id = l.category_id LEFT JOIN bucket b ON b.id = l.category_bucket_id "
                  "WHERE l.period_id BETWEEN ? AND ? AND l.on_budget = 1 AND l.category_kind = 'expense' AND l.status <> 'planned'"
                  + narrow + " GROUP BY 1, 2", binds), false);
        take(rows("SELECT l.category_id AS id, " + bucketExpr + " AS bucket, SUM(-l.amount) AS amount, COUNT(*) AS n FROM v_line l "
                  "LEFT JOIN bucket b ON b.id = l.category_bucket_id WHERE l.category_id = ? "
                  "AND l.period_id BETWEEN ? AND ? AND l.on_budget = 1 AND l.category_kind = 'expense' AND l.status <> 'planned'"
                  + narrow + " GROUP BY 1, 2", binds), true);
        for (auto it = byPart.constBegin(); it != byPart.constEnd(); ++it) {
            QVariantMap p = it.value();
            if (p.value("amount").toLongLong() == 0)
                continue;
            const int pid = it.key();
            const QVariantMap ci = categoryInfo(pid);
            p.insert("kind", "category");
            p.insert("id", pid);
            p.insert("own", isOwn.value(pid));
            p.insert("label", ci.value("label"));
            p.insert("hasChildren", !isOwn.value(pid) && scalar("SELECT COUNT(*) FROM category WHERE parent_id = ? AND deleted_at IS NULL", {pid}).toInt() > 0);
            QString main;
            qlonglong best = -1;
            const QVariantMap bk = p.value("buckets").toMap();
            for (auto b = bk.constBegin(); b != bk.constEnd(); ++b)
                if (b.value().toLongLong() > best) {
                    best = b.value().toLongLong();
                    main = b.key();
                }
            p.insert("bucket", main);
            parts << p;
        }
        std::sort(parts.begin(), parts.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap().value("amount").toLongLong() > b.toMap().value("amount").toLongLong();
        });
        // Interest sits in a category, but what is paid off is not a category at all.
        // Shown beside it, never added to it.
        const QString key = scalar("SELECT key FROM category WHERE id = ?", {id}).toString();
        const QString subtree = "WITH RECURSIVE sub(id) AS (SELECT ? UNION ALL SELECT c.id FROM category c JOIN sub ON c.parent_id = sub.id) ";
        const bool mortgageInterest = scalar(subtree + "SELECT COUNT(*) FROM category WHERE key = 'mortgage_interest' AND id IN (SELECT id FROM sub)", {id}).toInt() > 0;
        const bool loanInterest = scalar(subtree + "SELECT COUNT(*) FROM category WHERE key = 'loan_interest' AND id IN (SELECT id FROM sub)", {id}).toInt() > 0;
        if (mortgageInterest || loanInterest) {
            const QVariantList keep = parts;
            parts.clear();
            accountParts("AND l.amount < 0 AND dest.kind IN (" + QString(mortgageInterest && loanInterest ? "'mortgage','loan','credit'"
                         : mortgageInterest ? "'mortgage'" : "'loan','credit'") + ")", {});
            qlonglong relatedTotal = 0;
            for (const QVariant &v : parts)
                relatedTotal += v.toMap().value("amount").toLongLong();
            out.insert("related", parts);
            out.insert("relatedTotal", relatedTotal);
            parts = keep;
        }
        total = 0;
        for (const QVariant &v : parts) {
            total += v.toMap().value("amount").toLongLong();
            rowCount += v.toMap().value("n").toInt();
        }
        out.insert("parts", parts);
        out.insert("total", total);
        out.insert("rows", rowCount);
        return out;
    }
    for (const QVariant &v : parts) {
        total += v.toMap().value("amount").toLongLong();
        rowCount += v.toMap().value("n").toInt();
    }
    std::sort(parts.begin(), parts.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value("amount").toLongLong() > b.toMap().value("amount").toLongLong();
    });
    out.insert("parts", parts);
    out.insert("total", total);
    out.insert("rows", rowCount);
    return out;
}

// What came in, year by year and month by month. The salary is the rows marked
// as salary; the rest is other income. The average is per month that had a salary,
// so a part year compares fairly with a whole one.
QVariantMap Store::incomeHistory()
{
    QVariantMap out;
    const QString base = "FROM v_line l JOIN category c ON c.id = l.category_id WHERE c.kind = 'income' AND l.on_budget = 1 "
                         "AND l.status <> 'planned' ";
    QVariantList years;
    double previous = 0;
    for (const QVariant &v : rows("SELECT SUBSTR(l.period_id, 1, 4) AS year, "
                                  "SUM(CASE WHEN l.is_salary = 1 THEN l.amount ELSE 0 END) AS salary, "
                                  "SUM(CASE WHEN l.is_salary = 1 THEN 0 ELSE l.amount END) AS other, "
                                  "COUNT(DISTINCT CASE WHEN l.is_salary = 1 THEN l.period_id END) AS months " + base +
                                  "GROUP BY 1 ORDER BY 1")) {
        QVariantMap r = v.toMap();
        const int months = r.value("months").toInt();
        const double avg = months > 0 ? double(r.value("salary").toLongLong()) / months : 0;
        r.insert("avg", qRound64(avg));
        r.insert("partial", months > 0 && months < 12);
        r.insert("change", previous > 0 && avg > 0 ? QVariant((avg / previous - 1) * 100) : QVariant());
        if (avg > 0)
            previous = avg;
        years << r;
    }
    QVariantList months;
    for (const QVariant &v : rows("SELECT l.period_id AS id, SUM(CASE WHEN l.is_salary = 1 THEN l.amount ELSE 0 END) AS salary, "
                                  "SUM(CASE WHEN l.is_salary = 1 THEN 0 ELSE l.amount END) AS other " + base +
                                  "GROUP BY 1 ORDER BY 1 DESC LIMIT 36"))
        months.prepend(v);
    out.insert("years", years);
    out.insert("months", months);
    return out;
}

// This month and the ones ahead, as the planned rows add up: what comes in,
// what goes out, what is left. A month with no income planned says so.
QVariantList Store::forecast(int months)
{
    QVariantList out;
    const QString now = currentPeriod();
    for (int i = 0; i <= qBound(1, months, 36); ++i) {
        const QString id = shiftPeriod(now, i);
        const QVariantMap info = periodInfo(id);
        const QVariantMap s = summary(id);
        QVariantMap m;
        m.insert("id", id);
        m.insert("start", info.value("start"));
        m.insert("end", info.value("end"));
        m.insert("current", info.value("current"));
        const qlonglong in = s.value("income").toLongLong() + s.value("plannedIncome").toLongLong();
        const qlonglong spent = s.value("spentTotal").toLongLong(), planned = s.value("plannedTotal").toLongLong();
        m.insert("income", in);
        m.insert("hasIncome", in > 0);
        m.insert("out", spent + planned);
        m.insert("spent", spent);
        m.insert("planned", planned);
        m.insert("left", in - spent - planned);
        out << m;
    }
    return out;
}

QVariantList Store::categoryTransactions(int categoryId, const QString &fromPeriod, const QString &toPeriod, bool directOnly)
{
    QVariantList out;
    for (const QVariant &v : rows(
             "WITH RECURSIVE sub(id) AS (SELECT ? UNION ALL SELECT c.id FROM category c JOIN sub ON c.parent_id = sub.id) "
             "SELECT l.id, l.date, l.description, l.amount, l.amount_full, c.key AS ckey, c.name AS cname FROM v_line l "
             "JOIN category c ON c.id = l.category_id WHERE l.category_id IN (SELECT id FROM sub WHERE ? = 0 OR id = (SELECT ?)) AND l.period_id BETWEEN ? AND ? "
             "AND l.on_budget = 1 AND l.status <> 'planned' ORDER BY l.date DESC, l.id DESC", {categoryId, directOnly ? 1 : 0, categoryId, fromPeriod, toPeriod})) {
        QVariantMap r = v.toMap();
        r.insert("category", categoryName(r.value("ckey").toString(), r.value("cname").toString()));
        r.insert("shared", !r.value("amount_full").isNull() && r.value("amount_full").toLongLong() != 0);
        out << r;
    }
    return out;
}

// ------------------------------------------------------------------ files
QString Store::exportFolder() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + "/fiat-ratio";
    QDir().mkpath(dir);
    return dir;
}

QVariantMap Store::importBundle(const QString &path, const QString &mode)
{
    QVariantMap result;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        result.insert("error", "cannot-read");
        return result;
    }
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        result.insert("error", "not-json");
        return result;
    }
    result = Bundle::importBundle(m_db, doc.object(), mode);
    if (!result.contains("error"))
        autoPlan();
    touch();
    return result;
}

QString Store::exportBundle()
{
    const QJsonObject b = Bundle::exportBundle(m_db, true, QString::fromUtf8(APP_VERSION));
    const QString path = exportFolder() + "/fiat-ratio-" + QDateTime::currentDateTime().toString("yyyy-MM-dd-HHmm") + ".json";
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly))
        return QString();
    f.write(QJsonDocument(b).toJson(QJsonDocument::Compact));
    return path;
}

QString Store::exportCsv()
{
    const QString path = exportFolder() + "/transactions-" + QDateTime::currentDateTime().toString("yyyy-MM-dd-HHmm") + ".csv";
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return QString();
    QTextStream out(&f);
    out.setCodec("UTF-8");
    out << "uuid,date,period,account,amount,amount_full,currency,status,type,category,bucket,transfer_account,method,context,payee,person,description,notes,scope\n";
    const QVariantList all = rows(
        "SELECT t.uuid, t.date, t.period_id, a.name AS account, t.amount, t.amount_full, a.currency, t.status, "
        "CASE WHEN t.transfer_peer_id IS NOT NULL THEN 'transfer' WHEN c.kind = 'income' THEN 'income' "
        "WHEN c.kind = 'neutral' THEN 'neutral' WHEN t.amount > 0 AND c.kind = 'expense' THEN 'refund' "
        "WHEN c.kind = 'expense' THEN 'expense' ELSE '' END AS type, c.key AS ckey, c.name AS cname, "
        "b.key AS bkey, b.name AS bname, pa.name AS peer, m.name AS method, x.name AS context, py.name AS payee, "
        "pe.name AS person, t.description, t.notes, t.scope "
        "FROM txn t JOIN account a ON a.id = t.account_id LEFT JOIN category c ON c.id = t.category_id "
        "LEFT JOIN bucket b ON b.id = c.bucket_id LEFT JOIN txn peer ON peer.id = t.transfer_peer_id "
        "LEFT JOIN account pa ON pa.id = peer.account_id LEFT JOIN method m ON m.id = t.method_id "
        "LEFT JOIN context x ON x.id = t.context_id LEFT JOIN payee py ON py.id = t.payee_id "
        "LEFT JOIN person pe ON pe.id = t.person_id WHERE t.deleted_at IS NULL ORDER BY t.date, t.id");
    for (const QVariant &v : all) {
        const QVariantMap r = v.toMap();
        const QString cat = r.value("ckey").isNull() && r.value("cname").isNull() ? QString()
                          : categoryName(r.value("ckey").toString(), r.value("cname").toString());
        const QString bucket = r.value("bkey").isNull() && r.value("bname").isNull() ? QString()
                             : bucketName(r.value("bkey").toString(), r.value("bname").toString());
        QStringList cells;
        cells << csvField(r.value("uuid")) << csvField(r.value("date")) << csvField(r.value("period_id"))
              << csvField(r.value("account")) << money(r.value("amount").toLongLong())
              << (r.value("amount_full").isNull() ? QString() : money(r.value("amount_full").toLongLong()))
              << csvField(r.value("currency")) << csvField(r.value("status")) << csvField(r.value("type"))
              << csvField(cat) << csvField(bucket) << csvField(r.value("peer")) << csvField(r.value("method"))
              << csvField(r.value("context")) << csvField(r.value("payee")) << csvField(r.value("person"))
              << csvField(r.value("description")) << csvField(r.value("notes")) << csvField(r.value("scope"));
        out << cells.join(',') << '\n';
    }
    return path;
}
