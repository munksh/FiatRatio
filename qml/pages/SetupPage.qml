import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

// Three questions. Everything else is asked the first time it is needed.
Page {
    id: page

    property string mode: "salary"
    property bool standard: true

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()
    Connections { target: FiatRatioTheme; onAmbientChanged: page.paint() }

    function start() {
        store.setupFresh({
            "base_currency": currencyField.text.trim().toUpperCase() || store.localeCurrency(),
            "period_mode": page.mode,
            "payday_day": paydayField.text || "25",
            "standard_categories": page.standard
        })
        pageStack.replaceAbove(null, Qt.resolvedUrl("MonthPage.qml"))
    }

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
        contentHeight: content.height + startButton.height + Theme.paddingLarge * 2

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingMedium

            PageHead { title: qsTr("set up") }

            SectionLabel {
                x: Theme.horizontalPageMargin
                text: qsTr("When does your month start?")
            }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                choices: [
                    { label: qsTr("salary arrives"), value: "salary" },
                    { label: qsTr("on the 1st"), value: "calendar" }
                ]
                current: page.mode
                onChosen: page.mode = value
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
                text: page.mode === "salary"
                      ? qsTr("The month starts when the salary arrives. Until then, payday is the guess.")
                      : qsTr("Plain calendar months.")
            }
            TextField {
                id: paydayField
                visible: page.mode !== "calendar"
                width: parent.width
                label: qsTr("Payday, day of the month")
                text: "25"
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 1; top: 31 }
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }
            TextField {
                id: currencyField
                width: parent.width
                label: qsTr("Currency")
                text: store.localeCurrency()
                inputMethodHints: Qt.ImhUppercaseOnly | Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }
            SectionLabel {
                x: Theme.horizontalPageMargin
                text: qsTr("Categories")
            }
            WordChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                choices: [
                    { label: qsTr("the usual ones"), value: true },
                    { label: qsTr("only the essentials"), value: false }
                ]
                current: page.standard
                onChosen: page.standard = value
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: FiatRatioTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Methods, contexts and people are added when you first need them. Change anything in settings.")
            }
        }
        VerticalScrollDecorator { }
    }

    FiatButton {
        id: startButton
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.paddingLarge
        filled: true
        text: qsTr("start")
        onClicked: page.start()
    }
}
