import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Canvas {
    id: root

    renderStrategy: Canvas.Cooperative
    opacity: 0.85

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    function ridge(ctx, baseY, peak, color1, color2, phase) {
        var w = width, h = height
        var g = ctx.createLinearGradient(0, baseY - peak, 0, h)
        g.addColorStop(0, color1)
        g.addColorStop(1, color2)
        ctx.fillStyle = g
        ctx.beginPath()
        ctx.moveTo(0, h)
        ctx.lineTo(0, baseY)
        var steps = 6
        for (var i = 0; i <= steps; i++) {
            var x = (w / steps) * i
            var y = baseY - Math.abs(Math.sin(i * 1.7 + phase)) * peak
            ctx.lineTo(x, y)
        }
        ctx.lineTo(w, baseY)
        ctx.lineTo(w, h)
        ctx.closePath()
        ctx.fill()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (width <= 0 || height <= 0) return
        ridge(ctx, height * 0.78, height * 0.28, Theme.mountA1, Theme.mountA2, 0.4)
        ridge(ctx, height * 0.9, height * 0.2, Theme.mountB1, Theme.mountB2, 1.6)
    }
}
