import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// What something is worth today: a fund, a pension, the house.
Dialog {
    id: dialog

    property int accountId
    property string accountName
    property real share: 1
    property string currency: "SEK"
    property string date: store.today()

    readonly property real whole: F.parse(valueField.text)
    readonly property bool shared: share > 0 && share < 1

    canAccept: valueField.text.trim() !== ""

    function paint() { FiatRatioTheme.applyPalette(dialog) }
    Component.onCompleted: paint()

    onAccepted: store.addValuation(accountId, whole, date)

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
            id: valueField
            width: parent.width
            focus: true
            label: dialog.shared ? qsTr("Total") : qsTr("Worth today")
            placeholderText: label
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            description: dialog.shared
                         ? qsTr("Your part (%1): %2").arg(F.percent(dialog.share)).arg(F.money(Math.round(dialog.whole * dialog.share), dialog.currency))
                         : ""
        }
        SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("When") }
        WordChoice {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            choices: [
                { label: qsTr("today"), value: store.today() },
                { label: dialog.date !== store.today() ? F.dayMonthYear(appLanguage, dialog.date) : qsTr("date"), value: "pick" }
            ]
            current: dialog.date === store.today() ? dialog.date : "pick"
            onChosen: {
                if (value !== "pick") { dialog.date = value; return }
                var d = pageStack.push("Sailfish.Silica.DatePickerDialog", { "date": F.fromIso(dialog.date) })
                d.accepted.connect(function() { dialog.date = F.isoDate(d.date) })
            }
        }
    }
}
