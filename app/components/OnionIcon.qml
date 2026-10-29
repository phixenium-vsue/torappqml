import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Item {
    id: root

    property bool on: false
    property bool connecting: false
    property int progress: 0
    property bool interactive: true
    property real spinAngle: 0
    property real pressGlow: 0

    signal clicked()

    implicitWidth: units.gu(12)
    implicitHeight: units.gu(12)

    Item {
        id: stack
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        scale: mouse.pressed ? 0.92 : 1.0

        Behavior on scale {
            SpringAnimation { spring: 3.4; damping: 0.34; epsilon: 0.005 }
        }

        Canvas {
            id: ring
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative

            Component.onCompleted: requestPaint()

            Connections {
                target: root
                onSpinAngleChanged: ring.requestPaint()
                onOnChanged: ring.requestPaint()
                onConnectingChanged: ring.requestPaint()
                onProgressChanged: ring.requestPaint()
                onPressGlowChanged: ring.requestPaint()
            }

            readonly property color trackColor: root.on ? Theme.onionOn1 : Theme.onionOff1

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width, h = height
                if (w <= 0 || h <= 0) return
                var cx = w / 2, cy = h / 2
                var ringR = Math.min(w, h) * 0.45
                var ringW = Math.min(w, h) * 0.045
                var startA = -Math.PI / 2
                ctx.lineCap = "round"

                if (root.connecting) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, ringR, 0, Math.PI * 2)
                    ctx.strokeStyle = Qt.rgba(trackColor.r, trackColor.g, trackColor.b, 0.18)
                    ctx.lineWidth = ringW
                    ctx.stroke()

                    var frac = Math.max(0.02, Math.min(1, root.progress / 100))
                    ctx.beginPath()
                    ctx.arc(cx, cy, ringR, startA, startA + Math.PI * 2 * frac)
                    ctx.strokeStyle = Theme.green
                    ctx.lineWidth = ringW
                    ctx.stroke()

                    var rad = root.spinAngle * Math.PI / 180
                    ctx.beginPath()
                    ctx.arc(cx, cy, ringR, rad, rad + Math.PI * 0.22)
                    ctx.strokeStyle = "#ffffff"
                    ctx.lineWidth = ringW * 0.7
                    ctx.stroke()
                } else if (root.on) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, ringR, 0, Math.PI * 2)
                    ctx.strokeStyle = Theme.green
                    ctx.lineWidth = ringW
                    ctx.stroke()
                }

                if (root.pressGlow > 0.01) {
                    var haloR = ringR * (1.06 + 0.06 * root.pressGlow)
                    ctx.beginPath()
                    ctx.arc(cx, cy, haloR, 0, Math.PI * 2)
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.55 * root.pressGlow)
                    ctx.lineWidth = ringW * (1.0 + 1.6 * root.pressGlow)
                    ctx.stroke()
                }
            }
        }

        Image {
            anchors.centerIn: parent
            width: parent.width * 0.74
            height: width
            source: Qt.resolvedUrl("onion.png")
            sourceSize.width: width
            sourceSize.height: height
            smooth: true
            fillMode: Image.PreserveAspectFit
        }
    }

    NumberAnimation on spinAngle {
        running: root.connecting
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 1100
    }

    Behavior on pressGlow {
        NumberAnimation { duration: 150 }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        onPressedChanged: root.pressGlow = pressed ? 1.0 : 0.0
        onClicked: root.clicked()
    }
}
