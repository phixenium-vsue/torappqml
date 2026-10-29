import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property string title: ""
    property string body: ""
    property bool opened: false

    signal closed()

    anchors.fill: parent
    color: "#cc000000"
    visible: opened

    function open(t, b) {
        title = t
        body = b
        opened = true
    }

    function close() {
        opened = false
        closed()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - units.gu(6), units.gu(34))
        height: popCol.height + units.gu(4)
        radius: Theme.radiusCard
        color: Theme.bgCard
        border.width: 1
        border.color: Theme.stroke

        MouseArea { anchors.fill: parent }

        Column {
            id: popCol
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: units.gu(2)
                rightMargin: units.gu(2)
            }
            spacing: units.gu(1.6)

            Label {
                width: parent.width
                text: root.title
                color: Theme.text
                fontSize: "large"
                font.bold: true
                wrapMode: Text.WordWrap
            }

            Label {
                width: parent.width
                text: root.body
                color: Theme.textDim
                fontSize: "small"
                wrapMode: Text.WordWrap
            }

            ButtonPrimary {
                width: parent.width
                text: i18n.tr("Понятно")
                onClicked: root.close()
            }
        }
    }
}
