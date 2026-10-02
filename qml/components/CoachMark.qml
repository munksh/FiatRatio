import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// The practice run's guide: a note at the bottom of the page, in the accent.
Rectangle {
    id: root

    property string text: ""
    property string nextText: qsTr("next")
    property string label: qsTr("practice run")
    property bool showEnd: true
    signal next()
    signal end()

    x: Theme.horizontalPageMargin
    width: parent ? parent.width - 2 * Theme.horizontalPageMargin : 0
    height: col.height + 2 * Theme.paddingLarge
    radius: Theme.paddingLarge
    color: FiatRatioTheme.accent
    visible: text !== ""

    Column {
        id: col
        x: Theme.paddingLarge
        y: Theme.paddingLarge
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingMedium

        Label {
            text: root.label
            visible: root.label !== ""
            color: FiatRatioTheme.onAccent
            opacity: 0.75
            font.pixelSize: Theme.fontSizeTiny
            font.italic: true
            font.family: FiatRatioTheme.serif
        }
        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.text
            color: FiatRatioTheme.onAccent
            font.pixelSize: Theme.fontSizeSmall
        }
        Item {
            width: parent.width
            height: Theme.itemSizeExtraSmall
            MouseArea {
                visible: root.showEnd
                anchors.left: parent.left
                width: endLabel.width + Theme.paddingLarge
                height: parent.height
                onClicked: root.end()
                Label {
                    id: endLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("end")
                    color: FiatRatioTheme.onAccent
                    opacity: 0.75
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
            MouseArea {
                anchors.right: parent.right
                width: nextLabel.width + Theme.paddingLarge
                height: parent.height
                onClicked: root.next()
                Label {
                    id: nextLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.nextText + " ›"
                    color: FiatRatioTheme.onAccent
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
            }
        }
    }
}
