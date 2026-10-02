import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// Savings, something you own, or money between people.
Dialog {
    id: dialog

    property string group: "saved"
    property string kind: group === "owned" ? "property" : group === "people" ? "person" : "savings"
    property bool shared: false
    property string share: "50"
    property int personId: 0
    property bool theyOwe: true

    readonly property var people: { store.revision; return store.list("person") }
    readonly property real whole: F.parse(amountField.text)
    readonly property real mine: shared ? Math.round(whole * Number(share) / 100) : whole
    readonly property string currency: store.setting("base_currency", "SEK")

    canAccept: (group === "people" ? personId > 0 : nameField.text.trim() !== "")

    function paint() { FiatRatioTheme.applyPalette(dialog) }
    Component.onCompleted: paint()

    function personName(id) {
        for (var i = 0; i < people.length; ++i)
            if (people[i].id === id) return people[i].name
        return ""
    }

    onAccepted: {
        var a = {
            "name": group === "people" ? personName(personId) : nameField.text,
            "kind": kind,
            "myShare": shared && group !== "people" ? Number(share) / 100 : 1,
            "openingWhole": group === "people" ? (theyOwe ? whole : -whole) : whole,
            "sharedWithId": shared ? personId : 0,
            "personId": group === "people" ? personId : 0
        }
        store.addAccount(a)
    }

    Kinds { id: kinds }

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
                title: dialog.group === "owned" ? qsTr("something you own") : dialog.group === "people" ? qsTr("between people") : qsTr("savings")
            }

            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.group !== "people"
                choices: {
                    var list = dialog.group === "owned" ? ["property", "vehicle", "possessions"]
                                                        : ["savings", "investment", "pension", "crypto", "deposit"]
                    var out = []
                    for (var i = 0; i < list.length; ++i) out.push({ "label": kinds.label(list[i]), "value": list[i] })
                    return out
                }
                current: dialog.kind
                onChosen: dialog.kind = value
            }

            // ---- between people ----
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.group === "people"
                choices: [ { label: qsTr("they owe me"), value: true }, { label: qsTr("I owe them"), value: false } ]
                current: dialog.theyOwe
                onChosen: dialog.theyOwe = value
            }
            SectionLabel {
                x: Theme.horizontalPageMargin
                visible: dialog.group === "people"
                text: qsTr("Who")
            }

            TextField {
                id: nameField
                width: parent.width
                visible: dialog.group !== "people"
                focus: dialog.group !== "people"
                label: qsTr("Name")
                placeholderText: dialog.group === "owned" ? qsTr("The house, the car …") : qsTr("Buffer, holiday …")
            }
            TextField {
                id: amountField
                width: parent.width
                label: dialog.group === "people" ? qsTr("Amount")
                       : kinds.valued(dialog.kind) ? (dialog.shared ? qsTr("Total") : qsTr("Worth today"))
                       : (dialog.shared ? qsTr("Total") : qsTr("Balance today"))
                placeholderText: label
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                description: dialog.shared ? qsTr("Your part: %1").arg(F.money(dialog.mine, dialog.currency)) : ""
            }

            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: dialog.group !== "people"
                text: dialog.shared ? qsTr("joint") : qsTr("joint?")
                color: dialog.shared ? FiatRatioTheme.accent : FiatRatioTheme.secondaryText
                onClicked: dialog.shared = !dialog.shared
            }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.shared && dialog.group !== "people"
                choices: [ { label: "50 %", value: "50" }, { label: "33 %", value: "33" }, { label: "25 %", value: "25" } ]
                current: dialog.share
                onChosen: dialog.share = value
            }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.group === "people" || dialog.shared
                choices: {
                    var out = []
                    for (var i = 0; i < dialog.people.length; ++i) out.push({ "label": dialog.people[i].name, "value": dialog.people[i].id })
                    return out
                }
                current: dialog.personId
                onChosen: dialog.personId = value
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: dialog.group === "people" || dialog.shared
                text: qsTr("+ someone new")
                onClicked: {
                    var d = pageStack.push(Qt.resolvedUrl("TextDialog.qml"), { "title": qsTr("someone new"), "label": qsTr("Name") })
                    d.accepted.connect(function() { dialog.personId = store.addListItem("person", d.value) })
                }
            }
        }
        VerticalScrollDecorator { }
    }
}
