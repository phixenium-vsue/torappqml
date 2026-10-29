import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property string icon: ""
    property color iconColor: Theme.teal

    width: units.gu(4.6)
    height: width
    radius: units.gu(1.3)
    color: Theme.bgCard2
    border.width: 1
    border.color: Theme.stroke

    AppIcon {
        anchors.centerIn: parent
        name: root.icon
        color: root.iconColor
        size: units.gu(2.4)
    }
}
