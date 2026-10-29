import QtQuick 2.12
import Lomiri.Components 1.3
import "../theme"

Rectangle {
    id: root

    property bool connected: false
    property bool connecting: false
    property int bootPercent: 0
    property string bridgeMode: ""
    property bool customBridgesEnabled: false
    property bool systemVpn: false
    property bool vpnLeftover: false
    property bool forwarder: false
    property string exitIp: ""
    property bool nodeStale: false
    property string netState: "unknown"

    signal onionClicked()
    signal bridgeSelected(string key)
    signal bridgeCustomRequested()
    signal systemVpnClicked()
    signal forwarderClicked()
    signal healthClicked()

    // Объединённый индикатор «здоровья»: сеть + свежесть узла.
    //   зелёный — сеть есть и узел актуален
    //   жёлтый  — сеть есть, но узел не обновляется (или портал авторизации)
    //   красный — сети нет
    readonly property bool netOk: netState === "full" || netState === "limited"
    readonly property color healthColor: !netOk ? Theme.red
                                       : (nodeStale || netState === "portal")
                                         ? Theme.yellow : Theme.green
    readonly property string healthHint: !netOk ? i18n.tr("Нет сети")
                                       : netState === "portal" ? i18n.tr("Требуется вход в сеть")
                                       : nodeStale ? i18n.tr("Узел не обновляется")
                                       : i18n.tr("Сеть в порядке")

    readonly property color statusColor: connected ? Theme.green
                                       : (connecting ? Theme.yellow : Theme.textDim2)
    readonly property string statusText: connected ? i18n.tr("Подключено")
                                       : (connecting ? i18n.tr("Подключение…") : i18n.tr("Отключено"))
    readonly property string subtitle: connected
                                       ? (root.nodeStale
                                          ? i18n.tr("Трафик защищён · узел обновляется…")
                                          : i18n.tr("Трафик защищён · выход: ") + (root.exitIp || "—"))
                                       : (connecting
                                          ? (root.bootPercent > 0
                                             ? i18n.tr("Загрузка сети Tor… ") + root.bootPercent + "%"
                                             : i18n.tr("Устанавливаем соединение…"))
                                          : i18n.tr("нажмите на луковицу чтобы подключиться"))

    radius: Theme.radiusCard
    clip: true
    implicitHeight: content.height + units.gu(4.5)

    Gradient {
        id: heroGrad
        GradientStop { position: 0.0; color: Theme.heroTop }
        GradientStop { position: 0.55; color: Theme.heroMid }
        GradientStop { position: 1.0; color: Theme.heroBot }
    }
    gradient: heroGrad

    SceneMountains { anchors.fill: parent }

    Column {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: units.gu(2)
            rightMargin: units.gu(2)
            topMargin: units.gu(2)
        }
        spacing: units.gu(2)

        Row {
            width: parent.width
            spacing: units.gu(1.5)

            Column {
                width: parent.width - onion.width - units.gu(1.5)
                anchors.verticalCenter: parent.verticalCenter
                spacing: units.gu(0.8)

                Row {
                    spacing: units.gu(0.9)

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Tor"
                        color: Theme.text
                        font.pixelSize: units.gu(3)
                        font.bold: true
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(1.1); height: width; radius: width / 2
                        color: root.statusColor
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.statusText
                        color: Theme.text
                        font.pixelSize: units.gu(2.4)
                    }
                    // Индикатор-«светофор»: сеть + свежесть узла (нажмите — обновить)
                    Rectangle {
                        id: health
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(1.4); height: width; radius: width / 2
                        color: root.healthColor
                        border.width: units.dp(1)
                        border.color: Qt.rgba(0, 0, 0, 0.25)
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -units.gu(0.6)
                            onClicked: root.healthClicked()
                        }
                    }
                }

                Label {
                    width: parent.width
                    text: root.subtitle
                    color: Theme.textDim
                    fontSize: "small"
                    wrapMode: Text.WordWrap
                }
            }

            OnionIcon {
                id: onion
                width: units.gu(10)
                height: units.gu(10)
                on: root.connected
                connecting: root.connecting
                progress: root.bootPercent
                onClicked: root.onionClicked()
            }
        }

        BridgePicker {
            width: parent.width
            current: root.bridgeMode
            customEnabled: root.customBridgesEnabled
            onSelected: root.bridgeSelected(key)
            onCustomRequested: root.bridgeCustomRequested()
        }

        Row {
            width: parent.width
            spacing: units.gu(1.2)

            PillTile {
                width: (parent.width - units.gu(1.2)) / 2
                title: i18n.tr("VPN")
                subtitle: i18n.tr("вся система")
                alert: root.vpnLeftover
                showSwitch: true
                switchChecked: root.systemVpn
                onSwitchToggled: root.systemVpnClicked()
            }
            PillTile {
                width: (parent.width - units.gu(1.2)) / 2
                title: i18n.tr("Форвардинг")
                subtitle: "8118"
                showSwitch: true
                switchChecked: root.forwarder
                onSwitchToggled: root.forwarderClicked()
            }
        }
    }
}
