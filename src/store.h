#ifndef STORE_H
#define STORE_H

#include <QDate>
#include <QJsonObject>
#include <QObject>
#include <QSqlDatabase>
#include <QVariant>

class Store : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(bool setUp READ isSetUp NOTIFY changed)
    Q_PROPERTY(QString language READ language CONSTANT)
    Q_PROPERTY(QString languageSetting READ languageSetting NOTIFY languageSettingChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY changed)
    Q_PROPERTY(bool demo READ isDemo NOTIFY demoChanged)
    Q_PROPERTY(int coachStep READ coachStep WRITE setCoachStep NOTIFY demoChanged)

public:
    Store(const QString &schemaPath, const QString &standardPath, const QString &language, QObject *parent = nullptr);
    bool open();

    int revision() const { return m_revision; }
    bool isSetUp();
    QString language() const { return m_language; }
    // Standard names follow the language; changing it re-reads them everywhere.
    void setContentLanguage(const QString &code) { m_language = code; touch(); }
    QString languageSetting() const;
    QString lastError() const { return m_error; }
    bool isDemo() const { return m_demo; }
    int coachStep() const { return m_coach; }
    void setCoachStep(int step);

    // ---- settings
    Q_INVOKABLE QString setting(const QString &key, const QString &fallback = QString());
    Q_INVOKABLE void setSetting(const QString &key, const QString &value);
    Q_INVOKABLE void setLanguage(const QString &code);
    Q_INVOKABLE void setupFresh(const QVariantMap &options);
    Q_INVOKABLE QString localeCurrency() const;

    // ---- practice run: a separate database with made-up money
    Q_INVOKABLE void startDemo();
    Q_INVOKABLE void endDemo();

    // ---- months
    Q_INVOKABLE QString today() const;
    Q_INVOKABLE QString yesterday() const;
    Q_INVOKABLE QString currentPeriod();
    Q_INVOKABLE QString periodFor(const QString &isoDate);
    Q_INVOKABLE QString shiftPeriod(const QString &periodId, int months);
    Q_INVOKABLE QVariantMap periodInfo(const QString &periodId);
    Q_INVOKABLE QVariantMap summary(const QString &periodId);
    Q_INVOKABLE QVariantList plannedItems(const QString &periodId);
    Q_INVOKABLE QVariantList upcoming(const QString &periodId);
    Q_INVOKABLE QVariantList transactions(const QString &periodId, bool includePlanned = true, int limit = 0);
    Q_INVOKABLE int transactionCount(const QString &periodId);

    // ---- transactions
    Q_INVOKABLE int addTransaction(const QVariantMap &t);
    Q_INVOKABLE QVariantMap transaction(int txnId);
    Q_INVOKABLE bool updateTransaction(int txnId, const QVariantMap &t);
    Q_INVOKABLE void confirmPlanned(int txnId, const QVariantMap &c);
    Q_INVOKABLE void setCleared(int txnId, bool cleared);
    Q_INVOKABLE void deleteTransaction(int txnId);
    Q_INVOKABLE QVariantMap lastFor(const QString &description);
    Q_INVOKABLE int usualMethod();
    Q_INVOKABLE int unsortedCount(const QString &periodId);
    Q_INVOKABLE QVariantMap breakdown(const QString &kind, const QString &ref, const QString &fromPeriod, const QString &toPeriod,
                                      const QString &bucketKey = QString());
    Q_INVOKABLE QVariantMap incomeHistory();
    Q_INVOKABLE QVariantList forecast(int months);

    // ---- repeating
    Q_INVOKABLE QVariantList schedules();
    Q_INVOKABLE QVariantMap schedule(int id);
    Q_INVOKABLE int addSchedule(const QVariantMap &s);
    Q_INVOKABLE void updateSchedule(int id, const QVariantMap &s);
    Q_INVOKABLE void setScheduleActive(int id, bool active);
    Q_INVOKABLE void endScheduleAfter(int id, const QString &isoDate);
    Q_INVOKABLE void deleteSchedule(int id);
    Q_INVOKABLE int autoPlan();

    // ---- categories and lists
    Q_INVOKABLE QVariantList buckets();
    Q_INVOKABLE QVariantList categories(const QString &kind);
    Q_INVOKABLE QVariantMap categoryInfo(int id);
    Q_INVOKABLE int addCategory(const QString &name, const QString &kind, int bucketId, int parentId);
    Q_INVOKABLE void renameCategory(int id, const QString &name);
    Q_INVOKABLE void setCategoryBucket(int id, int bucketId);
    Q_INVOKABLE void archiveCategory(int id);
    Q_INVOKABLE QVariantList list(const QString &table);
    Q_INVOKABLE int addListItem(const QString &table, const QString &name);
    Q_INVOKABLE void renameListItem(const QString &table, int id, const QString &name);
    Q_INVOKABLE void archiveListItem(const QString &table, int id);

    // ---- what you have and what you owe
    Q_INVOKABLE QVariantList accounts();
    Q_INVOKABLE QVariantMap account(int id);
    Q_INVOKABLE QVariantList accountTransactions(int id, int limit);
    Q_INVOKABLE int addAccount(const QVariantMap &a);
    Q_INVOKABLE int addLoan(const QVariantMap &l);
    Q_INVOKABLE bool correctBalance(int accountId, qlonglong trueWhole);
    Q_INVOKABLE void addValuation(int accountId, qlonglong wholeValue, const QString &isoDate);
    Q_INVOKABLE void addRate(int accountId, double rate);
    Q_INVOKABLE void closeAccount(int id);
    Q_INVOKABLE QVariantMap netWorth();
    Q_INVOKABLE QVariantList netWorthSeries(int months);

    // ---- looking back
    Q_INVOKABLE QVariantList history(int months);
    Q_INVOKABLE QVariantMap analysis(const QString &fromPeriod, const QString &toPeriod);
    Q_INVOKABLE QVariantList categoryTransactions(int categoryId, const QString &fromPeriod, const QString &toPeriod, bool directOnly = false);

    // ---- files
    Q_INVOKABLE QVariantMap importBundle(const QString &path, const QString &mode);
    Q_INVOKABLE QString exportBundle();
    Q_INVOKABLE QString exportCsv();
    Q_INVOKABLE QString exportFolder() const;

    Q_INVOKABLE void requestAdd() { emit addRequested(); }

