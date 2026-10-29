#!/usr/bin/env python3
"""
backend.py — PyOtherSide-бэкенд TorApp (этап 2A+).
Управляет Tor: запуск/остановка, загрузка/перебор мостов (по 2 за попытку),
прогресс bootstrap, выходной IP, журнал, свои мосты, источники, настройки.
События наружу (pyotherside.send):
  log               {text, kind}                 kind: info|ok|warn|dim
  bootstrap         {percent, summary}
  connected         {ip, country, iso, asn}
  exit_ip           {ip, country, iso, asn}
  failed            {reason}
  stopped           {}
  port_busy         {ports: [{port, pid, name}]}
  bridges_updated   {obfs4, webtunnel}
  settings          {sources, autoUpdate, bridgeMode, bridgeModeChosen,
                     bindAll, ipService, customBridges}
  ready             {}
"""

import os
import re
import ssl
import sys
import json
import time
import signal
import socket
import shutil
import random
import fnmatch
import subprocess
import threading
import urllib.request
import urllib.parse

import pyotherside

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TOR_DIR = os.path.join(SCRIPT_DIR, "tor")
TOR_BIN = os.path.join(TOR_DIR, "tor")
LYREBIRD_BIN = os.path.join(TOR_DIR, "pluggable_transports", "lyrebird")
TOR_DATA_DIR = os.path.join(SCRIPT_DIR, "tor_data")
TORRC_PATH = os.path.join(SCRIPT_DIR, "torrc")
PID_FILE = os.path.join(SCRIPT_DIR, "tor.pid")
BRIDGE_DIR = os.path.join(SCRIPT_DIR, "txtbridge")
OBFS4_FILE = os.path.join(BRIDGE_DIR, "obfs4.txt")
WEBTUNNEL_FILE = os.path.join(BRIDGE_DIR, "webtunnel.txt")
WORKING_BRIDGES = os.path.join(BRIDGE_DIR, "working_bridges.txt")
CUSTOM_BRIDGES = os.path.join(BRIDGE_DIR, "custom.txt")
LOG_DIR = os.path.join(SCRIPT_DIR, "logs")
RUN_DIR = os.path.join(SCRIPT_DIR, "run")
SETTINGS_PATH = os.path.join(RUN_DIR, "settings.json")
VPN_STATE_FILE = os.path.join(RUN_DIR, "vpn_state")

SOCKS_PORT = 9050
CONTROL_PORT = 9151
TRANS_PORT = 9040
DNS_PORT = 5353
HTTP_PORT = 8118

HOME_DIR = os.path.expanduser("~")
APPLICATIONS_DIR = os.path.join(HOME_DIR, ".local", "share", "applications")
# Каталог установленных click-приложений: /opt/click.ubuntu.com/<pkg>/current -> <версия>.
CLICK_APPS_DIR = "/opt/click.ubuntu.com"
# Центральное хранилище оригиналов проксируемых .desktop-файлов.
# Выход из папки проекта согласован с пользователем (см. AGENTS.md).
PROXYBAK_DIR = os.path.join(HOME_DIR, ".local", "bin", "proxybak")
# Drop-in'ы systemd --user для приложений, у которых сеть живёт в сервисе,
# а не в .desktop (например Greenline: демон WhatsApp).
SYSTEMD_USER_DIR = os.path.join(HOME_DIR, ".config", "systemd", "user")
SYSTEMD_DROPIN_NAME = "zz-torapp.conf"
PROXY_URL = "socks5://127.0.0.1:%d" % SOCKS_PORT
PROXY_ENV_PREFIX = "env ALL_PROXY=%s " % PROXY_URL
PROXY_MARKER = "ALL_PROXY=%s" % PROXY_URL
# Опрос состояния сети (NetworkManager) для индикатора-«светофора».
NET_POLL_INTERVAL = 5
NET_LABELS = {
    "full": "есть интернет",
    "limited": "ограниченный интернет",
    "portal": "портал авторизации",
    "none": "нет интернета",
    "unknown": "неизвестно",
}
# QtWebEngine‑флаг, используемый только для YouTube‑click‑приложения
YOUTUBE_PROXY_FLAG = "QTWEBENGINE_CHROMIUM_FLAGS=\"--proxy-server=socks5://127.0.0.1:%d\"" % SOCKS_PORT

# Приложения, которым можно включить SOCKS5-прокси правкой .desktop-файла.
# globs — маски имён файлов в ~/.local/share/applications (версии в именах
# меняются при обновлениях, поэтому используются маски). emoji — префикс
# ярлыка в проксированном варианте (📺 YouTube (Tor)), name — чистое имя.
APP_TARGETS = [
    {"key": "youtube", "name": "YouTube", "emoji": "📺", "author": "Mateo Salta",
     "enabled": True, "pkg": "youtube-web.mateo-salta", "app": "youtube-web",
     "globs": ["youtube-web.mateo-salta_youtube-web_*.desktop"], "needs_qt_flag": True},
    {"key": "openstore", "name": "OpenStore", "emoji": "🛒", "author": "openstore-team",
     "enabled": True, "mode": "http", "pkg": "openstore.openstore-team", "app": "openstore",
     "globs": ["openstore.openstore-team_openstore_*.desktop"]},
    {"key": "greenline", "name": "Greenline", "emoji": "🎶", "author": "brennoflavio",
     "enabled": True, "strategy": "systemd_user", "service": "greenline.service",
     "pkg": "greenline.brennoflavio", "app": "greenline",
     "globs": ["greenline.brennoflavio_greenline_*.desktop"]},
]

VPN_CHAIN = "TORAPP"
SUDO_BIN = "/usr/bin/sudo"
PRIVATE_V4 = [
    "0.0.0.0/8", "127.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12",
    "192.168.0.0/16", "169.254.0.0/16", "100.64.0.0/10", "224.0.0.0/4",
]
PRIVATE_V6 = ["::1/128", "fc00::/7", "fe80::/10", "ff00::/8"]

BOOTSTRAP_TIMEOUT = 45
VALID_TRANSPORTS = ("obfs4", "webtunnel")

DEFAULT_SOURCES = [
    "https://raw.githubusercontent.com/igareck/vpn-configs-for-russia/"
    "main/TOR-BRIDGES/TOR_BRIDGES_ALL.txt",
]
DEFAULT_IP_SERVICE = "https://ifconfig.co/json"

DEFAULT_SETTINGS = {
    "sources": list(DEFAULT_SOURCES),
    "autoUpdate": True,
    "bridgeMode": "obfs4",
    "bridgeModeChosen": False,
    "bindAll": False,
    "ipService": DEFAULT_IP_SERVICE,
    "vpnDns": "udp_tcp",     # system (порт 53, возможна утечка) | udp | udp_tcp
    "vpnIpv6": "drop",       # off (Напрямую) | tor (Через Tor) | drop (Отключить)
    "vpnAntiLoop": True,
    "ipv6NatOk": True,
    "proxiedApps": [],
    "bindings": {},
    "forwarder": False,
    "forwarderAuto": False,
    "forwarderBindAll": False,
}

_ANSI = re.compile(r"\x1b\[[0-9;]*m")


def _log_file(text):
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        with open(os.path.join(LOG_DIR, "backend.log"), "a") as f:
            f.write("%s %s\n" % (time.strftime("%H:%M:%S"), text))
    except Exception:
        pass


def emit(event, payload=None):
    try:
        pyotherside.send(event, payload)
    except Exception:
        pass


def _kill_group(proc):
    try:
        os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
    except Exception:
        try:
            proc.terminate()
        except Exception:
            pass


def _net_state():
    """Состояние сети по NetworkManager: full/limited/portal/none/unknown.

    Используется стандартный API NetworkManager (есть в любой Ubuntu Touch)."""
    try:
        r = subprocess.run(["nmcli", "-t", "-f", "CONNECTIVITY", "general", "status"],
                           capture_output=True, text=True, timeout=6)
        state = (r.stdout or "").strip().lower()
    except Exception:
        return "unknown"
    if state in ("full", "limited", "portal", "none"):
        return state
    return "unknown"


def _port_busy(port):
    s = socket.socket()
    s.settimeout(0.6)
    try:
        s.connect(("127.0.0.1", port))
        return True
    except Exception:
        return False
    finally:
        try:
            s.close()
        except Exception:
            pass


def _port_owner(port):
    try:
        out = subprocess.run(["ss", "-ltnp"], capture_output=True, text=True, timeout=5).stdout
    except Exception:
        out = ""
    if not out:
        try:
            out = subprocess.run(["netstat", "-tlnp"], capture_output=True, text=True, timeout=5).stdout
        except Exception:
            out = ""
    for line in out.splitlines():
        if (":%d " % port) in line or line.endswith(":%d" % port):
            m = re.search(r"pid=(\d+),fd=\d+\s+(\S+)?", line)
            if not m:
                m = re.search(r"(\d+)/(\S+)", line)
                if m:
                    return int(m.group(1)), m.group(2)
                return None, ""
            return int(m.group(1)), (m.group(2) or "")
    return None, ""


