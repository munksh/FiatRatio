#ifndef BUNDLE_H
#define BUNDLE_H

#include <QJsonObject>
#include <QSqlDatabase>
#include <QVariantMap>

// The fiat ratio bundle: one JSON file, rows referenced by uuid, months by label.
// Same format as tools/fiat_bundle.py, which is its specification by example.
namespace Bundle {
    QJsonObject exportBundle(QSqlDatabase &db, bool includeArchive, const QString &appVersion);
    // mode: "replace" wipes the database first; "merge" keeps the newer updated_at per row.
    // Returns inserted / updated / skipped, or error.
    QVariantMap importBundle(QSqlDatabase &db, const QJsonObject &bundle, const QString &mode);
}

#endif
