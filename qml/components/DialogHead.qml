import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// The house dialog header. Cancel and save are short and sit in the corners on
// the status row; the title hangs below on the right, where PageHead puts it.
Item {
    id: root

    property Item dialog
    property string title: ""
    property string acceptText: qsTr("save")
    property string cancelText: qsTr("cancel")

    width: parent ? parent.width : 0
    height: FiatRatioTheme.statusRowCenter * 2 + (title !== "" ? titleLabel.height : 0) + Theme.paddingMedium

    MouseArea {
        id: cancelArea
        anchors.left: parent.left
        width: cancelLabel.width + 2 * Theme.horizontalPageMargin
        height: FiatRatioTheme.statusRowCenter * 2
        onClicked: if (root.dialog) root.dialog.reject()
        Label {
            id: cancelLabel
            x: Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            text: root.cancelText
            color: cancelArea.pressed ? FiatRatioTheme.accent : FiatRatioTheme.secondaryText
            font.pixelSize: Theme.fontSizeMedium
        }
    }

    MouseArea {
        id: acceptArea
        anchors.right: parent.right
        width: acceptLabel.width + 2 * Theme.horizontalPageMargin
        height: FiatRatioTheme.statusRowCenter * 2
        enabled: root.dialog ? root.dialog.canAccept : false
        onClicked: root.dialog.accept()
        Label {
            id: acceptLabel
            anchors.right: parent.right
            anchors.rightMargin: Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            text: root.acceptText
            color: FiatRatioTheme.accent
            opacity: acceptArea.enabled ? (acceptArea.pressed ? 0.6 : 1.0) : 0.35
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
        }
    }

    Label {
        id: titleLabel
        anchors.right: parent.right
        anchors.rightMargin: Theme.horizontalPageMargin
        y: FiatRatioTheme.statusRowCenter * 2 - Theme.paddingSmall
        width: parent.width - 2 * Theme.horizontalPageMargin
        visible: root.title !== ""
        horizontalAlignment: Text.AlignRight
        truncationMode: TruncationMode.Fade
        text: root.title
        font.pixelSize: Math.round(Theme.fontSizeLarge * 0.85)
        font.family: FiatRatioTheme.serif
        color: FiatRatioTheme.primaryText
    }
}
