import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// Looking back: where the money came from and where it went, each category
// beside what is usual for you.
Page {
    id: page

    property string periodId: store.currentPeriod()
    property string range: "last"
    property string picked: ""
    property bool coachHidden: false

    readonly property string currency: { store.revision; return store.setting("base_currency", "SEK") }
    readonly property string current: { store.revision; return store.currentPeriod() }
    readonly property var span: {
        if (picked !== "") return [picked, picked]
        if (range === "this") return [current, current]
        if (range === "three") return [store.shiftPeriod(current, -3), store.shiftPeriod(current, -1)]
        if (range === "year") return [current.substring(0, 4) + "-01", current]
        if (range === "twelve") return [store.shiftPeriod(current, -12), store.shiftPeriod(current, -1)]
        return [store.shiftPeriod(current, -1), store.shiftPeriod(current, -1)]
    }
    readonly property var a: { store.revision; return store.analysis(span[0], span[1]) }
    readonly property var bucketList: { store.revision; return store.buckets() }
    readonly property var months: { store.revision; return store.history(12) }

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()
    Connections { target: FiatRatioTheme; onAmbientChanged: page.paint() }

    function spanTitle() {
        if (span[0] === span[1]) return F.monthTitle(appLanguage, span[0])
        return F.shortMonth(appLanguage, Number(span[0].substring(5, 7))) + " " + span[0].substring(0, 4)
             + " – " + F.shortMonth(appLanguage, Number(span[1].substring(5, 7))) + " " + span[1].substring(0, 4)
    }
    function percentOf(x, of) {
        return of > 0 ? Math.round(100 * x / of) + " %" : "–"
    }
    function biggest() {
        var c = a.categories || []
        return c.length > 0 ? Number(c[0].amount) : 1
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
            spacing: Theme.paddingSmall

            PageHead {
                title: qsTr("trends")
                subtitle: page.spanTitle()
            }

            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                choices: [
                    { label: qsTr("this month"), value: "this" },
                    { label: qsTr("last month"), value: "last" },
                    { label: qsTr("3 months"), value: "three" },
                    { label: qsTr("this year"), value: "year" },
                    { label: qsTr("12 months"), value: "twelve" }
                ]
                current: page.picked === "" ? page.range : ""
                onChosen: { page.picked = ""; page.range = value }
            }

            // ---- the totals ----
            Item { width: 1; height: Theme.paddingMedium }
            MoneyRow { label: qsTr("Income"); value: F.money(page.a.income || 0, page.currency); strong: true }
            MoneyRow { label: qsTr("Expenses"); value: F.money((page.a.total || 0) - (page.a.saved || 0), page.currency); strong: true }
            MoneyRow {
                label: qsTr("Saved")
                value: F.money(page.a.saved || 0, page.currency) + "  ·  " + page.percentOf(page.a.saved || 0, page.a.income || 0)
                strong: true
            }
            MoneyRow {
                label: qsTr("Left")
                value: F.money((page.a.income || 0) - (page.a.total || 0), page.currency)
                valueColor: (page.a.income || 0) - (page.a.total || 0) < 0 ? FiatRatioTheme.wrong : FiatRatioTheme.primaryText
                strong: true
            }

            // ---- what it counts as ----
            Item { width: 1; height: Theme.paddingLarge }
            BucketBar {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                buckets: page.bucketList
                spent: page.a.buckets || ({})
                planned: ({})
                income: page.a.income || 0
            }
            Item { width: 1; height: Theme.paddingSmall }
            Repeater {
                model: page.bucketList
                BackgroundItem {
                    id: bucketRow
                    readonly property real v: Number((page.a.buckets || {})[modelData.key] || 0)
                    width: content.width
                    height: visible ? Theme.itemSizeExtraSmall : 0
                    visible: v !== 0
                    highlightedColor: FiatRatioTheme.highlightWash
                    onClicked: pageStack.push(Qt.resolvedUrl("BreakdownPage.qml"), {
                        "kind": "bucket", "ref": modelData.key, "label": modelData.label,
                        "fromPeriod": page.span[0], "toPeriod": page.span[1] })
                    MoneyRow {
                        anchors.verticalCenter: parent.verticalCenter
                        dot: FiatRatioTheme.bucketColor(modelData.key, modelData.color)
                        label: modelData.label
                        value: F.plain(bucketRow.v) + "  ·  " + page.percentOf(bucketRow.v, page.a.income || 0) + "  ›"
                    }
                }
            }
            BackgroundItem {
                width: content.width
                height: visible ? Theme.itemSizeSmall : 0
                visible: Number(page.a.repaid || 0) > 0
                highlightedColor: FiatRatioTheme.highlightWash
                onClicked: pageStack.push(Qt.resolvedUrl("BreakdownPage.qml"), {
                    "kind": "debt", "ref": "", "label": qsTr("Paying off loans"),
                    "fromPeriod": page.span[0], "toPeriod": page.span[1] })
                Column {
                    anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin; right: repaidValue.left; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                    Label {
                        width: parent.width
                        text: qsTr("Paying off loans")
                        truncationMode: TruncationMode.Fade
                        color: FiatRatioTheme.primaryText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Label {
                        width: parent.width
                        text: qsTr("Part of Needs")
                        truncationMode: TruncationMode.Fade
                        color: FiatRatioTheme.secondaryText
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
                Label {
                    id: repaidValue
                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                    text: F.plain(page.a.repaid || 0) + "  ›"
                    color: FiatRatioTheme.primaryText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            // ---- categories ----
            SectionLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                visible: (page.a.categories || []).length > 0
                text: page.a.hasBaseline ? qsTr("Categories, against typical") : qsTr("Categories")
            }
            Repeater {
                model: page.a.categories || []
                BackgroundItem {
                    width: content.width
                    height: Theme.itemSizeMedium
                    highlightedColor: FiatRatioTheme.highlightWash
                    readonly property real amount: Number(modelData.amount)
                    readonly property real usual: Number(modelData.usual)
                    readonly property bool above: page.a.hasBaseline && usual > 0 && amount > usual * 1.2
                    onClicked: pageStack.push(Qt.resolvedUrl("BreakdownPage.qml"), {
                        "kind": "category", "ref": String(modelData.id), "label": modelData.label,
                        "fromPeriod": page.span[0], "toPeriod": page.span[1] })
                    Rectangle {
                        x: Theme.horizontalPageMargin
                        y: Theme.paddingSmall
                        height: parent.height - 2 * Theme.paddingSmall
                        width: Math.max(2, (parent.width - 2 * Theme.horizontalPageMargin) * parent.amount / page.biggest())
                        radius: Theme.paddingSmall
                        color: FiatRatioTheme.bucketColor(modelData.bucket || "uncategorised", "")
                        opacity: 0.22
                    }
                    Column {
                        x: Theme.horizontalPageMargin + Theme.paddingMedium
                        width: parent.width * 0.55
                        anchors.verticalCenter: parent.verticalCenter
                        Label {
                            width: parent.width
                            text: modelData.label
                            truncationMode: TruncationMode.Fade
                            color: FiatRatioTheme.primaryText
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Label {
                            visible: page.a.hasBaseline && usual > 0
                            text: qsTr("typical %1").arg(F.plain(usual))
                            color: FiatRatioTheme.secondaryText
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                    Label {
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin + Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                        text: F.plain(amount)
                        color: above ? FiatRatioTheme.nearly : FiatRatioTheme.primaryText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // ---- places ----
            SectionLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                visible: (page.a.places || []).length > 0
                text: qsTr("Where")
            }
            Repeater {
                model: page.a.places || []
                MoneyRow {
                    label: modelData.name + (Number(modelData.n) > 1 ? "  ×" + modelData.n : "")
                    value: F.plain(modelData.amount)
                }
            }

            // ---- shared ----
            SectionLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                visible: page.a.shared && Number(page.a.shared.n) > 0
                text: qsTr("Split")
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.a.shared && Number(page.a.shared.n) > 0
                wrapMode: Text.WordWrap
                text: page.a.shared ? qsTr("%1 split costs came to %2. Your part was %3.")
                                      .arg(page.a.shared.n).arg(F.money(page.a.shared.whole, page.currency))
                                      .arg(F.money(page.a.shared.mine, page.currency)) : ""
                color: FiatRatioTheme.primaryText
                font.pixelSize: Theme.fontSizeSmall
            }

            // ---- month by month ----
            SectionLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                text: qsTr("Month by month")
            }
            StackedBars {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                months: page.months
                buckets: page.bucketList
                selected: page.span[0] === page.span[1] ? page.span[0] : ""
                onPicked: page.picked = periodId
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("Bars are expenses by type. The line is income. Tap a month to open it.")
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            Item { width: 1; height: Theme.paddingLarge }
            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: 1
                color: FiatRatioTheme.innerBorder
            }
            Repeater {
                model: [
                    { "text": qsTr("Income"), "page": "IncomePage.qml" },
                    { "text": qsTr("Future"), "page": "ForecastPage.qml" }
                ]
                BackgroundItem {
                    width: content.width
                    height: Theme.itemSizeSmall
                    highlightedColor: FiatRatioTheme.highlightWash
                    onClicked: pageStack.push(Qt.resolvedUrl(modelData.page))
                    Label {
                        anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                        text: modelData.text
                        color: FiatRatioTheme.primaryText
                        font.pixelSize: Theme.fontSizeMedium
                        font.family: FiatRatioTheme.serif
                    }
                    Label {
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                        text: "›"
                        color: FiatRatioTheme.secondaryText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }
            Item { width: 1; height: Theme.paddingLarge }
            CoachMark {
                visible: store.demo && store.coachStep === 5 && !page.coachHidden
                text: visible ? qsTr("A made-up month has little history, so there is little typical to compare with. Your own months fill it in.") : ""
                nextText: qsTr("got it")
                onNext: page.coachHidden = true
                onEnd: page.coachHidden = true
            }
        }
        VerticalScrollDecorator { }
    }
}
