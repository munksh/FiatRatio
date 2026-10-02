import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// One horizontal bar split by share. Each share is { key, amount }; the colour
// is the bucket's. Segments too thin to see are still drawn at a hairline.
Item {
    id: bar
    property var shares: []
    readonly property real total: {
        var t = 0
        for (var i = 0; i < shares.length; ++i) t += Math.max(0, Number(shares[i].amount))
        return t
    }

    implicitHeight: Theme.paddingLarge * 1.6

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: FiatRatioTheme.innerBorder
    }
    Row {
        anchors.fill: parent
        spacing: 1
        Repeater {
            model: bar.shares
            Rectangle {
                height: bar.height
                width: bar.total > 0 ? Math.max(2, (bar.width - bar.shares.length) * Math.max(0, Number(modelData.amount)) / bar.total) : 0
                color: FiatRatioTheme.bucketColor(modelData.key, "")
            }
        }
    }
}
