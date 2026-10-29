#!/bin/sh
# TorApp QML — удаление установленного приложения.
# Убирает: папку приложения и ярлык, а также возвращает проксированные
# системные .desktop и systemd drop-in в состояние «до TorApp».

DEST="$HOME/.local/bin/torappqml"
APPS="$HOME/.local/share/applications"
DESKTOP="$APPS/torappqml.desktop"

echo "== TorApp QML: удаление =="

# 1. Остановить процессы приложения (только из нашей папки).
#    Скобки [x] в шаблоне не дают pkill убить собственную команду.
pkill -f "$DEST/app/[r]un.sh" 2>/dev/null
pkill -f "$DEST/app/[M]ain.qml" 2>/dev/null
pkill -f "$DEST/app/[t]or/tor" 2>/dev/null
pkill -f "$DEST/app/[t]or/pluggable_transports/[l]yrebird" 2>/dev/null

alive() {
    pgrep -f "$DEST/app/[r]un.sh" >/dev/null 2>&1 && return 0
    pgrep -f "$DEST/app/[M]ain.qml" >/dev/null 2>&1 && return 0
    pgrep -f "$DEST/app/[t]or/tor" >/dev/null 2>&1 && return 0
    pgrep -f "$DEST/app/[t]or/pluggable_transports/[l]yrebird" >/dev/null 2>&1 && return 0
    return 1
}

i=0
while alive && [ $i -lt 10 ]; do
    sleep 1
    i=$((i + 1))
done
if alive; then
    pkill -9 -f "$DEST/app/[r]un.sh" 2>/dev/null
    pkill -9 -f "$DEST/app/[M]ain.qml" 2>/dev/null
    pkill -9 -f "$DEST/app/[t]or/tor" 2>/dev/null
    pkill -9 -f "$DEST/app/[t]or/pluggable_transports/[l]yrebird" 2>/dev/null
    sleep 1
    echo "процессы остановлены (принудительно)"
else
    echo "процессы остановлены"
fi

# 2. Вернуть систему в исходное состояние (снять прокси, убрать drop-in).
if [ -f "$DEST/app/restore_proxies.py" ]; then
    python3 "$DEST/app/restore_proxies.py" || \
        echo "предупреждение: не всё удалось восстановить (см. вывод выше)"
else
    echo "restore_proxies.py не найден — возврат прокси пропущен"
fi

# 3. Удалить папку и ярлык.
rm -rf "$DEST"
rm -f "$DESKTOP"

# 4. Проверка следов.
echo ""
fail=0
for p in "$DEST" "$DESKTOP"; do
    if [ -e "$p" ]; then
        echo "  ОСТАЛОСЬ: $p"
        fail=1
    else
        echo "  удалено: $p"
    fi
done
echo ""
if [ "$fail" = "0" ]; then
    echo "Готово: приложение удалено."
else
    echo "Что-то не удалилось — покажите этот вывод."
    exit 1
fi
