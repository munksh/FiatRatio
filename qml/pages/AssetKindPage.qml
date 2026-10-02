import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

Page {
    id: page

    function paint() { FiatRatioTheme.applyPalette(page) }
    Component.onCompleted: paint()

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

        PageHead { title: qsTr("add") }

        Repeater {
            model: [
                { "title": qsTr("Savings"), "what": qsTr("A savings account, a buffer, funds, a pension"), "page": "AssetDialog.qml", "group": "saved" },
                { "title": qsTr("Something you own"), "what": qsTr("A home, a car, an instrument. You update its value when you like."), "page": "AssetDialog.qml", "group": "owned" },
                { "title": qsTr("A loan or credit"), "what": qsTr("A new loan, a mortgage, a card, a loan from a person"), "page": "LoanDialog.qml", "group": "debt" },
                { "title": qsTr("Between people"), "what": qsTr("Someone owes you, or you owe someone"), "page": "AssetDialog.qml", "group": "people" }
            ]
            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeLarge
                highlightedColor: FiatRatioTheme.highlightWash
                onClicked: pageStack.replace(Qt.resolvedUrl(modelData.page), { "group": modelData.group })
                Column {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        text: modelData.title
                        color: FiatRatioTheme.primaryText
                        font.pixelSize: Theme.fontSizeMedium
                        font.family: FiatRatioTheme.serif
                    }
                    Label {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: modelData.what
                        color: FiatRatioTheme.secondaryText
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }
        }
    }
}
