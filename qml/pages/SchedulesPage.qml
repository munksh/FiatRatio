import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// Everything that comes back. Switched on, it is written into each month as
// planned rows; switched off, it waits here.
Page {
    id: page

    property string periodId: ""
    property bool coachHidden: false
    readonly property var all: { store.revision; return store.schedules() }
    readonly property string currency: { store.revision; return store.setting("base_currency", "SEK") }

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()
    Connections { target: FiatRatioTheme; onAmbientChanged: page.paint() }

    function group(freq, active) {
        var out = []
        for (var i = 0; i < all.length; ++i) {
            var s = all[i]
            if ((Number(s.active) === 1) !== active) continue
            if (freq !== "" && s.freq !== freq) continue
            out.push(s)
        }
        return out
    }
    function perMonth() {
        var sum = 0
        for (var i = 0; i < all.length; ++i) {
            var s = all[i]
            if (Number(s.active) !== 1 || s.kind === "income") continue
            var a = Number(s.amount)
            sum += s.freq === "monthly" ? a : s.freq === "quarterly" ? a / 3 : s.freq === "yearly" ? a / 12 : a * 52 / 12
        }
        return sum
    }
    function when(s) {
        if (s.freq === "monthly") return qsTr("on the %1").arg(s.day)
        if (s.freq === "quarterly") return qsTr("quarterly from %1").arg(F.shortMonth(appLanguage, Number(s.month) || 1))
        if (s.freq === "yearly") return Number(s.day) + " " + F.shortMonth(appLanguage, Number(s.month) || 1)
        return qsTr("every week")
    }
    function subLine(s) {
        var parts = [when(s)]
        if (s.kind === "transfer") parts.push("→ " + (s.to_kind === "pot" ? qsTr("the month's money") : s.to_name))
        else if (s.category) parts.push(s.category)
        if (s.end_date) parts.push(qsTr("until %1").arg(F.dayMonthYear(appLanguage, s.end_date)))
        else if (Number(s.active) === 1 && s.next) parts.push(qsTr("next %1").arg(F.dayMonth(appLanguage, s.next)))
        return parts.join(" · ")
    }

    Rectangle {
        anchors.fill: parent
        visible: !FiatRatioTheme.ambient
        gradient: Gradient {
            GradientStop { position: 0.0; color: FiatRatioTheme.backgroundHigh }
            GradientStop { position: 1.0; color: FiatRatioTheme.backgroundLow }
        }
    }

    Component {
        id: rowComponent
        ListItem {
            id: row
            property var s
            contentHeight: Math.max(Theme.itemSizeMedium, col.height + 2 * Theme.paddingSmall)
            onClicked: pageStack.push(Qt.resolvedUrl("ScheduleDialog.qml"), { "scheduleId": row.s.id })
            menu: ContextMenu {
                MenuItem {
                    text: Number(row.s.active) === 1 ? qsTr("pause") : qsTr("resume")
                    onClicked: store.setScheduleActive(row.s.id, Number(row.s.active) !== 1)
                }
                MenuItem {
                    text: qsTr("delete")
                    onClicked: row.remorseDelete(function() { store.deleteSchedule(row.s.id) })
                }
            }
            Column {
                id: col
                anchors {
                    left: parent.left; leftMargin: Theme.horizontalPageMargin
                    right: amountLabel.left; rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                Label {
                    width: parent.width
                    text: row.s ? row.s.name : ""
                    truncationMode: TruncationMode.Fade
                    color: row.highlighted ? FiatRatioTheme.accent : FiatRatioTheme.primaryText
                    opacity: row.s && Number(row.s.active) === 1 ? 1.0 : 0.6
                    font.pixelSize: Theme.fontSizeSmall
                }
                Label {
                    width: parent.width
                    text: row.s ? page.subLine(row.s) : ""
                    truncationMode: TruncationMode.Fade
                    color: FiatRatioTheme.secondaryText
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
            }
            Label {
                id: amountLabel
                anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                text: row.s ? (row.s.kind === "income" ? "+" : "") + F.plain(row.s.amount) : ""
                color: FiatRatioTheme.primaryText
                opacity: row.s && Number(row.s.active) === 1 ? 1.0 : 0.6
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        PullDownMenu {
            highlightColor: FiatRatioTheme.chromeAccent
            MenuItem {
                text: qsTr("Future")
                color: FiatRatioTheme.primaryText
                onClicked: pageStack.push(Qt.resolvedUrl("ForecastPage.qml"))
            }
            // Last, nearest the thumb.
            MenuItem {
                text: qsTr("Add recurring")
                color: FiatRatioTheme.primaryText
                onClicked: pageStack.push(Qt.resolvedUrl("ScheduleDialog.qml"))
            }
        }

        Column {
            id: content
            width: parent.width

            PageHead {
                title: qsTr("recurring")
                subtitle: qsTr("about %1 a month").arg(F.money(page.perMonth(), page.currency))
            }

            Repeater {
                model: [
                    { "title": qsTr("Every month"), "freq": "monthly", "active": true },
                    { "title": qsTr("Every quarter"), "freq": "quarterly", "active": true },
                    { "title": qsTr("Every year"), "freq": "yearly", "active": true },
                    { "title": qsTr("Every week"), "freq": "weekly", "active": true },
                    { "title": qsTr("Paused"), "freq": "", "active": false }
                ]
                Column {
                    width: content.width
                    readonly property var members: page.group(modelData.freq, modelData.active)
                    visible: members.length > 0
                    SectionLabel {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                        text: modelData.title
                    }
                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        visible: !modelData.active
                        wrapMode: Text.WordWrap
                        text: qsTr("Tap and hold to resume one. It is then planned for the coming months.")
                        color: FiatRatioTheme.secondaryText
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                    Repeater {
                        model: parent.members
                        Loader {
                            width: content.width
                            sourceComponent: rowComponent
                            onLoaded: item.s = modelData
                        }
                    }
                }
            }

            EmptyNote {
                visible: page.all.length === 0
                text: qsTr("Nothing recurring yet. Rent, insurance, a yearly fee: add it once.")
            }

            Item { width: 1; height: Theme.paddingLarge }
            CoachMark {
                visible: store.demo && store.coachStep === 3 && !page.coachHidden
                text: visible ? qsTr("Tap a row to change the amount or set an end. Quarterly and yearly ones are planned a year ahead.") : ""
                nextText: qsTr("got it")
                onNext: page.coachHidden = true
                onEnd: page.coachHidden = true
            }
        }
        VerticalScrollDecorator { }
    }
}