def _norm_bridge(line):
    line = line.strip()
    if line.startswith("Bridge "):
        line = line[7:].strip()
    return line


def _is_valid_bridge(line):
    low = line.lower()
    if "snowflake" in low or "meek" in low:
        return False
    return any(t in low for t in VALID_TRANSPORTS)


def _bridge_ip(line):
    parts = line.split()
    if len(parts) < 2:
        return None
    addr = parts[1]
    if addr.startswith("["):
        end = addr.find("]")
        return addr[1:end] if end > 1 else None
    if ":" in addr:
        return addr.rsplit(":", 1)[0]
    return addr


def _filter_bridges(text):
    kept = []
    seen = set()
    for raw in (text or "").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        line = _norm_bridge(line)
        if not _is_valid_bridge(line) or line in seen:
            continue
        seen.add(line)
        kept.append(line)
    return kept


def _parse_bridge_file(path):
    if not os.path.exists(path):
        return []
    with open(path, "r", errors="ignore") as f:
        return _filter_bridges(f.read())


def _load_bridges(mode):
    if mode == "custom":
        return _parse_bridge_file(CUSTOM_BRIDGES)
    if mode == "local":
        return _parse_bridge_file(WORKING_BRIDGES)
    if mode == "webtunnel":
        return _parse_bridge_file(WEBTUNNEL_FILE)
    return _parse_bridge_file(OBFS4_FILE)


def _transport_for(bridge_line):
    low = bridge_line.lower()
    if "webtunnel" in low:
        return "webtunnel"
    if "obfs4" in low:
        return "obfs4"
    return "obfs4"


# ---------- per-app SOCKS5 proxy (via .desktop overrides) ----------
def _resolve_desktop(patterns):
    if not os.path.isdir(APPLICATIONS_DIR):
        return None
    try:
        files = sorted(os.listdir(APPLICATIONS_DIR))
    except Exception:
        return None
    for pat in patterns:
        for name in files:
            if not name.endswith(".desktop"):
                continue
            if fnmatch.fnmatch(name, pat):
                return os.path.join(APPLICATIONS_DIR, name)
    return None


def _parse_desktop(path):
    info = {"name": "", "icon": ""}
    if not path:
        return info
    try:
        with open(path, "r", errors="ignore") as f:
            group = None
            for raw in f:
                line = raw.rstrip("\n")
                s = line.strip()
                if s.startswith("[") and s.endswith("]"):
                    group = s
                    continue
                if group != "[Desktop Entry]":
                    continue
                if not info["name"] and line.startswith("Name="):
                    info["name"] = line[5:].strip()
                elif not info["icon"] and line.startswith("Icon="):
                    info["icon"] = line[5:].strip()
    except Exception:
        pass
    return info


def _real_desktop(mirror):
    """Реальный файл запуска click-приложения: из зеркала берём X-Lomiri-Source-Desktop."""
    if not mirror:
        return None
    try:
        with open(mirror, "r", errors="ignore") as f:
            for line in f:
                if line.startswith("X-Lomiri-Source-Desktop="):
                    p = line.split("=", 1)[1].strip()
                    if p:
                        return os.path.realpath(p)
    except Exception:
        pass
    return os.path.realpath(mirror)


def _source_desktop_raw(mirror):
    """Сырое значение X-Lomiri-Source-Desktop из зеркала (без realpath), или None."""
    if not mirror:
        return None
    try:
        with open(mirror, "r", errors="ignore") as f:
            for line in f:
                if line.startswith("X-Lomiri-Source-Desktop="):
                    p = line.split("=", 1)[1].strip()
                    return p or None
    except Exception:
        pass
    return None


def _pkg_from_source(src):
    """Имя click-пакета из пути .click/users/@all/<pkg>/... (работает и для preinstalled)."""
    if not src:
        return None
    m = re.search(r"/\.click/users/@all/([^/]+)/", src)
    return m.group(1) if m else None


def _binding_for(target):
    """Привязка цели в settings: {pkg, app} (или короткая строка-пакет)."""
    b = (GLOBAL.settings.get("bindings", {}) or {}).get(target.get("key"))
    if isinstance(b, dict) and b.get("pkg"):
        return b
    if isinstance(b, str) and b:
        return {"pkg": b}
    return None


def _bound_mirror(target, binding):
    """Зеркало, чей источник принадлежит привязанному пакету (и app, если задан)."""
    pkg = binding.get("pkg")
    want_app = binding.get("app") or target.get("app")
    if not pkg or not os.path.isdir(APPLICATIONS_DIR):
        return None
    best = None
    try:
        names = sorted(os.listdir(APPLICATIONS_DIR))
    except Exception:
        return None
    for name in names:
        if not name.endswith(".desktop"):
            continue
        path = os.path.join(APPLICATIONS_DIR, name)
        src = _source_desktop_raw(path)
        if _pkg_from_source(src) != pkg:
            continue
        real = os.path.realpath(src)
        app = os.path.splitext(os.path.basename(real))[0]
        if want_app and app == want_app:
            return path
        if best is None:
            best = path
    return best


def _installed_apps():
    """Все установленные click-приложения по зеркалам (pkg, app, name, icon)."""
    out = []
    if not os.path.isdir(APPLICATIONS_DIR):
        return out
    seen = set()
    try:
        names = sorted(os.listdir(APPLICATIONS_DIR))
    except Exception:
        return out
    for name in names:
        if not name.endswith(".desktop"):
            continue
        path = os.path.join(APPLICATIONS_DIR, name)
        src = _source_desktop_raw(path)
        pkg = _pkg_from_source(src)
        if not pkg:
            continue
        real = os.path.realpath(src)
        app = os.path.splitext(os.path.basename(real))[0]
        ident = (pkg, app)
        if ident in seen:
            continue
        seen.add(ident)
        info = _parse_desktop(path)
        icon = info.get("icon", "")
        if icon and not icon.startswith("/"):
            icon = os.path.join(os.path.dirname(real), icon)
        out.append({
            "pkg": pkg,
            "app": app,
            "name": info.get("name", "") or app,
            "icon": icon,
            "mirror": path,
            "desktop": real,
        })
    return out


def _http_proxy_env():
    """env-префикс HTTP-прокси на локальный форвардер (:8118)."""
    return "env http_proxy=http://127.0.0.1:%d https_proxy=http://127.0.0.1:%d " \
        % (HTTP_PORT, HTTP_PORT)


def _proxy_env_for(target):
    """env-префикс для Exec в зависимости от режима прокси приложения."""
    if target.get("mode") == "http":
        return _http_proxy_env()
    if target.get("needs_qt_flag"):
        return "env %s " % YOUTUBE_PROXY_FLAG
    return PROXY_ENV_PREFIX


def _proxy_marker_for(target):
    """Строка-маркер, по которой узнаём, что .desktop уже проксирован."""
    if target.get("mode") == "http":
        return "http_proxy=http://127.0.0.1:%d" % HTTP_PORT
    if target.get("needs_qt_flag"):
        return YOUTUBE_PROXY_FLAG
    return PROXY_MARKER


def _target_needs_forwarder(target):
    """Целям в HTTP-режиме (OpenStore) нужен локальный HTTP-форвардер :8118."""
    return target.get("mode") == "http"


# ---------- systemd --user (для приложений, у которых сеть в сервисе) ----------
def _systemd_dropin(target):
    service = target.get("service", "")
    if not service:
        return ""
    return os.path.join(SYSTEMD_USER_DIR, service + ".d", "zz-torapp.conf")


def _systemd_env_lines():
    return [
        "# Управляется torappqml: per-app прокси через Tor\n",
        "[Service]\n",
        "Environment=HTTP_PROXY=socks5://127.0.0.1:%d\n" % SOCKS_PORT,
        "Environment=HTTPS_PROXY=socks5://127.0.0.1:%d\n" % SOCKS_PORT,
        "Environment=ALL_PROXY=socks5://127.0.0.1:%d\n" % SOCKS_PORT,
        "Environment=NO_PROXY=127.0.0.1,localhost\n",
    ]


def _systemctl_user(args):
    try:
        r = subprocess.run(["systemctl", "--user"] + list(args),
                           capture_output=True, text=True, timeout=20)
        return r.returncode, (r.stderr or r.stdout or "").strip()
    except Exception as e:
        return 1, str(e)


def _systemd_proxied(target):
    path = _systemd_dropin(target)
    return bool(path) and os.path.exists(path)


def _systemd_enable(target):
    path = _systemd_dropin(target)
    service = target.get("service", "")
    if not path or not service:
        return False, "no_service"
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.writelines(_systemd_env_lines())
    except Exception as e:
        return False, str(e)
    _systemctl_user(["daemon-reload"])
    rc, err = _systemctl_user(["restart", service])
    return (rc == 0), ("" if rc == 0 else err)


