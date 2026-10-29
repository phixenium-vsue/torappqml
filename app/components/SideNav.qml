import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property string currentKey: "home"
    property var toggleStates: ({})

    signal selected(string key)
    signal toggled(string key)
    signal action(string key)

    readonly property var navItems: [
        { type: "nav",    key: "home",    icon: "home",    title: i18n.tr("Главная") },
        { type: "nav",    key: "journal", icon: "journal", title: i18n.tr("Журнал") },
        { type: "action", key: "custom",  icon: "list",    title: i18n.tr("Ввести свои мосты") }
    ]
    readonly property var bindItems: [
        { key: "bindall",       title: i18n.tr("Слушаю 9050 на 0.0.0.0") },
        { key: "forwarderbind", title: i18n.tr("Форвардер на 0.0.0.0") }
    ]
    readonly property var tailItems: [
        { type: "nav", key: "settings", icon: "gear", title: i18n.tr("Настройки") }
    ]

    color: Theme.bgApp

    Column {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: units.gu(1.5)
            rightMargin: units.gu(1.5)
            topMargin: units.gu(2)
        }
        spacing: units.gu(0.6)

        Row {
            width: parent.width
            spacing: units.gu(1.2)

            AppIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "onion"
                color: Theme.accent
                size: units.gu(3)
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "TorApp"
                color: Theme.text
                fontSize: "large"
                font.bold: true
            }
        }

        Item { width: 1; height: units.gu(1.0) }

        Repeater {
            model: root.navItems
            delegate: Loader {
                width: parent.width
                sourceComponent: navComp
                property var item: modelData
            }
        }

        Item {
            width: parent.width
            height: headerLabel.height + units.gu(0.8)

            Label {
                id: headerLabel
                anchors {
                    left: parent.left
                    leftMargin: units.gu(0.8)
                    bottom: parent.bottom
                }
                text: i18n.tr("Настройки binding")
                color: Theme.textDim
                fontSize: "x-small"
            }
        }

        Rectangle {
            width: parent.width
            height: bindColumn.height + units.gu(1.2)
            radius: units.gu(1)
            color: Theme.bgCard2
            border.width: 1
            border.color: Theme.stroke

            Column {
                id: bindColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: units.gu(0.8)
                    rightMargin: units.gu(0.8)
                }
                spacing: units.gu(0.8)

                Repeater {
                    model: root.bindItems
                    delegate: SwitchRow {
                        width: bindColumn.width
                        title: modelData.title
                        checked: root.toggleStates[modelData.key] === true
                        onToggled: root.toggled(modelData.key)
                    }
                }
            }
        }

        Item { width: 1; height: units.gu(1.0) }

        Rectangle {
            width: parent.width
            height: hotspotRow.height + units.gu(1.2)
            radius: units.gu(1)
            color: Theme.bgCard2
            border.width: 1
            border.color: Theme.stroke

            SwitchRow {
                id: hotspotRow
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: units.gu(0.8)
                    rightMargin: units.gu(0.8)
                }
                title: i18n.tr("Раздача по WiFi")
                checked: root.toggleStates["hotspot"] === true
                onToggled: root.toggled("hotspot")
            }
        }

        Repeater {
            model: root.tailItems
            delegate: Loader {
                width: parent.width
                sourceComponent: modelData.type === "toggle" ? toggleComp : navComp
                property var item: modelData
            }
        }
    }

    Component {
        id: navComp
        NavItem {
            width: parent ? parent.width : 0
            icon: item.icon
            title: item.title
            active: item.type === "nav" && item.key === root.currentKey
            onClicked: item.type === "action" ? root.action(item.key) : root.selected(item.key)
        }
    }

    Component {
        id: toggleComp
        SwitchRow {
            width: parent ? parent.width : 0
            title: item.title
            checked: root.toggleStates[item.key] === true
            onToggled: root.toggled(item.key)
        }
    }

    Label {
        anchors {
            left: parent.left
            bottom: parent.bottom
            margins: units.gu(2)
        }
        text: "v1.0 · Tor 0.4.x"
        color: Theme.textDim2
        fontSize: "x-small"
    }
}
