import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property string placeholder: ""
    property bool mono: false
    signal accepted(string text)
    signal edited(string text)

    implicitHeight: units.gu(5)
    radius: Theme.radiusRow
    color: Theme.bgCard2
    border.width: 1
    border.color: input.activeFocus ? Theme.rowSelBorder : Theme.stroke

    TextInput {
        id: input
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: units.gu(1.2)
            rightMargin: units.gu(1.2)
        }
        color: Theme.text
        font.pixelSize: units.gu(1.7)
        font.family: root.mono ? "Ubuntu Mono" : "Ubuntu"
        selectByMouse: true
        clip: true
        onAccepted: root.accepted(text)
        onEditingFinished: root.edited(text)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: Theme.textDim2
            font: input.font
            visible: input.text === "" && !input.activeFocus
        }
    }
}
