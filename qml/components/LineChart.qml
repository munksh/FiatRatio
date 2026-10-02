import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../js/format.js" as F

// A single series over time, with the zero line when it crosses it.
Canvas {
    id: chart
    property var points: []      // [{date, net}]
    property string valueKey: "net"
    property color lineColor: FiatRatioTheme.accent

    implicitHeight: Theme.itemSizeHuge * 1.3

    onPointsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onLineColorChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (points.length < 2)
            return
        var lo = 0, hi = 0
        for (var i = 0; i < points.length; ++i) {
            var v = Number(points[i][valueKey])
            if (i === 0) { lo = v; hi = v }
            lo = Math.min(lo, v); hi = Math.max(hi, v)
        }
        if (hi === lo) { hi += 1; lo -= 1 }
        var pad = Theme.paddingMedium
        var h = height - 2 * pad
        function yOf(v) { return pad + h - h * (v - lo) / (hi - lo) }
        var step = width / (points.length - 1)
        if (lo < 0 && hi > 0) {
            ctx.strokeStyle = FiatRatioTheme.css(FiatRatioTheme.innerBorder)
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(0, yOf(0)); ctx.lineTo(width, yOf(0))
            ctx.stroke()
        }
        ctx.strokeStyle = FiatRatioTheme.css(lineColor)
        ctx.lineWidth = Math.max(2, Theme.paddingSmall / 2)
        ctx.lineJoin = "round"
        ctx.beginPath()
        for (var j = 0; j < points.length; ++j) {
            var x = j * step, y = yOf(Number(points[j][valueKey]))
            if (j === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
        }
        ctx.stroke()
        ctx.fillStyle = FiatRatioTheme.css(FiatRatioTheme.secondaryText)
        ctx.font = Math.round(Theme.fontSizeTiny) + "px sans-serif"
        ctx.textAlign = "left"
        ctx.textBaseline = "top"
        ctx.fillText(F.plain(hi), 0, 0)
        ctx.textBaseline = "bottom"
        ctx.fillText(F.plain(lo), 0, height)
        var lx = width - 1, ly = yOf(Number(points[points.length - 1][valueKey]))
        ctx.fillStyle = FiatRatioTheme.css(lineColor)
        ctx.beginPath()
        ctx.arc(lx - Theme.paddingSmall, ly, Theme.paddingSmall, 0, 2 * Math.PI)
        ctx.fill()
    }
}
