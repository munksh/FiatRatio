import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import ".."
import "../components"

// First start. The newcomer tries the app on made-up money before anything is real.
Page {
    id: page

    property string message: ""
    property string pendingPath: ""

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()
    Connections { target: FiatRatioTheme; onAmbientChanged: page.paint() }

    // The picker is still leaving when it reports the file; act once we are back.
    onStatusChanged: {
        if (status !== PageStatus.Active || pendingPath === "")
            return
        var path = pendingPath
        pendingPath = ""
        var r = store.importBundle(path, "replace")
        if (r.error)
            message = qsTr("That file could not be read: %1").arg(r.error)
        else if (store.setUp)
            pageStack.replaceAbove(null, Qt.resolvedUrl("MonthPage.qml"))
        else
            message = qsTr("The file was read, but it holds no month's money.")
    }

    Rectangle {
        anchors.fill: parent
        visible: !FiatRatioTheme.ambient
        gradient: Gradient {
            GradientStop { position: 0.0; color: FiatRatioTheme.backgroundHigh }
            GradientStop { position: 1.0; color: FiatRatioTheme.backgroundLow }
        }
    }

    Component {
        id: picker
        FilePickerPage {
            nameFilters: ["*.json"]
            onSelectedContentPropertiesChanged: page.pendingPath = selectedContentProperties.filePath
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: Theme.paddingLarge

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "fiat ratio"
            color: FiatRatioTheme.primaryText
            font.pixelSize: Theme.fontSizeHuge
            font.family: FiatRatioTheme.serif
            font.italic: true
        }
        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Money from one salary to the next.")
            color: FiatRatioTheme.secondaryText
            font.pixelSize: Theme.fontSizeMedium
            font.family: FiatRatioTheme.serif
        }
        Item { width: 1; height: Theme.paddingLarge }
        FiatButton {
            filled: true
            text: qsTr("practice run")
            onClicked: {
                store.startDemo()
                pageStack.replaceAbove(null, Qt.resolvedUrl("MonthPage.qml"))
            }
        }
        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Short guided tour. Nothing is kept.")
            color: FiatRatioTheme.secondaryText
            font.pixelSize: Theme.fontSizeExtraSmall
        }
        FiatButton {
            filled: false
            text: qsTr("start for real")
            onClicked: pageStack.push(Qt.resolvedUrl("SetupPage.qml"))
        }
        LinkText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("import a file")
            onClicked: pageStack.push(picker)
        }
        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            visible: page.message !== ""
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: page.message
            color: FiatRatioTheme.wrong
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
