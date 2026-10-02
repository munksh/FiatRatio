import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

// Where money comes from or goes to: the month's money first, then every place.
Page {
    id: page

    property int selectedId: -1
    property int excludeId: -2
    signal picked(int id)

    readonly property var places: {
        store.revision
        var out = [{ "id": 0, "name": qsTr("the month's money"), "kind": "pot" }]
        var all = store.accounts()
        for (var i = 0; i < all.length; ++i) out.push(all[i])
        return out.filter(function(a) { return a.id !== page.excludeId })
    }

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()

    Kinds { id: kinds }

    Rectangle {
        anchors.fill: parent
        visible: !FiatRatioTheme.ambient
        gradient: Gradient {
            GradientStop { position: 0.0; color: FiatRatioTheme.backgroundHigh }
            GradientStop { position: 1.0; color: FiatRatioTheme.backgroundLow }
        }
    }

    SilicaListView {
        anchors.fill: parent
        model: page.places
        header: PageHead { title: qsTr("where") }
        delegate: BackgroundItem {
            width: parent ? parent.width : 0
            height: Theme.itemSizeMedium
            highlighted: down || modelData.id === page.selectedId
            highlightedColor: FiatRatioTheme.highlightWash
            onClicked: { page.picked(modelData.id); pageStack.pop() }
            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    width: parent.width
                    text: modelData.name
                    truncationMode: TruncationMode.Fade
                    color: modelData.id === page.selectedId ? FiatRatioTheme.accent : FiatRatioTheme.primaryText
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: modelData.kind === "pot" ? FiatRatioTheme.serif : Theme.fontFamily
                    font.italic: modelData.kind === "pot"
                }
                Label {
                    text: kinds.label(modelData.kind)
                    visible: modelData.kind !== "pot"
                    color: FiatRatioTheme.secondaryText
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
            }
        }
        VerticalScrollDecorator { }
    }
}
