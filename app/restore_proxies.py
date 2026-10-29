#!/usr/bin/env python3
"""Вернуть системные .desktop и systemd drop-in в состояние «до TorApp».

Используется удалятором: снимает per-app прокси, наложенные приложением.
Источник оригиналов — ~/.local/bin/proxybak/<key>/*.orig (их создаёт бэкенд).
Правка файлов в /opt требует root — будет один запрос пароля (sudo).

Никаких секретов не хранит и не печатает.
"""
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

HOME = os.path.expanduser("~")
PROXYBAK = os.path.join(HOME, ".local", "bin", "proxybak")
APPLICATIONS = os.path.join(HOME, ".local", "share", "applications")
CLICK_APPS = "/opt/click.ubuntu.com"
SYSTEMD_USER = os.path.join(HOME, ".config", "systemd", "user")
DROPIN = "zz-torapp.conf"

MARKERS = (
    "ALL_PROXY=socks5://127.0.0.1:9050",
    "QTWEBENGINE_CHROMIUM_FLAGS",
    "http_proxy=http://127.0.0.1:8118",
)

_sudo_checked = False
_sudo_ok = False


def _read(path):
    try:
        with open(path, "r", errors="ignore") as f:
            return f.read()
    except Exception:
        return None


def _is_proxied(text):
    return any(m in text for m in MARKERS)


def _sudo(argv):
    global _sudo_checked, _sudo_ok
    if not _sudo_checked:
        _sudo_checked = True
        try:
            _sudo_ok = subprocess.call(["sudo", "-v"]) == 0
        except Exception:
            _sudo_ok = False
        if not _sudo_ok:
            print("  ! нужен root для правки /opt (запусти из терминала) — пропускаю")
    if not _sudo_ok:
        return False
    try:
        return subprocess.call(["sudo"] + argv) == 0
    except Exception:
        return False


def _write(path, text):
    if os.access(path, os.W_OK) and os.access(os.path.dirname(path), os.W_OK):
        tmp = path + ".torapp.tmp"
        try:
            with open(tmp, "w") as f:
                f.write(text)
            os.replace(tmp, path)
            return True
        except Exception:
            try:
                os.remove(tmp)
            except Exception:
                pass
            return False
    fd, tmp = tempfile.mkstemp(prefix="torapp-", suffix=".desktop")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
        return _sudo(["install", "-o", "clickpkg", "-g", "clickpkg",
                      "-m", "644", tmp, path])
    finally:
        try:
            os.remove(tmp)
        except Exception:
            pass


def _resolve_real(mirror):
    src = None
    if mirror and os.path.exists(mirror):
        try:
            with open(mirror, "r", errors="ignore") as f:
                for line in f:
                    if line.startswith("X-Lomiri-Source-Desktop="):
                        src = line.split("=", 1)[1].strip()
                        break
        except Exception:
            src = None
    if src:
        return os.path.realpath(src)
    return os.path.realpath(mirror) if mirror else None


def _targets(base, mirror_hint):
    out = []
    mirror = os.path.join(APPLICATIONS, base)
    if os.path.exists(mirror):
        out.append(mirror)
    real = _resolve_real(mirror if os.path.exists(mirror) else mirror_hint)
    if real and os.path.exists(real) and os.path.basename(real) == base \
            and real not in out:
        out.append(real)
    for p in glob.glob(os.path.join(CLICK_APPS, "*", "current", base)):
        if os.path.exists(p) and p not in out:
            out.append(p)
    return out


def _remove_orig(path):
    orig = path + ".orig"
    if not os.path.exists(orig):
        return
    if os.access(os.path.dirname(path), os.W_OK):
        try:
            os.remove(orig)
            return
        except Exception:
            pass
    _sudo(["rm", "-f", orig])


def restore_desktops():
    failures = 0
    if not os.path.isdir(PROXYBAK):
        print("proxybak не найден — прокси не применялись")
        return 0
    for keydir in sorted(glob.glob(os.path.join(PROXYBAK, "*"))):
        if not os.path.isdir(keydir):
            continue
        key = os.path.basename(keydir)
        meta = {}
        try:
            with open(os.path.join(keydir, "meta.json")) as f:
                meta = json.load(f)
        except Exception:
            pass
        mirror_hint = meta.get("desktop") or ""
        handled = True
        found = False
        for orig in sorted(glob.glob(os.path.join(keydir, "*.orig"))):
            base = os.path.basename(orig)[:-5]
            content = _read(orig)
            if content is None:
                continue
            targets = _targets(base, mirror_hint)
            if not targets:
                print("  %s: %s — цель не найдена, пропуск" % (key, base))
                continue
            found = True
            for path in targets:
                cur = _read(path)
                if cur is None:
                    continue
                if not _is_proxied(cur):
                    print("  %s: %s — уже без прокси" % (key, path))
                    _remove_orig(path)
                    continue
                if _write(path, content):
                    print("  %s: восстановлен %s" % (key, path))
                    _remove_orig(path)
                else:
                    print("  %s: НЕ удалось восстановить %s" % (key, path))
                    handled = False
        if found and handled:
            shutil.rmtree(keydir, ignore_errors=True)
        failures += 0 if handled else 1
    return failures


def restore_systemd():
    confs = glob.glob(os.path.join(SYSTEMD_USER, "*.service.d", DROPIN))
    if not confs:
        return 0
    services = []
    for conf in confs:
        svc = os.path.basename(os.path.dirname(conf))[:-len(".d")]
        try:
            os.remove(conf)
            print("  systemd: удалён drop-in для %s" % svc)
            services.append(svc)
        except Exception as e:
            print("  systemd: не удалось удалить %s: %s" % (conf, e))
    for d in glob.glob(os.path.join(SYSTEMD_USER, "*.service.d")):
        try:
            if not os.listdir(d):
                os.rmdir(d)
        except Exception:
            pass
    if services:
        subprocess.call(["systemctl", "--user", "daemon-reload"])
        for svc in services:
            subprocess.call(["systemctl", "--user", "restart", svc])
    return 0


def main():
    print("== Возврат системы в состояние до TorApp ==")
    failures = restore_desktops()
    restore_systemd()
    if failures:
        print("Были ошибки — проверь вывод выше (возможно, нужен root).")
        return 1
    print("Готово: прокси сняты, оригиналы возвращены.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
