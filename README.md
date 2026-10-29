# TorApp QML

Панель управления Tor для Ubuntu Touch (Lomiri): мосты, системный VPN,
per-app проксирование и HTTP-форвардер. Нативный интерфейс на QML
(`qmlscene` + Python-бэкенд через PyOtherSide).

> **Статус: pre-release (`v0.1.0-beta`).** Приложение рабочее, но API и
> поведение могут меняться. Только `aarch64` / Ubuntu Touch.

## Возможности

- Подключение к Tor, выбор режима мостов: `obfs4`, `webtunnel`, свои мосты,
  локально сохранённые рабочие мосты.
- Системный VPN-режим (прозрачное проксирование всей системы).
- **Per-app прокси**: YouTube (QtWebEngine), OpenStore (HTTP-форвардер),
  Greenline (через `systemd --user`). Автоматический бэкап оригинальных
  `.desktop` и возврат при выключении.
- HTTP-форвардер `:8118` (SOCKS5 → HTTP/CONNECT) с авто-включением.
- Индикатор «здоровья»: состояние сети (NetworkManager) + свежесть узла.
- Обновление списков мостов из источников прямо из приложения.

## Требования

- Ubuntu Touch (Lomiri), **aarch64**.
- `qmlscene`, `python3`, модуль QML **PyOtherSide** (обычно уже в системе).
- Сеть для первого запуска (если нужны свежие мосты); дальше возможна
  офлайн-работа с сохранёнными списками.

## Установка одной строкой (рекомендуется)

```sh
wget -qO- https://raw.githubusercontent.com/phixenium-vsue/torappqml/main/install.sh | sh
```

После установки в меню Lomiri появится **🧅 TorApp QML**.

Ставится в `~/.local/bin/torappqml/` (ярлык —
`~/.local/share/applications/torappqml.desktop`). При установке поверх
сохраняются `run/settings.json`, `tor_data/` и пользовательские мосты.

## Установка без интернета (офлайн)

1. **Самоустановщик (один файл):** положить `torappqml-setup.run` рядом и
   запустить:

   ```sh
   sh torappqml-setup.run
   ```

2. **Два файла:** положить в одну папку `install.sh` + `torappqml.tar.gz`:

   ```sh
   sh install.sh
   ```

   (либо явно: `TORAPPQML_TARBALL=./torappqml.tar.gz sh install.sh`)

## Запуск из терминала

```sh
~/.local/bin/torappqml/app/run.sh
```

> Из чистой SSH-сессии без графической сессии Lomiri окно не отрисуется —
> запускать из сессии Lomiri.

## Удаление

```sh
~/.local/bin/torappqml/app/uninstall.sh
```

Удалятор останавливает процессы, **возвращает проксированные `.desktop`**
(зеркала и реальные файлы в `/opt`) и systemd drop-in в состояние «до
TorApp», затем удаляет папку и ярлык. Так как файлы в `/opt` принадлежат
`clickpkg`, для их восстановления может один раз потребоваться `sudo`
(запускайте удаление из терминала).

## Ограничения

- Только Ubuntu Touch / aarch64; в комплекте Tor 0.4.9.6 и transport
  `lyrebird` (obfs4 + webtunnel). `snowflake`/`meek` не поставляются.
- GasTube и YouTube Music намеренно не входят в per-app прокси: первый
  отдаёт видео системному плееру (не наследует прокси), второй ограничен
  по региону на стороне сервиса.
- Приложение не является анонимайзером «в один клик» и не заменяет
  полноценную модель угроз: используйте осознанно.

## Лицензия

GNU General Public License v3.0 — см. [LICENSE](LICENSE).
Сторонние компоненты (Tor, lyrebird, OpenSSL, libevent) — см.
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
