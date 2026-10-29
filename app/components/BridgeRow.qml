import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property string icon: "bridge"
    property string title: ""
    property string desc: ""
    property string badge: ""
    property bool selected: false
    signal clicked()

    radius: Theme.radiusRow
    color: selected ? Theme.bgRowSel : Theme.bgCard2
    border.width: 1
    border.color: selected ? "#8c4f63ff" : Theme.stroke
    implicitHeight: content.height + units.gu(3)

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Row {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: units.gu(1.6)
            rightMargin: units.gu(1.6)
        }
        spacing: units.gu(1.2)

        RadioIndicator {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.selected
        }

        IconBox {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - units.gu(2.4) - units.gu(4.6) - units.gu(1.2) * 3
                    - (badgeItem.visible ? badgeItem.width : 0)
            spacing: units.gu(0.3)

            Label {
                width: parent.width
                text: root.title
                color: Theme.text
                fontSize: "medium"
                font.bold: true
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                text: root.desc
                color: Theme.textDim
                fontSize: "small"
                wrapMode: Text.WordWrap
                visible: root.desc !== ""
            }
        }

        Badge {
            id: badgeItem
            anchors.verticalCenter: parent.verticalCenter
            text: root.badge
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
