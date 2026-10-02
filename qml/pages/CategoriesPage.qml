import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

Page {
    id: page

    property string kind: "expense"
    readonly property var rows: { store.revision; return store.categories(kind) }
    readonly property var bucketList: { store.revision; return store.buckets() }

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()

    function bucketLabel(key) {
        for (var i = 0; i < bucketList.length; ++i)
            if (bucketList[i].key === key) return bucketList[i].label
        return ""
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
        id: top
        width: parent.width
        PageHead {
            title: qsTr("categories")
            subtitle: qsTr("Standard names follow the language. Your own name wins.")
        }
        WordChoice {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            choices: [ { label: qsTr("spending"), value: "expense" }, { label: qsTr("income"), value: "income" } ]
            current: page.kind
            onChosen: page.kind = value
        }
        LinkText {
            x: Theme.horizontalPageMargin - Theme.paddingSmall
            text: qsTr("+ a category")
            onClicked: pageStack.push(Qt.resolvedUrl("CategoryDialog.qml"), { "kind": page.kind })
        }
    }

    SilicaListView {
        anchors { top: top.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: page.rows
        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeSmall
            menu: ContextMenu {
                MenuItem {
                    text: qsTr("archive")
                    onClicked: item.remorseAction(qsTr("Archiving"), function() { store.archiveCategory(modelData.id) })
                }
            }
            onClicked: pageStack.push(Qt.resolvedUrl("CategoryDialog.qml"), {
                "kind": page.kind, "categoryId": modelData.id, "name": modelData.name || "",
                "standardLabel": modelData.key ? modelData.label : "", "bucketId": Number(modelData.bucket_id) || 0 })
            Label {
                anchors {
                    left: parent.left; leftMargin: Theme.horizontalPageMargin + modelData.depth * Theme.paddingLarge * 1.5
                    right: counts.left; rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                text: modelData.label
                truncationMode: TruncationMode.Fade
                color: item.highlighted ? FiatRatioTheme.accent : FiatRatioTheme.primaryText
                font.pixelSize: Theme.fontSizeSmall
                font.bold: modelData.depth === 0
            }
            Label {
                id: counts
                anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                visible: page.kind === "expense" && !!modelData.bucket
                text: page.bucketLabel(modelData.bucket).toLowerCase()
                color: FiatRatioTheme.bucketColor(modelData.bucket, "")
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }
        VerticalScrollDecorator { }
    }
}
