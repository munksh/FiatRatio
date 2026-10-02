import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// A loan the way a person knows it. The app writes the debt, and the
// amortisation and interest as things that come back.
Dialog {
    id: dialog

    property string group: "debt"
    property string kind: "loan"
    property bool shared: false
    property string share: "50"
    property int personId: 0
    property string where: "in"

    readonly property var people: { store.revision; return store.list("person") }
    readonly property string currency: store.setting("base_currency", "SEK")
    readonly property real whole: F.parse(amountField.text)
    readonly property real fraction: shared ? Number(share) / 100 : 1
    readonly property real mine: Math.round(whole * fraction)
    readonly property real rate: Number(String(rateField.text).replace(",", ".")) || 0
    readonly property real interest: Math.round(mine * rate / 100 / 12)
    readonly property real amort: Math.round(F.parse(amortField.text) * fraction)
    readonly property string name: nameField.text.trim() !== "" ? nameField.text.trim() : kindLabel(kind)

    canAccept: whole > 0

    function paint() { FiatRatioTheme.applyPalette(dialog) }
    Component.onCompleted: paint()

    function kindLabel(k) {
        if (k === "mortgage") return qsTr("mortgage")
        if (k === "credit") return qsTr("credit")
        if (k === "person") return qsTr("loan from a person")
        return qsTr("loan")
    }

    onAccepted: store.addLoan({
        "kind": kind,
        "name": name,
        "whole": whole,
        "myShare": fraction,
        "sharedWithId": shared ? personId : 0,
        "where": where,
        "rate": rate,
        "amortWhole": F.parse(amortField.text),
        "day": Number(dayField.text) || 27,
        "amortName": qsTr("Paying off %1").arg(name),
        "interestName": qsTr("Interest %1").arg(name)
    })

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

            DialogHead {
                dialog: dialog
                title: qsTr("a loan or credit")
            }

            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                choices: [
                    { label: qsTr("loan"), value: "loan" },
                    { label: qsTr("mortgage"), value: "mortgage" },
                    { label: qsTr("credit or card"), value: "credit" },
                    { label: qsTr("from a person"), value: "person" }
                ]
                current: dialog.kind
                onChosen: dialog.kind = value
            }
            TextField {
                id: nameField
                width: parent.width
                focus: true
                label: dialog.kind === "person" ? qsTr("Who") : qsTr("Lender, or a name")
                placeholderText: label
            }
            TextField {
                id: amountField
                width: parent.width
                label: dialog.shared ? qsTr("Total") : qsTr("Amount")
                placeholderText: label
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                description: dialog.shared ? qsTr("Your part of the debt: %1").arg(F.money(dialog.mine, dialog.currency)) : ""
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: dialog.kind !== "person"
                text: dialog.shared ? qsTr("joint") : qsTr("joint?")
                color: dialog.shared ? FiatRatioTheme.accent : FiatRatioTheme.secondaryText
                onClicked: dialog.shared = !dialog.shared
            }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.shared
                choices: [ { label: "50 %", value: "50" }, { label: "33 %", value: "33" }, { label: "25 %", value: "25" } ]
                current: dialog.share
                onChosen: dialog.share = value
            }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.shared
                choices: {
                    var out = []
                    for (var i = 0; i < dialog.people.length; ++i) out.push({ "label": dialog.people[i].name, "value": dialog.people[i].id })
                    return out
                }
                current: dialog.personId
                onChosen: dialog.personId = value
            }

            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Where did the money go?") }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                choices: [
                    { label: qsTr("to the month"), value: "in" },
                    { label: qsTr("to a thing"), value: "thing" },
                    { label: qsTr("existing"), value: "old" }
                ]
                current: dialog.where
                onChosen: dialog.where = value
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
                text: dialog.where === "in"
                      ? qsTr("Added to this month, not income. The debt is under Loans.")
                      : dialog.where === "thing"
                        ? qsTr("Like a home or a car. Add the thing itself under Things if it is not there.")
                        : qsTr("Only the debt as it stands today. No money moves.")
            }

            TextField {
                id: rateField
                width: parent.width
                label: qsTr("Interest, % a year")
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                description: qsTr("Variable? Write today's. You confirm each payment with the real amount.")
            }
            TextField {
                id: amortField
                width: parent.width
                label: dialog.shared ? qsTr("Paying off each month, total") : qsTr("Paying off each month")
                inputMethodHints: Qt.ImhFormattedNumbersOnly
            }
            TextField {
                id: dayField
                width: parent.width
                label: qsTr("Day of the month")
                text: "27"
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 1; top: 31 }
            }

            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("What this writes") }
            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: preview.height + 2 * Theme.paddingMedium
                radius: Theme.paddingMedium
                color: FiatRatioTheme.recessFill
                border.color: FiatRatioTheme.recessBorder
                border.width: 1
                Column {
                    id: preview
                    y: Theme.paddingMedium
                    width: parent.width
                    MoneyRow {
                        label: qsTr("%1, under loans and credit").arg(dialog.name)
                        value: F.money(-dialog.mine, dialog.currency)
                        valueColor: FiatRatioTheme.wrong
                    }
                    MoneyRow {
                        visible: dialog.amort > 0
                        label: qsTr("↻ paying off, your part")
                        value: F.money(dialog.amort, dialog.currency)
                    }
                    MoneyRow {
                        visible: dialog.interest > 0
                        label: qsTr("↻ interest, about")
                        value: F.money(dialog.interest, dialog.currency)
                    }
                    MoneyRow {
                        visible: dialog.where === "in" && dialog.mine > 0
                        label: qsTr("into this month, not income")
                        value: "+" + F.money(dialog.mine, dialog.currency)
                    }
                }
            }
        }
        VerticalScrollDecorator { }
    }
}
