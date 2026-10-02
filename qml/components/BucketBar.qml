import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// One bar for the month: spent per bucket (solid), planned (faded), and what
// is left, against the income. When spending passes income the bar scales to
// the spending and the overflow is marked.
Item {
    id: bar
    property var buckets: []          // [{key, color}]
    property var spent: ({})
    property var planned: ({})
    property real income: 0

    implicitHeight: Theme.paddingLarge * 1.6

    readonly property real total: {
        var t = 0
        for (var k in spent) t += Number(spent[k])
        for (var p in planned) t += Number(planned[p])
        return t
    }
    readonly property real scale: Math.max(income, total, 1)

    function segments() {
        var out = []
        var keys = []
        for (var i = 0; i < buckets.length; ++i) keys.push(buckets[i].key)
        if (keys.indexOf("uncategorised") < 0) keys.push("uncategorised")
        for (var j = 0; j < keys.length; ++j) {
            var b = buckets[j] || { key: keys[j], color: "" }
            var s = Number(spent[keys[j]] || 0)
            var p = Number(planned[keys[j]] || 0)
            var c = FiatRatioTheme.bucketColor(keys[j], b.color)
            if (s > 0) out.push({ w: s, c: c, o: 1.0 })
            if (p > 0) out.push({ w: p, c: c, o: 0.35 })
        }
        return out
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: FiatRatioTheme.innerBorder
    }
    Row {
        id: row
        anchors.fill: parent
        Repeater {
            model: bar.segments()
            Rectangle {
                width: Math.max(1, bar.width * modelData.w / bar.scale)
                height: row.height
                color: modelData.c
                opacity: modelData.o
            }
        }
    }
    Rectangle {
        visible: bar.total > bar.income && bar.income > 0
        x: bar.width * bar.income / bar.scale - width / 2
        width: 2
        height: parent.height + Theme.paddingSmall * 2
        anchors.verticalCenter: parent.verticalCenter
        color: FiatRatioTheme.wrong
    }
}
