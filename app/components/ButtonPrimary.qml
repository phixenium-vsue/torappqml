import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property string text: ""
    property string iconName: ""
    property bool square: false
    property string variant: "primary"   // "primary" | "flat"
    property bool busy: false
    property bool enabled: true
    signal clicked()

    implicitHeight: units.gu(6)
    implicitWidth: contentRow.width + units.gu(3)
    radius: Theme.radiusBtn
    opacity: enabled ? 1.0 : 0.5

    color: variant === "flat"
           ? (mouse.pressed ? "#24305a" : "#1c2748")
           : "transparent"
    border.width: variant === "flat" ? 1 : 0
    border.color: Theme.stroke2
    scale: mouse.pressed ? 0.94 : 1.0

    Behavior on scale {
        SpringAnimation { spring: 3.2; damping: 0.35; epsilon: 0.005 }
    }

    Gradient {
        id: grad
        GradientStop { position: 0.0; color: Theme.accent }
        GradientStop { position: 1.0; color: Theme.accent2 }
    }
    Gradient {
        id: gradNone
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 1.0; color: "transparent" }
    }
    gradient: variant === "primary" ? grad : gradNone

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: units.gu(1.1)

        Rectangle {
            visible: root.square
            anchors.verticalCenter: parent.verticalCenter
            width: units.gu(1.6); height: width; radius: units.gu(0.4)
            color: "#cdd5ea"
        }

        AppIcon {
            visible: !root.square && root.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.iconName
            color: "#ffffff"
            size: units.gu(2)
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: "#ffffff"
            fontSize: "medium"
            font.bold: true
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
