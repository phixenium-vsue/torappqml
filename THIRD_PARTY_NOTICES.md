# Сторонние компоненты

TorApp QML распространяется под GNU GPL v3.0 (см. `LICENSE`). В комплект
входят сторонние программы/библиотеки со своими лицензиями.

## Tor

- Файл: `app/tor/tor`, версия **0.4.9.6**.
- Лицензия: **GNU General Public License v3.0**.
- Исходники: <https://www.torproject.org/> / <https://gitlab.torproject.org/tpo/core/tor>

## lyrebird (pluggable transport: obfs4, webtunnel)

- Файл: `app/tor/pluggable_transports/lyrebird`.
- Лицензия: **GNU General Public License v3.0**.
- Исходники: <https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird>

## OpenSSL

- Файлы: `app/tor/libssl.so.3`, `app/tor/libcrypto.so.3`.
- Лицензия: **Apache License 2.0**.
- Сайт: <https://www.openssl.org/>

## libevent

- Файл: `app/tor/libevent-2.1.so.7`.
- Лицензия: **BSD 3-Clause**.
- Сайт: <https://libevent.org/>

---

Tor и lyrebird распространяются под GPLv3; соответствующий исходный код
доступен по ссылкам выше. Если вы распространяете изменённую сборку —
соблюдайте условия GPLv3.
