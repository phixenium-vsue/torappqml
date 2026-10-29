import QtQuick 2.12
import "../theme"

Canvas {
    id: root

    property color color: Theme.teal
    property real thickness: 2
    property real angle: 0

    implicitWidth: 18
    implicitHeight: 18

    NumberAnimation on angle {
        running: root.visible
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 900
    }

    onAngleChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var w = width, h = height
        if (w <= 0 || h <= 0) return
        var cx = w / 2, cy = h / 2
        var r = Math.min(w, h) / 2 - thickness
        var rad = angle * Math.PI / 180

        ctx.beginPath()
        ctx.arc(cx, cy, r, 0, Math.PI * 2)
        ctx.strokeStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, 0.25)
        ctx.lineWidth = thickness
        ctx.stroke()

        ctx.beginPath()
        ctx.arc(cx, cy, r, rad, rad + Math.PI * 0.7)
        ctx.strokeStyle = root.color
        ctx.lineWidth = thickness
        ctx.lineCap = "round"
        ctx.stroke()
    }
}
