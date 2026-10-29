import QtQuick 2.12
import Lomiri.Components 1.3
import "../components"
import "../theme"
import "../state"

Item {
    id: shell

    property bool drawerOpen: false
    property var busyPorts: []
    property bool busyVisible: false
    property bool bindConfirmVisible: false
    property bool pendingBind: false
    property bool sudoVisible: false
    property string sudoPwd: ""
    property string sudoError: ""
    property string sudoMode: "enable"   // enable | disable | cleanup

    signal openJournal()
    signal openCustomBridges()
    signal openSettings()

    function fmtUptime(s) {
        var days = Math.floor(s / 86400)
        var h = Math.floor((s % 86400) / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        var hms = ("0" + h).slice(-2) + ":" + ("0" + m).slice(-2) + ":" + ("0" + sec).slice(-2)
        return days > 0 ? (days + "d " + hms) : hms
    }

    function showProxyInfo() {
        infoPopup.open(
            i18n.tr("Приложения через Tor"),
            i18n.tr("Плитка-контур — приложение ещё не привязано. Нажмите на неё и укажите установленное приложение на этом устройстве.\n\nПосле привязки рубильник справа включает проксирование: трафик пойдёт через Tor (SOCKS5 127.0.0.1:9050), без системного VPN. Ярлык в меню станет «📺 YouTube (Tor)».\n\nЕсли приложение обновилось и ярлык изменился — нажмите на плитку, чтобы привязать заново."))
    }

    function showAppInfo(m) {
        if (!m) return
        if (!m.installed) {
            var line = "Install " + m.name + (m.author ? " by " + m.author : "") + " from OpenStore"
            infoPopup.open(m.name, line)
            return
        }
        if (!m.enabled) {
            infoPopup.open(m.name, i18n.tr("Это приложение ещё в разработке."))
            return
        }
        var label = (m.emoji ? m.emoji + " " : "") + m.name + " (Tor)"
        infoPopup.open(m.name, i18n.tr("Включите рубильник справа — трафик приложения пойдёт через Tor (SOCKS5 127.0.0.1:9050), а ярлык станет «" + label + "»."))
    }

    function requestBind(m) {
        if (!m) return
        App.findAppTarget(m.key, function (res) {
            bindOverlay.open(m.key, m.name, res)
        })
    }

    function openProxySudo() {
        shell.sudoMode = "proxy"
        shell.sudoError = ""
        shell.sudoPwd = ""
        shell.sudoVisible = true
    }

    Connections {
        target: App
        onProxyPasswordNeeded: shell.openProxySudo()
        onProxyResult: {
            if (ok) {
                if (shell.sudoMode === "proxy") {
                    shell.sudoVisible = false
                    shell.sudoPwd = ""
                    shell.sudoError = ""
                }
            } else if (error === "bad_password" && shell.sudoVisible) {
                shell.sudoError = i18n.tr("Неверный пароль")
            }
        }
        onPortBusy: {
            shell.busyPorts = ports
            shell.busyVisible = true
        }
        onBackendFailed: {
            if (reason === "no_bridge_worked")
                App.log("Не удалось подключиться: ни один мост не подошёл", "warn")
            else if (reason === "no_bridges")
                App.log("Нет мостов — добавьте свои или обновите список", "warn")
            else if (reason === "binary_missing")
                App.log("Не найдены бинарники tor/lyrebird", "warn")
        }
        onVpnDone: {
            if (ok) {
                shell.sudoVisible = false
                shell.sudoPwd = ""
                shell.sudoError = ""
            } else if (error === "need_password" || error === "bad_password") {
                shell.sudoError = (error === "bad_password")
                    ? i18n.tr("Неверный пароль") : ""
                shell.sudoVisible = true
            } else if (error === "leftover") {
                App.log("Сначала очистите правила системного VPN", "warn")
            } else if (error === "tor_off") {
                App.log("Сначала подключитесь к Tor", "warn")
            } else if (error !== "") {
                App.log("VPN: ошибка (" + error + ")", "warn")
            }
        }
    }

    AppBar {
        id: appbar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        onMenuClicked: shell.drawerOpen = true
        onThemeToggled: Theme.dark = !Theme.dark
    }

    Flickable {
        id: flick
        anchors {
            left: parent.left
            right: parent.right
            top: appbar.bottom
            bottom: parent.bottom
        }
        contentHeight: col.y + col.height + units.gu(4)
        clip: true

        Column {
            id: col
            x: units.gu(1.6)
            y: units.gu(1.6)
            width: flick.width - units.gu(3.2)
            spacing: units.gu(2)

            HeroCard {
                width: parent.width
                connected: App.connected
                connecting: App.connecting
                bootPercent: App.bootPercent
                bridgeMode: App.bridgeModeChosen ? App.bridgeMode : ""
                customBridgesEnabled: App.customBridges !== ""
                systemVpn: App.systemVpn
                vpnLeftover: App.vpnLeftover
                forwarder: App.forwarder
                exitIp: App.exitIp
                nodeStale: App.nodeStale
                netState: App.netState
                onHealthClicked: App.refreshExitIp()
                onOnionClicked: {
                    if (App.vpnLeftover) {
                        App.log("Активны правила VPN — очистите их перед запуском Tor", "warn")
                        return
                    }
                    if (App.connected || App.connecting)
                        App.stopTor()
                    else
                        App.startTor()
                }
                onBridgeSelected: App.chooseBridgeMode(key)
                onBridgeCustomRequested: shell.openCustomBridges()
                onSystemVpnClicked: {
                    if (App.vpnBusy)
                        return
                    if (App.vpnLeftover) {
                        shell.sudoMode = "cleanup"
                        shell.sudoError = ""
                        shell.sudoVisible = true
                    } else if (App.systemVpn) {
                        shell.sudoMode = "disable"
                        App.vpnDisable("")
                    } else {
                        if (!App.connected) {
                            App.log("Сначала подключитесь к Tor", "warn")
                            return
                        }
                        App.log("Включаю системный VPN…", "info")
                        shell.sudoMode = "enable"
                        App.vpnEnable("")
                    }
                }
                onForwarderClicked: App.toggleForwarder()
            }

            MetricsRow {
                width: parent.width
                country: App.country
                iso: App.countryIso
                ip: App.nodeStale ? "—" : App.exitIp
                session: shell.fmtUptime(App.sessionSec)
                node: App.connected
                      ? (App.nodeStale ? i18n.tr("нет данных") : shell.fmtUptime(App.uptimeSec))
                      : "—"
                ipBusy: App.refreshingIp
                onIpClicked: App.refreshExitIp()
            }

            Card {
                width: parent.width
                title: i18n.tr("Приложения через Tor")
                subtitle: i18n.tr("Рубильник справа — трафик приложения пойдёт через SOCKS5 :9050, без системного VPN")
                rightIcon: "info"
                onRightClicked: shell.showProxyInfo()

                Flow {
                    id: appFlow
                    width: parent.width
                    spacing: units.gu(1.6)

                    Repeater {
                        model: App.appTargets
                        delegate: AppProxyCell {
                            width: (appFlow.width - 2 * appFlow.spacing) / 3
                            appName: modelData.name
                            iconSource: modelData.icon !== "" ? "file://" + modelData.icon : ""
                            installed: modelData.installed
                            proxied: modelData.proxied
                            tileEnabled: modelData.enabled
                            bound: modelData.bound
                            state: modelData.state !== undefined ? modelData.state : "ready"
                            onToggled: {
                                if (!modelData.installed) {
                                    shell.showAppInfo(modelData)
                                    return
                                }
                                if (!modelData.enabled) {
                                    shell.showAppInfo(modelData)
                                    return
                                }
                                App.toggleAppKey(modelData.key, !modelData.proxied)
                            }
                            onInfoRequested: shell.showAppInfo(modelData)
                            onBindRequested: shell.requestBind(modelData)
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: sessionTimer
        interval: 1000
        repeat: true
        running: App.sessionActive
        onTriggered: App.sessionSec += 1
    }

    Timer {
        id: uptimeTimer
        interval: 1000
        repeat: true
        running: App.connected && !App.nodeStale
        onTriggered: App.uptimeSec += 1
    }

    Timer {
        id: ipTimer
        interval: 60000
        repeat: true
        running: App.connected
        onTriggered: App.refreshExitIp()
    }

    Timer {
        id: retryTimer
        interval: 1500
        onTriggered: App.startTor()
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: "#aa000000"
        opacity: shell.drawerOpen ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 160 } }

        MouseArea {
            anchors.fill: parent
            onClicked: shell.drawerOpen = false
        }
    }

    Rectangle {
        id: drawer
        width: units.gu(30)
        height: parent.height
        color: Theme.bgApp
        x: shell.drawerOpen ? 0 : -width
        border.width: 1
        border.color: Theme.stroke

        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }

        SideNav {
            anchors.fill: parent
            currentKey: "home"
            toggleStates: ({ "hotspot": App.hotspot,
                             "bindall": App.bindAll,
                             "forwarderbind": App.forwarderBindAll })
            onSelected: {
                shell.drawerOpen = false
                if (key === "journal")
                    shell.openJournal()
                else if (key === "settings")
                    shell.openSettings()
            }
            onAction: {
                shell.drawerOpen = false
                if (key === "custom")
                    shell.openCustomBridges()
            }
            onToggled: {
                if (key === "hotspot") {
                    App.hotspot = !App.hotspot
                    App.log("Раздача: " + (App.hotspot ? "вкл" : "выкл") + " (скоро)", "dim")
                } else if (key === "bindall") {
                    if (App.connected) {
                        shell.pendingBind = !App.bindAll
                        shell.bindConfirmVisible = true
                    } else {
                        App.setBind(!App.bindAll)
                    }
                } else if (key === "forwarderbind") {
                    App.setForwarderBind(!App.forwarderBindAll)
                }
            }
        }
    }

    Rectangle {
        id: busyOverlay
        anchors.fill: parent
        color: "#cc000000"
        visible: shell.busyVisible

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - units.gu(6)
            height: busyCol.height + units.gu(4)
            radius: Theme.radiusCard
            color: Theme.bgCard
            border.width: 1
            border.color: Theme.stroke

            Column {
                id: busyCol
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
                    text: i18n.tr("Порты заняты")
                    color: Theme.text
                    fontSize: "large"
                    font.bold: true
                }
                Label {
                    width: parent.width
                    text: i18n.tr("Порты 9050/9151/9040 уже используются другим процессом Tor. Завершить все процессы Tor и повторить?")
                    color: Theme.textDim
                    fontSize: "small"
                    wrapMode: Text.WordWrap
                }
                Repeater {
                    model: shell.busyPorts
                    delegate: Label {
                        width: busyCol.width
                        text: "• :" + modelData.port
                              + (modelData.pid ? "  pid " + modelData.pid : "")
                              + (modelData.name ? "  " + modelData.name : "")
                        color: Theme.textDim2
                        fontSize: "x-small"
                        font.family: "Ubuntu Mono"
                    }
                }

                Row {
                    width: parent.width
                    spacing: units.gu(1.2)

                    ButtonPrimary {
                        width: (parent.width - units.gu(1.2)) / 2
                        text: i18n.tr("Отмена")
                        variant: "flat"
                        onClicked: shell.busyVisible = false
                    }
                    ButtonPrimary {
                        width: (parent.width - units.gu(1.2)) / 2
                        text: i18n.tr("Завершить")
                        onClicked: {
                            shell.busyVisible = false
                            App.killAllTor()
                            retryTimer.restart()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: bindConfirmOverlay
        anchors.fill: parent
        color: "#cc000000"
        visible: shell.bindConfirmVisible

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - units.gu(6)
            height: bindCol.height + units.gu(4)
            radius: Theme.radiusCard
            color: Theme.bgCard
            border.width: 1
            border.color: Theme.stroke

            Column {
                id: bindCol
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
                    text: i18n.tr("Требуется перезапуск Tor")
                    color: Theme.text
                    fontSize: "large"
                    font.bold: true
                }
                Label {
                    width: parent.width
                    text: i18n.tr("Смена адреса прослушивания применится только после перезапуска Tor. Перезапустить сейчас?")
                    color: Theme.textDim
                    fontSize: "small"
                    wrapMode: Text.WordWrap
                }
                Row {
                    width: parent.width
                    spacing: units.gu(1.2)

                    ButtonPrimary {
                        width: (parent.width - units.gu(1.2)) / 2
                        text: i18n.tr("Позже")
                        variant: "flat"
                        onClicked: {
                            shell.bindConfirmVisible = false
                            App.setBind(shell.pendingBind)
                        }
                    }
                    ButtonPrimary {
                        width: (parent.width - units.gu(1.2)) / 2
                        text: i18n.tr("Перезапустить")
                        onClicked: {
                            shell.bindConfirmVisible = false
                            App.setBind(shell.pendingBind)
                            App.restartTor()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: sudoOverlay
        anchors.fill: parent
        color: "#cc000000"
        visible: shell.sudoVisible

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - units.gu(6)
            height: sudoCol.height + units.gu(4)
            radius: Theme.radiusCard
            color: Theme.bgCard
            border.width: 1
            border.color: Theme.stroke

            Column {
                id: sudoCol
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
                    text: i18n.tr("Требуется пароль администратора")
                    color: Theme.text
                    fontSize: "large"
                    font.bold: true
                }
                Label {
                    width: parent.width
                    text: shell.sudoMode === "cleanup"
                          ? i18n.tr("Для очистки правил системного VPN нужны права root. Введите пароль пользователя (он не сохраняется на диск).")
                          : shell.sudoMode === "proxy"
                            ? i18n.tr("Чтобы включить прокси приложения, нужно изменить системный .desktop-файл (в /opt). Введите пароль пользователя (он не сохраняется на диск).")
                            : i18n.tr("Для системного VPN нужны права root. Введите пароль пользователя (он не сохраняется на диск).")
                    color: Theme.textDim
                    fontSize: "small"
                    wrapMode: Text.WordWrap
                }
                TextField {
                    id: sudoField
                    width: parent.width
                    placeholder: i18n.tr("Пароль")
                    echoMode: TextInput.Password
                    onTextChanged: shell.sudoPwd = text
                    onAccepted: sudoApply()
                }
                Label {
                    width: parent.width
                    visible: shell.sudoError !== ""
                    text: shell.sudoError
                    color: Theme.red
                    fontSize: "small"
                    wrapMode: Text.WordWrap
                }
                Row {
                    width: parent.width
                    spacing: units.gu(1.2)

                    ButtonPrimary {
                        width: (parent.width - units.gu(1.2)) / 2
                        text: i18n.tr("Отмена")
                        variant: "flat"
                        enabled: !App.vpnBusy
                        onClicked: {
                            shell.sudoVisible = false
                            shell.sudoPwd = ""
                            shell.sudoError = ""
                        }
                    }
                    ButtonPrimary {
                        width: (parent.width - units.gu(1.2)) / 2
                        text: App.vpnBusy ? i18n.tr("Ввод…") : i18n.tr("Ввод")
                        enabled: !App.vpnBusy
                        onClicked: sudoApply()
                    }
                }
            }
        }
    }

    onSudoVisibleChanged: {
        if (shell.sudoVisible) {
            sudoField.text = ""
            shell.sudoPwd = ""
            sudoField.forceActiveFocus()
        }
    }

    function sudoApply() {
        shell.sudoError = ""
        if (shell.sudoMode === "disable")
            App.vpnDisable(shell.sudoPwd)
        else if (shell.sudoMode === "cleanup")
            App.vpnCleanup(shell.sudoPwd)
        else if (shell.sudoMode === "proxy")
            App.retryProxy(shell.sudoPwd)
        else
            App.vpnEnable(shell.sudoPwd)
    }

    BindAppOverlay {
        id: bindOverlay
        onBindRequested: {
            App.bindApp(bindOverlay.appKey, pkg, app)
            bindOverlay.close()
        }
        onOpenStoreRequested: {
            bindOverlay.close()
            App.launchApp("openstore")
        }
    }

    InfoPopup {
        id: infoPopup
    }

    Component.onCompleted: {
        if (App.pendingProxyKey !== "")
            shell.openProxySudo()
    }
}