def _systemd_disable(target):
    path = _systemd_dropin(target)
    service = target.get("service", "")
    if not path:
        return False, "no_service"
    if os.path.exists(path):
        try:
            os.remove(path)
            d = os.path.dirname(path)
            if os.path.isdir(d) and not os.listdir(d):
                os.rmdir(d)
        except Exception as e:
            return False, str(e)
        _systemctl_user(["daemon-reload"])
        rc, err = _systemctl_user(["restart", service])
        if rc != 0:
            return False, err
    return True, ""


def _desktop_proxied(path, key=None):
    if not path:
        return False
    try:
        with open(path, "r", errors="ignore") as f:
            data = f.read()
    except Exception:
        return False
    target = _find_target(key) if key else None
    if target:
        return _proxy_marker_for(target) in data
    return (PROXY_MARKER in data) or (YOUTUBE_PROXY_FLAG in data) \
        or ("http_proxy=http://127.0.0.1:%d" % HTTP_PORT in data)


def _proxy_variant(content, key=None):
    """Проксированный вариант .desktop: Exec+флаг, Name=«📺 YouTube (Tor)»."""
    target = _find_target(key) or {}
    name = target.get("name", "")
    emoji = target.get("emoji", "")
    prefix = _proxy_env_for(target)
    lines = content.splitlines()
    out = []
    group = None
    exec_done = False
    name_done = False
    for line in lines:
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            group = s
        elif group == "[Desktop Entry]" and not exec_done and line.startswith("Exec="):
            line = "Exec=" + prefix + line[5:]
            exec_done = True
        elif group == "[Desktop Entry]" and not name_done and line.startswith("Name="):
            if name:
                line = "Name=" + (emoji + " " if emoji else "") + name + " (Tor)"
            name_done = True
        out.append(line)
    result = "\n".join(out)
    if content.endswith("\n"):
        result += "\n"
    return result


def _strip_proxy(content, key=None):
    """Снять прокси-флаг с Exec и вернуть чистое Name."""
    target = _find_target(key) or {}
    name = target.get("name", "")
    prefixes = []
    for pref in (PROXY_ENV_PREFIX, "env %s " % YOUTUBE_PROXY_FLAG,
                 _http_proxy_env(), _proxy_env_for(target)):
        entry = "Exec=" + pref
        if entry not in prefixes:
            prefixes.append(entry)
    lines = content.splitlines()
    out = []
    group = None
    name_done = False
    for line in lines:
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            group = s
        for pref in prefixes:
            if line.startswith(pref):
                line = "Exec=" + line[len(pref):]
                break
        if (group == "[Desktop Entry]" and not name_done
                and line.startswith("Name=") and name):
            line = "Name=" + name
            name_done = True
        out.append(line)
    result = "\n".join(out)
    if content.endswith("\n"):
        result += "\n"
    return result


def _central_backup_path(key, path):
    return os.path.join(PROXYBAK_DIR, key, os.path.basename(path) + ".orig")


def _save_central_backup(key, path, text):
    """Центральный бэкап оригинала: ~/.local/bin/proxybak/<key>/…orig + meta.json."""
    if not key:
        return
    try:
        dest = _central_backup_path(key, path)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w") as f:
            f.write(text)
        meta = {
            "key": key,
            "desktop": path,
            "file": os.path.basename(path),
            "saved": time.strftime("%Y-%m-%d %H:%M:%S"),
            "created": int(time.time()),
        }
        with open(os.path.join(PROXYBAK_DIR, key, "meta.json"), "w") as f:
            json.dump(meta, f, ensure_ascii=False, indent=2)
    except Exception:
        pass


def _write_desktop(path, text, pwd=""):
    """Записать .desktop. Если файл не наш — через sudo (install -o clickpkg)."""
    if os.access(path, os.W_OK) and os.access(os.path.dirname(path), os.W_OK):
        try:
            _write_file(path, text)
            return True, ""
        except Exception as e:
            return False, str(e)
    tmp = os.path.join(RUN_DIR, ".desktop_write.tmp")
    try:
        os.makedirs(RUN_DIR, exist_ok=True)
        with open(tmp, "w") as f:
            f.write(text)
    except Exception as e:
        return False, str(e)
    rc, out, err = GLOBAL._run_sudo(
        ["install", "-o", "clickpkg", "-g", "clickpkg", "-m", "644", tmp, path], pwd)
    try:
        os.remove(tmp)
    except Exception:
        pass
    if rc != 0:
        has_pwd = bool(pwd or GLOBAL._sudo_pwd)
        return False, ("sudo_failed" if has_pwd else "need_password")
    if pwd:
        GLOBAL._sudo_pwd = pwd
    return True, ""


def _store_original(path, key, original, pwd):
    orig = path + ".orig"
    if not os.path.exists(orig):
        ok, err = _write_desktop(orig, original, pwd)
        if not ok:
            return False, err
    _save_central_backup(key, path, original)
    return True, ""


def _write_file(path, text):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def _app_enable(path, key, pwd=""):
    """Включить прокси: оригинал → *.orig (рядом и в proxybak), вариант → на место."""
    if not path or not os.path.exists(path):
        return False, "not_installed"
    try:
        with open(path, "r", errors="ignore") as f:
            current = f.read()
    except Exception as e:
        return False, str(e)
    if _desktop_proxied(path, key):
        return _store_original(path, key, _strip_proxy(current, key), pwd)
    ok, err = _store_original(path, key, current, pwd)
    if not ok:
        return False, err
    return _write_desktop(path, _proxy_variant(current, key), pwd)


def _app_disable(path, key, pwd=""):
    """Выключить прокси: вернуть оригинал из *.orig (или proxybak)."""
    if not path or not os.path.exists(path):
        return False, "not_installed"
    if not _desktop_proxied(path, key):
        return True, ""
    base = None
    orig = path + ".orig"
    if os.path.exists(orig):
        try:
            with open(orig, "r", errors="ignore") as f:
                base = f.read()
        except Exception:
            base = None
    if base is None:
        central = _central_backup_path(key, path)
        if os.path.exists(central):
            try:
                with open(central, "r", errors="ignore") as f:
                    base = f.read()
            except Exception:
                base = None
    if base is None:
        try:
            with open(path, "r", errors="ignore") as f:
                base = _strip_proxy(f.read(), key)
        except Exception as e:
            return False, str(e)
    return _write_desktop(path, base, pwd)


def _target_path(target):
    """Зеркало цели: сначала по привязке (pkg), затем по старым маскам."""
    binding = _binding_for(target)
    if binding and binding.get("pkg"):
        path = _bound_mirror(target, binding)
        if path:
            return path
    return _resolve_desktop(target.get("globs", []))


def _target_status(target):
    binding = _binding_for(target)
    mirror = _target_path(target)
    real = _real_desktop(mirror) if mirror else None
    info = _parse_desktop(mirror) if mirror else {"name": "", "icon": ""}
    icon = info.get("icon") or ""
    if icon and not icon.startswith("/") and real:
        icon = os.path.join(os.path.dirname(real), icon)
    state_path = real if (real and os.path.exists(real)) else mirror
    installed = bool(mirror)
    bound = bool(binding)
    if not installed:
        state = "missing" if bound else "unbound"
    elif not bound:
        state = "unbound"
    else:
        state = "ready"
    if target.get("strategy") == "systemd_user":
        proxied = _systemd_proxied(target)
    else:
        proxied = bool(state_path) and _desktop_proxied(state_path, target["key"])
    return {
        "key": target["key"],
        "name": target["name"],
        "emoji": target.get("emoji", ""),
        "author": target.get("author", ""),
        "installed": installed,
        "proxied": proxied,
        "enabled": bool(target.get("enabled", True)),
        "bound": bound,
        "state": state,
        "pkg": (binding or {}).get("pkg", target.get("pkg", "")),
        "icon": icon,
        "desktop": state_path or "",
        "mirror": mirror or "",
    }


def _all_targets():
    return [_target_status(t) for t in APP_TARGETS]


def get_app_targets():
    return {"apps": _all_targets()}


def get_installed_apps():
    """Список установленных click-приложений (для экрана привязки)."""
    return {"apps": _installed_apps()}


def find_app_target(key):
    """Кандидаты на привязку для цели: по pkg, при необходимости — по app."""
    target = _find_target(key)
    if not target:
        return {"ok": False, "error": "unknown_app"}
    pkg = target.get("pkg")
    want = target.get("app")
    cands = [a for a in _installed_apps() if a["pkg"] == pkg]
    if want:
        exact = [a for a in cands if a["app"] == want]
        if exact:
            cands = exact
    return {"ok": True, "key": key, "candidates": cands,
            "binding": _binding_for(target)}


