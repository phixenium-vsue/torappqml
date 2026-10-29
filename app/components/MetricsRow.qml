import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property string country: ""
    property string iso: ""
    property string ip: "—"
    property string session: "00:00:00"
    property string node: "—"
    property bool ipBusy: false

    signal ipClicked()

    readonly property real pad: units.gu(1.2)
    readonly property real valueRowH: units.gu(3.4)
    readonly property real countryW: width * 0.22
    readonly property real timeW: width * 0.375
    readonly property real ipW: width - countryW - timeW

    radius: Theme.radiusCard
    color: Theme.bgCard
    border.width: 1
    border.color: Theme.stroke
    implicitHeight: timeCol.implicitHeight + pad * 2

    MetricCell {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: root.countryW
        icon: "pin"
        label: i18n.tr("Страна")
        value: root.iso || "—"
        trailingType: "flag"
        iso: root.iso
        pad: root.pad
        valueRowHeight: root.valueRowH
        centerValue: true
    }

    MetricCell {
        id: ipCell
        anchors { left: parent.left; leftMargin: root.countryW; top: parent.top; bottom: parent.bottom }
        width: root.ipW
        icon: "globe"
        label: i18n.tr("Выходной IP")
        value: root.ip
        busy: root.ipBusy
        pad: root.pad
        valueRowHeight: root.valueRowH
    }

    Item {
        id: timeCell
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: root.timeW

        Column {
            id: timeCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: root.pad
                leftMargin: root.pad
                rightMargin: root.pad
            }
            spacing: units.gu(0.5)

            Row {
                spacing: units.gu(0.6)
                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "clock"
                    color: Theme.teal
                    size: units.gu(2)
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: i18n.tr("Время")
                    color: Theme.textDim
                    fontSize: "x-small"
                }
            }

            Item {
                width: parent.width
                height: root.valueRowH
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    text: root.session
                    color: Theme.text
                    fontSize: "small"
                    font.bold: true
                }
            }

            Row {
                width: parent.width
                spacing: units.gu(0.4)
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.node
                    color: Theme.text
                    fontSize: "small"
                    font.bold: true
                }
                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "globe"
                    color: Theme.teal
                    size: units.gu(1.7)
                }
            }
        }
    }

    Rectangle {
        anchors.fill: ipCell
        color: Theme.rowSelBorder
        opacity: mouse.pressed ? 0.18 : 0.0
        Behavior on opacity { NumberAnimation { duration: 90 } }
    }

    MouseArea {
        id: mouse
        anchors.fill: ipCell
        onClicked: root.ipClicked()
    }

    Rectangle {
        width: 1; height: parent.height - units.gu(2.5); y: units.gu(1.25)
        x: root.countryW
        color: Theme.stroke
    }
    Rectangle {
        width: 1; height: parent.height - units.gu(2.5); y: units.gu(1.25)
        x: parent.width - root.timeW
        color: Theme.stroke
    }
}
