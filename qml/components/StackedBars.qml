import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// Months side by side: spending stacked by bucket, a tick for the income.
Canvas {
    id: chart
    property var months: []      // store.history()
    property var buckets: []     // store.buckets()
    property string selected: ""
    signal picked(string periodId)

    implicitHeight: Theme.itemSizeHuge * 1.6

    onMonthsChanged: requestPaint()
    onBucketsChanged: requestPaint()
    onSelectedChanged: requestPaint()
    onWidthChanged: requestPaint()

    Connections {
        target: FiatRatioTheme
        onAmbientChanged: chart.requestPaint()
    }

    function maxValue() {
        var m = 1
        for (var i = 0; i < months.length; ++i)
            m = Math.max(m, Number(months[i].total), Number(months[i].income))
        return m
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (months.length === 0)
            return
        var n = months.length
        var gap = Math.max(2, width / n * 0.25)
        var bw = (width - gap * (n - 1)) / n
        var top = Theme.paddingSmall
        var h = height - Theme.fontSizeTiny - Theme.paddingMedium - top
        var maxV = maxValue()
        var keys = []
        for (var b = 0; b < buckets.length; ++b) keys.push(buckets[b].key)
        keys.push("uncategorised")
        for (var i = 0; i < n; ++i) {
            var m = months[i]
            var x = i * (bw + gap)
            var y = top + h
            ctx.globalAlpha = (selected === "" || selected === m.id) ? 1.0 : 0.45
            for (var k = 0; k < keys.length; ++k) {
                var v = Number(m.buckets[keys[k]] || 0)
                if (v <= 0) continue
                var bh = h * v / maxV
                ctx.fillStyle = FiatRatioTheme.css(FiatRatioTheme.bucketColor(keys[k], k < buckets.length ? buckets[k].color : ""))
                ctx.fillRect(x, y - bh, bw, bh)
                y -= bh
            }
            if (Number(m.income) > 0) {
                ctx.fillStyle = FiatRatioTheme.css(FiatRatioTheme.primaryText)
                ctx.fillRect(x - 1, top + h - h * Number(m.income) / maxV - 1, bw + 2, 2)
            }
            ctx.globalAlpha = 1.0
            if (n <= 12 || i % 2 === (n - 1) % 2) {
                ctx.fillStyle = FiatRatioTheme.css(FiatRatioTheme.secondaryText)
                ctx.font = Math.round(Theme.fontSizeTiny) + "px sans-serif"
                ctx.textAlign = "center"
                ctx.fillText(m.id.substring(5, 7), x + bw / 2, height - Theme.paddingSmall)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (chart.months.length === 0) return
            var i = Math.floor(mouse.x / (chart.width / chart.months.length))
            i = Math.max(0, Math.min(chart.months.length - 1, i))
            chart.picked(chart.months[i].id)
        }
    }
}
