import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// Put it beside a list, never inside: a child of a ListView is moved into its
// contentItem, which has no height while the model is empty.
Label {
    x: Theme.horizontalPageMargin
    width: parent ? parent.width - 2 * Theme.horizontalPageMargin : implicitWidth
    wrapMode: Text.WordWrap
    horizontalAlignment: Text.AlignHCenter
    color: FiatRatioTheme.secondaryText
    font.pixelSize: Theme.fontSizeMedium
    font.family: FiatRatioTheme.serif
    font.italic: true
}
