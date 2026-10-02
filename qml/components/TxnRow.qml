import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../js/format.js" as F

// One row of money: date, what it was, and the amount. A row that comes back
// carries ↻; a planned one is in italics until it has happened.
ListItem {
    id: row

    property var item: ({})
    property bool showDate: true
    readonly property bool planned: item.status === "planned"
    readonly property bool isMove: item.isMove === true
    readonly property real amount: Number(item.amount || 0)
    readonly property bool repeats: item.repeats === true

    contentHeight: Math.max(Theme.itemSizeMedium, textCol.height + 2 * Theme.paddingSmall)

    function otherName() {
        return item.other_kind === "pot" ? qsTr("the month's money") : item.other
    }
    function subLine() {
        var parts = []
        if (isMove) parts.push(amount < 0 ? "→ " + otherName() : qsTr("from %1").arg(otherName()))
        else if (item.category) parts.push(item.category)
        if (item.person) parts.push(qsTr("with %1").arg(item.person))
        else if (item.shared === true) parts.push(qsTr("split"))
        if (item.method) parts.push(item.method)
        if (item.context) parts.push(item.context)
        if (Number(item.is_salary) === 1) parts.push(qsTr("salary"))
        return parts.join(" · ")
    }

    Label {
        id: dateLabel
        visible: row.showDate
        x: Theme.horizontalPageMargin
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? Theme.itemSizeMedium : 0
        text: F.dayMonth(appLanguage, row.item.date)
        color: FiatRatioTheme.secondaryText
        font.pixelSize: Theme.fontSizeExtraSmall
    }
    Column {
        id: textCol
        anchors {
            left: row.showDate ? dateLabel.right : parent.left
            leftMargin: row.showDate ? 0 : Theme.horizontalPageMargin
            right: amountCol.left; rightMargin: Theme.paddingMedium
            verticalCenter: parent.verticalCenter
        }
        Label {
            width: parent.width
            text: (row.repeats ? "↻ " : "") + (row.item.description || row.item.category || (row.isMove ? row.otherName() : "–"))
            truncationMode: TruncationMode.Fade
            color: row.highlighted ? FiatRatioTheme.accent : FiatRatioTheme.primaryText
            font.italic: row.planned
            font.pixelSize: Theme.fontSizeSmall
        }
        Label {
            width: parent.width
            visible: text !== ""
            text: row.subLine()
            truncationMode: TruncationMode.Fade
            color: FiatRatioTheme.secondaryText
            font.pixelSize: Theme.fontSizeExtraSmall
        }
    }
    Column {
        id: amountCol
        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
        Label {
            anchors.right: parent.right
            text: row.amount > 0 ? "+" + F.plain(row.amount) : F.plain(row.amount)
            color: row.planned ? FiatRatioTheme.secondaryText : FiatRatioTheme.primaryText
            font.pixelSize: Theme.fontSizeSmall
        }
        Label {
            anchors.right: parent.right
            visible: row.item.shared === true
            //: Under a shared amount, the whole price: "of 840"
            text: qsTr("of %1").arg(F.plain(Math.abs(Number(row.item.amount_full || 0))))
            color: FiatRatioTheme.secondaryText
            font.pixelSize: Theme.fontSizeTiny
        }
    }
}
