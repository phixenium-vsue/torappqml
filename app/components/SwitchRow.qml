import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool enabled: true
    signal toggled()

    implicitHeight: Math.max(textCol.height, track.height) + units.gu(1.5)
    opacity: enabled ? 1.0 : 0.5

    Column {
        id: textCol
        anchors {
            left: parent.left
            right: track.left
            rightMargin: units.gu(1.0)
            verticalCenter: parent.verticalCenter
        }
        spacing: units.gu(0.3)

        Label {
            width: parent.width
            text: root.title
            color: Theme.text
            fontSize: "medium"
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            text: root.subtitle
            color: Theme.textDim
            fontSize: "x-small"
            wrapMode: Text.WordWrap
            visible: root.subtitle !== ""
        }
    }

    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: units.gu(4.4)
        height: units.gu(2.4)
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.bgCard2
        border.width: 1
        border.color: root.checked ? Theme.accent : Theme.stroke2

        Rectangle {
            id: knob
            width: units.gu(1.8)
            height: width
            radius: width / 2
            color: "#ffffff"
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - units.gu(0.3) : units.gu(0.3)

            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.InOutQuad } }
        }

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.toggled()
    }
}
