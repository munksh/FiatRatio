import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// The real balance of an account, when the app has drifted from it. On an account
// kept by its rows the difference is one row, neither income nor spending; on one
// kept by values it is today's value.
Dialog {
    id: dialog

    property int accountId
    property string accountName
    property real share: 1
    property string currency: "SEK"
    property real current: 0        // my part, as the app has it now
    property bool debt: false
    property bool person: false     // signed: they owe me, or I owe them
    property bool byValue: false
    property bool theyOwe: current >= 0

    readonly property real whole: F.parse(balanceField.text)
    readonly property bool shared: share > 0 && share < 1
    readonly property real mine: Math.round(whole * (share > 0 ? share : 1))
    readonly property real target: debt ? -Math.abs(mine) : (person && !theyOwe ? -Math.abs(mine) : mine)
    readonly property real diff: target - current

    canAccept: balanceField.text.trim() !== "" && diff !== 0

    function paint() { FiatRatioTheme.applyPalette(dialog) }
    Component.onCompleted: paint()

    onAccepted: store.correctBalance(accountId, person && !theyOwe ? -Math.abs(whole) : whole)

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
            label: dialog.shared ? qsTr("Total") : (dialog.debt ? qsTr("Owed today") : dialog.byValue ? qsTr("Worth today") : qsTr("Balance today"))
            placeholderText: label
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            description: dialog.shared
                         ? qsTr("Your part (%1): %2").arg(F.percent(dialog.share)).arg(F.money(Math.round(dialog.target), dialog.currency))
                         : ""
        }
        WordChoice {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            visible: dialog.person
            choices: [ { label: qsTr("they owe me"), value: true }, { label: qsTr("I owe them"), value: false } ]
            current: dialog.theyOwe
            onChosen: dialog.theyOwe = value
        }
        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.WordWrap
            color: FiatRatioTheme.secondaryText
            font.pixelSize: Theme.fontSizeExtraSmall
            readonly property string difference: (dialog.diff > 0 ? "+" : "") + F.money(Math.round(dialog.diff), dialog.currency)
            text: balanceField.text.trim() === ""
                  ? (dialog.byValue ? qsTr("Write what it is worth today.")
                                    : qsTr("Write what the account really holds. The app saves the difference as a balance correction."))
                  : (dialog.diff === 0
                     ? qsTr("Already right. Nothing to correct.")
                     : dialog.byValue ? qsTr("Difference: %1. Saved as today's value.").arg(difference)
                                      : qsTr("Difference: %1. Saved as a balance correction. It does not count as income or saving.").arg(difference))
        }
    }
}