def bind_app_target(key, pkg, app=""):
    """Привязать цель к конкретному установленному пакету."""
    target = _find_target(key)
    if not target:
        return {"ok": False, "error": "unknown_app", "apps": _all_targets()}
    if not pkg:
        return {"ok": False, "error": "bad_pkg", "apps": _all_targets()}
    bindings = dict(GLOBAL.settings.get("bindings", {}) or {})
    entry = {"pkg": pkg}
    if app:
        entry["app"] = app
    bindings[key] = entry
    GLOBAL.settings["bindings"] = bindings
    GLOBAL.save_settings()
    GLOBAL._log("«%s»: привязано к %s" % (target["name"], pkg), "ok")
    apps = _all_targets()
    emit("app_proxy", {"key": key, "enabled": False, "error": "", "apps": apps})
    return {"ok": True, "error": "", "apps": apps}


def unbind_app_target(key):
    """Снять привязку цели."""
    target = _find_target(key)
    if not target:
        return {"ok": False, "error": "unknown_app", "apps": _all_targets()}
    bindings = dict(GLOBAL.settings.get("bindings", {}) or {})
    bindings.pop(key, None)
    GLOBAL.settings["bindings"] = bindings
    GLOBAL.save_settings()
    apps = _all_targets()
    emit("app_proxy", {"key": key, "enabled": False, "error": "", "apps": apps})
    return {"ok": True, "error": "", "apps": apps}


