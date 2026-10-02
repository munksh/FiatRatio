import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// A planned row is a guess until it happens. Confirm it with what it really
// cost, when, and how it was paid.
Dialog {
    id: dialog

    property int txnId: 0
    property string when: "today"
    property string otherDate: ""
    property int methodId: 0
    property bool forward: false
    property bool coachHidden: false

    readonly property var t: store.transaction(txnId)
    readonly property var rule: t.scheduleId > 0 ? store.schedule(t.scheduleId) : ({})
    readonly property bool hasRule: t.scheduleId > 0
    readonly property bool isShared: Number(t.amountFull) > 0
    readonly property real expected: Number(isShared ? t.amountFull : t.amount) || 0
    readonly property real entered: F.parse(amountField.text)
    readonly property real mine: isShared ? Math.round(entered * Number(t.amount) / Number(t.amountFull)) : entered
    readonly property string currency: store.setting("base_currency", "SEK")
    readonly property var methods: { store.revision; return store.list("method") }
    readonly property string chosenDate: when === "today" ? store.today() : when === "planned" ? t.date : otherDate

    canAccept: mine > 0

    function paint() { FiatRatioTheme.applyPalette(dialog) }
    Component.onCompleted: {
        paint()
        amountField.text = F.forField(expected)
        methodId = t.methodId || 0
    }
    Connections { target: FiatRatioTheme; onAmbientChanged: dialog.paint() }

    function freqText() {
        if (!hasRule) return ""
        if (rule.freq === "monthly") return qsTr("every month")
        if (rule.freq === "quarterly") return qsTr("every quarter")
        if (rule.freq === "yearly") return qsTr("every year")
        return qsTr("every week")
    }
    function payload() {
        return { "amount": mine, "amountFull": isShared ? entered : 0, "date": chosenDate,
                 "methodId": methodId, "forward": forward }
    }

    onAccepted: store.confirmPlanned(txnId, payload())

    RemorsePopup { id: remorse }

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
                title: dialog.t.description || ""
                acceptText: qsTr("confirm")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("Planned for %1, expected %2.").arg(F.dayMonth(appLanguage, dialog.t.date)).arg(F.money(dialog.expected, dialog.currency))
                      + (dialog.hasRule ? "\n↻ " + dialog.freqText() : "")
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeSmall
            }

            TextField {
                id: amountField
                width: parent.width
                focus: true
                label: dialog.isShared ? qsTr("Total") : qsTr("It came to")
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                description: {
                    var d = dialog.entered - dialog.expected
                    var part = dialog.isShared ? qsTr("Your part: %1. ").arg(F.money(dialog.mine, dialog.currency)) : ""
                    if (d > 0) return part + qsTr("%1 more than expected").arg(F.money(d, dialog.currency))
                    if (d < 0) return part + qsTr("%1 less than expected").arg(F.money(-d, dialog.currency))
                    return part + qsTr("as expected")
                }
            }

            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("When") }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                choices: [
                    { label: qsTr("today"), value: "today" },
                    { label: qsTr("as planned, %1").arg(F.dayMonth(appLanguage, dialog.t.date)), value: "planned" },
                    { label: dialog.otherDate !== "" ? F.dayMonth(appLanguage, dialog.otherDate) : qsTr("date"), value: "other" }
                ]
                current: dialog.when
                onChosen: {
                    if (value === "other") {
                        var d = pageStack.push("Sailfish.Silica.DatePickerDialog", { "date": new Date() })
                        d.accepted.connect(function() { dialog.otherDate = F.isoDate(d.date); dialog.when = "other" })
                    } else {
                        dialog.when = value
                    }
                }
            }

            SectionLabel {
                x: Theme.horizontalPageMargin
                visible: dialog.t.type === "expense" && dialog.methods.length > 0
                text: qsTr("Method")
            }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.t.type === "expense" && dialog.methods.length > 0
                choices: {
                    var out = []
                    for (var i = 0; i < dialog.methods.length; ++i)
                        out.push({ "label": dialog.methods[i].name, "value": dialog.methods[i].id })
                    return out
                }
                current: dialog.methodId
                onChosen: dialog.methodId = value
            }

            SectionLabel {
                x: Theme.horizontalPageMargin
                visible: dialog.hasRule && dialog.entered !== dialog.expected && dialog.entered > 0
                text: qsTr("Next time")
            }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.hasRule && dialog.entered !== dialog.expected && dialog.entered > 0
                choices: [
                    { label: qsTr("keep %1").arg(F.plain(dialog.expected)), value: false },
                    { label: qsTr("count on %1").arg(F.plain(dialog.entered)), value: true }
                ]
                current: dialog.forward
                onChosen: dialog.forward = value
            }

            Item { width: 1; height: Theme.paddingLarge }
            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: 1
                color: FiatRatioTheme.innerBorder
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                text: qsTr("skip once")
                color: FiatRatioTheme.secondaryText
                onClicked: remorse.execute(qsTr("Skipping"), function() {
                    store.deleteTransaction(dialog.txnId)
                    pageStack.pop()
                })
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: dialog.hasRule
                text: qsTr("this is the last time")
                color: FiatRatioTheme.secondaryText
                onClicked: {
                    store.confirmPlanned(dialog.txnId, dialog.payload())
                    store.endScheduleAfter(dialog.t.scheduleId, dialog.chosenDate)
                    pageStack.pop()
                }
            }

            Item { width: 1; height: Theme.paddingLarge }
            CoachMark {
                visible: store.demo && store.coachStep === 1 && !dialog.coachHidden
                text: visible ? qsTr("The electricity cost more than guessed. Write 350 and confirm. Under Next time you choose whether to count on 350 from now on.") : ""
                nextText: qsTr("got it")
                onNext: dialog.coachHidden = true
                onEnd: dialog.coachHidden = true
            }
        }
        VerticalScrollDecorator { }
    }
}
