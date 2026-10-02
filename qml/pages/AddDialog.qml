import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../js/format.js" as F

// Add or change one row. Each kind shows only its own fields: an expense is
// paid with something, income is not, a move goes from one place to another.
Dialog {
    id: dialog

    property int txnId: 0
    property string presetDate: ""
    property string presetType: "expense"
    property int presetToAccountId: -1

    property string type: presetType
    property bool shared: false
    property string share: "50"
    property int personId: 0
    property int categoryId: 0
    property string categoryLabel: ""
    property bool categoryTouched: false
    property int methodId: 0
    property int contextId: 0
    property int fromId: 0
    property int toId: -1
    property bool arrivedOther: false
    property string date: presetDate !== "" ? presetDate : store.today()
    property string repeat: "no"
    property string lastDate: ""
    property bool coachHidden: false
    property bool more: false
    property bool methodTouched: false
    property bool contextTouched: false

    readonly property bool editing: txnId > 0
    readonly property string currency: store.setting("base_currency", "SEK")
    readonly property bool salaryMode: store.setting("period_mode", "salary") === "salary"
    // The salary is an income in the category Salary. It is what starts a month.
    readonly property bool isSalary: type === "income" && categoryId > 0 && categoryInfo.key === "salary"
    readonly property var people: { store.revision; return store.list("person") }
    readonly property var methods: { store.revision; return store.list("method") }
    readonly property var contexts: { store.revision; return store.list("context") }
    readonly property var accountList: { store.revision; return store.accounts() }
    readonly property var categoryInfo: categoryId > 0 ? store.categoryInfo(categoryId) : ({})

    readonly property real whole: F.parse(amountField.text)
    readonly property real sharePercent: share === "other" ? Math.max(0, Math.min(100, Number(customShare.text) || 0)) : Number(share)
    readonly property real mine: (shared && type !== "move") ? Math.round(whole * sharePercent / 100) : whole

    canAccept: mine > 0 && (type !== "move" || (toId >= 0 && fromId !== toId))

    function paint() { FiatRatioTheme.applyPalette(dialog) }
    Component.onCompleted: {
        paint()
        if (presetToAccountId >= 0) { type = "move"; toId = presetToAccountId }
        if (editing) { load(); more = true }
        else prefillMethod()
    }
    Connections { target: FiatRatioTheme; onAmbientChanged: dialog.paint() }

    function load() {
        var t = store.transaction(txnId)
        if (!t.id) return
        type = t.type
        shared = t.amountFull > 0 && t.type !== "move"
        amountField.text = F.forField(shared ? t.amountFull : t.amount)
        if (shared) {
            var p = Math.round(100 * t.amount / t.amountFull)
            if (p === 50 || p === 33 || p === 25) share = String(p)
            else { share = "other"; customShare.text = String(p) }
        }
        personId = t.personId
        descField.text = t.description
        categoryId = t.categoryId
        categoryLabel = t.categoryLabel
        categoryTouched = true
        methodId = t.methodId
        contextId = t.contextId
        if (t.type === "move") {
            fromId = t.fromAccountId
            toId = t.toAccountId
            if (t.amountIn !== t.amount) { arrivedOther = true; arrivedField.text = F.forField(t.amountIn) }
        }
        date = t.date
        notesField.text = t.notes || ""
    }

    // How it is usually paid: the way used most among the last ten expenses,
    // or the first on the list when there is no history yet.
    function prefillMethod() {
        if (editing || type !== "expense" || methodTouched || methodId > 0) return
        var u = store.usualMethod()
        if (u <= 0 && methods.length > 0) u = methods[0].id
        methodId = u
    }
    function nameOf(list, id, fallback) {
        for (var i = 0; i < list.length; ++i)
            if (list[i].id === id) return list[i].name
        return fallback
    }
    function summary() {
        var parts = []
        if (type === "expense" && methodId > 0) parts.push(nameOf(methods, methodId, ""))
        if (type !== "move" && contextId > 0) parts.push(nameOf(contexts, contextId, ""))
        if (type !== "move" && shared) parts.push(qsTr("split"))
        if (!editing && repeat !== "no") parts.push("↻ " + (repeat === "m" ? qsTr("every month") : repeat === "q" ? qsTr("every quarter") : qsTr("every year")))
        return parts.length > 0 ? parts.join(" · ") : qsTr("none")
    }
    function pickFromList(table, title, hint, selected, noneLabel, done) {
        var p = pageStack.push(Qt.resolvedUrl("ListPage.qml"),
                               { "table": table, "title": title, "hint": hint, "picking": true,
                                 "selectedId": selected, "noneLabel": noneLabel })
        p.picked.connect(done)
    }
    function accountName(id) {
        if (id === 0) return qsTr("the month's money")
        for (var i = 0; i < accountList.length; ++i)
            if (accountList[i].id === id) return accountList[i].name
        return qsTr("choose")
    }
    function accountKind(id) {
        if (id === 0) return "pot"
        for (var i = 0; i < accountList.length; ++i)
            if (accountList[i].id === id) return accountList[i].kind
        return ""
    }
    function moveNote() {
        if (toId < 0) return ""
        var from = accountKind(fromId), to = accountKind(toId), k = kinds
        if (from === "pot" && (k.debt(to) || to === "person"))
            return qsTr("Paying off: lowers the debt. Counts as a need.")
        if (from === "pot")
            return qsTr("Counts as saving. The money is still yours.")
        if (to === "pot" && (k.debt(from) || from === "person"))
            return qsTr("Borrowed money. Not income, and the debt grows.")
        if (to === "pot")
            return qsTr("Taken from savings. Not income, and lowers this month's saving.")
        return qsTr("Between your own places. The month is not affected.")
    }
    function choices(list, noneLabel) {
        var out = []
        for (var i = 0; i < list.length; ++i)
            out.push({ "label": list[i].name, "value": list[i].id })
        if (noneLabel !== "")
            out.push({ "label": noneLabel, "value": 0 })
        return out
    }
    function addToList(table, title, done) {
        var d = pageStack.push(Qt.resolvedUrl("TextDialog.qml"), { "title": title, "label": qsTr("Name") })
        d.accepted.connect(function() { done(store.addListItem(table, d.value)) })
    }
    function pickAccount(which) {
        var p = pageStack.push(Qt.resolvedUrl("AccountPickerPage.qml"),
                               { "selectedId": which === "from" ? fromId : toId, "excludeId": which === "from" ? toId : fromId })
        p.picked.connect(function(id) { if (which === "from") fromId = id; else toId = id })
    }
    function pickDate(apply) {
        var d = pageStack.push("Sailfish.Silica.DatePickerDialog", { "date": F.fromIso(date) })
        d.accepted.connect(function() { apply(F.isoDate(d.date)) })
    }

    onTypeChanged: {
        if (editing) return
        if (!categoryTouched) { categoryId = 0; categoryLabel = "" }
        if (type === "expense") prefillMethod()
        if (type === "move" && toId < 0 && accountList.length > 0) toId = -1
    }

    onAccepted: {
        var t = {
            "type": type,
            "amount": mine,
            "amountFull": (shared && type !== "move") ? whole : 0,
            "date": date,
            "description": descField.text,
            "categoryId": type === "move" ? 0 : categoryId,
            "methodId": type === "expense" ? methodId : 0,
            "contextId": type === "move" ? 0 : contextId,
            "personId": (shared && type !== "move") ? personId : 0,
            "fromAccountId": fromId,
            "toAccountId": Math.max(0, toId),
            "amountIn": arrivedOther ? F.parse(arrivedField.text) : 0,
            "isSalary": isSalary,
            "repeat": editing ? "" : repeat,
            "lastDate": repeat !== "no" ? lastDate : "",
            "notes": notesField.text
        }
        if (editing) store.updateTransaction(txnId, t)
        else store.addTransaction(t)
    }

    Kinds { id: kinds }
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
                title: dialog.editing ? qsTr("change") : qsTr("add")
            }

            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: !dialog.editing || dialog.type !== "move"
                choices: [
                    { label: qsTr("expense"), value: "expense" },
                    { label: qsTr("income"), value: "income" },
                    { label: qsTr("move money"), value: "move" }
                ]
                current: dialog.type
                onChosen: dialog.type = value
            }

            TextField {
                id: amountField
                width: parent.width
                focus: !dialog.editing
                font.pixelSize: Theme.fontSizeExtraLarge
                label: dialog.shared && dialog.type !== "move" ? qsTr("Total") : qsTr("Amount")
                placeholderText: label
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                description: dialog.shared && dialog.type !== "move" ? qsTr("Your part: %1").arg(F.money(dialog.mine, dialog.currency)) : ""
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: descField.focus = true
            }

            TextField {
                id: descField
                width: parent.width
                label: dialog.type === "income" ? qsTr("From") : dialog.type === "move" ? qsTr("What") : qsTr("What")
                placeholderText: label
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
                onActiveFocusChanged: {
                    if (activeFocus || dialog.editing || dialog.type === "move" || text.trim() === "")
                        return
                    // A known place fills in what it was last time.
                    var last = store.lastFor(text)
                    if (!dialog.categoryTouched && last.categoryId) {
                        dialog.categoryId = last.categoryId
                        dialog.categoryLabel = last.categoryLabel
                    }
                    if (!dialog.methodTouched && last.methodId) dialog.methodId = last.methodId
                    if (!dialog.contextTouched && dialog.contextId === 0 && last.contextId) dialog.contextId = last.contextId
                    if (last.split && !dialog.shared) {
                        dialog.shared = true
                        if (last.share === 50 || last.share === 33 || last.share === 25) dialog.share = String(last.share)
                        if (last.personId) dialog.personId = last.personId
                    }
                }
            }

            // ---- category ----
            ValueButton {
                visible: dialog.type !== "move"
                label: qsTr("Category")
                value: dialog.categoryLabel !== "" ? dialog.categoryLabel : qsTr("choose")
                description: dialog.type === "expense" && dialog.categoryInfo.bucketLabel
                             ? qsTr("counts as %1").arg(String(dialog.categoryInfo.bucketLabel).toLowerCase()) : ""
                onClicked: {
                    var p = pageStack.push(Qt.resolvedUrl("CategoryPickerPage.qml"),
                                           { "kind": dialog.type === "income" ? "income" : "expense", "selectedId": dialog.categoryId })
                    p.picked.connect(function(id, label) {
                        dialog.categoryId = id
                        dialog.categoryLabel = label
                        dialog.categoryTouched = true
                    })
                }
            }

            // ---- move: from and to ----
            ValueButton {
                visible: dialog.type === "move"
                label: qsTr("From")
                value: dialog.accountName(dialog.fromId)
                onClicked: dialog.pickAccount("from")
            }
            ValueButton {
                visible: dialog.type === "move"
                label: qsTr("To")
                value: dialog.toId >= 0 ? dialog.accountName(dialog.toId) : qsTr("choose")
                onClicked: dialog.pickAccount("to")
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.type === "move" && text !== ""
                wrapMode: Text.WordWrap
                text: dialog.type === "move" ? dialog.moveNote() : ""
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: dialog.type === "move" && !dialog.arrivedOther
                text: qsTr("a different amount arrived")
                color: FiatRatioTheme.secondaryText
                onClicked: dialog.arrivedOther = true
            }
            TextField {
                id: arrivedField
                width: parent.width
                visible: dialog.type === "move" && dialog.arrivedOther
                label: qsTr("Arrived, in that place's currency")
                inputMethodHints: Qt.ImhFormattedNumbersOnly
            }

            // ---- when ----
            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("When") }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                choices: [
                    { label: qsTr("today"), value: store.today() },
                    { label: qsTr("yesterday"), value: store.yesterday() },
                    { label: (dialog.date !== store.today() && dialog.date !== store.yesterday())
                             ? F.dayMonthYear(appLanguage, dialog.date) : qsTr("date"), value: "pick" }
                ]
                current: (dialog.date === store.today() || dialog.date === store.yesterday()) ? dialog.date : "pick"
                onChosen: {
                    if (value === "pick") dialog.pickDate(function(d) { dialog.date = d })
                    else dialog.date = value
                }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.date > store.today()
                wrapMode: Text.WordWrap
                text: qsTr("A later day: stays planned until you confirm it.")
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            // ---- the salary ----
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.isSalary && dialog.salaryMode
                wrapMode: Text.WordWrap
                text: qsTr("The salary starts a new month.")
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            // ---- more: everything that has a sensible default ----
            BackgroundItem {
                id: moreHead
                width: parent.width
                height: Theme.itemSizeMedium
                highlightedColor: FiatRatioTheme.highlightWash
                onClicked: dialog.more = !dialog.more
                Rectangle {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    height: 1
                    color: FiatRatioTheme.innerBorder
                }
                Label {
                    id: moreLabel
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("More")
                    color: FiatRatioTheme.primaryText
                    font.pixelSize: Theme.fontSizeMedium
                }
                Label {
                    anchors.left: moreLabel.right
                    anchors.leftMargin: Theme.paddingLarge
                    anchors.right: caret.left
                    anchors.rightMargin: Theme.paddingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    truncationMode: TruncationMode.Fade
                    text: dialog.more ? "" : dialog.summary()
                    color: FiatRatioTheme.secondaryText
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
                Label {
                    id: caret
                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                    text: "›"
                    color: FiatRatioTheme.secondaryText
                    font.pixelSize: Theme.fontSizeLarge
                    rotation: dialog.more ? 270 : 90
                    Behavior on rotation { NumberAnimation { duration: 160 } }
                }
            }
            Item {
                id: morePanel
                width: parent.width
                height: dialog.more ? moreColumn.height + Theme.paddingLarge : 0
                visible: height > 0.5
                clip: true
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                Rectangle { anchors.fill: parent; color: FiatRatioTheme.wash }
                Column {
                    id: moreColumn
                    width: parent.width
                    spacing: Theme.paddingSmall

                    ValueButton {
                        visible: dialog.type === "expense"
                        label: qsTr("Method")
                        value: dialog.nameOf(dialog.methods, dialog.methodId, qsTr("not chosen"))
                        onClicked: dialog.pickFromList("method", qsTr("methods"), qsTr("How it was paid."),
                                                       dialog.methodId, "", function(id) { dialog.methodId = id; dialog.methodTouched = true })
                    }
                    ValueButton {
                        visible: dialog.type !== "move"
                        label: qsTr("Context")
                        value: dialog.nameOf(dialog.contexts, dialog.contextId, qsTr("none"))
                        onClicked: dialog.pickFromList("context", qsTr("contexts"), qsTr("Travel, work, a project. Optional."),
                                                       dialog.contextId, qsTr("none"), function(id) { dialog.contextId = id; dialog.contextTouched = true })
                    }

                    Row {
                        x: Theme.horizontalPageMargin
                        spacing: Theme.paddingLarge
                        visible: dialog.type !== "move"
                        LinkText {
                            text: dialog.shared ? qsTr("split") : qsTr("split?")
                            underline: !dialog.shared
                            color: dialog.shared ? FiatRatioTheme.accent : FiatRatioTheme.secondaryText
                            onClicked: dialog.shared = !dialog.shared
                        }
                        LinkText {
                            visible: dialog.shared
                            text: qsTr("no split")
                            color: FiatRatioTheme.secondaryText
                            onClicked: dialog.shared = false
                        }
                    }
                    Column {
                        width: parent.width
                        visible: dialog.shared && dialog.type !== "move"
                        spacing: Theme.paddingSmall
                        SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Your share") }
                        WordChoice {
                            x: Theme.horizontalPageMargin
                            width: parent.width - 2 * Theme.horizontalPageMargin
                            choices: [
                                { label: "50 %", value: "50" }, { label: "33 %", value: "33" },
                                { label: "25 %", value: "25" }, { label: qsTr("other"), value: "other" }
                            ]
                            current: dialog.share
                            onChosen: dialog.share = value
                        }
                        TextField {
                            id: customShare
                            width: parent.width
                            visible: dialog.share === "other"
                            label: qsTr("Your share, %")
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator { bottom: 1; top: 99 }
                        }
                        SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Who, if you like") }
                        WordChoice {
                            x: Theme.horizontalPageMargin
                            width: parent.width - 2 * Theme.horizontalPageMargin
                            choices: dialog.choices(dialog.people, qsTr("no one in particular"))
                            current: dialog.personId
                            onChosen: dialog.personId = value
                        }
                        LinkText {
                            x: Theme.horizontalPageMargin - Theme.paddingSmall
                            text: qsTr("+ someone new")
                            onClicked: dialog.addToList("person", qsTr("someone new"), function(id) { dialog.personId = id })
                        }
                    }

                    SectionLabel {
                        x: Theme.horizontalPageMargin
                        visible: !dialog.editing
                        text: qsTr("Recurring")
                    }
                    WordChoice {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        visible: !dialog.editing
                        choices: [
                            { label: qsTr("no"), value: "no" },
                            { label: qsTr("every month"), value: "m" },
                            { label: qsTr("every quarter"), value: "q" },
                            { label: qsTr("every year"), value: "y" }
                        ]
                        current: dialog.repeat
                        onChosen: dialog.repeat = value
                    }
                    Row {
                        x: Theme.horizontalPageMargin - Theme.paddingSmall
                        visible: !dialog.editing && dialog.repeat !== "no"
                        spacing: Theme.paddingLarge
                        LinkText {
                            text: dialog.lastDate === "" ? qsTr("until: not set")
                                                         : qsTr("until: %1").arg(F.dayMonthYear(appLanguage, dialog.lastDate))
                            onClicked: dialog.pickDate(function(d) { dialog.lastDate = d })
                        }
                        LinkText {
                            visible: dialog.lastDate !== ""
                            text: qsTr("no end")
                            color: FiatRatioTheme.secondaryText
                            onClicked: dialog.lastDate = ""
                        }
                    }

                    TextField {
                        id: notesField
                        width: parent.width
                        label: qsTr("Note")
                        placeholderText: label
                    }

                }
            }

            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: dialog.editing
                text: qsTr("delete")
                color: FiatRatioTheme.wrong
                onClicked: remorse.execute(qsTr("Deleting"), function() {
                    store.deleteTransaction(dialog.txnId)
                    pageStack.pop()
                })
            }

            Item { width: 1; height: Theme.paddingLarge }
            CoachMark {
                visible: store.demo && store.coachStep === 2 && !dialog.coachHidden && !dialog.editing
                text: visible ? qsTr("Write 840, open More, tap split, and save. Who with is up to you.") : ""
                nextText: qsTr("got it")
                onNext: dialog.coachHidden = true
                onEnd: dialog.coachHidden = true
            }
        }
        VerticalScrollDecorator { }
    }
}
