import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// Pay over the years: what came in per month, as an average for each year,
// and how that moved from one year to the next.
Page {
    id: page

    readonly property string currency: { store.revision; return store.setting("base_currency", "SEK") }
    readonly property var h: { store.revision; return store.incomeHistory() }
    readonly property var years: h.years || []
    readonly property var months: h.months || []

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()
    Connections { target: FiatRatioTheme; onAmbientChanged: page.paint() }

    function biggest() {
        var m = 1
        for (var i = 0; i < years.length; ++i) m = Math.max(m, Number(years[i].avg))
        return m
    }
    function changeText(y) {
        if (y.change === null || y.change === undefined) return ""
        var c = Math.round(Number(y.change) * 10) / 10
        return (c > 0 ? "+" : "") + String(c).replace(".", appLanguage === "en" ? "." : ",") + " %"
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

        Column {
            id: content
            width: parent.width

            PageHead {
                title: qsTr("income")
                subtitle: qsTr("salary per month, by year")
            }

            Repeater {
                model: page.years
                BackgroundItem {
                    width: content.width
                    height: Theme.itemSizeMedium
                    enabled: false
                    Rectangle {
                        x: Theme.horizontalPageMargin
                        y: Theme.paddingSmall
                        height: parent.height - 2 * Theme.paddingSmall
                        width: Math.max(2, (parent.width - 2 * Theme.horizontalPageMargin) * 0.7 * Number(modelData.avg) / page.biggest())
                        radius: Theme.paddingSmall
                        color: FiatRatioTheme.bucketColor("savings", "")
                        opacity: 0.22
                    }
                    Column {
                        x: Theme.horizontalPageMargin + Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        Label {
                            text: modelData.year
                            color: FiatRatioTheme.primaryText
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Label {
                            text: modelData.partial ? qsTr("%1 months so far").arg(modelData.months) : qsTr("%1 months").arg(modelData.months)
                            color: FiatRatioTheme.secondaryText
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                    Column {
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin + Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                        Label {
                            anchors.right: parent.right
                            text: F.plain(modelData.avg)
                            color: FiatRatioTheme.primaryText
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Label {
                            anchors.right: parent.right
                            text: page.changeText(modelData)
                            color: modelData.change !== null && Number(modelData.change) < 0 ? FiatRatioTheme.nearly : FiatRatioTheme.secondaryText
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("The average is salary per month that had a salary, in %1. Bonuses and back pay paid as salary lift a year.").arg(page.currency)
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            SectionLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                visible: page.months.length > 1
                text: qsTr("Month by month")
            }
            LineChart {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.months.length > 1
                points: page.months
                valueKey: "salary"
            }

            SectionLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                visible: page.years.length > 0
                text: qsTr("Other income, whole year")
            }
            Repeater {
                model: page.years
                MoneyRow {
                    label: modelData.year
                    value: F.plain(modelData.other)
                }
            }

            EmptyNote {
                visible: page.years.length === 0
                text: qsTr("No salary yet. Add it as salary and it shows here.")
            }
            Item { width: 1; height: Theme.paddingLarge }
        }
        VerticalScrollDecorator { }
    }
}
