import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

Page {
    id: page

    property string periodId: store.currentPeriod()
    property bool coachPushed: false

    readonly property string currency: { store.revision; return store.setting("base_currency", "SEK") }
    readonly property var info: { store.revision; return store.periodInfo(periodId) }
    readonly property var sum: { store.revision; return store.summary(periodId) }
    readonly property var bucketList: { store.revision; return store.buckets() }
    readonly property var planned: { store.revision; return store.plannedItems(periodId) }
    readonly property var soon: { store.revision; return store.upcoming(periodId) }
    readonly property var latest: { store.revision; return store.transactions(periodId, false, 5) }
    readonly property int count: { store.revision; return store.transactionCount(periodId) }
    readonly property var worth: { store.revision; return store.netWorth() }
    readonly property int repeating: { store.revision; return store.schedules().length }
    readonly property int unsorted: { store.revision; return store.unsortedCount(periodId) }
    property bool hintGone: store.setting("hint_pulldown", "") === "done"

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()
    Connections { target: FiatRatioTheme; onAmbientChanged: page.paint() }

    function figureColor() {
        if (sum.left < 0) return FiatRatioTheme.wrong
        if (sum.income > 0 && sum.left < sum.income * 0.1) return FiatRatioTheme.nearly
        return FiatRatioTheme.accent
    }
    function openPlanned(item) {
        pageStack.push(Qt.resolvedUrl("ConfirmDialog.qml"), { "txnId": item.id })
    }
    function addSomething() {
        pageStack.push(Qt.resolvedUrl("AddDialog.qml"), { "presetDate": info.current ? store.today() : info.start })
    }
    function openRow(item) {
        pageStack.push(Qt.resolvedUrl("AddDialog.qml"), { "txnId": item.id })
    }

    // ---- practice run ----
    // The month page leads; each step opens the page it talks about, and coming
    // back moves the guide on.
    readonly property var coachTexts: [
        qsTr("A made-up month. The big number is what is left until the next salary. The colours show where the money went."),
        qsTr("Rows marked ↻ are recurring. They are planned when a month opens, and you confirm them when they happen. Confirm the electricity next."),
        qsTr("Now add something. Normally you pull down and choose Add; this time we open it. Try a dinner you split: the total, and your share."),
        qsTr("All recurring items in one place, with their next date."),
        qsTr("Assets and debts, your part of them. Loans have their own heading."),
        qsTr("Trends: a month, three months or a year, each category beside what is typical for you."),
        qsTr("That's it. When you start for real, the made-up numbers are gone.")
    ]
    function coachNext() {
        var s = store.coachStep
        if (s === 0) { store.coachStep = 1; return }
        if (s >= 6) { store.endDemo(); pageStack.replaceAbove(null, Qt.resolvedUrl("SetupPage.qml")); return }
        page.coachPushed = true
        if (s === 1) {
            var target = null
            for (var i = 0; i < planned.length; ++i)
                if (planned[i].repeats) { target = planned[i]; break }
            if (target) openPlanned(target)
            else { page.coachPushed = false; store.coachStep = 2 }
        } else if (s === 2) {
            pageStack.push(Qt.resolvedUrl("AddDialog.qml"))
        } else if (s === 3) {
            pageStack.push(Qt.resolvedUrl("SchedulesPage.qml"))
        } else if (s === 4) {
            pageStack.push(Qt.resolvedUrl("AssetsPage.qml"))
        } else if (s === 5) {
            pageStack.push(Qt.resolvedUrl("AnalysisPage.qml"))
        }
    }
    onStatusChanged: {
        if (status === PageStatus.Active && coachPushed) {
            coachPushed = false
            if (store.demo && store.coachStep < 6)
                store.coachStep = store.coachStep + 1
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

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        PullDownMenu {
            highlightColor: FiatRatioTheme.chromeAccent

            MenuItem {
                text: qsTr("About")
                color: FiatRatioTheme.primaryText
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: FiatRatioTheme.ambient ? qsTr("Fiat colours") : qsTr("Follow ambience")
                color: FiatRatioTheme.primaryText
                onClicked: FiatRatioTheme.setAmbient(!FiatRatioTheme.ambient)
            }
            MenuItem {
                text: qsTr("Settings")
                color: FiatRatioTheme.primaryText
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Data")
                color: FiatRatioTheme.primaryText
                onClicked: pageStack.push(Qt.resolvedUrl("ExportImportPage.qml"))
            }
            // Last, so it is the one nearest the thumb.
            MenuItem {
                text: qsTr("Add")
                color: FiatRatioTheme.primaryText
                onClicked: page.addSomething()
            }
        }

        Column {
            id: content
            width: parent.width

            // ---- wordmark and month ----
            Item {
                width: parent.width
                height: FiatRatioTheme.statusRowCenter + wordmark.height / 2 + Theme.paddingMedium
                Text {
                    id: wordmark
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.top: parent.top
                    anchors.topMargin: Math.max(0, FiatRatioTheme.statusRowCenter - height / 2)
                    text: "fiat ratio"
                    color: FiatRatioTheme.primaryText
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: FiatRatioTheme.serif
                    font.italic: true
                }
                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: wordmark.verticalCenter
                    visible: store.demo
                    text: qsTr("practice run")
                    color: FiatRatioTheme.accent
                    font.pixelSize: Theme.fontSizeExtraSmall
                    font.italic: true
                    font.family: FiatRatioTheme.serif
                }
            }

            Item {
                width: parent.width
                height: Theme.itemSizeMedium
                LinkText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin - Theme.paddingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹"
                    underline: false
                    fontSize: Theme.fontSizeLarge
                    onClicked: page.periodId = store.shiftPeriod(page.periodId, -1)
                }
                Column {
                    anchors.centerIn: parent
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: F.monthTitle(appLanguage, page.periodId)
                        color: FiatRatioTheme.primaryText
                        font.pixelSize: Theme.fontSizeLarge
                        font.family: FiatRatioTheme.serif
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: page.info.current
                              ? qsTr("day %1 of %2 · %3 days left").arg(page.info.day).arg(page.info.days).arg(page.info.daysLeft)
                              : F.dayMonth(appLanguage, page.info.start) + " – " + F.dayMonth(appLanguage, page.info.end)
                        color: FiatRatioTheme.secondaryText
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
                LinkText {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin - Theme.paddingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    underline: false
                    fontSize: Theme.fontSizeLarge
                    horizontalAlignment: Text.AlignRight
                    onClicked: page.periodId = store.shiftPeriod(page.periodId, 1)
                }
            }
            LinkText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !page.info.current
                text: qsTr("back to this month")
                horizontalAlignment: Text.AlignHCenter
                onClicked: page.periodId = store.currentPeriod()
            }

            // ---- the first-time tip, below the status row and the notch ----
            Item { width: 1; height: Theme.paddingMedium; visible: tip.visible }
            CoachMark {
                id: tip
                visible: !store.demo && !page.hintGone && page.count === 0 && page.info.current
                label: qsTr("tip")
                showEnd: false
                text: visible ? qsTr("Pull down and choose Add to put in an expense or income. The menu also holds settings and data.") : ""
                nextText: qsTr("got it")
                onNext: { page.hintGone = true; store.setSetting("hint_pulldown", "done") }
            }
            Item { width: 1; height: Theme.paddingMedium; visible: tip.visible }

            // ---- figure ----
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: F.money(page.sum.left, page.currency)
                color: page.figureColor()
                font.pixelSize: Theme.fontSizeHuge
                font.family: FiatRatioTheme.serif
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: page.sum.income > 0 ? qsTr("left of %1").arg(F.money(page.sum.income, page.currency))
                                          : qsTr("left · no income yet this month")
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeSmall
            }
            Item { width: 1; height: Theme.paddingLarge }

            BucketBar {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                buckets: page.bucketList
                spent: page.sum.spent
                planned: page.sum.planned
                income: page.sum.income
            }
            Item { width: 1; height: Theme.paddingMedium }
            Repeater {
                model: page.bucketList
                BackgroundItem {
                    id: bucketRow
                    readonly property real s: Number(page.sum.spent[modelData.key] || 0)
                    readonly property real p: Number(page.sum.planned[modelData.key] || 0)
                    width: content.width
                    height: visible ? Theme.itemSizeExtraSmall : 0
                    visible: s !== 0 || p !== 0
                    highlightedColor: FiatRatioTheme.highlightWash
                    onClicked: pageStack.push(Qt.resolvedUrl("BreakdownPage.qml"), {
                        "kind": "bucket", "ref": modelData.key, "label": modelData.label,
                        "fromPeriod": page.periodId, "toPeriod": page.periodId })
                    MoneyRow {
                        anchors.verticalCenter: parent.verticalCenter
                        dot: FiatRatioTheme.bucketColor(modelData.key, modelData.color)
                        label: modelData.label
                        value: (bucketRow.p > 0 ? qsTr("%1 + %2 to come").arg(F.plain(bucketRow.s)).arg(F.plain(bucketRow.p)) : F.money(bucketRow.s, page.currency)) + "  ›"
                    }
                }
            }

            BackgroundItem {
                width: content.width
                height: Theme.itemSizeSmall
                visible: page.unsorted > 0
                highlightedColor: FiatRatioTheme.highlightWash
                onClicked: pageStack.push(Qt.resolvedUrl("TransactionsPage.qml"), { "periodId": page.periodId, "unsorted": true })
                Label {
                    anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                    text: qsTr("%1 to sort").arg(page.unsorted) + "  ›"
                    color: FiatRatioTheme.accent
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            // ---- empty month ----
            Item { width: 1; height: Theme.paddingLarge; visible: page.count === 0 && page.planned.length === 0 }
            EmptyNote {
                visible: page.count === 0 && page.planned.length === 0
                text: qsTr("Nothing yet. Pull down and add the salary. Rent, electricity and the like are added once, as recurring.")
                font.pixelSize: Theme.fontSizeSmall
            }

            // ---- coming up ----
            SectionLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                visible: page.planned.length > 0
                text: qsTr("Coming up")
            }
            Repeater {
                model: page.planned
                TxnRow {
                    id: plannedRow
                    item: modelData
                    onClicked: page.openPlanned(modelData)
                    menu: ContextMenu {
                        MenuItem {
                            text: qsTr("paid as expected")
                            onClicked: store.setCleared(modelData.id, true)
                        }
                        MenuItem {
                            text: qsTr("skip once")
                            onClicked: plannedRow.remorseAction(qsTr("Skipping"), function() { store.deleteTransaction(modelData.id) })
                        }
                    }
                }
            }

            // ---- soon, after this month ----
            SectionLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                visible: page.soon.length > 0 && page.info.current
                text: qsTr("Big bills soon")
            }
            Repeater {
                model: page.info.current ? page.soon : []
                MoneyRow {
                    label: F.dayMonth(appLanguage, modelData.date) + "  ↻ " + modelData.description
                    value: F.plain(modelData.amount)
                    valueColor: FiatRatioTheme.secondaryText
                }
            }

            // ---- so far ----
            SectionLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                visible: page.latest.length > 0
                text: qsTr("So far")
            }
            Repeater {
                model: page.latest
                TxnRow {
                    item: modelData
                    onClicked: page.openRow(modelData)
                }
            }
            LinkText {
                x: Theme.horizontalPageMargin
                visible: page.count > page.latest.length
                text: qsTr("all %1 this month").arg(page.count)
                onClicked: pageStack.push(Qt.resolvedUrl("TransactionsPage.qml"), { "periodId": page.periodId })
            }

            // ---- the other places ----
            Item { width: 1; height: Theme.paddingLarge }
            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: 1
                color: FiatRatioTheme.innerBorder
            }
            Repeater {
                model: [
                    { "text": qsTr("Trends"), "value": "", "page": "AnalysisPage.qml" },
                    { "text": qsTr("Recurring"), "value": String(page.repeating), "page": "SchedulesPage.qml" },
                    { "text": qsTr("Future"), "value": "", "page": "ForecastPage.qml" },
                    { "text": qsTr("Net worth"), "value": F.money(page.worth.net || 0, page.currency), "page": "AssetsPage.qml" }
                ]
                BackgroundItem {
                    width: content.width
                    height: Theme.itemSizeSmall
                    highlightedColor: FiatRatioTheme.highlightWash
                    onClicked: pageStack.push(Qt.resolvedUrl(modelData.page), { "periodId": page.periodId })
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.right: linkValue.left
                        anchors.rightMargin: Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text
                        truncationMode: TruncationMode.Fade
                        color: FiatRatioTheme.primaryText
                        font.pixelSize: Theme.fontSizeMedium
                        font.family: FiatRatioTheme.serif
                    }
                    Label {
                        id: linkValue
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.value + "  ›"
                        color: FiatRatioTheme.secondaryText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }
            CoachMark {
                visible: store.demo && store.coachStep >= 0 && store.coachStep <= 6
                text: visible ? page.coachTexts[store.coachStep] : ""
                nextText: store.coachStep === 0 ? qsTr("next") : store.coachStep === 6 ? qsTr("start for real") : qsTr("show me")
                onNext: page.coachNext()
                onEnd: { store.endDemo(); pageStack.replaceAbove(null, Qt.resolvedUrl("SetupPage.qml")) }
            }
        }
        VerticalScrollDecorator { }
    }
}
