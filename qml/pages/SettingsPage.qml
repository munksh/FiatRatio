import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

Page {
    id: page

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()
    Connections { target: FiatRatioTheme; onAmbientChanged: page.paint() }

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
        contentHeight: content.height + Theme.paddingLarge

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingSmall

            PageHead { title: qsTr("settings") }

            // ---- language ----
            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Language") }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                choices: [
                    { label: qsTr("as the phone"), value: "" },
                    { label: "english", value: "en" },
                    { label: "svenska", value: "sv" },
                    { label: "deutsch", value: "de" },
                    { label: "русский", value: "ru" }
                ]
                current: store.languageSetting
                onChosen: store.setLanguage(value)
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Takes effect at once.")
            }

            // ---- the month ----
            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Month starts") }
            WordChoice {
                id: modeChoice
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                choices: [
                    { label: qsTr("salary arrives"), value: "salary" },
                    { label: qsTr("on the 1st"), value: "calendar" }
                ]
                current: { store.revision; return store.setting("period_mode", "salary") }
                onChosen: store.setSetting("period_mode", value)
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Takes effect from the next month.")
            }
            TextField {
                visible: modeChoice.current !== "calendar"
                width: parent.width
                label: qsTr("Payday, day of the month")
                text: store.setting("payday_day", "25")
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 1; top: 31 }
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
                onActiveFocusChanged: if (!activeFocus && acceptableInput) store.setSetting("payday_day", text)
            }
            TextField {
                width: parent.width
                label: qsTr("Currency")
                text: store.setting("base_currency", "SEK")
                inputMethodHints: Qt.ImhUppercaseOnly | Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
                onActiveFocusChanged: if (!activeFocus && text.trim().length === 3) store.setSetting("base_currency", text.trim().toUpperCase())
            }

            // ---- how far ahead what repeats is written ----
            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Plan ahead") }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                choices: [
                    { label: qsTr("3 months"), value: "3" },
                    { label: qsTr("6 months"), value: "6" },
                    { label: qsTr("12 months"), value: "12" },
                    { label: qsTr("24 months"), value: "24" }
                ]
                current: store.setting("plan_months", "12")
                onChosen: { store.setSetting("plan_months", value); store.autoPlan() }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Recurring items are planned this far ahead, until you end them.")
            }

            // ---- lists ----
            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Lists") }
            Repeater {
                model: [
                    { "text": qsTr("Methods"), "page": "ListPage.qml",
                      "props": { "table": "method", "title": qsTr("methods"), "hint": qsTr("How it was paid.") } },
                    { "text": qsTr("Contexts"), "page": "ListPage.qml",
                      "props": { "table": "context", "title": qsTr("contexts"), "hint": qsTr("Travel, work, a project. Optional.") } },
                    { "text": qsTr("People"), "page": "ListPage.qml",
                      "props": { "table": "person", "title": qsTr("people"), "hint": qsTr("People you split costs with, or who owe you.") } },
                    { "text": qsTr("Categories"), "page": "CategoriesPage.qml", "props": {} },
                    { "text": qsTr("Recurring"), "page": "SchedulesPage.qml", "props": {} }
                ]
                BackgroundItem {
                    width: content.width
                    highlightedColor: FiatRatioTheme.highlightWash
                    Label {
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text
                        color: FiatRatioTheme.primaryText
                        font.pixelSize: Theme.fontSizeMedium
                        font.family: FiatRatioTheme.serif
                    }
                    onClicked: pageStack.push(Qt.resolvedUrl(modelData.page), modelData.props)
                }
            }

            Item { width: 1; height: Theme.paddingLarge }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: !store.demo
                text: qsTr("practice run again")
                onClicked: {
                    store.startDemo()
                    pageStack.replaceAbove(null, Qt.resolvedUrl("MonthPage.qml"))
                }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: !store.demo
                wrapMode: Text.WordWrap
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Made-up numbers, kept apart. Yours come back when it ends.")
            }
        }
        VerticalScrollDecorator { }
    }
}
