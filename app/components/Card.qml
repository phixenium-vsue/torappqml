import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string headerIcon: ""
    property color iconColor: Theme.teal
    property string rightText: ""
    property string rightIcon: ""
    signal rightClicked()

    default property alias content: body.data

    color: Theme.bgCard
    radius: Theme.radiusCard
    border.width: 1
    border.color: Theme.stroke
    implicitHeight: layout.height + units.gu(4)

    Column {
        id: layout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: units.gu(2)
        }
        spacing: units.gu(1.6)

        Item {
            id: head
            width: parent.width
            height: Math.max(titleCol.height, hbox.height, rightBox.height, units.gu(1))
            visible: root.title !== "" || root.headerIcon !== ""

            IconBox {
                id: hbox
                visible: root.headerIcon !== ""
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                icon: root.headerIcon
                iconColor: root.iconColor
            }

            Column {
                id: titleCol
                anchors.left: hbox.visible ? hbox.right : parent.left
                anchors.leftMargin: hbox.visible ? units.gu(1.4) : 0
                anchors.right: rightBox.left
                anchors.rightMargin: units.gu(1)
                anchors.verticalCenter: parent.verticalCenter
                spacing: units.gu(0.3)

                Label {
                    text: root.title
                    color: Theme.text
                    fontSize: "medium"
                    font.bold: true
                    visible: root.title !== ""
                }
                Label {
                    width: parent.width
                    text: root.subtitle
                    color: Theme.textDim
                    fontSize: "small"
                    wrapMode: Text.WordWrap
                    visible: root.subtitle !== ""
                }
            }

            Item {
                id: rightBox
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(rightLabel.visible ? rightLabel.implicitWidth : 0,
                                rightIconItem.visible ? rightIconItem.width : 0)
                height: Math.max(rightLabel.visible ? rightLabel.implicitHeight : 0,
                                 rightIconItem.visible ? rightIconItem.height : 0)

                Label {
                    id: rightLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.rightText
                    color: Theme.teal
                    fontSize: "small"
                    visible: text !== ""
                }

                AppIcon {
                    id: rightIconItem
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.rightIcon
                    color: Theme.teal
                    size: units.gu(2.6)
                    visible: root.rightIcon !== ""
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -units.gu(1)
                    visible: root.rightText !== "" || root.rightIcon !== ""
                    onClicked: root.rightClicked()
                }
            }
        }

        Column {
            id: body
            width: parent.width
            spacing: units.gu(1.2)
        }
    }
}
