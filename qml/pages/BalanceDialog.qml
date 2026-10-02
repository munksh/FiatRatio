import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// The real balance of a savings account or a loan, when the app has drifted from
// it. The difference is saved as one row that is neither income nor spending.
Dialog {
    id: dialog

    property int accountId
    property string accountName
    property real share: 1
    property string currency: "SEK"
    property real current: 0        // my part, as the app has it now
    property bool debt: false

    readonly property real whole: F.parse(balanceField.text)
    readonly property bool shared: share > 0 && share < 1
    readonly property real mine: Math.round(whole * (share > 0 ? share : 1))
    readonly property real target: debt ? -Math.abs(mine) : mine
    readonly property real diff: target - current

    canAccept: balanceField.text.trim() !== "" && diff !== 0

    function paint() { FiatRatioTheme.applyPalette(dialog) }
    Component.onCompleted: paint()

    onAccepted: store.correctBalance(accountId, whole)

    Rectangle {
        anchors.fill: parent
        visible: !FiatRatioTheme.ambient
        gradient: Gradient {
            GradientStop { position: 0.0; color: FiatRatioTheme.backgroundHigh }
            GradientStop { position: 1.0; color: FiatRatioTheme.backgroundLow }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.paddingSmall

        DialogHead { dialog: dialog; title: dialog.accountName }
        TextField {
            id: balanceField
            width: parent.width
            focus: true
            label: dialog.shared ? qsTr("Total") : (dialog.debt ? qsTr("Owed today") : qsTr("Balance today"))
            placeholderText: label
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            description: dialog.shared
                         ? qsTr("Your part (%1): %2").arg(F.percent(dialog.share)).arg(F.money(Math.round(dialog.target), dialog.currency))
                         : ""
        }
        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.WordWrap
            color: FiatRatioTheme.secondaryText
            font.pixelSize: Theme.fontSizeExtraSmall
            text: balanceField.text.trim() === ""
                  ? qsTr("Write what the account really holds. The app saves the difference as a balance correction.")
                  : (dialog.diff === 0
                     ? qsTr("Already right. Nothing to correct.")
                     : qsTr("Difference: %1. Saved as a balance correction. It does not count as income or saving.")
                       .arg((dialog.diff > 0 ? "+" : "") + F.money(Math.round(dialog.diff), dialog.currency)))
        }
    }
}
