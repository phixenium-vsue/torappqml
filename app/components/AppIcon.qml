import QtQuick 2.12
import Lomiri.Components 1.3
import "icons.js" as Icons
import "svgpath.js" as Svg

Item {
    id: root

    property string name: "dot"
    property color color: "#2dd4bf"
    property real size: units.gu(2.4)

    readonly property var def: Icons.map[root.name] || Icons.map["dot"]

    width: size
    height: size

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            var ctx = getContext("2d")
            ctx.save()
            ctx.clearRect(0, 0, width, height)
            var s = width / 24
            ctx.scale(s, s)
            ctx.lineWidth = 1.8
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            var col = "rgba(" + Math.round(root.color.r * 255) + ","
                    + Math.round(root.color.g * 255) + ","
                    + Math.round(root.color.b * 255) + "," + root.color.a + ")"
            var paths = root.def.paths
            for (var k = 0; k < paths.length; k++) {
                var p = paths[k]
                ctx.beginPath()
                Svg.drawPath(ctx, p.d)
                if (p.fill) { ctx.fillStyle = col; ctx.fill() }
                else { ctx.strokeStyle = col; ctx.stroke() }
            }
            ctx.restore()
        }
    }

    onColorChanged: canvas.requestPaint()
    onNameChanged: canvas.requestPaint()
    onSizeChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()
}
