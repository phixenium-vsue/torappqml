import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool alert: false
    property color activeDotColor: Theme.teal
    property bool interactive: true
    // Вариант A: плитка-контур с тумблером внутри (сама плитка не нажимается).
    property bool showSwitch: false
    property bool switchChecked: false

    signal clicked()
    signal switchToggled()

    implicitHeight: root.subtitle !== "" ? units.gu(6.0) : units.gu(5.5)
    radius: units.gu(1.2)
    color: root.alert ? Theme.orangeSoft : Theme.bgCard2
    border.width: 1
    border.color: root.alert ? Theme.orange : Theme.stroke
    opacity: interactive ? 1.0 : 0.5

    Behavior on color { ColorAnimation { duration: 120 } }

    // --- контур с тумблером внутри: реагирует только сам тумблер ---
    Row {
        visible: root.showSwitch
        anchors.fill: parent
        anchors.leftMargin: units.gu(1.6)
        anchors.rightMargin: units.gu(1.2)
        spacing: units.gu(1)

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - switchTrack.width - parent.spacing
            spacing: units.gu(0.1)

            Label {
                width: parent.width
                text: root.title
                color: Theme.text
                fontSize: "small"
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Theme.textDim
                fontSize: "x-small"
            }
        }

        Rectangle {
            id: switchTrack
            anchors.verticalCenter: parent.verticalCenter
            width: units.gu(3.6)
            height: units.gu(2.0)
            radius: height / 2
            color: root.switchChecked ? Theme.accent : Theme.bgCard
            border.width: 1
            border.color: root.switchChecked ? Theme.accent : Theme.stroke2

            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                width: units.gu(1.5); height: width; radius: width / 2
                color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter
                x: root.switchChecked ? parent.width - width - units.gu(0.25)
                                      : units.gu(0.25)
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.InOutQuad } }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.interactive
                onClicked: root.switchToggled()
            }
        }
    }

    // --- обычный вариант: точка + подпись по центру ---
    Row {
        visible: !root.showSwitch
        anchors.centerIn: parent
        spacing: units.gu(0.8)

        Item {
            id: dotWrap
            anchors.verticalCenter: parent.verticalCenter
            width: units.gu(0.9); height: width

            Rectangle {
                anchors.centerIn: parent
                width: units.gu(1.7); height: width; radius: width / 2
                visible: root.active && !root.alert
                color: Theme.phosphorGlow
            }
            Rectangle {
                anchors.centerIn: parent
                width: units.gu(0.9); height: width; radius: width / 2
                color: root.alert ? Theme.orange
                                  : (root.active ? root.activeDotColor : Theme.textDim2)
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: (root.active || root.alert) ? Theme.text : Theme.textDim
            fontSize: "small"
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive && !root.showSwitch
        onClicked: root.clicked()
    }
}
