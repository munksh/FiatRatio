import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

// A managed list: ways to pay, contexts, people. With picking on, a tap chooses
// the row and the page closes; press and hold still renames or archives it.
Page {
    id: page

    property string table: "method"
    property string title
    property string hint
    property bool picking: false
    property int selectedId: 0
    property string noneLabel: ""      // picking only: a first row that clears the choice
    signal picked(int id, string name)

    readonly property var rows: { store.revision; return store.list(table) }

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()

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
        PageHead { title: page.title; subtitle: page.hint }
        TextField {
            id: addField
            width: parent.width
            label: qsTr("Add")
            placeholderText: qsTr("Add")
            EnterKey.enabled: text.trim() !== ""
            EnterKey.iconSource: "image://theme/icon-m-add"
            EnterKey.onClicked: {
                var id = store.addListItem(page.table, text)
                text = ""
                if (page.picking && id > 0) {
                    page.picked(id, store.list(page.table).filter(function(r) { return r.id === id })[0].name)
                    pageStack.pop()
                }
            }
        }
        BackgroundItem {
            width: parent.width
            height: Theme.itemSizeSmall
            visible: page.picking && page.noneLabel !== ""
            highlightedColor: FiatRatioTheme.highlightWash
            onClicked: { page.picked(0, ""); pageStack.pop() }
            Label {
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                text: page.noneLabel
                color: page.selectedId === 0 ? FiatRatioTheme.accent : FiatRatioTheme.secondaryText
                font.italic: true
            }
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
                    text: qsTr("rename")
                    onClicked: {
                        var d = pageStack.push(Qt.resolvedUrl("TextDialog.qml"),
                                               { "title": qsTr("rename"), "label": qsTr("Name"), "text": modelData.name })
                        d.accepted.connect(function() { store.renameListItem(page.table, modelData.id, d.value) })
                    }
                }
                MenuItem {
                    visible: page.table !== "person"
                    text: qsTr("archive")
                    onClicked: item.remorseAction(qsTr("Archiving"), function() { store.archiveListItem(page.table, modelData.id) })
                }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name
                truncationMode: TruncationMode.Fade
                color: (item.highlighted || (page.picking && modelData.id === page.selectedId))
                       ? FiatRatioTheme.accent : FiatRatioTheme.primaryText
            }
            Label {
                anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                visible: page.picking && modelData.id === page.selectedId
                text: "✓"
                color: FiatRatioTheme.accent
            }
            onClicked: {
                if (page.picking) { page.picked(modelData.id, modelData.name); pageStack.pop() }
                else openMenu()
            }
        }
        VerticalScrollDecorator { }
    }
}
