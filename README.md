# 3x-UI Lite Installer with Auto SSL Config

Лёгкий установщик панели 3x-UI (с Xray) с генерацией самоподписанного сертификата и автоматической настройкой в панели.

## 🚀 Быстрый старт

> ⚠️ Запускать от root (например: `sudo -i`).

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/uristdobra/3x-ui_panell_lite/main/install.sh)
```

Не нравится `curl | bash`? Тогда:

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/uristdobra/3x-ui_panell_lite/main/install.sh
bash install.sh
```

---

## ⚙️ Настройка переменными окружения

- `XUI_INSTALL_URL` — URL инсталлятора 3x-ui (по умолчанию: MHSanaei/3x-ui).
- `CERT_NAME` — имя сертификата (default: `selfsigned`).
- `DAYS_VALID` — срок действия (default: `3650`).
- `XUI_CN` — Common Name (обычно домен), default: `hostname -f`.
- `XUI_IP` — IP для SAN, default: первый IP из `hostname -I`.

Пример:

```bash
XUI_CN=panel.mydomain.com DAYS_VALID=825 bash <(curl -fsSL https://raw.githubusercontent.com/uristdobra/3x-ui_panell_lite/main/install.sh)
```

---

## 🛠 Что делает скрипт

1. Устанавливает зависимости (`curl`, `openssl`, `qrencode`, `sqlite3`).
2. Устанавливает 3x-UI (если нет), которая включает Xray.
3. Включает сервис systemd для 3x-UI.
4. Генерирует самоподписанный сертификат RSA-2048 с SAN (DNS/IP).
5. Автоматически обновляет базу данных 3x-UI для настройки путей к сертификатам.
6. Перезапускает панель для применения изменений.

---

## ⚠️ Важно

- Браузеры будут предупреждать о "недоверенном сертификате" — это нормально для self-signed.
- Для production используйте Let's Encrypt.
- Доступ к панели по HTTPS после установки.

---

## 📜 Лицензия

MIT
