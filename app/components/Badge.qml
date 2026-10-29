import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root
    property string text: ""

    implicitWidth: label.implicitWidth + units.gu(2.5)
    implicitHeight: label.implicitHeight + units.gu(1)
    radius: height / 2
    color: Theme.greenSoft
    visible: root.text !== ""

    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Theme.green
        fontSize: "small"
        font.bold: true
    }
}
