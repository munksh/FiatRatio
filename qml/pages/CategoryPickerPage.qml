import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

// One category from the tree. The search field stays outside the list, where
// a new model does not take its focus away.
Page {
    id: page

    property string kind: "expense"
    property int selectedId: 0
    signal picked(int id, string label)

    readonly property var all: { store.revision; return store.categories(kind) }
    property string filter: ""

    function filtered() {
        if (filter === "") return all
        var f = filter.toLowerCase()
        var out = []
        for (var i = 0; i < all.length; ++i) {
            var c = all[i]
            if (c.label.toLowerCase().indexOf(f) >= 0 || c.group.toLowerCase().indexOf(f) >= 0)
                out.push(c)
        }
        return out
    }

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
        PageHead { title: qsTr("category") }
        SearchField {
            width: parent.width
            placeholderText: qsTr("Search")
            onTextChanged: page.filter = text
            EnterKey.iconSource: "image://theme/icon-m-enter-close"
            EnterKey.onClicked: focus = false
        }
    }

    SilicaListView {
        anchors { top: top.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: page.filtered()
        delegate: BackgroundItem {
            width: parent ? parent.width : 0
            height: Theme.itemSizeSmall
            highlighted: down || modelData.id === page.selectedId
            highlightedColor: FiatRatioTheme.highlightWash
            Rectangle {
                id: dot
                x: Theme.horizontalPageMargin + (page.filter !== "" ? 0 : modelData.depth * Theme.paddingLarge * 1.5)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.paddingMedium; height: width; radius: width / 2
                color: FiatRatioTheme.bucketColor(modelData.bucket || "uncategorised", "")
                visible: page.kind === "expense"
            }
            Label {
                anchors {
                    left: dot.visible ? dot.right : parent.left
                    leftMargin: dot.visible ? Theme.paddingMedium : Theme.horizontalPageMargin + modelData.depth * Theme.paddingLarge * 1.5
                    right: parent.right; rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                text: page.filter !== "" && modelData.depth > 0 ? modelData.group + " › " + modelData.label : modelData.label
                truncationMode: TruncationMode.Fade
                color: modelData.id === page.selectedId ? FiatRatioTheme.accent : FiatRatioTheme.primaryText
                font.pixelSize: Theme.fontSizeSmall
                font.bold: modelData.depth === 0 && page.filter === ""
            }
            onClicked: {
                page.picked(modelData.id, modelData.label)
                pageStack.pop()
            }
        }
        VerticalScrollDecorator { }
    }
}
