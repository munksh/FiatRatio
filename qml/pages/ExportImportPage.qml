import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import ".."
import "../components"

Page {
    id: page

    property string result: ""
    property bool resultBad: false
    property string pendingPath: ""
    property string pendingMode: ""

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()

    function report(r) {
        if (r.error) {
            resultBad = true
            result = qsTr("Nothing was changed: %1").arg(r.error)
        } else {
            resultBad = false
            result = qsTr("Done. %1 rows added, %2 updated, %3 already up to date.").arg(r.inserted).arg(r.updated).arg(r.skipped)
        }
    }

    // The picker is still leaving when it reports the file; act once we are back.
    onStatusChanged: {
        if (status !== PageStatus.Active || pendingPath === "")
            return
        var path = pendingPath, mode = pendingMode
        pendingPath = ""
        if (mode === "replace")
            remorse.execute(qsTr("Replacing everything"), function() { page.report(store.importBundle(path, "replace")) })
        else
            page.report(store.importBundle(path, "merge"))
    }

    RemorsePopup { id: remorse }

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

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingMedium

            PageHead {
                title: qsTr("data")
                subtitle: store.exportFolder()
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.result !== ""
                wrapMode: Text.WordWrap
                text: page.result
                color: page.resultBad ? FiatRatioTheme.wrong : FiatRatioTheme.accent
                font.pixelSize: Theme.fontSizeSmall
            }

            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Take it with you") }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("One open JSON file with every row: months, places, values, what comes back, and what earlier imports brought in. It is the backup, the way to a new phone, and the way out.")
            }
            FiatButton {
                filled: true
                text: qsTr("export everything")
                onClicked: {
                    var path = store.exportBundle()
                    page.resultBad = path === ""
                    page.result = path !== "" ? qsTr("Saved to %1").arg(path) : qsTr("Could not write the file.")
                }
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                text: qsTr("only the rows, as CSV for a spreadsheet")
                onClicked: {
                    var path = store.exportCsv()
                    page.resultBad = path === ""
                    page.result = path !== "" ? qsTr("Saved to %1").arg(path) : qsTr("Could not write the file.")
                }
            }

            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Bring it in") }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Merge keeps what is here and takes the newer version of each row from the file. Replace empties the app first and loads the file as it is.")
            }
            FiatButton {
                filled: false
                text: qsTr("merge a file")
                onClicked: { page.pendingMode = "merge"; pageStack.push(picker) }
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                text: qsTr("replace everything with a file")
                color: FiatRatioTheme.wrong
                onClicked: { page.pendingMode = "replace"; pageStack.push(picker) }
            }
        }
        VerticalScrollDecorator { }
    }
}
