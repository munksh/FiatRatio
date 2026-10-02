import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

Page {
    id: page

    property int categoryId: 0
    property string label: ""
    property string fromPeriod: ""
    property string toPeriod: ""
    property bool directOnly: false
    readonly property var rows: { store.revision; return store.categoryTransactions(categoryId, fromPeriod, toPeriod, directOnly) }

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

    SilicaListView {
        anchors.fill: parent
        model: page.rows
        header: PageHead {
            title: page.label
            subtitle: qsTr("%1 rows").arg(page.rows.length)
        }
        delegate: TxnRow {
            item: modelData
            onClicked: pageStack.push(Qt.resolvedUrl("AddDialog.qml"), { "txnId": modelData.id })
        }
        VerticalScrollDecorator { }
    }
}
