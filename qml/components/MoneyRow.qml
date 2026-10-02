import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// "label ........ 12 345 kr", with a colour dot when it stands for a kind of spending.
Item {
    property alias label: left.text
    property alias value: right.text
    property color dot: "transparent"
    property color valueColor: FiatRatioTheme.primaryText
    property bool strong: false

    width: parent ? parent.width : implicitWidth
    height: Math.max(left.height, right.height) + Theme.paddingSmall

    Rectangle {
        id: dotItem
        visible: dot.a > 0
        x: Theme.horizontalPageMargin
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.paddingMedium; height: width; radius: width / 2
        color: dot
    }
    Label {
        id: left
        anchors {
            left: dotItem.visible ? dotItem.right : parent.left
            leftMargin: dotItem.visible ? Theme.paddingMedium : Theme.horizontalPageMargin
            right: right.left; rightMargin: Theme.paddingMedium
            verticalCenter: parent.verticalCenter
        }
        truncationMode: TruncationMode.Fade
        color: strong ? FiatRatioTheme.primaryText : FiatRatioTheme.secondaryText
        font.pixelSize: strong ? Theme.fontSizeMedium : Theme.fontSizeSmall
    }
    Label {
        id: right
        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
        color: valueColor
        font.pixelSize: strong ? Theme.fontSizeMedium : Theme.fontSizeSmall
    }
}