def open_app_by_key(key):
    """Запустить приложение цели (напр. OpenStore) через lomiri-app-launch."""
    target = _find_target(key)
    if not target:
        return {"ok": False, "error": "unknown_app"}
    mirror = _target_path(target)
    if not mirror:
        return {"ok": False, "error": "not_installed"}
    app_id = ""
    try:
        with open(mirror, "r", errors="ignore") as f:
            for line in f:
                if line.startswith("X-Lomiri-Application-ID="):
                    app_id = line.split("=", 1)[1].strip()
                    break
    except Exception:
        pass
    if not app_id:
        return {"ok": False, "error": "no_app_id"}
    for launcher in ("/usr/bin/lomiri-app-launch", "lomiri-app-launch"):
        try:
            subprocess.Popen([launcher, app_id],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
            return {"ok": True}
        except Exception:
            continue
    return {"ok": False, "error": "launch_failed"}


def _find_target(key):
    for t in APP_TARGETS:
        if t["key"] == key:
            return t
    return None


def set_app_proxy(key, enabled, pwd=""):
    enabled = bool(enabled)
    target = _find_target(key)
    if target is None:
        return {"ok": False, "error": "unknown_app", "apps": _all_targets()}
    if not target.get("enabled", True):
        GLOBAL._log("«%s»: пока в разработке" % target["name"], "dim")
        return {"ok": False, "error": "not_ready", "apps": _all_targets()}
    mirror = _target_path(target)
    if not mirror:
        return {"ok": False, "error": "not_installed", "apps": _all_targets()}

    errors = []
    if target.get("strategy") == "systemd_user":
        # сеть приложения живёт в systemd --user-сервисе (напр. Greenline)
        ok, err = _systemd_enable(target) if enabled else _systemd_disable(target)
        if not ok and err:
            errors.append(err)
    else:
        real = _real_desktop(mirror)

        def _do(path, ppwd):
            if not path:
                return
            ok, err = _app_enable(path, key, ppwd) if enabled \
                else _app_disable(path, key, ppwd)
            if not ok and err:
                errors.append(err)

        # сначала реальный файл (может требовать пароль), затем зеркало
        _do(real, pwd)
        if not errors:
            _do(mirror, "")
    ok = not errors
    err = errors[0] if errors else ""
    if ok:
        keys = set(GLOBAL.settings.get("proxiedApps", []) or [])
        if enabled:
            keys.add(key)
        else:
            keys.discard(key)
        GLOBAL.settings["proxiedApps"] = sorted(keys)
        GLOBAL.save_settings()
        _forwarder_for_target(target, enabled)
        GLOBAL._log("«%s»: прокси %s" % (target["name"],
                                         "включён" if enabled else "выключен"),
                    "ok" if enabled else "dim")
    else:
        GLOBAL._log("«%s»: не удалось изменить прокси (%s)"
                    % (target["name"], err), "warn")
    apps = _all_targets()
    emit("app_proxy", {"key": key, "enabled": enabled and ok,
                       "error": err, "apps": apps})
    return {"ok": ok, "error": err, "apps": apps}


def _apply_saved_proxies():
    """Восстановить прокси для приложений из настроек при запуске."""
    keys = list(GLOBAL.settings.get("proxiedApps", []) or [])
    kept = []
    needs_pwd = None
    for key in keys:
        target = _find_target(key)
        if target is None or not target.get("enabled", True):
            continue
        mirror = _target_path(target)
        if not mirror:
            continue
        kept.append(key)
        if target.get("strategy") == "systemd_user":
            if not _systemd_proxied(target):
                _systemd_enable(target)
            continue
        real = _real_desktop(mirror)
        if real and os.path.exists(real) and _desktop_proxied(real, key):
            _app_enable(mirror, key, "")
            continue
        ok, err = _app_enable(real, key) if real else (True, "")
        if not ok:
            if err == "need_password":
                needs_pwd = key
            continue
        _app_enable(mirror, key, "")
    if set(kept) != set(keys):
        GLOBAL.settings["proxiedApps"] = sorted(kept)
        GLOBAL.save_settings()
    if needs_pwd:
        emit("app_password_needed", {"key": needs_pwd})
    for key in kept:
        t = _find_target(key)
        if t and _target_needs_forwarder(t):
            _forwarder_for_target(t, True)
    # форвардер был включён автоматически, но HTTP-приложений больше нет
    if GLOBAL.forwarder_auto and not _http_targets_active():
        GLOBAL.forwarder_auto = False
        GLOBAL.settings["forwarderAuto"] = False
        _set_forwarder_raw(False)


class TorBackend(object):
    def __init__(self):
        self.proc = None
        self.thread = None
        self.stop_flag = False
        self.connected = False
        self.exit_info = None
        self.settings = dict(DEFAULT_SETTINGS)
        self._settings_loaded = False
        self._lock = threading.Lock()
        self.active_bridges = []
        self.vpn_on = False
        self._sudo_pwd = ""
        self._v6nat_ok = None
        # HTTP-форвардер (HTTP/CONNECT -> SOCKS5 :9050) на порту HTTP_PORT
        self.forwarder_on = False
        self.forwarder_auto = False
        self.forwarder_bind_all = False
        self._fwd_sock = None
        self._fwd_thread = None
        self._fwd_stop = False
        self._fwd_lock = threading.Lock()
        # Монитор состояния сети (NetworkManager) для индикатора-«светофора»
        self.net_state = "unknown"
        self._net_ok = None
        self._net_thread = None
        self._net_stop = False
        self._net_lock = threading.Lock()

    # ---------- состояние сети ----------
    def _start_net_monitor(self):
        with self._net_lock:
            if self._net_thread is not None and self._net_thread.is_alive():
                return
            self._net_stop = False
            self._net_thread = threading.Thread(target=self._net_loop, daemon=True)
            self._net_thread.start()

    def _net_loop(self):
        while not self._net_stop:
            state = _net_state()
            if state != self.net_state:
                self.net_state = state
                emit("net", {"state": state})
                self._log("Сеть: %s" % NET_LABELS.get(state, state),
                          "dim" if state in ("full", "limited") else "warn")
            ok = state in ("full", "limited")
            if ok and self._net_ok is False and self.connected:
                # связь восстановилась — быстро обновим данные об узле
                refresh_exit_ip()
            self._net_ok = ok
            time.sleep(NET_POLL_INTERVAL)

    # ---------- settings ----------
    def load_settings(self):
        data = dict(DEFAULT_SETTINGS)
        try:
            if os.path.exists(SETTINGS_PATH):
                with open(SETTINGS_PATH) as f:
                    stored = json.load(f)
                if isinstance(stored, dict):
                    data.update(stored)
        except Exception:
            pass
        if not data.get("sources"):
            data["sources"] = list(DEFAULT_SOURCES)
        self.settings = data
        self._settings_loaded = True
        return data

    def save_settings(self):
        if not self._settings_loaded:
            return
        try:
            os.makedirs(RUN_DIR, exist_ok=True)
            with open(SETTINGS_PATH, "w") as f:
                json.dump(self.settings, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    def settings_payload(self):
        payload = dict(self.settings)
        try:
            with open(CUSTOM_BRIDGES, "r", errors="ignore") as f:
                payload["customBridges"] = f.read()
        except Exception:
            payload["customBridges"] = ""
        return payload

    def _emit_settings(self):
        emit("settings", self.settings_payload())

    # ---------- helpers ----------
    def _log(self, text, kind="info"):
        text = _ANSI.sub("", text).strip()
        if not text:
            return
        _log_file(text)
        emit("log", {"text": text, "kind": kind})

    def _kind_for_tor_line(self, line):
        low = line.lower()
        if "[warn]" in low or "[err]" in low:
            return "warn"
        return "dim"

    def _our_pid(self):
        try:
            with open(PID_FILE) as f:
                return int(f.read().strip())
        except Exception:
            return None

    def _kill_our_tor(self):
        if self.proc is not None:
            try:
                _kill_group(self.proc)
            except Exception:
                pass
            self.proc = None
        pid = self._our_pid()
        if pid:
            try:
                os.kill(pid, signal.SIGTERM)
            except Exception:
                pass
        try:
            if os.path.exists(PID_FILE):
                os.remove(PID_FILE)
        except Exception:
            pass

    def _busy_ports(self):
        result = []
        for port in (SOCKS_PORT, CONTROL_PORT, TRANS_PORT):
            if _port_busy(port):
                pid, name = _port_owner(port)
                result.append({"port": port, "pid": pid, "name": name})
        return result

    # ---------- HTTP forwarder (HTTP/CONNECT -> SOCKS5 :9050) ----------
    def _forwarder_addr(self):
        return "0.0.0.0" if self.forwarder_bind_all else "127.0.0.1"

    def _start_forwarder(self):
        if self._fwd_thread is not None and self._fwd_thread.is_alive():
            return True
        addr = self._forwarder_addr()
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            sock.bind((addr, HTTP_PORT))
            sock.listen(16)
            sock.settimeout(1)
        except Exception as e:
            try:
                sock.close()
            except Exception:
                pass
            self._log("Форвардер: не удалось занять %s:%d (%s)"
                      % (addr, HTTP_PORT, e), "warn")
            return False
        self._fwd_sock = sock
        self._fwd_stop = False
        self._fwd_thread = threading.Thread(target=self._forwarder_loop, daemon=True)
        self._fwd_thread.start()
        self._log("Форвардер: HTTP-прокси на %s:%d" % (addr, HTTP_PORT), "ok")
        return True

    def _forwarder_loop(self):
        while not self._fwd_stop:
            try:
                client, _ = self._fwd_sock.accept()
            except socket.timeout:
                continue
            except Exception:
                break
            threading.Thread(target=self._handle_forwarder, args=(client,),
                             daemon=True).start()
        try:
            if self._fwd_sock:
                self._fwd_sock.close()
        except Exception:
            pass
        self._fwd_sock = None

    def _stop_forwarder(self):
        self._fwd_stop = True
        sock = self._fwd_sock
        if sock is not None:
            try:
                sock.close()
            except Exception:
                pass
        th = self._fwd_thread
        self._fwd_thread = None
        if th is not None and th.is_alive():
            th.join(timeout=2)

    def _sync_forwarder(self):
        """Привести работу форвардера в соответствие с флагом и состоянием Tor."""
        want = bool(self.forwarder_on and self.connected)
        with self._fwd_lock:
            running = self._fwd_thread is not None and self._fwd_thread.is_alive()
            if want and not running:
                self._start_forwarder()
            elif not want and running:
                self._stop_forwarder()
                if self.forwarder_on and not self.connected:
                    self._log("Форвардер: остановлен (Tor отключён)", "dim")

    @staticmethod
    def _pump(src, dst):
        try:
            while True:
                data = src.recv(4096)
                if not data:
                    break
                dst.sendall(data)
        except Exception:
            pass
        finally:
            try:
                dst.shutdown(socket.SHUT_WR)
            except Exception:
                pass

    def _forward_streams(self, a, b):
        t1 = threading.Thread(target=self._pump, args=(a, b), daemon=True)
        t2 = threading.Thread(target=self._pump, args=(b, a), daemon=True)
        t1.start()
        t2.start()
        t1.join()
        t2.join()
        for s in (a, b):
            try:
                s.close()
            except Exception:
                pass

    def _handle_forwarder(self, client):
        """Обработка одного HTTP/CONNECT-запроса: туннель к SOCKS5 :9050."""
        try:
            client.settimeout(30)
            request = client.recv(65536)
            if not request:
                client.close()
                return
            first_line = request.split(b"\n", 1)[0].decode("latin-1")
            parts = first_line.split()
            if len(parts) < 2:
                client.close()
                return
            method, url = parts[0].upper(), parts[1]
            if method == "CONNECT":
                host, _, port_s = url.partition(":")
                port = int(port_s) if port_s else 443
            else:
                u = url[7:] if url.startswith("http://") else url
                authority = u.split("/", 1)[0]
                host, _, port_s = authority.partition(":")
                port = int(port_s) if port_s else 80
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(30)
            sock.connect(("127.0.0.1", SOCKS_PORT))
            sock.sendall(b"\x05\x01\x00")
            if sock.recv(2) != b"\x05\x00":
                raise OSError("socks handshake failed")
            hb = host.encode("latin-1")
            sock.sendall(b"\x05\x01\x00\x03" + bytes([len(hb)]) + hb
                         + port.to_bytes(2, "big"))
            resp = sock.recv(10)
            if len(resp) < 2 or resp[1] != 0:
                raise OSError("socks connect failed")
            if method == "CONNECT":
                client.sendall(b"HTTP/1.0 200 Connection established\r\n\r\n")
            else:
                sock.sendall(request)
            self._forward_streams(client, sock)
        except Exception:
            try:
                client.close()
            except Exception:
                pass

    # ---------- torrc ----------
    def _generate_torrc(self, bridges):
        shutil.rmtree(TOR_DATA_DIR, ignore_errors=True)
        os.makedirs(TOR_DATA_DIR, exist_ok=True)
        bind = "0.0.0.0" if self.settings.get("bindAll") else "127.0.0.1"
        config = (
            "DataDirectory %s\n"
            "SocksPort %s:%d\n"
            "TransPort %s:%d\n"
            "DNSPort %s:%d\n"
            "AutomapHostsOnResolve 1\n"
            "ControlPort %d\n"
            "Log notice stdout\n"
            % (TOR_DATA_DIR, bind, SOCKS_PORT, bind, TRANS_PORT, bind, DNS_PORT,
               CONTROL_PORT)
        )
        if bridges:
            transports = []
            for b in bridges:
                t = _transport_for(b)
                if t not in transports:
                    transports.append(t)
            config += "\nUseBridges 1\n"
            for t in transports:
                config += "ClientTransportPlugin %s exec %s\n" % (t, LYREBIRD_BIN)
            for b in bridges:
                config += "Bridge %s\n" % b
        with open(TORRC_PATH, "w") as f:
            f.write(config)
        return TORRC_PATH

    def _pump_output(self, proc):
        try:
            for line in iter(proc.stdout.readline, ""):
                self._log(line, self._kind_for_tor_line(line))
        except Exception:
            pass
        finally:
            try:
                proc.stdout.close()
            except Exception:
                pass

    def _wait_bootstrap(self, timeout=BOOTSTRAP_TIMEOUT):
        start = time.time()
        last = 0
        while time.time() - start < timeout:
            if self.stop_flag:
                return False
            if self.proc is not None and self.proc.poll() is not None:
                return False
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(3)
                sock.connect(("127.0.0.1", CONTROL_PORT))
                sock.send(b"AUTHENTICATE\r\n")
                resp = sock.recv(1024)
                if b"250 OK" in resp:
                    sock.send(b"GETINFO status/bootstrap-phase\r\n")
                    resp = sock.recv(1024).decode(errors="ignore")
                    for line in resp.split("\n"):
                        if "PROGRESS=" in line:
                            percent = int(line.split("PROGRESS=")[1].split()[0])
                            summary = ""
                            if "SUMMARY=\"" in line:
                                summary = line.split("SUMMARY=\"")[1].split("\"")[0]
                            if percent > last:
                                last = percent
                                emit("bootstrap", {"percent": percent, "summary": summary})
                            if percent >= 100:
                                try:
                                    sock.send(b"QUIT\r\n")
                                except Exception:
                                    pass
                                sock.close()
                                return True
                sock.close()
            except Exception:
                pass
            time.sleep(3)
        return False

    # ---------- IP over SOCKS5 ----------
    def _socks5_connect(self, host, port):
        s = socket.create_connection(("127.0.0.1", SOCKS_PORT), timeout=15)
        s.settimeout(15)
        s.sendall(b"\x05\x01\x00")
        if s.recv(2)[:2] != b"\x05\x00":
            raise OSError("socks handshake failed")
        hb = host.encode("idna")
        req = b"\x05\x01\x00\x03" + bytes([len(hb)]) + hb + port.to_bytes(2, "big")
        s.sendall(req)
        resp = s.recv(10)
        if len(resp) < 2 or resp[1] != 0:
            raise OSError("socks connect failed")
        return s

    def _http_get_via_socks(self, url):
        p = urllib.parse.urlsplit(url)
        host = p.hostname
        if not host:
            raise ValueError("bad url")
        scheme = p.scheme or "http"
        port = p.port or (443 if scheme == "https" else 80)
        path = p.path or "/"
        if p.query:
            path += "?" + p.query
        s = self._socks5_connect(host, port)
        if scheme == "https":
            ctx = ssl.create_default_context()
            s = ctx.wrap_socket(s, server_hostname=host)
        req = ("GET %s HTTP/1.0\r\nHost: %s\r\nUser-Agent: Mozilla/5.0\r\n"
               "Connection: close\r\n\r\n" % (path, host)).encode()
        s.sendall(req)
        data = b""
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            data += chunk
        try:
            s.close()
        except Exception:
            pass
        return data

    def _get_exit_info(self):
        service = self.settings.get("ipService") or DEFAULT_IP_SERVICE
        try:
            raw = self._http_get_via_socks(service)
            body = raw.split(b"\r\n\r\n", 1)[-1].decode(errors="ignore").strip()
            if body and "{" in body:
                return json.loads(body)
        except Exception:
            pass
        return None

    def _info_payload(self, info):
        return {
            "ip": info.get("ip", ""),
            "country": info.get("country", ""),
            "iso": (info.get("country_iso") or info.get("country_code") or "").upper(),
            "asn": info.get("asn_org") or info.get("asn") or "",
        }

    # ---------- bridge download ----------
    def _download_url(self, url):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read().decode("utf-8", "ignore")
        except Exception as e:
            self._log("urllib: %s — пробую wget…" % e, "warn")
        try:
            out = subprocess.run(["wget", "-q", "-O", "-", url],
                                 capture_output=True, timeout=45)
            if out.returncode == 0 and out.stdout:
                return out.stdout.decode("utf-8", "ignore")
        except Exception as e2:
            self._log("wget: %s" % e2, "warn")
        return None

    def _download_bridges(self):
        sources = self.settings.get("sources") or []
        plain = []
        for url in sources:
            self._log("Источник: %s" % url, "dim")
            text = self._download_url(url)
            if not text:
                self._log("  не удалось скачать", "warn")
                continue
            count = 0
            for raw in text.splitlines():
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                line = _norm_bridge(line)
                if _is_valid_bridge(line):
                    plain.append(line)
                    count += 1
            self._log("  строк: %d" % count, "ok" if count else "dim")

        seen = set()
        bridges = []
        for b in plain:
            if b not in seen:
                seen.add(b)
                bridges.append(b)

        obfs4 = [b for b in bridges if "obfs4" in b.lower()]
        webt = [b for b in bridges if "webtunnel" in b.lower()]

        os.makedirs(BRIDGE_DIR, exist_ok=True)
        with open(OBFS4_FILE, "w") as f:
            for b in obfs4:
                f.write(b + "\n")
        with open(WEBTUNNEL_FILE, "w") as f:
            for b in webt:
                f.write(b + "\n")

        self._log("Обновлено: obfs4=%d, webtunnel=%d" % (len(obfs4), len(webt)), "ok")
        emit("bridges_updated", {"obfs4": len(obfs4), "webtunnel": len(webt)})
        return bridges

    # ---------- worker ----------
    def _run(self, mode):
        try:
            if not (os.path.exists(TOR_BIN) and os.path.exists(LYREBIRD_BIN)):
                self._log("Не найден tor или lyrebird в tor/", "warn")
                emit("failed", {"reason": "binary_missing"})
                return

            if (mode in ("obfs4", "webtunnel")
                    and self.settings.get("autoUpdate")
                    and self.settings.get("sources")):
                self._log("Обновляю списки мостов…", "info")
                self._download_bridges()

            bridges = _load_bridges(mode)
            if not bridges:
                self._log("Нет мостов для режима «%s»" % mode, "warn")
                emit("failed", {"reason": "no_bridges"})
                return

            random.shuffle(bridges)
            self._log("Мосты (%s): %d шт. (по 2 за попытку)" % (mode, len(bridges)), "info")

            total = len(bridges)
            for i in range(0, total, 2):
                if self.stop_flag:
                    break
                pair = bridges[i:i + 2]
                self._log("Попытка [%d-%d/%d]: %s…"
                          % (i + 1, i + len(pair), total, pair[0][:52]), "info")
                self._generate_torrc(pair)

                self.proc = subprocess.Popen(
                    [TOR_BIN, "-f", TORRC_PATH],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    start_new_session=True,
                )
                threading.Thread(target=self._pump_output, args=(self.proc,), daemon=True).start()

                if self._wait_bootstrap():
                    self._log("Сеть Tor загружена!", "ok")
                    time.sleep(3)
                    info = self._get_exit_info()
                    self._save_pid(self.proc.pid)
                    for b in pair:
                        self._save_working_bridge(b)
                    self.active_bridges = list(pair)
                    self.connected = True
                    if info:
                        self.exit_info = info
                        emit("connected", self._info_payload(info))
                        self._log("Выходной узел: %s (%s)" % (
                            info.get("country", "?"),
                            (info.get("country_iso") or "").upper()), "ok")
                    else:
                        emit("connected", {"ip": "", "country": "", "iso": "", "asn": ""})
                    self._sync_forwarder()
                    return

                self._log("Пара не подошла, следующая…", "dim")
                self._kill_our_tor()
                time.sleep(1)

            if self.stop_flag:
                self._log("Запуск отменён", "dim")
            else:
                self._log("Ни один мост не подошёл.", "warn")
                emit("failed", {"reason": "no_bridge_worked"})
        except Exception as e:
            self._log("Ошибка запуска: %s" % e, "warn")
            emit("failed", {"reason": str(e)})
        finally:
            with self._lock:
                self.thread = None

    def _save_working_bridge(self, bridge_line):
        try:
            os.makedirs(BRIDGE_DIR, exist_ok=True)
            existing = set()
            if os.path.exists(WORKING_BRIDGES):
                with open(WORKING_BRIDGES, "r", errors="ignore") as f:
                    existing = set(l.strip() for l in f if l.strip())
            entry = "Bridge " + bridge_line
            if entry not in existing and bridge_line not in existing:
                with open(WORKING_BRIDGES, "a") as f:
                    f.write(entry + "\n")
        except Exception:
            pass

    def _save_pid(self, pid):
        try:
            with open(PID_FILE, "w") as f:
                f.write(str(pid))
        except Exception:
            pass

    # ---------- sudo / system VPN ----------
    def _run_sudo(self, args, pwd=None):
        if not pwd:
            pwd = self._sudo_pwd or None
        cmd = [SUDO_BIN]
        if pwd:
            cmd += ["-S", "-p", ""]
        else:
            cmd += ["-n"]
        cmd += list(args)
        try:
            p = subprocess.run(
                cmd,
                input=(pwd + "\n").encode() if pwd else None,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=25,
            )
            return p.returncode, p.stdout.decode(errors="ignore"), p.stderr.decode(errors="ignore")
        except Exception as e:
            return 1, "", str(e)

    def sudo_check(self, pwd=""):
        pwd = pwd or ""
        rc, _, _ = self._run_sudo(["/bin/true"], pwd)
        if rc == 0 and pwd:
            self._sudo_pwd = pwd
        return {"ok": rc == 0}

    def _ipt(self, prog, args, pwd):
        rc, out, err = self._run_sudo([prog, "-w"] + list(args), pwd)
        return rc, (err or out).strip()

    def _active_bridge_ips(self):
        ips = []
        for b in self.active_bridges:
            ip = _bridge_ip(b)
            if ip and ip not in ips:
                ips.append(ip)
        return ips

    # ---- v6 NAT capability (this kernel often lacks ip6table_nat) ----
    def _detect_ipv6_nat(self):
        """Detect ip6tables nat support without root via /proc/config.gz.
        Returns True/False, or None if unknown."""
        try:
            import gzip
            with gzip.open("/proc/config.gz", "rt", errors="ignore") as f:
                for line in f:
                    s = line.strip()
                    if s.startswith("CONFIG_IP6_NF_NAT="):
                        return s.endswith("=y") or s.endswith("=m")
                    if s == "# CONFIG_IP6_NF_NAT is not set":
                        return False
        except Exception:
            pass
        return None

    def _v6_nat_supported(self, pwd):
        if self._v6nat_ok is not None:
            return self._v6nat_ok
        rc, out, err = self._run_sudo(["ip6tables", "-w", "-t", "nat", "-L", "-n"], pwd)
        text = ((err or "") + " " + (out or "")).lower()
        if rc == 0:
            self._v6nat_ok = True
        elif ("does not exist" in text or "can't initialize" in text
                or "table" in text and "nat" in text):
            self._v6nat_ok = False
        else:
            self._v6nat_ok = False
        return self._v6nat_ok

    def _clean_v4(self, pwd):
        self._ipt("iptables", ["-t", "nat", "-D", "OUTPUT", "-j", VPN_CHAIN], pwd)
        self._ipt("iptables", ["-t", "nat", "-F", VPN_CHAIN], pwd)
        self._ipt("iptables", ["-t", "nat", "-X", VPN_CHAIN], pwd)

    def _clean_v6(self, pwd):
        self._ipt("ip6tables", ["-t", "nat", "-D", "OUTPUT", "-j", VPN_CHAIN], pwd)
        self._ipt("ip6tables", ["-t", "nat", "-F", VPN_CHAIN], pwd)
        self._ipt("ip6tables", ["-t", "nat", "-X", VPN_CHAIN], pwd)
        self._ipt("ip6tables", ["-D", "OUTPUT", "-j", VPN_CHAIN], pwd)
        self._ipt("ip6tables", ["-F", VPN_CHAIN], pwd)
        self._ipt("ip6tables", ["-X", VPN_CHAIN], pwd)

    def _apply_rules(self):
        pwd = self._sudo_pwd
        dns = self.settings.get("vpnDns", "system")
        ipv6 = self.settings.get("vpnIpv6", "off")
        antiloop = bool(self.settings.get("vpnAntiLoop", False))
        bridge_ips = self._active_bridge_ips() if antiloop else []

        # ---- IPv4 (primary) ----
        self._clean_v4(pwd)
        self._ipt("iptables", ["-t", "nat", "-N", VPN_CHAIN], pwd)
        for net in PRIVATE_V4:
            self._ipt("iptables", ["-t", "nat", "-A", VPN_CHAIN, "-d", net, "-j", "RETURN"], pwd)
        for ip in bridge_ips:
            if ":" not in ip:
                self._ipt("iptables", ["-t", "nat", "-A", VPN_CHAIN, "-d", ip, "-j", "RETURN"], pwd)
        if dns in ("udp", "udp_tcp"):
            self._ipt("iptables", ["-t", "nat", "-A", VPN_CHAIN, "-p", "udp",
                                   "--dport", "53", "-j", "REDIRECT", "--to-ports", str(DNS_PORT)], pwd)
        if dns == "udp_tcp":
            self._ipt("iptables", ["-t", "nat", "-A", VPN_CHAIN, "-p", "tcp",
                                   "--dport", "53", "-j", "REDIRECT", "--to-ports", str(TRANS_PORT)], pwd)
        self._ipt("iptables", ["-t", "nat", "-A", VPN_CHAIN, "-p", "tcp",
                               "-j", "REDIRECT", "--to-ports", str(TRANS_PORT)], pwd)
        rc4, err4 = self._ipt("iptables", ["-t", "nat", "-A", "OUTPUT", "-j", VPN_CHAIN], pwd)
        v4_ok = (rc4 == 0)
        if not v4_ok:
            self._log("VPN v4: ошибка применения правил: %s" % err4, "warn")

        # ---- IPv6 (optional, never breaks v4) ----
        self._clean_v6(pwd)
        v6_ok = True
        note = ""
        if ipv6 == "drop":
            self._ipt("ip6tables", ["-N", VPN_CHAIN], pwd)
            for net in PRIVATE_V6:
                self._ipt("ip6tables", ["-A", VPN_CHAIN, "-d", net, "-j", "RETURN"], pwd)
            for ip in bridge_ips:
                if ":" in ip:
                    self._ipt("ip6tables", ["-A", VPN_CHAIN, "-d", ip, "-j", "RETURN"], pwd)
            self._ipt("ip6tables", ["-A", VPN_CHAIN, "-j", "DROP"], pwd)
            rc6, err6 = self._ipt("ip6tables", ["-A", "OUTPUT", "-j", VPN_CHAIN], pwd)
            v6_ok = (rc6 == 0)
            note = "v6: блокировка активна" if v6_ok else ("v6: ошибка DROP: " + err6)
        elif ipv6 == "tor":
            if not self._v6_nat_supported(pwd):
                v6_ok = False
                note = "v6: таблица nat недоступна в ядре — режим «Через Tor» пропущен"
                self.settings["ipv6NatOk"] = False
                self.save_settings()
            else:
                self._ipt("ip6tables", ["-t", "nat", "-N", VPN_CHAIN], pwd)
                for net in PRIVATE_V6:
                    self._ipt("ip6tables", ["-t", "nat", "-A", VPN_CHAIN, "-d", net, "-j", "RETURN"], pwd)
                for ip in bridge_ips:
                    if ":" in ip:
                        self._ipt("ip6tables", ["-t", "nat", "-A", VPN_CHAIN, "-d", ip, "-j", "RETURN"], pwd)
                if dns in ("udp", "udp_tcp"):
                    self._ipt("ip6tables", ["-t", "nat", "-A", VPN_CHAIN, "-p", "udp",
                                            "--dport", "53", "-j", "REDIRECT", "--to-ports", str(DNS_PORT)], pwd)
                if dns == "udp_tcp":
                    self._ipt("ip6tables", ["-t", "nat", "-A", VPN_CHAIN, "-p", "tcp",
                                            "--dport", "53", "-j", "REDIRECT", "--to-ports", str(TRANS_PORT)], pwd)
                self._ipt("ip6tables", ["-t", "nat", "-A", VPN_CHAIN, "-p", "tcp",
                                        "-j", "REDIRECT", "--to-ports", str(TRANS_PORT)], pwd)
                rc6, err6 = self._ipt("ip6tables", ["-t", "nat", "-A", "OUTPUT", "-j", VPN_CHAIN], pwd)
                v6_ok = (rc6 == 0)
                note = "v6: через Tor" if v6_ok else ("v6: ошибка REDIRECT: " + err6)

        if note:
            self._log(note, "dim" if v6_ok else "warn")
        dns_label = {"system": "системный (порт 53 — возможна утечка DNS!)",
                     "udp": "через Tor (UDP/53)",
                     "udp_tcp": "через Tor (UDP+TCP/53)"}.get(dns, dns)
        self._log("DNS: " + dns_label, "warn" if dns == "system" else "dim")
        ipv6_label = {"off": "Напрямую (без правил)",
                      "drop": "Отключить (DROP)",
                      "tor": "Через Tor"}.get(ipv6, ipv6)
        self._log("IPv6: " + ipv6_label, "dim")
        if v4_ok:
            self._log("VPN v4: правила применены", "ok")

        return {"ok": v4_ok, "v4": v4_ok, "v6": v6_ok, "note": note,
                "error": ("" if v4_ok else ("v4: " + err4))}

    # ---- marker ----
    def _write_vpn_marker(self):
        try:
            os.makedirs(RUN_DIR, exist_ok=True)
            with open(VPN_STATE_FILE, "w") as f:
                f.write("on\n")
        except Exception:
            pass

    def _clear_vpn_marker(self):
        try:
            if os.path.exists(VPN_STATE_FILE):
                os.remove(VPN_STATE_FILE)
        except Exception:
            pass

    def _vpn_leftover(self):
        return os.path.exists(VPN_STATE_FILE)

    def vpn_start(self, pwd=""):
        if not self.connected:
            return {"ok": False, "error": "tor_off"}
        pwd = pwd or ""
        if not self.sudo_check(pwd)["ok"]:
            return {"ok": False, "error": "bad_password" if pwd else "need_password"}
        res = self._apply_rules()
        if not res.get("ok"):
            emit("vpn", {"on": False, "error": res.get("error", "apply_failed")})
            return res
        self.vpn_on = True
        self._write_vpn_marker()
        self._log("Системный VPN включён", "ok")
        emit("vpn", {"on": True, "error": ""})
        return {"ok": True, "v6": res.get("v6", True), "note": res.get("note", "")}

    def vpn_stop(self, pwd=""):
        pwd = pwd or ""
        if not self.sudo_check(pwd)["ok"]:
            return {"ok": False, "error": "bad_password" if pwd else "need_password"}
        self._clean_v4(self._sudo_pwd)
        self._clean_v6(self._sudo_pwd)
        self.vpn_on = False
        self._clear_vpn_marker()
        self._log("Системный VPN выключен", "dim")
        emit("vpn", {"on": False, "error": ""})
        return {"ok": True}

    def vpn_reapply(self):
        if not self.vpn_on:
            return {"ok": True, "on": False}
        res = self._apply_rules()
        if res.get("ok"):
            self._log("Правила VPN обновлены", "info")
        else:
            self._log("Не удалось обновить правила VPN: %s" % res.get("error", ""), "warn")
        return res

    def vpn_status(self):
        return {
            "on": bool(self.vpn_on),
            "leftover": self._vpn_leftover(),
            "ipv6NatOk": bool(self.settings.get("ipv6NatOk", True)),
        }


GLOBAL = TorBackend()


# ---------- PyOtherSide handlers ----------
def init():
    try:
        os.makedirs(RUN_DIR, exist_ok=True)
        os.makedirs(LOG_DIR, exist_ok=True)
        os.makedirs(BRIDGE_DIR, exist_ok=True)
    except Exception:
        pass
    GLOBAL.load_settings()
    GLOBAL.forwarder_on = bool(GLOBAL.settings.get("forwarder", False))
    GLOBAL.forwarder_auto = bool(GLOBAL.settings.get("forwarderAuto", False))
    GLOBAL.forwarder_bind_all = bool(GLOBAL.settings.get("forwarderBindAll", False))
    nat = GLOBAL._detect_ipv6_nat()
    if nat is not None:
        GLOBAL._v6nat_ok = nat
        if GLOBAL.settings.get("ipv6NatOk", True) != nat:
            GLOBAL.settings["ipv6NatOk"] = nat
            GLOBAL.save_settings()
        if not nat and GLOBAL.settings.get("vpnIpv6") == "tor":
            GLOBAL.settings["vpnIpv6"] = "drop"
            GLOBAL.save_settings()
    _apply_saved_proxies()
    GLOBAL._start_net_monitor()
    GLOBAL._log("Бэкенд запущен (Python %s)" % sys.version.split()[0], "dim")
    GLOBAL._emit_settings()
    emit("app_targets", _all_targets())
    emit("forwarder", get_forwarder())
    emit("net", {"state": GLOBAL.net_state})
    emit("vpn_state", GLOBAL.vpn_status())
    emit("ready", {})
    return "ready"


def get_settings():
    return GLOBAL.settings_payload()


def set_setting(key, value):
    if key in ("sources", "autoUpdate", "bridgeMode", "bridgeModeChosen",
               "bindAll", "ipService", "vpnDns", "vpnIpv6", "vpnAntiLoop",
               "ipv6NatOk"):
        GLOBAL.settings[key] = value
        GLOBAL.save_settings()
        GLOBAL._emit_settings()
        if GLOBAL.vpn_on and key in ("vpnDns", "vpnIpv6", "vpnAntiLoop"):
            GLOBAL.vpn_reapply()
    return GLOBAL.settings_payload()


def normalize(text):
    kept = _filter_bridges(text)
    GLOBAL._log("Приведено к виду: %d мостов" % len(kept), "ok" if kept else "dim")
    return {"count": len(kept), "text": "\n".join(kept)}


def save_custom(text):
    res = normalize(text)
    os.makedirs(BRIDGE_DIR, exist_ok=True)
    with open(CUSTOM_BRIDGES, "w") as f:
        for line in res["text"].splitlines():
            f.write(line + "\n")
    GLOBAL._emit_settings()
    return res


def update_bridges():
    def worker():
        GLOBAL._log("Обновление списков мостов…", "info")
        GLOBAL._download_bridges()
    threading.Thread(target=worker, daemon=True).start()
    return {"status": "started"}


def start(mode="obfs4", bind_all=True):
    with GLOBAL._lock:
        if GLOBAL.thread is not None and GLOBAL.thread.is_alive():
            GLOBAL._log("Уже выполняется запуск…", "warn")
            return {"status": "busy"}

        if GLOBAL._vpn_leftover():
            GLOBAL._log("Активны правила системного VPN — сначала очистите их", "warn")
            emit("failed", {"reason": "vpn_leftover"})
            return {"status": "vpn_leftover"}

        GLOBAL.settings["bindAll"] = bool(bind_all)
        GLOBAL.settings["bridgeMode"] = mode
        GLOBAL.save_settings()

        GLOBAL._kill_our_tor()
        busy = GLOBAL._busy_ports()
        if busy:
            emit("port_busy", {"ports": busy})
            return {"status": "port_busy", "ports": busy}

        GLOBAL.stop_flag = False
        GLOBAL.connected = False
        GLOBAL._log("Запуск Tor (режим: %s, bind %s)…"
                    % (mode, "0.0.0.0" if bind_all else "127.0.0.1"), "info")
        t = threading.Thread(target=GLOBAL._run, args=(mode,), daemon=True)
        GLOBAL.thread = t
        t.start()
        return {"status": "started"}


def stop():
    GLOBAL.stop_flag = True
    GLOBAL.connected = False
    if GLOBAL.vpn_on:
        GLOBAL.vpn_stop()
    GLOBAL._kill_our_tor()
    GLOBAL._stop_forwarder()
    GLOBAL._log("Tor остановлен", "dim")
    emit("stopped", {})
    return {"status": "stopped"}


def status():
    running = GLOBAL.proc is not None and GLOBAL.proc.poll() is None
    return {
        "running": running,
        "connected": GLOBAL.connected,
        "bind_all": GLOBAL.settings.get("bindAll", False),
        "vpn": bool(GLOBAL.vpn_on),
        "vpn_leftover": GLOBAL._vpn_leftover(),
        "ipv6_nat_ok": bool(GLOBAL.settings.get("ipv6NatOk", True)),
    }


def kill_all_tor():
    GLOBAL._log("Завершаю все процессы Tor…", "warn")
    try:
        subprocess.run("pkill -f 'tor ' 2>/dev/null", shell=True, timeout=10)
    except Exception:
        pass
    try:
        subprocess.run("pkill -f 'lyrebird' 2>/dev/null", shell=True, timeout=10)
    except Exception:
        pass
    GLOBAL.proc = None
    GLOBAL.stop_flag = True
    GLOBAL.connected = False
    GLOBAL._stop_forwarder()
    try:
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
    except Exception:
        pass
    time.sleep(1)
    GLOBAL._log("Все процессы Tor завершены", "ok")
    return {"status": "killed"}


def check_ports():
    return {"ports": GLOBAL._busy_ports()}


def set_bind(bind_all):
    set_setting("bindAll", bool(bind_all))
    return {"bind_address": "0.0.0.0" if bind_all else "127.0.0.1"}


def get_forwarder():
    return {"on": bool(GLOBAL.forwarder_on),
            "bindAll": bool(GLOBAL.forwarder_bind_all),
            "running": bool(GLOBAL._fwd_thread is not None
                            and GLOBAL._fwd_thread.is_alive())}


def _set_forwarder_raw(enabled):
    """Применить состояние форвардера без правки флага «авто»."""
    enabled = bool(enabled)
    GLOBAL.forwarder_on = enabled
    GLOBAL.settings["forwarder"] = enabled
    GLOBAL.save_settings()
    GLOBAL._sync_forwarder()
    emit("forwarder", get_forwarder())


def set_forwarder(enabled):
    enabled = bool(enabled)
    # ручное действие пользователя — форвардер больше не «авто»
    GLOBAL.forwarder_auto = False
    GLOBAL.settings["forwarderAuto"] = False
    _set_forwarder_raw(enabled)
    GLOBAL._log("Форвардер %s" % ("включён" if enabled else "выключен"),
                "ok" if enabled else "dim")
    if enabled and not GLOBAL.connected:
        GLOBAL._log("Форвардер заработает после подключения к Tor", "dim")
    return get_forwarder()


def set_forwarder_bind(bind_all):
    bind_all = bool(bind_all)
    GLOBAL.forwarder_bind_all = bind_all
    GLOBAL.settings["forwarderBindAll"] = bind_all
    GLOBAL.save_settings()
    with GLOBAL._fwd_lock:
        if GLOBAL._fwd_thread is not None and GLOBAL._fwd_thread.is_alive():
            GLOBAL._stop_forwarder()
    GLOBAL._sync_forwarder()
    emit("forwarder", get_forwarder())
    return get_forwarder()


def _http_targets_active(exclude=None):
    """Есть ли ещё проксируемые приложения в HTTP-режиме (кроме exclude)."""
    for k in GLOBAL.settings.get("proxiedApps", []) or []:
        if k == exclude:
            continue
        t = _find_target(k)
        if t and t.get("enabled", True) and _target_needs_forwarder(t):
            return True
    return False


def _forwarder_for_target(target, enabled):
    """HTTP-режим требует форвардер. Включаем «на время» и запоминаем это,
    чтобы вернуть исходное состояние, когда прокси приложения выключат."""
    if not _target_needs_forwarder(target):
        return
    if enabled:
        if not GLOBAL.forwarder_on:
            GLOBAL.forwarder_auto = True
            GLOBAL.settings["forwarderAuto"] = True
            _set_forwarder_raw(True)
            GLOBAL._log("Форвардер включён автоматически (нужен для «%s»)"
                        % target.get("name", ""), "info")
    else:
        if GLOBAL.forwarder_auto and not _http_targets_active(exclude=target.get("key")):
            GLOBAL.forwarder_auto = False
            GLOBAL.settings["forwarderAuto"] = False
            _set_forwarder_raw(False)
            GLOBAL._log("Форвардер выключен (авто)", "dim")


def refresh_exit_ip():
    def worker():
        if not GLOBAL.connected:
            GLOBAL._log("Выходной IP: нет подключения", "dim")
            return
        info = GLOBAL._get_exit_info()
        if info:
            GLOBAL.exit_info = info
            emit("exit_ip", GLOBAL._info_payload(info))
            GLOBAL._log("Выходной IP: %s" % info.get("ip", "?"), "info")
        else:
            GLOBAL._log("Не удалось обновить данные об узле", "warn")
            emit("exit_ip", {"ip": "", "country": "", "iso": "", "asn": "",
                             "error": "no_exit"})
    threading.Thread(target=worker, daemon=True).start()
    return {"status": "checking"}


def sudo_check(pwd=""):
    return GLOBAL.sudo_check(pwd)


def vpn_start(pwd=""):
    return GLOBAL.vpn_start(pwd)


def vpn_stop(pwd=""):
    return GLOBAL.vpn_stop(pwd)


def vpn_status():
    return GLOBAL.vpn_status()


def vpn_reapply():
    return GLOBAL.vpn_reapply()


def vpn_cleanup(pwd=""):
    return GLOBAL.vpn_stop(pwd)
