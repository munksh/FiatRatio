import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// The months ahead: what is already planned to come in and go out, and what
// that leaves. Repeating items are written into every month up to the horizon.
Page {
    id: page

    readonly property string currency: { store.revision; return store.setting("base_currency", "SEK") }
    readonly property int ahead: { store.revision; return Number(store.setting("plan_months", "12")) }
    readonly property var months: { store.revision; return store.forecast(ahead) }
    readonly property bool anyIncome: {
        for (var i = 1; i < months.length; ++i) if (months[i].hasIncome) return true
        return false
    }

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()
    Connections { target: FiatRatioTheme; onAmbientChanged: page.paint() }

    function biggest() {
        var m = 1
        for (var i = 0; i < months.length; ++i) m = Math.max(m, Number(months[i].out), Number(months[i].income))
        return m
    }

    Rectangle {
        anchors.fill: parent
        visible: !FiatRatioTheme.ambient
        gradient: Gradient {
            GradientStop { position: 0.0; color: FiatRatioTheme.backgroundHigh }
            GradientStop { position: 1.0; color: FiatRatioTheme.backgroundLow }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge * 2

        PullDownMenu {
            highlightColor: FiatRatioTheme.chromeAccent
            MenuItem {
                text: qsTr("Recurring")
                color: FiatRatioTheme.primaryText
                onClicked: pageStack.push(Qt.resolvedUrl("SchedulesPage.qml"))
            }
            // Last, nearest the thumb.
            MenuItem {
                text: qsTr("Add planned")
                color: FiatRatioTheme.primaryText
                onClicked: pageStack.push(Qt.resolvedUrl("AddDialog.qml"), {
                    "presetDate": page.months.length > 1 ? page.months[1].start : store.today() })
            }
        }

        Column {
            id: content
            width: parent.width

            PageHead {
                title: qsTr("future")
                subtitle: qsTr("the next %1 months").arg(page.ahead)
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: !page.anyIncome
                wrapMode: Text.WordWrap
                text: qsTr("No salary is planned after this month, so nothing is left to compare with. Add the salary as repeating and it shows here.")
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeSmall
            }
            LinkText {
                x: Theme.horizontalPageMargin
                visible: !page.anyIncome
                text: qsTr("Recurring")
                onClicked: pageStack.push(Qt.resolvedUrl("SchedulesPage.qml"))
            }
            Item { width: 1; height: Theme.paddingMedium }

            Repeater {
                model: page.months
                BackgroundItem {
                    width: content.width
                    height: Theme.itemSizeMedium
                    highlightedColor: FiatRatioTheme.highlightWash
                    onClicked: pageStack.push(Qt.resolvedUrl("MonthPage.qml"), { "periodId": modelData.id })
                    Rectangle {
                        x: Theme.horizontalPageMargin
                        y: Theme.paddingSmall
                        height: parent.height - 2 * Theme.paddingSmall
                        width: Math.max(2, (parent.width - 2 * Theme.horizontalPageMargin) * Number(modelData.out) / page.biggest())
                        radius: Theme.paddingSmall
                        color: FiatRatioTheme.bucketColor("needs", "")
                        opacity: 0.22
                    }
                    Column {
                        x: Theme.horizontalPageMargin + Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        Label {
                            text: F.monthTitle(appLanguage, modelData.id)
                            color: FiatRatioTheme.primaryText
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Label {
                            text: qsTr("expenses %1").arg(F.plain(modelData.out))
                                  + (modelData.hasIncome ? "  ·  " + qsTr("income %1").arg(F.plain(modelData.income)) : "")
                            color: FiatRatioTheme.secondaryText
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                    Label {
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin + Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                        visible: modelData.hasIncome
                        text: F.plain(modelData.left)
                        color: Number(modelData.left) < 0 ? FiatRatioTheme.wrong : FiatRatioTheme.primaryText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("Out is what is planned plus what is already spent. A cost that is only on one day, like an invoice, is added with Plan a cost. How far ahead it plans is set in Settings.")
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }
            Item { width: 1; height: Theme.paddingLarge }
        }
        VerticalScrollDecorator { }
    }
}
