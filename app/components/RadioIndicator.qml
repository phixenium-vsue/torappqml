import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Item {
    id: root
    property bool checked: false

    width: units.gu(2.4)
    height: width

    Rectangle {
        id: ring
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: root.checked ? Theme.accent : Theme.textDim2

        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.5
        height: width
        radius: width / 2
        visible: root.checked
        color: Theme.accent
    }
}
