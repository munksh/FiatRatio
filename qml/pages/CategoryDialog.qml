import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

// A new category, or a new name and kind of spending for one.
Dialog {
    id: dialog

    property string kind: "expense"
    property int categoryId: 0
    property string name: ""
    property string standardLabel: ""
    property int bucketId: 0
    property int parentId: 0
    property string parentLabel: ""

    readonly property var bucketList: store.buckets()

    canAccept: categoryId > 0 || nameField.text.trim() !== ""

    function paint() { FiatRatioTheme.applyPalette(dialog) }
    Component.onCompleted: paint()

    onAccepted: {
        if (categoryId > 0) {
            store.renameCategory(categoryId, nameField.text)
            if (kind === "expense") store.setCategoryBucket(categoryId, bucketId)
        } else {
            store.addCategory(nameField.text, kind, bucketId, parentId)
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !FiatRatioTheme.ambient
        gradient: Gradient {
            GradientStop { position: 0.0; color: FiatRatioTheme.backgroundHigh }
            GradientStop { position: 1.0; color: FiatRatioTheme.backgroundLow }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.paddingSmall

        DialogHead {
            dialog: dialog
            title: dialog.categoryId > 0 ? qsTr("category") : qsTr("a new category")
        }
        TextField {
            id: nameField
            width: parent.width
            text: dialog.name
            label: qsTr("Name")
            placeholderText: dialog.standardLabel !== "" ? dialog.standardLabel : qsTr("Name")
            description: dialog.standardLabel !== "" ? qsTr("Empty keeps the standard name.") : ""
        }
        ValueButton {
            visible: dialog.categoryId === 0
            label: qsTr("Inside")
            value: dialog.parentLabel !== "" ? dialog.parentLabel : qsTr("nothing, a main category")
            onClicked: {
                var p = pageStack.push(Qt.resolvedUrl("CategoryPickerPage.qml"), { "kind": dialog.kind, "selectedId": dialog.parentId })
                p.picked.connect(function(id, label) { dialog.parentId = id; dialog.parentLabel = label })
            }
        }
        SectionLabel {
            x: Theme.horizontalPageMargin
            visible: dialog.kind === "expense"
            text: qsTr("Counts as")
        }
        WordChoice {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            visible: dialog.kind === "expense"
            choices: {
                var out = []
                for (var i = 0; i < dialog.bucketList.length; ++i)
                    out.push({ "label": String(dialog.bucketList[i].label).toLowerCase(), "value": dialog.bucketList[i].id })
                return out
            }
            current: dialog.bucketId
            onChosen: dialog.bucketId = value
        }
        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            visible: dialog.kind === "expense"
            wrapMode: Text.WordWrap
            text: qsTr("Needs, wants or saving. Sets the colour on the month bar.")
            color: FiatRatioTheme.secondaryText
            font.pixelSize: Theme.fontSizeExtraSmall
        }
    }
}