signals:
    void changed();
    void addRequested();
    void languageSettingChanged();
    void demoChanged();

private:
    QVariantList rows(const QString &sql, const QVariantList &binds = QVariantList());
    QVariant scalar(const QString &sql, const QVariantList &binds = QVariantList());
    bool exec(const QString &sql, const QVariantList &binds = QVariantList());
    int insert(const QString &table, const QVariantMap &rec);
    void touch();
    bool openFile(const QString &fileName);
    bool runSchema();
    bool migrate(const QString &fileName);
    void seedDemo();
    QString categoryName(const QString &key, const QString &name) const;
    QString bucketName(const QString &key, const QString &name) const;
    QDate predictedStart(const QString &periodId);
    QString ensurePeriod(const QString &periodId, const QDate &start = QDate());
    QString openSalaryPeriod(const QDate &date, int anchorTxn);
    int potId();
    int keyedCategory(const QString &key);
    int insertTxn(const QVariantMap &t, int scheduleId);
    int scheduleFromTxn(const QVariantMap &t, const QString &repeat);
    QList<QDate> scheduleDates(const QVariantMap &s, const QDate &from, const QDate &to);
    int writePlanned(const QVariantMap &s, const QDate &date);
    int planInto(const QString &periodId, bool onlyRare, const QDate &notBefore);
    void dropFuturePlanned(int scheduleId, const QDate &after);
    void deleteTxnPair(int txnId);

    QSqlDatabase m_db;
    QString m_schemaPath;
    QString m_language;
    QJsonObject m_standard;
    QString m_error;
    int m_revision = 0;
    bool m_demo = false;
    int m_coach = -1;
};

#endif
