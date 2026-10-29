pragma Singleton
import QtQuick 2.12
import io.thp.pyotherside 1.3

QtObject {
    id: root

    // connection
    property bool connected: false
    property bool connecting: false
    property int bootPercent: 0
    property string country: ""
    property string countryIso: ""
    property string exitIp: "—"
    property int uptimeSec: 0        // узел: с последнего (пере)подключения
    property int sessionSec: 0       // сессия: с первого подключения за запуск
    property bool sessionActive: false
    property bool refreshingIp: false
    property bool nodeStale: false   // нет свежих данных об узле (таймер узла стоит)
    // состояние сети по NetworkManager: full/limited/portal/none/unknown
    property string netState: "unknown"

    // features
    property bool systemVpn: false
    property bool vpnBusy: false
    property bool vpnLeftover: false       // активны «залипшие» правила VPN (маркер)
    property bool ipv6NatOk: true          // доступна ли таблица ip6tables nat в ядре
    property bool hotspot: false
    property bool forwarder: false
    property bool forwarderBindAll: false
    property bool bindAll: false

    // bridges
    property string bridgeMode: "obfs4"      // obfs4 | webtunnel | local | custom
    property bool bridgeModeChosen: false
    property string customBridges: ""
    property var sources: []

    // settings
    property bool autoUpdate: true
    property string ipService: "https://ifconfig.co/json"
    property string vpnDns: "udp_tcp"    // system (порт 53, утечка) | udp | udp_tcp
    property string vpnIpv6: "drop"      // off (Напрямую) | tor (Через Tor) | drop (Отключить)
    property bool vpnAntiLoop: true

    // per-app SOCKS5 proxy (плитки приложений)
    property var appTargets: []
    property var bindings: ({})
    property string pendingProxyKey: ""
    property bool pendingProxyEnabled: false

    // backend state
    property bool pythonReady: false

    // signals to UI
    signal portBusy(var ports)
    signal backendFailed(string reason)
    signal vpnDone(bool ok, string error)
    signal proxyPasswordNeeded()
    signal proxyResult(bool ok, string error)

    // journal: entries { time, text, kind }  kind: info|ok|warn|dim
    property var logLines: [
        { time: "00:00:00", text: "Готово к запуску", kind: "dim" }
    ]

    function log(text, kind) {
        var d = new Date()
        var t = ("0" + d.getHours()).slice(-2) + ":"
              + ("0" + d.getMinutes()).slice(-2) + ":"
              + ("0" + d.getSeconds()).slice(-2)
        var arr = logLines.slice()
        arr.push({ time: t, text: text, kind: kind || "info" })
        if (arr.length > 300) arr = arr.slice(arr.length - 300)
        logLines = arr
    }

    function clearLog() {
        logLines = []
    }

    // ---- backend events ----
    function handleEvent(payload) {
        if (!payload || payload.length < 1)
            return
        var type = payload[0]
        var data = payload.length > 1 ? payload[1] : null

        if (type === "log") {
            log(data.text, data.kind)
        } else if (type === "bootstrap") {
            connecting = true
            connected = false
            bootPercent = data.percent
            log("Bootstrapped " + data.percent + "%"
                + (data.summary ? " (" + data.summary + ")" : ""),
                data.percent >= 100 ? "ok" : "dim")
        } else if (type === "connected") {
            connecting = false
            connected = true
            bootPercent = 100
            exitIp = data.ip && data.ip !== "" ? data.ip : "—"
            countryIso = data.iso || ""
            country = data.country || data.iso || ""
            uptimeSec = 0
            nodeStale = false
            sessionActive = true
            log("Выходной узел: " + (data.country || "?")
                + (data.iso ? " (" + data.iso + ")" : ""), "ok")
        } else if (type === "net") {
            netState = data && data.state ? data.state : "unknown"
        } else if (type === "exit_ip") {
            if (data && data.error) {
                // свежих данных нет — помечаем узел «устаревшим»
                if (!nodeStale)
                    log("Данные об узле недоступны — ждём обновления", "warn")
                nodeStale = true
                refreshingIp = false
            } else {
                var newIp = data.ip && data.ip !== "" ? data.ip : exitIp
                if (connected && newIp !== exitIp
                        && exitIp !== "" && exitIp !== "—"
                        && newIp !== "—") {
                    uptimeSec = 0
                    log("Смена выходного узла: " + newIp, "dim")
                }
                exitIp = newIp
                if (data.iso) countryIso = data.iso
                if (data.country) country = data.country
                nodeStale = false
                refreshingIp = false
            }
        } else if (type === "stopped") {
            connecting = false
            connected = false
            bootPercent = 0
            country = ""
            countryIso = ""
            exitIp = "—"
            uptimeSec = 0
            nodeStale = false
        } else if (type === "failed") {
            connecting = false
            connected = false
            bootPercent = 0
            backendFailed(data ? (data.reason || "") : "")
        } else if (type === "port_busy") {
            connecting = false
            connected = false
            bootPercent = 0
            portBusy(data && data.ports ? data.ports : [])
        } else if (type === "bridges_updated") {
            log("Списки мостов: obfs4=" + data.obfs4 + ", webtunnel=" + data.webtunnel, "ok")
        } else if (type === "settings") {
            applySettings(data)
        } else if (type === "app_targets") {
            appTargets = data || []
        } else if (type === "app_proxy") {
            if (data && data.apps) appTargets = data.apps
        } else if (type === "app_password_needed") {
            if (data && data.key) {
                pendingProxyKey = data.key
                pendingProxyEnabled = true
                proxyPasswordNeeded()
            }
        } else if (type === "forwarder") {
            if (data) {
                forwarder = !!data.on
                forwarderBindAll = !!data.bindAll
            }
        } else if (type === "vpn_state") {
            systemVpn = !!(data && data.on)
            vpnLeftover = !!(data && data.leftover)
            if (data && data.ipv6NatOk !== undefined) ipv6NatOk = data.ipv6NatOk
            if (vpnLeftover)
                log("Обнаружены активные правила системного VPN", "warn")
        } else if (type === "vpn") {
            systemVpn = !!(data && data.on)
            vpnLeftover = false
            var verr = (data && data.error) ? data.error : ""
            if (systemVpn)
                log("Системный VPN включён", "ok")
            else if (verr !== "")
                log("Системный VPN: ошибка (" + verr + ")", "warn")
            else
                log("Системный VPN выключен", "dim")
        } else if (type === "ready") {
            log("Бэкенд готов", "dim")
        }
    }

    function applySettings(s) {
        if (!s) return
        if (s.sources !== undefined) sources = s.sources
        if (s.autoUpdate !== undefined) autoUpdate = s.autoUpdate
        if (s.bridgeMode !== undefined) bridgeMode = s.bridgeMode
        if (s.bridgeModeChosen !== undefined) bridgeModeChosen = s.bridgeModeChosen
        if (s.bindAll !== undefined) bindAll = s.bindAll
        if (s.forwarder !== undefined) forwarder = s.forwarder
        if (s.forwarderBindAll !== undefined) forwarderBindAll = s.forwarderBindAll
        if (s.ipService !== undefined) ipService = s.ipService
        if (s.vpnDns !== undefined) vpnDns = s.vpnDns
        if (s.vpnIpv6 !== undefined) vpnIpv6 = s.vpnIpv6
        if (s.vpnAntiLoop !== undefined) vpnAntiLoop = s.vpnAntiLoop
        if (s.ipv6NatOk !== undefined) ipv6NatOk = s.ipv6NatOk
        if (s.customBridges !== undefined) customBridges = s.customBridges
        if (s.bindings !== undefined) bindings = s.bindings
    }

    // ---- backend commands ----
    function startTor() {
        if (!pythonReady) { log("Бэкенд ещё не готов", "dim"); return }
        bootPercent = 0
        py.call("backend.start", [bridgeMode, bindAll])
    }

    function stopTor() {
        if (!pythonReady) return
        py.call("backend.stop", [])
    }

    function restartTor() {
        stopTor()
        if (!pythonReady) return
        py.call("backend.stop", [], function () {
            root.startTor()
        })
    }

    function killAllTor() {
        if (!pythonReady) return
        py.call("backend.kill_all_tor", [])
    }

    function refreshExitIp() {
        if (!pythonReady) return
        if (!connected) { log("Выходной IP: нет подключения", "dim"); return }
        refreshingIp = true
        py.call("backend.refresh_exit_ip", [])
    }

    function updateBridges() {
        if (!pythonReady) return
        py.call("backend.update_bridges", [])
    }

    // ---- per-app SOCKS5 proxy ----
    function refreshApps() {
        if (!pythonReady) return
        py.call("backend.get_app_targets", [], function (res) {
            if (res && res.apps) root.appTargets = res.apps
        })
    }

    function toggleAppKey(key, enabled, pwd) {
        if (!pythonReady) { log("Бэкенд ещё не готов", "dim"); return }
        var pw = pwd || ""
        py.call("backend.set_app_proxy", [key, enabled, pw], function (res) {
            if (res && res.apps) root.appTargets = res.apps
            var ok = !!(res && res.ok)
            var e = (res && res.error) ? res.error : ""
            if (ok) {
                root.proxyResult(true, "")
            } else if (e === "need_password") {
                root.pendingProxyKey = key
                root.pendingProxyEnabled = enabled
                root.proxyPasswordNeeded()
            } else if (e === "sudo_failed" && pw !== "") {
                root.proxyResult(false, "bad_password")
            } else if (e === "not_installed") {
                log("Приложение не установлено", "warn")
            } else if (e === "not_ready") {
                log("Это приложение ещё в разработке", "dim")
            } else if (e === "unknown_app") {
                log("Неизвестное приложение", "warn")
            } else if (e !== "") {
                log("Прокси приложения: ошибка (" + e + ")", "warn")
            }
        })
    }

    function retryProxy(pwd) {
        toggleAppKey(pendingProxyKey, pendingProxyEnabled, pwd)
    }

    // ---- привязка приложений (человекопроверка) ----
    function findAppTarget(key, cb) {
        if (!pythonReady) return
        py.call("backend.find_app_target", [key], function (res) {
            if (cb) cb(res || ({ "ok": false, "candidates": [] }))
        })
    }

    function bindApp(key, pkg, app) {
        if (!pythonReady) { log("Бэкенд ещё не готов", "dim"); return }
        py.call("backend.bind_app_target", [key, pkg, app || ""], function (res) {
            if (res && res.apps) root.appTargets = res.apps
            if (!(res && res.ok))
                log("Не удалось привязать приложение (" + ((res && res.error) || "?") + ")", "warn")
        })
    }

    function unbindApp(key) {
        if (!pythonReady) return
        py.call("backend.unbind_app_target", [key], function (res) {
            if (res && res.apps) root.appTargets = res.apps
        })
    }

    function launchApp(key) {
        if (!pythonReady) { log("Бэкенд ещё не готов", "dim"); return }
        py.call("backend.open_app_by_key", [key], function (res) {
            if (!(res && res.ok))
                log("Не удалось открыть приложение (" + ((res && res.error) || "?") + ")", "warn")
        })
    }

    // ---- system VPN ----
    function vpnEnable(pwd) {
        if (!pythonReady) { log("Бэкенд ещё не готов", "dim"); return }
        if (vpnBusy) return
        if (vpnLeftover) { vpnDone(false, "leftover"); return }
        if (!connected) { log("Сначала подключитесь к Tor", "warn"); return }
        vpnBusy = true
        py.call("backend.vpn_start", [pwd || ""], function (res) {
            vpnBusy = false
            var ok = !!(res && res.ok)
            var err = (res && res.error) ? res.error : ""
            if (ok) {
                systemVpn = true
                if (res && res.v6 === false)
                    log("IPv6: режим не применён (" + (res.note || "") + ")", "warn")
            }
            vpnDone(ok, err)
        })
    }

    function vpnDisable(pwd) {
        if (!pythonReady || vpnBusy) return
        vpnBusy = true
        py.call("backend.vpn_stop", [pwd || ""], function (res) {
            vpnBusy = false
            var ok = !!(res && res.ok)
            var err = (res && res.error) ? res.error : ""
            if (ok) {
                systemVpn = false
                vpnLeftover = false
            }
            vpnDone(ok, err)
        })
    }

    function vpnCleanup(pwd) {
        if (!pythonReady || vpnBusy) return
        vpnBusy = true
        py.call("backend.vpn_cleanup", [pwd || ""], function (res) {
            vpnBusy = false
            var ok = !!(res && res.ok)
            var err = (res && res.error) ? res.error : ""
            if (ok) {
                systemVpn = false
                vpnLeftover = false
            }
            vpnDone(ok, err)
        })
    }

    function setVpnSetting(key, value) {
        if (key === "vpnDns") vpnDns = value
        else if (key === "vpnIpv6") vpnIpv6 = value
        else if (key === "vpnAntiLoop") vpnAntiLoop = value
        setSetting(key, value)
    }

    function normalizeBridges(text, cb) {
        if (!pythonReady) return
        py.call("backend.normalize", [text], function (res) {
            if (cb) cb(res.count, res.text)
        })
    }

    function saveCustomBridges(text) {
        if (!pythonReady) { log("Бэкенд ещё не готов", "dim"); return }
        py.call("backend.save_custom", [text], function (res) {
            root.customBridges = res.text
            if (res.count > 0) {
                root.bridgeMode = "custom"
                root.bridgeModeChosen = true
                root.setSetting("bridgeMode", "custom")
                root.setSetting("bridgeModeChosen", true)
            } else if (root.bridgeMode === "custom") {
                root.bridgeModeChosen = false
                root.setSetting("bridgeModeChosen", false)
            }
        })
    }

    function setSetting(key, value) {
        if (!pythonReady) return
        py.call("backend.set_setting", [key, value])
    }

    function setBind(all) {
        bindAll = all
        if (pythonReady)
            py.call("backend.set_bind", [all])
    }

    function toggleForwarder() {
        if (!pythonReady) { log("Бэкенд ещё не готов", "dim"); return }
        var next = !forwarder
        forwarder = next
        py.call("backend.set_forwarder", [next], function (res) {
            if (res) {
                forwarder = !!res.on
                forwarderBindAll = !!res.bindAll
            }
        })
    }

    function setForwarderBind(all) {
        if (!pythonReady) return
        forwarderBindAll = all
        py.call("backend.set_forwarder_bind", [all], function (res) {
            if (res) {
                forwarder = !!res.on
                forwarderBindAll = !!res.bindAll
            }
        })
    }

    function chooseBridgeMode(key) {
        bridgeMode = key
        bridgeModeChosen = true
        setSetting("bridgeMode", key)
        setSetting("bridgeModeChosen", true)
    }

    property Python py: Python {
        id: pyBackend
        onError: function (traceback) {
            root.log("Python: " + traceback, "warn")
        }
        onReceived: function (data) {
            root.handleEvent(data)
        }
    }

    Component.onCompleted: {
        py.addImportPath(Qt.resolvedUrl("../"))
        py.importModule("backend", function () {
            root.pythonReady = true
            py.call("backend.init", [], function () { root.refreshApps() })
        })
    }
}
