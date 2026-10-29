#!/bin/sh
# TorApp (QML) launcher
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR" || exit 1

export QML2_IMPORT_PATH="$APP_DIR/qml-plugins:$QML2_IMPORT_PATH"

exec qmlscene "$APP_DIR/Main.qml" --scaling --gles
