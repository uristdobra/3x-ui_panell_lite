# 3x-ui Lite Installer (Self-signed SSL)

Лёгкий установщик **3x-ui** с генерацией **самоподписанного сертификата** (SAN: DNS/IP).

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

1. Ставит зависимости (`curl`, `openssl`, `qrencode`).
2. Устанавливает 3x-ui (если нет).
3. Включает сервис systemd.
4. Генерирует **самоподписанный сертификат RSA-2048** с SAN (DNS/IP).
5. Подсказывает, куда прописать пути в панели 3x-ui.

---

## ⚠️ Важно

Браузеры будут ругаться на «недоверенный сертификат» — это нормально для self-signed.  
Для боевого HTTPS лучше использовать Let's Encrypt (ACME).

---

## 📜 Лицензия

MIT
