#!/bin/sh
# Собирает torappqml-setup.run — офлайн-самоустановщик (один файл).
# Внутри: sh-заголовок + метка __PAYLOAD__ + gzip-тарболл {install.sh, torappqml.tar.gz}.
# Запуск на устройстве: sh torappqml-setup.run  (сеть не нужна)
set -e
cd "$(dirname "$0")"

OUT="torappqml-setup.run"
[ -f install.sh ] || { echo "нет install.sh"; exit 1; }
[ -f torappqml.tar.gz ] || { echo "нет torappqml.tar.gz"; exit 1; }

STUB="$(mktemp)"
PAYD="$(mktemp -d)"
trap 'rm -f "$STUB" "$PAYD.tarball"; rm -rf "$PAYD"' EXIT INT TERM

cat > "$STUB" <<'STUB_EOF'
#!/bin/sh
# TorApp QML — самоустановщик. Офлайн, только sh + gzip + tar.
# Использование: sh torappqml-setup.run
set -e
SELF="$0"
LINE="$(LC_ALL=C grep -a -n -m1 '^__PAYLOAD__$' "$SELF" | cut -d: -f1)"
[ -n "$LINE" ] || { echo "ошибка: повреждённый файл (нет метки payload)"; exit 1; }
PAY="$(mktemp -d -t torappqml-setup-XXXX)"
cleanup() { rm -rf "$PAY"; }
trap cleanup EXIT INT TERM
tail -n "+$((LINE + 1))" "$SELF" | tar xzf - -C "$PAY"
echo "Найден пакет: install.sh + torappqml.tar.gz"
TORAPPQML_TARBALL="$PAY/torappqml.tar.gz" sh "$PAY/install.sh"
exit 0
__PAYLOAD__
STUB_EOF

sh -n "$STUB"

cp install.sh torappqml.tar.gz "$PAYD/"
( cd "$PAYD" && tar czf - install.sh torappqml.tar.gz ) > "$PAYD.tarball"

cat "$STUB" "$PAYD.tarball" > "$OUT"
chmod 755 "$OUT"
echo "Собрано: $OUT ($(wc -c < "$OUT") байт)"
