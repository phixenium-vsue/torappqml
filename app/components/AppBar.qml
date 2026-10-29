import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property string title: "TorApp"
    property bool canGoBack: false
    property string rightText: ""

    signal menuClicked()
    signal backClicked()
    signal themeToggled()
    signal rightClicked()

    height: units.gu(7)
    color: Theme.bgApp

    Item {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: units.gu(7)

        AppIcon {
            anchors.centerIn: parent
            name: root.canGoBack ? "chevL" : "burger"
            color: Theme.text
            size: units.gu(2.6)
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.canGoBack ? root.backClicked() : root.menuClicked()
        }
    }

    Label {
        anchors.centerIn: parent
        text: root.title
        color: Theme.text
        fontSize: "large"
        font.bold: true
    }

    Row {
        anchors { right: parent.right; rightMargin: units.gu(1); verticalCenter: parent.verticalCenter }
        spacing: units.gu(1.5)

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.rightText
            color: Theme.teal
            fontSize: "small"
            font.bold: true
            visible: root.rightText !== ""

            MouseArea {
                anchors.fill: parent
                anchors.margins: -units.gu(1)
                onClicked: root.rightClicked()
            }
        }

        Item {
            width: units.gu(4)
            height: units.gu(4)
            anchors.verticalCenter: parent.verticalCenter

            AppIcon {
                anchors.centerIn: parent
                name: Theme.dark ? "sun" : "moon"
                color: Theme.text
                size: units.gu(2.5)
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.themeToggled()
            }
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.stroke
    }
}
