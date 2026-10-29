import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Item {
    id: root

    property string title: ""
    property string iconName: ""
    property bool enabled: true
    signal clicked()

    implicitHeight: units.gu(8)
    scale: mouse.pressed ? 0.97 : 1.0
    opacity: enabled ? 1.0 : 0.5

    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

    Rectangle {
        id: shadow
        anchors.fill: button
        anchors.topMargin: units.gu(0.6)
        anchors.leftMargin: units.gu(0.3)
        anchors.rightMargin: units.gu(0.3)
        radius: button.radius
        color: "#000000"
        opacity: mouse.pressed ? 0.15 : 0.45

        Behavior on opacity { NumberAnimation { duration: 90 } }
    }

    Rectangle {
        id: button
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.implicitHeight - units.gu(0.6)
        radius: Theme.radiusBtn

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.accent }
            GradientStop { position: 1.0; color: Theme.accent2 }
        }

        Rectangle {
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: units.gu(0.4); rightMargin: units.gu(0.4); topMargin: units.gu(0.4)
            }
            height: parent.height * 0.42
            radius: parent.radius - units.gu(0.3)
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#40ffffff" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: units.gu(1.2)

            AppIcon {
                visible: root.iconName !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: root.iconName
                color: "#ffffff"
                size: units.gu(2.6)
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                color: "#ffffff"
                fontSize: "large"
                font.bold: true
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
