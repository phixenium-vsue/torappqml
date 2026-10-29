import QtQuick 2.12
import Lomiri.Components 1.3
import "../components"
import "../theme"
import "../state"

Item {
    id: page

    signal back()

    property string newSource: ""
    property bool showCheck: false

    AppBar {
        id: appbar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        canGoBack: true
        title: i18n.tr("Настройки")
        onBackClicked: page.back()
    }

    Flickable {
        id: flick
        anchors {
            left: parent.left
            right: parent.right
            top: appbar.bottom
            bottom: parent.bottom
        }
        contentHeight: col.height + units.gu(4)
        clip: true

        Column {
            id: col
            x: units.gu(1.6)
            y: units.gu(1.6)
            width: flick.width - units.gu(3.2)
            spacing: units.gu(1.4)

            // ---- sources ----
            Row {
                width: parent.width
                spacing: units.gu(0.8)

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: i18n.tr("Источники мостов (URL)")
                    color: Theme.textDim
                    fontSize: "small"
                }
                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "check"
                    color: Theme.green
                    size: units.gu(2)
                    visible: page.showCheck
                }
            }
            Label {
                width: parent.width
                text: i18n.tr("Это ссылки на файлы со списками мостов. При старте obfs4/webtunnel списки обновляются отсюда.")
                color: Theme.textDim2
                fontSize: "x-small"
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: App.sources
                delegate: Rectangle {
                    width: col.width
                    height: Math.max(srcLabel.height + units.gu(1.6), units.gu(5))
                    radius: Theme.radiusRow
                    color: Theme.bgCard2
                    border.width: 1
                    border.color: Theme.stroke

                    Label {
                        id: srcLabel
                        anchors {
                            left: parent.left
                            right: delBtn.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: units.gu(1.2)
                            rightMargin: units.gu(1)
                        }
                        text: modelData
                        color: Theme.text
                        fontSize: "x-small"
                        font.family: "Ubuntu Mono"
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        id: delBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: units.gu(0.8) }
                        width: units.gu(3.4); height: units.gu(3.4)
                        radius: width / 2
                        color: mouseDel.pressed ? Theme.bgRowSel : "transparent"
                        AppIcon {
                            anchors.centerIn: parent
                            name: "close"
                            color: Theme.textDim
                            size: units.gu(1.8)
                        }
                        MouseArea {
                            id: mouseDel
                            anchors.fill: parent
                            onClicked: {
                                var arr = App.sources.slice()
                                arr.splice(index, 1)
                                App.sources = arr
                                App.setSetting("sources", arr)
                            }
                        }
                    }
                }
            }

            TextField {
                id: newSrcField
                width: parent.width
                placeholder: i18n.tr("https://…/bridges.txt")
                mono: true
                onEdited: page.newSource = text
                onAccepted: {
                    page.newSource = text
                    addSource()
                }
            }
            ButtonPrimary {
                width: parent.width
                text: i18n.tr("Добавить")
                iconName: "check"
                onClicked: {
                    page.newSource = newSrcField.text
                    addSource()
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.stroke }

            SwitchRow {
                width: parent.width
                title: i18n.tr("Автообновление при старте")
                subtitle: i18n.tr("Скачивать свежие списки перед подключением (obfs4/webtunnel)")
                checked: App.autoUpdate
                onToggled: App.setSetting("autoUpdate", !App.autoUpdate)
            }

            ButtonPrimary {
                width: parent.width
                text: i18n.tr("Обновить мосты сейчас")
                iconName: "list"
                onClicked: {
                    App.updateBridges()
                    flashCheck()
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.stroke }

            Label {
                text: i18n.tr("Сервис определения IP")
                color: Theme.textDim
                fontSize: "small"
            }
            TextField {
                id: ipField
                width: parent.width
                text: App.ipService
                placeholder: "https://ifconfig.co/json"
                mono: true
                onAccepted: App.setSetting("ipService", text)
                onEdited: App.setSetting("ipService", text)
            }

            Rectangle { width: parent.width; height: 1; color: Theme.stroke }

            // ---- advanced: system VPN ----
            Label {
                text: i18n.tr("Продвинутое: Системный VPN")
                color: Theme.textDim
                fontSize: "small"
            }
            Label {
                width: parent.width
                text: i18n.tr("Настройки применяются к системному VPN (все приложения). Изменения вступают в силу сразу, если VPN включён.")
                color: Theme.textDim2
                fontSize: "x-small"
                wrapMode: Text.WordWrap
            }

            Label {
                text: i18n.tr("DNS")
                color: Theme.text
                fontSize: "small"
            }
            SegmentedControl {
                width: parent.width
                current: App.vpnDns
                options: [
                    { key: "system",  label: i18n.tr("Системный*") },
                    { key: "udp",     label: i18n.tr("UDP Tor") },
                    { key: "udp_tcp", label: i18n.tr("UDP+TCP") }
                ]
                onSelected: App.setVpnSetting("vpnDns", key)
            }
            Label {
                width: parent.width
                visible: App.vpnDns === "system"
                text: i18n.tr("* «Системный» — DNS идёт на порт 53 напрямую: возможна утечка DNS и цензура провайдера. Используйте только при проблемах (captive portal, локальные имена).")
                color: Theme.orange
                fontSize: "x-small"
                wrapMode: Text.WordWrap
            }

            Label {
                text: i18n.tr("IPv6")
                color: Theme.text
                fontSize: "small"
            }
            SegmentedControl {
                width: parent.width
                current: App.vpnIpv6
                options: [
                    { key: "off",  label: i18n.tr("Напрямую") },
                    { key: "tor",  label: i18n.tr("Через Tor"), disabled: !App.ipv6NatOk },
                    { key: "drop", label: i18n.tr("Отключить") }
                ]
                onSelected: App.setVpnSetting("vpnIpv6", key)
            }
            Label {
                width: parent.width
                visible: !App.ipv6NatOk
                text: i18n.tr("«Через Tor» недоступно на этом устройстве (нет таблицы ip6tables nat).")
                color: Theme.orange
                fontSize: "x-small"
                wrapMode: Text.WordWrap
            }

            SwitchRow {
                width: parent.width
                title: i18n.tr("Анти-петля (исключать IP мостов)")
                subtitle: i18n.tr("Включите, если Tor зацикливается при включённом VPN")
                checked: App.vpnAntiLoop
                onToggled: App.setVpnSetting("vpnAntiLoop", !App.vpnAntiLoop)
            }
        }
    }

    Timer {
        id: checkTimer
        interval: 2200
        onTriggered: page.showCheck = false
    }

    function flashCheck() {
        page.showCheck = true
        checkTimer.restart()
    }

    function addSource() {
        var url = (page.newSource || "").trim()
        if (url === "")
            return
        var arr = App.sources.slice()
        if (arr.indexOf(url) === -1) {
            arr.push(url)
            App.sources = arr
            App.setSetting("sources", arr)
        }
        page.newSource = ""
        newSrcField.text = ""
        flashCheck()
    }
}
