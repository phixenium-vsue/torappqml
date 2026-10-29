import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Row {
    id: root

    property string text: ""
    property color dotColor: Theme.green
    property color textColor: Theme.text
    property real fontSize: units.gu(2.4)
    property bool bold: true
    property bool pulse: false

    spacing: units.gu(1)

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: units.gu(1.1)
        height: width
        radius: width / 2
        color: root.dotColor
        opacity: 1

        SequentialAnimation on opacity {
            running: root.pulse
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.35; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
        }
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.textColor
        font.pixelSize: root.fontSize
        font.bold: root.bold
    }
}
