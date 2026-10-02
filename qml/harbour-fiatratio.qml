import QtQuick 2.0
import Sailfish.Silica 1.0
import "."
import "pages"

ApplicationWindow {
    id: app

    initialPage: store.setUp ? Qt.resolvedUrl("pages/MonthPage.qml") : Qt.resolvedUrl("pages/WelcomePage.qml")
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: Orientation.Portrait
    _defaultPageOrientations: Orientation.Portrait

    Component.onCompleted: FiatRatioTheme.applyPalette(app)
    Connections { target: FiatRatioTheme; onAmbientChanged: FiatRatioTheme.applyPalette(app) }

    // The cover's + opens the add dialog over whatever is showing.
    Connections {
        target: store
        onAddRequested: {
            if (!store.setUp) return
            app.activate()
            pageStack.push(Qt.resolvedUrl("pages/AddDialog.qml"), {}, PageStackAction.Immediate)
        }
    }
}
