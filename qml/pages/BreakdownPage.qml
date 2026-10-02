import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// Open a bucket or a category and see what it is made of: each part with its
// amount and share, and which bucket it counts as. Parts that have parts of
// their own open further; the last step is the rows.
Page {
    id: page

    property string kind: "category"     // "bucket", "category" or "debt"
    property string ref: ""
    property string label: ""
    property string fromPeriod: ""
    property string toPeriod: ""
    property string bucketKey: ""        // narrow a category to what counts as this bucket

    readonly property string currency: { store.revision; return store.setting("base_currency", "SEK") }
    readonly property var bd: { store.revision; return store.breakdown(kind, ref, fromPeriod, toPeriod, bucketKey) }
    readonly property var parts: bd.parts || []
    readonly property real total: Number(bd.total || 0)
    readonly property var bucketList: { store.revision; return store.buckets() }
    readonly property var split: bucketSplit()

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()
    Connections { target: FiatRatioTheme; onAmbientChanged: page.paint() }

    function bucketLabel(key) {
        for (var i = 0; i < bucketList.length; ++i)
            if (bucketList[i].key === key) return bucketList[i].label
        return key === "uncategorised" ? qsTr("Not sorted") : key
    }
    // What the whole counts as, bucket by bucket, biggest first.
    function bucketSplit() {
        var sum = {}
        for (var i = 0; i < parts.length; ++i) {
            var bk = parts[i].buckets || {}
            if (parts[i].kind === "account") {
                var k = parts[i].bucket
                sum[k] = (sum[k] || 0) + Number(parts[i].amount)
            } else {
                for (var key in bk) sum[key] = (sum[key] || 0) + Number(bk[key])
            }
        }
        var out = []
        for (var s in sum) out.push({ key: s, amount: sum[s], label: bucketLabel(s) })
        out.sort(function(a, b) { return b.amount - a.amount })
        return out
    }
    function share(x) {
        return total > 0 ? Math.round(100 * Number(x) / total) + " %" : "–"
    }
    function biggest() {
        return parts.length > 0 ? Math.max(1, Number(parts[0].amount)) : 1
    }
    function subText(p) {
        if (p.kind === "account") return p.sub === "paying off" ? qsTr("paying off") : qsTr("moved to savings")
        var bk = p.buckets || {}
        var list = []
        for (var k in bk) list.push({ key: k, v: Number(bk[k]) })
        list.sort(function(a, b) { return b.v - a.v })
        var names = []
        for (var i = 0; i < list.length; ++i) names.push(bucketLabel(list[i].key))
        if (kind === "bucket" || names.length === 0) return qsTr("%1 rows").arg(p.n)
        return names.join(" · ") + "  ·  " + qsTr("%1 rows").arg(p.n)
    }
    function open(p) {
        if (p.kind === "account") {
            pageStack.push(Qt.resolvedUrl("AccountPage.qml"), { "accountId": p.id })
        } else if (p.own) {
            pageStack.push(Qt.resolvedUrl("CategoryTxnsPage.qml"), {
                "categoryId": p.id, "label": p.label, "fromPeriod": fromPeriod, "toPeriod": toPeriod, "directOnly": true })
        } else if (p.hasChildren) {
            pageStack.push(Qt.resolvedUrl("BreakdownPage.qml"), {
                "kind": "category", "ref": String(p.id), "label": p.label, "fromPeriod": fromPeriod, "toPeriod": toPeriod,
                "bucketKey": kind === "bucket" ? ref : bucketKey })
        } else {
            pageStack.push(Qt.resolvedUrl("CategoryTxnsPage.qml"), {
                "categoryId": p.id, "label": p.label, "fromPeriod": fromPeriod, "toPeriod": toPeriod })
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

    Component {
        id: partRow
        BackgroundItem {
            id: row
            property var p
            width: content.width
            height: Theme.itemSizeMedium
            highlightedColor: FiatRatioTheme.highlightWash
            onClicked: page.open(p)
            Rectangle {
                x: Theme.horizontalPageMargin
                y: Theme.paddingSmall
                height: parent.height - 2 * Theme.paddingSmall
                width: Math.max(2, (parent.width - 2 * Theme.horizontalPageMargin) * Number(row.p.amount) / page.biggest())
                radius: Theme.paddingSmall
                color: FiatRatioTheme.bucketColor(row.p.bucket || "uncategorised", "")
                opacity: 0.22
            }
            Column {
                anchors {
                    left: parent.left; leftMargin: Theme.horizontalPageMargin + Theme.paddingMedium
                    right: amountLabel.left; rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                Label {
                    width: parent.width
                    text: row.p.own ? qsTr("Directly in %1").arg(page.bd.title) : row.p.label
                    truncationMode: TruncationMode.Fade
                    color: FiatRatioTheme.primaryText
                    font.pixelSize: Theme.fontSizeSmall
                }
                Label {
                    width: parent.width
                    text: page.subText(row.p)
                    truncationMode: TruncationMode.Fade
                    color: FiatRatioTheme.secondaryText
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
            }
            Label {
                id: amountLabel
                anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin + Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                text: F.plain(row.p.amount) + "  ·  " + page.share(row.p.amount)
                color: FiatRatioTheme.primaryText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge * 2

        Column {
            id: content
            width: parent.width

            PageHead {
                title: page.bd.title || page.label
                subtitle: F.money(page.total, page.currency)
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.bucketKey !== ""
                text: qsTr("Only what counts as %1").arg(page.bucketLabel(page.bucketKey))
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            // ---- what the whole counts as ----
            Item { width: 1; height: Theme.paddingMedium }
            ShareBar {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.split.length > 1
                shares: page.split
            }
            Item { width: 1; height: Theme.paddingSmall; visible: page.split.length > 1 }
            Repeater {
                model: page.split.length > 1 ? page.split : []
                BackgroundItem {
                    width: content.width
                    height: Theme.itemSizeExtraSmall
                    highlightedColor: FiatRatioTheme.highlightWash
                    enabled: page.kind === "category" && page.bucketKey === ""
                    onClicked: pageStack.push(Qt.resolvedUrl("BreakdownPage.qml"), {
                        "kind": "category", "ref": page.ref, "label": page.label, "fromPeriod": page.fromPeriod,
                        "toPeriod": page.toPeriod, "bucketKey": modelData.key })
                    MoneyRow {
                        anchors.verticalCenter: parent.verticalCenter
                        dot: FiatRatioTheme.bucketColor(modelData.key, "")
                        label: modelData.label
                        value: F.plain(modelData.amount) + "  ·  " + page.share(modelData.amount)
                    }
                }
            }

            // ---- the parts ----
            SectionLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                visible: page.parts.length > 0
                text: page.kind === "bucket" ? qsTr("What is in it") : qsTr("What it is made of")
            }
            Repeater {
                model: page.parts
                Loader {
                    width: content.width
                    sourceComponent: partRow
                    onLoaded: item.p = modelData
                }
            }
            EmptyNote {
                visible: page.parts.length === 0
                text: qsTr("Nothing in this period.")
            }

            // ---- paid off beside it, not part of the sum ----
            SectionLabel {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignRight
                height: implicitHeight + Theme.paddingLarge
                verticalAlignment: Text.AlignBottom
                visible: (page.bd.related || []).length > 0
                text: qsTr("Paid off beside it")
            }
            Repeater {
                model: page.bd.related || []
                MoneyRow {
                    label: modelData.label
                    value: F.plain(modelData.amount)
                    dot: FiatRatioTheme.bucketColor(modelData.bucket, "")
                }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: (page.bd.related || []).length > 0
                wrapMode: Text.WordWrap
                text: qsTr("The interest is in the list above. What is paid off is not an expense: it lowers the loan. Not counted in the sum.")
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            Item { width: 1; height: Theme.paddingMedium }
            LinkText {
                x: Theme.horizontalPageMargin
                visible: page.kind === "category" && page.bd.categoryId > 0
                text: qsTr("all %1 rows").arg(page.bd.rows || 0)
                onClicked: pageStack.push(Qt.resolvedUrl("CategoryTxnsPage.qml"), {
                    "categoryId": page.bd.categoryId, "label": page.bd.title,
                    "fromPeriod": page.fromPeriod, "toPeriod": page.toPeriod })
            }
            Item { width: 1; height: Theme.paddingLarge }
        }
        VerticalScrollDecorator { }
    }
}
