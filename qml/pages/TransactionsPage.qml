import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

Page {
    id: page

    property string periodId: store.currentPeriod()
    property bool unsorted: false     // only rows saved without a category
    readonly property var rows: {
        store.revision
        var all = store.transactions(periodId, !unsorted, 0)
        if (!unsorted) return all
        return all.filter(function(r) { return !r.category && !r.isMove })
    }

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()
    Connections { target: FiatRatioTheme; onAmbientChanged: page.paint() }

    Rectangle {
        anchors.fill: parent
        visible: !FiatRatioTheme.ambient
        gradient: Gradient {
            GradientStop { position: 0.0; color: FiatRatioTheme.backgroundHigh }
            GradientStop { position: 1.0; color: FiatRatioTheme.backgroundLow }
        }
    }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.rows

        header: PageHead {
            title: page.unsorted ? qsTr("to sort") : F.monthTitle(appLanguage, page.periodId)
            //: Number of rows in a month
            subtitle: page.unsorted ? F.monthTitle(appLanguage, page.periodId) : qsTr("%1 rows").arg(page.rows.length)
        }

        delegate: TxnRow {
            id: row
            item: modelData
            onClicked: pageStack.push(Qt.resolvedUrl(row.planned ? "ConfirmDialog.qml" : "AddDialog.qml"), { "txnId": modelData.id })
            menu: ContextMenu {
                MenuItem {
                    visible: row.planned
                    text: qsTr("paid as expected")
                    onClicked: store.setCleared(modelData.id, true)
                }
                MenuItem {
                    text: qsTr("delete")
                    onClicked: row.remorseDelete(function() { store.deleteTransaction(modelData.id) })
                }
            }
        }
        VerticalScrollDecorator { }
    }

    EmptyNote {
        anchors.centerIn: parent
        visible: page.rows.length === 0
        text: page.unsorted ? qsTr("Everything has a category.") : qsTr("Nothing this month yet.")
    }
}
