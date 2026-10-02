#include <QtQuick>
#include <QLocale>
#include <QSettings>
#include <QTranslator>
#include <QTimer>

#include <sailfishapp.h>

#include "store.h"

#ifndef APP_VERSION
#define APP_VERSION "0.0.0-dev"
#endif

namespace {
// Languages the app ships. Finnish is left out on purpose.
const QStringList LANGUAGES = {"en", "sv", "de", "ru"};
}

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    app->setOrganizationName(QStringLiteral("se.munkstolen"));
    app->setApplicationName(QStringLiteral("harbour-fiatratio"));
    app->setApplicationVersion(QString::fromUtf8(APP_VERSION));

    // Language follows the phone. A language picked in Settings is a deliberate
    // override; empty means "follow the phone". libsailfishapp already loaded the
    // phone's translation. An override is installed on top, and wins because the
    // last installed translator is asked first.
    QTranslator override;
    auto resolve = [&]() -> QString {
        const QString chosen = QSettings().value(QStringLiteral("language")).toString();
        QString c = chosen.isEmpty() ? QLocale::system().name().left(2) : chosen;
        return LANGUAGES.contains(c) ? c : QStringLiteral("en");
    };
    auto installOverride = [&]() {
        app->removeTranslator(&override);
        if (QSettings().value(QStringLiteral("language")).toString().isEmpty())
            return;
        if (override.load(QStringLiteral("harbour-fiatratio-") + resolve(),
                          SailfishApp::pathTo(QStringLiteral("translations")).toLocalFile()))
            app->installTranslator(&override);
    };
    QString code = resolve();
    installOverride();

    Store store(SailfishApp::pathTo(QStringLiteral("qml/data/schema.sql")).toLocalFile(),
                SailfishApp::pathTo(QStringLiteral("qml/data/standard.json")).toLocalFile(),
                code);
    store.open();

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->rootContext()->setContextProperty(QStringLiteral("store"), &store);
    view->rootContext()->setContextProperty(QStringLiteral("appVersion"), QString::fromUtf8(APP_VERSION));
    view->rootContext()->setContextProperty(QStringLiteral("appLanguage"), code);
    view->setSource(SailfishApp::pathToMainQml());
    view->show();

    // A language chosen in Settings applies at once. The change arrives from a
    // QML handler, so the interface is rebuilt one turn of the event loop later,
    // never while that handler is still running.
    QObject::connect(&store, &Store::languageSettingChanged, &store, [&]() {
        installOverride();
        const QString now = resolve();
        store.setContentLanguage(now);
        view->rootContext()->setContextProperty(QStringLiteral("appLanguage"), now);
        QTimer::singleShot(0, &store, [&]() {
#if QT_VERSION >= QT_VERSION_CHECK(5, 10, 0)
            view->engine()->retranslate();
#else
            // Qt 5.6 (Sailfish OS) cannot refresh texts in place: start the
            // interface again. Open pages are closed; settings and data stay.
            view->setSource(QUrl());
            view->engine()->clearComponentCache();
            view->setSource(SailfishApp::pathToMainQml());
#endif
        });
    });

    return app->exec();
}
