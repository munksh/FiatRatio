import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

Dialog {
    id: dialog
    property string title
    property string label
    property string text
    property bool numeric: false
    property alias value: field.text

    canAccept: field.text.trim() !== ""

    function paint() { FiatRatioTheme.applyPalette(dialog) }
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
        DialogHead { dialog: dialog; title: dialog.title }
        TextField {
            id: field
            width: parent.width
            focus: true
            text: dialog.text
            label: dialog.label
            placeholderText: dialog.label
            inputMethodHints: dialog.numeric ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: dialog.accept()
        }
    }
}
