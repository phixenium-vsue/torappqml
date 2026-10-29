import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property string current: ""
    property bool expanded: false
    property bool customEnabled: false

    signal selected(string key)
    signal customRequested()

    readonly property var options: [
        { key: "obfs4",     label: "obfs4" },
        { key: "webtunnel", label: "WebTunnel" },
        { key: "local",     label: "Из файла" },
        { key: "custom",    label: "Свои мосты", custom: true }
    ]

    function labelOf(k) {
        for (var i = 0; i < options.length; i++)
            if (options[i].key === k) return options[i].label
        return ""
    }

    radius: Theme.radiusRow
    color: Theme.bgCard2
    border.width: 1
    border.color: root.expanded ? Theme.rowSelBorder : Theme.stroke
    implicitHeight: col.height + units.gu(2.6)

    Column {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: units.gu(1.6)
            rightMargin: units.gu(1.6)
        }
        spacing: units.gu(1)

        Item {
            width: parent.width
            height: header.height

            Row {
                id: header
                width: parent.width
                spacing: units.gu(1.2)

                IconBox {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "bridge"
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - units.gu(4.6) - units.gu(3) - units.gu(1.2) * 2
                    spacing: units.gu(0.2)

                    Label {
                        width: parent.width
                        text: i18n.tr("Выбор мостов")
                        color: Theme.textDim
                        fontSize: "x-small"
                    }
                    Label {
                        width: parent.width
                        text: root.current === "" ? i18n.tr("Не выбран") : root.labelOf(root.current)
                        color: Theme.text
                        fontSize: "medium"
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }

                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.expanded ? "chevD" : "chevR"
                    color: Theme.teal
                    size: units.gu(2.2)
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.expanded = !root.expanded
            }
        }

        Column {
            id: list
            width: parent.width
            spacing: units.gu(0.8)
            visible: root.expanded

            Repeater {
                model: root.options
                delegate: Rectangle {
                    width: parent.width
                    height: units.gu(5)
                    radius: Theme.radiusRow
                    color: selected ? Theme.bgRowSel : "transparent"
                    readonly property bool disabled: modelData.custom === true && !root.customEnabled
                    readonly property bool selected: root.current === modelData.key
                    opacity: disabled ? 0.5 : 1.0

                    Row {
                        anchors {
                            left: parent.left
                            leftMargin: units.gu(1)
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: units.gu(1.2)

                        RadioIndicator {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: root.current === modelData.key
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: Theme.text
                            fontSize: "medium"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (modelData.custom === true && !root.customEnabled) {
                                root.customRequested()
                            } else {
                                root.current = modelData.key
                                root.expanded = false
                                root.selected(modelData.key)
                            }
                        }
                    }
                }
            }
        }
    }
}
