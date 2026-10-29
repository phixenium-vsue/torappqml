import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property string icon: "home"
    property string title: ""
    property bool active: false
    signal clicked()

    implicitHeight: units.gu(6)
    radius: Theme.radiusRow
    color: active ? Theme.bgRowSel : (mouse.containsMouse ? Theme.bgCard2 : "transparent")
    border.width: active ? 1 : 0
    border.color: "#8c4f63ff"

    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        anchors {
            left: parent.left
            leftMargin: units.gu(1.5)
            verticalCenter: parent.verticalCenter
        }
        spacing: units.gu(1.4)

        AppIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            color: root.active ? Theme.teal : Theme.textDim
            size: units.gu(2.4)
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: root.active ? Theme.text : Theme.textDim
            fontSize: "medium"
            font.bold: root.active
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
