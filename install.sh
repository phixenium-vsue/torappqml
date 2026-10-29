#!/bin/sh
# TorApp QML — установщик (онлайн из latest-релиза или офлайн рядом с архивом).
set -e

REPO="phixenium-vsue/torappqml"
ASSET="torappqml.tar.gz"
DEST="$HOME/.local/bin/torappqml"
APPS="$HOME/.local/share/applications"
DESKTOP="$APPS/torappqml.desktop"
ICON="$DEST/app/icon.png"
RUN="$DEST/app/run.sh"

mkdir -p "$DEST" "$APPS" "$HOME/.local/bin"

# Самолечение: прошлый запуск оборвался между сохранением и возвратом состояния.
if [ -d "$DEST.keep" ] && [ ! -d "$DEST/app" ]; then
    mkdir -p "$DEST/app"
    cp -a "$DEST.keep/." "$DEST/app/" 2>/dev/null || true
    rm -rf "$DEST.keep"
fi

# Архив: переменная, локальный рядом со скриптом, либо скачиваем.
TARBALL="${TORAPPQML_TARBALL:-}"
if [ -z "$TARBALL" ] && [ -f "$0" ]; then
    NEAR="$(dirname "$0")/$ASSET"
    if [ -f "$NEAR" ]; then
        echo "Найден локальный архив: $NEAR"
        TARBALL="$NEAR"
    fi
fi
MINE=0
if [ -z "$TARBALL" ]; then
    TARBALL="$(mktemp -t torappqml-XXXX.tar.gz)"
    MINE=1
    URL="https://github.com/$REPO/releases/latest/download/$ASSET"
    echo "Downloading $URL..."
    if command -v wget >/dev/null 2>&1; then
        wget -q --show-progress -O "$TARBALL" "$URL" || { echo "wget failed"; exit 1; }
    else
        echo "wget не найден"; exit 1
    fi
fi
[ -f "$TARBALL" ] || { echo "архив не найден: $TARBALL"; exit 1; }

# Распаковка.
echo "Extracting to $DEST..."
rm -rf "$DEST.tmp"
mkdir -p "$DEST.tmp"
tar xzf "$TARBALL" -C "$DEST.tmp"
if [ -d "$DEST.tmp/app" ]; then
    SRC="$DEST.tmp/app"
else
    SRC="$DEST.tmp"
fi

# Сохранить состояние пользователя при установке поверх.
rm -rf "$DEST.keep"
mkdir -p "$DEST.keep"
if [ -d "$DEST/app" ]; then
    for rel in run tor_data txtbridge/custom.txt txtbridge/working_bridges.txt; do
        if [ -e "$DEST/app/$rel" ]; then
            mkdir -p "$DEST.keep/$(dirname "$rel")"
            cp -a "$DEST/app/$rel" "$DEST.keep/$rel" 2>/dev/null || true
        fi
    done
fi

rm -rf "$DEST"
mkdir -p "$DEST"
mv "$SRC" "$DEST/app"
rm -rf "$DEST.tmp"

# Вернуть сохранённое состояние.
if [ -d "$DEST.keep" ]; then
    cp -a "$DEST.keep/." "$DEST/app/" 2>/dev/null || true
    rm -rf "$DEST.keep"
fi

# Права на исполнение.
chmod +x "$RUN" 2>/dev/null || true
chmod +x "$DEST/app/uninstall.sh" 2>/dev/null || true
chmod +x "$DEST/app/restore_proxies.py" 2>/dev/null || true
[ -f "$DEST/app/tor/tor" ] && chmod +x "$DEST/app/tor/tor" || true
[ -f "$DEST/app/tor/pluggable_transports/lyrebird" ] && \
    chmod +x "$DEST/app/tor/pluggable_transports/lyrebird" || true

# Убрать временный архив (только скачанный нами).
if [ "$MINE" = "1" ]; then
    rm -f "$TARBALL"
fi

# Ярлык.
cat > "$DESKTOP" << DESK
[Desktop Entry]
Name=🧅 TorApp QML
Comment=Tor Control Panel (native QML)
Exec=$RUN
Icon=$ICON
Type=Application
Categories=Network;
Terminal=false
X-Ubuntu-Touch=true
X-Lomiri-Touch=true
DESK
chmod +x "$DESKTOP" 2>/dev/null || true

echo "Done."
echo "Installed to: $DEST"
echo "Launcher: $DESKTOP"
echo "Удаление: ~/.local/bin/torappqml/app/uninstall.sh"
