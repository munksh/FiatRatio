import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// Something that comes back: new, or changed from the next time on.
Dialog {
    id: dialog

    property int scheduleId: 0
    property string kind: "expense"
    property string freq: "monthly"
    property int month: new Date().getMonth() + 1
    property bool shared: false
    property string share: "50"
    property int categoryId: 0
    property string categoryLabel: ""
    property int methodId: 0
    property int fromId: 0
    property int toId: -1
    property string startDate: store.today()
    property string lastDate: ""
    property bool active: true

    readonly property bool editing: scheduleId > 0
    readonly property var methods: { store.revision; return store.list("method") }
    readonly property var accountList: { store.revision; return store.accounts() }
    readonly property real whole: F.parse(amountField.text)
    readonly property real mine: shared && kind !== "transfer" ? Math.round(whole * Number(share) / 100) : whole
    readonly property string currency: store.setting("base_currency", "SEK")

    canAccept: nameField.text.trim() !== "" && mine > 0 && (kind !== "transfer" || (toId >= 0 && toId !== fromId))

    function paint() { FiatRatioTheme.applyPalette(dialog) }
    Component.onCompleted: {
        paint()
        if (editing) load()
        else dayField.text = String(new Date().getDate())
    }
    Connections { target: FiatRatioTheme; onAmbientChanged: dialog.paint() }

    function load() {
        var s = store.schedule(scheduleId)
        nameField.text = s.name
        kind = s.kind
        freq = s.freq
        month = Number(s.month) || month
        dayField.text = String(s.day)
        var full = Number(s.amount_full) || 0
        shared = full > Number(s.amount)
        amountField.text = F.forField(shared ? full : s.amount)
        if (shared) {
            var p = Math.round(100 * Number(s.amount) / full)
            share = (p === 33 || p === 25) ? String(p) : "50"
        }
        categoryId = Number(s.category_id) || 0
        categoryLabel = s.categoryLabel || ""
        methodId = Number(s.method_id) || 0
        fromId = s.fromAccountId
        toId = s.toAccountId
        lastDate = s.end_date || ""
        active = Number(s.active) === 1
    }
    function accountName(id) {
        if (id === 0) return qsTr("the month's money")
        for (var i = 0; i < accountList.length; ++i)
            if (accountList[i].id === id) return accountList[i].name
        return qsTr("choose")
    }
    function pickAccount(which) {
        var p = pageStack.push(Qt.resolvedUrl("AccountPickerPage.qml"),
                               { "selectedId": which === "from" ? fromId : toId, "excludeId": which === "from" ? toId : fromId })
        p.picked.connect(function(id) { if (which === "from") fromId = id; else toId = id })
    }
    function pickDate(current, apply) {
        var d = pageStack.push("Sailfish.Silica.DatePickerDialog", { "date": current !== "" ? F.fromIso(current) : new Date() })
        d.accepted.connect(function() { apply(F.isoDate(d.date)) })
    }

    onAccepted: {
        var s = {
            "name": nameField.text,
            "kind": kind,
            "amount": mine,
            "amountFull": shared && kind !== "transfer" ? whole : 0,
            "freq": freq,
            "day": Number(dayField.text) || 1,
            "month": month,
            "categoryId": kind === "transfer" ? 0 : categoryId,
            "methodId": kind === "expense" ? methodId : 0,
            "fromAccountId": fromId,
            "toAccountId": Math.max(0, toId),
            "startDate": startDate,
            "endDate": lastDate
        }
        if (editing) store.updateSchedule(scheduleId, s)
        else store.addSchedule(s)
    }

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
                title: dialog.editing ? qsTr("recurring") : qsTr("new recurring")
            }

            TextField {
                id: nameField
                width: parent.width
                focus: !dialog.editing
                label: qsTr("Name")
                placeholderText: qsTr("Rent, insurance, a domain …")
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: amountField.focus = true
            }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: !dialog.editing
                choices: [
                    { label: qsTr("expense"), value: "expense" },
                    { label: qsTr("income"), value: "income" },
                    { label: qsTr("move money"), value: "transfer" }
                ]
                current: dialog.kind
                onChosen: dialog.kind = value
            }
            TextField {
                id: amountField
                width: parent.width
                label: dialog.shared ? qsTr("Total") : qsTr("Amount")
                placeholderText: label
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                description: dialog.shared ? qsTr("Your part: %1").arg(F.money(dialog.mine, dialog.currency))
                                           : qsTr("A guess is fine when it varies. You confirm the real amount each time.")
            }
            Row {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                spacing: Theme.paddingLarge
                visible: dialog.kind !== "transfer"
                LinkText {
                    text: dialog.shared ? qsTr("split") : qsTr("split?")
                    color: dialog.shared ? FiatRatioTheme.accent : FiatRatioTheme.secondaryText
                    onClicked: dialog.shared = !dialog.shared
                }
            }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.shared && dialog.kind !== "transfer"
                choices: [ { label: "50 %", value: "50" }, { label: "33 %", value: "33" }, { label: "25 %", value: "25" } ]
                current: dialog.share
                onChosen: dialog.share = value
            }

            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("How often") }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                choices: [
                    { label: qsTr("every month"), value: "monthly" },
                    { label: qsTr("every quarter"), value: "quarterly" },
                    { label: qsTr("every year"), value: "yearly" }
                ]
                current: dialog.freq
                onChosen: dialog.freq = value
            }
            SectionLabel {
                x: Theme.horizontalPageMargin
                visible: dialog.freq === "yearly" || dialog.freq === "quarterly"
                text: dialog.freq === "yearly" ? qsTr("In") : qsTr("Starting in")
            }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.freq === "yearly" || dialog.freq === "quarterly"
                choices: {
                    var out = []
                    for (var m = 1; m <= 12; ++m)
                        out.push({ "label": F.shortMonth(appLanguage, m), "value": m })
                    return out
                }
                current: dialog.month
                onChosen: dialog.month = value
            }
            TextField {
                id: dayField
                width: parent.width
                label: qsTr("Day of the month")
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 1; top: 31 }
            }

            ValueButton {
                visible: dialog.kind !== "transfer"
                label: qsTr("Category")
                value: dialog.categoryLabel !== "" ? dialog.categoryLabel : qsTr("choose")
                onClicked: {
                    var p = pageStack.push(Qt.resolvedUrl("CategoryPickerPage.qml"),
                                           { "kind": dialog.kind === "income" ? "income" : "expense", "selectedId": dialog.categoryId })
                    p.picked.connect(function(id, label) { dialog.categoryId = id; dialog.categoryLabel = label })
                }
            }
            ValueButton {
                visible: dialog.kind === "transfer"
                enabled: !dialog.editing
                label: qsTr("From")
                value: dialog.accountName(dialog.fromId)
                onClicked: dialog.pickAccount("from")
            }
            ValueButton {
                visible: dialog.kind === "transfer"
                enabled: !dialog.editing
                label: qsTr("To")
                value: dialog.toId >= 0 ? dialog.accountName(dialog.toId) : qsTr("choose")
                onClicked: dialog.pickAccount("to")
            }

            SectionLabel {
                x: Theme.horizontalPageMargin
                visible: dialog.kind === "expense" && dialog.methods.length > 0
                text: qsTr("Method")
            }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.kind === "expense" && dialog.methods.length > 0
                choices: {
                    var out = []
                    for (var i = 0; i < dialog.methods.length; ++i)
                        out.push({ "label": dialog.methods[i].name, "value": dialog.methods[i].id })
                    return out
                }
                current: dialog.methodId
                onChosen: dialog.methodId = (dialog.methodId === value ? 0 : value)
            }

            Row {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: !dialog.editing
                spacing: Theme.paddingLarge
                LinkText {
                    text: dialog.startDate === store.today() ? qsTr("from: today")
                                                             : qsTr("from: %1").arg(F.dayMonthYear(appLanguage, dialog.startDate))
                    onClicked: dialog.pickDate(dialog.startDate, function(d) { dialog.startDate = d })
                }
            }
            Row {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                spacing: Theme.paddingLarge
                LinkText {
                    text: dialog.lastDate === "" ? qsTr("until: not set")
                                                 : qsTr("until: %1").arg(F.dayMonthYear(appLanguage, dialog.lastDate))
                    onClicked: dialog.pickDate(dialog.lastDate, function(d) { dialog.lastDate = d })
                }
                LinkText {
                    visible: dialog.lastDate !== ""
                    text: qsTr("no end")
                    color: FiatRatioTheme.secondaryText
                    onClicked: dialog.lastDate = ""
                }
            }

            Item { width: 1; height: Theme.paddingLarge; visible: dialog.editing }
            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: 1
                visible: dialog.editing
                color: FiatRatioTheme.innerBorder
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: dialog.editing
                text: dialog.active ? qsTr("pause") : qsTr("resume")
                color: FiatRatioTheme.secondaryText
                onClicked: {
                    store.setScheduleActive(dialog.scheduleId, !dialog.active)
                    pageStack.pop()
                }
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: dialog.editing
                text: qsTr("delete, with what is still planned")
                color: FiatRatioTheme.wrong
                onClicked: remorse.execute(qsTr("Deleting"), function() {
                    store.deleteSchedule(dialog.scheduleId)
                    pageStack.pop()
                })
            }
        }
        VerticalScrollDecorator { }
    }
}
