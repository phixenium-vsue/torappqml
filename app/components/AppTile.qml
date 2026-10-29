import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Item {
    id: root

    property string appName: ""
    property string iconSource: ""
    property bool installed: true
    property bool proxied: false
    property bool tileEnabled: true

    signal toggled()

    readonly property bool usable: installed && tileEnabled

    implicitWidth: units.gu(7.5)
    implicitHeight: box.height + label.height + units.gu(1.6)
    width: implicitWidth
    height: implicitHeight
    opacity: installed ? (tileEnabled ? 1.0 : 0.45) : 0.35

    Rectangle {
        id: box
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: width
        radius: Theme.radiusRow
        color: root.proxied ? Theme.bgRowSel : Theme.bgCard2
        border.width: root.proxied ? 2 : 1
        border.color: root.proxied ? Theme.phosphor : Theme.stroke
        scale: mouse.pressed && root.usable ? 0.95 : 1.0

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

        Image {
            id: img
            anchors.centerIn: parent
            width: parent.width - units.gu(2.2)
            height: width
            source: root.installed ? root.iconSource : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            visible: status === Image.Ready
        }

        Label {
            anchors.centerIn: parent
            text: img.visible ? "" : (root.installed ? "?" : "∅")
            color: Theme.textDim2
            fontSize: "large"
            font.bold: true
        }

        Item {
            id: dotWrap
            anchors { right: parent.right; top: parent.top; margins: units.gu(0.7) }
            width: units.gu(1.3); height: width
            visible: root.proxied

            Rectangle {
                anchors.centerIn: parent
                width: units.gu(2.4); height: width; radius: width / 2
                color: Theme.phosphorGlow
            }
            Rectangle {
                anchors.centerIn: parent
                width: units.gu(1.3); height: width; radius: width / 2
                color: Theme.phosphor
            }
        }
    }

    Label {
        id: label
        anchors {
            top: box.bottom
            topMargin: units.gu(0.6)
            left: parent.left
            right: parent.right
        }
        text: root.appName
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: root.proxied ? Theme.text : Theme.textDim
        fontSize: "x-small"
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        onClicked: root.toggled()
    }
}
