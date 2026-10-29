import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property var options: []          // [{ key: "x", label: "…" }, …]
    property string current: ""
    property color activeDotColor: Theme.teal
    signal selected(string key)

    implicitHeight: units.gu(5)
    radius: units.gu(1.2)
    color: Theme.bgCard2
    border.width: 1
    border.color: Theme.stroke

    Row {
        id: row
        anchors.fill: parent
        anchors.margins: units.gu(0.35)
        spacing: units.gu(0.35)

        Repeater {
            model: root.options
            delegate: Rectangle {
                id: seg
                property bool active: root.current === modelData.key
                property bool disabled: modelData.disabled === true
                width: row.width > 0
                       ? (row.width - (row.spacing * (root.options.length - 1))) / Math.max(1, root.options.length)
                       : 0
                height: row.height
                radius: units.gu(0.9)
                color: seg.active ? Theme.bgRowSel : "transparent"
                border.width: seg.active ? 1 : 0
                border.color: Theme.rowSelBorder
                opacity: seg.disabled ? 0.4 : 1.0

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: units.gu(0.5)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(0.7); height: width; radius: width / 2
                        visible: seg.active
                        color: root.activeDotColor
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, seg.width - units.gu(1.4))
                        text: modelData.label
                        color: seg.active ? Theme.text : Theme.textDim
                        fontSize: "x-small"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !seg.disabled
                    onClicked: root.selected(modelData.key)
                }
            }
        }
    }
}
