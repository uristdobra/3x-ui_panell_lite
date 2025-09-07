3x-UI Lite Installer with Auto SSL Config
Лёгкий установщик панели 3x-UI (с Xray) с генерацией самоподписанного сертификата и автоматической настройкой в панели.
🚀 Быстрый старт
⚠️ Запускать от root (например: sudo -i).
bash <(curl -fsSL https://raw.githubusercontent.com/uristdobra/3x-ui_panell_lite/main/install.sh)

Не нравится curl | bash? Тогда:
curl -fsSL -o install.sh https://raw.githubusercontent.com/uristdobra/3x-ui_panell_lite/main/install.sh
bash install.sh

⚙️ Настройка переменными окружения

XUI_INSTALL_URL — URL инсталлятора 3x-UI (по умолчанию: MHSanaei/3x-UI).
CERT_NAME — имя сертификата (default: selfsigned).
DAYS_VALID — срок действия (default: 3650).
XUI_CN — Common Name (домен), default: hostname -f.
XUI_IP — IP для SAN, default: первый IP из hostname -I.

Пример:
XUI_CN=panel.mydomain.com DAYS_VALID=825 bash <(curl -fsSL https://raw.githubusercontent.com/uristdobra/3x-ui_panell_lite/main/install.sh)

🛠 Что делает скрипт

Устанавливает зависимости (curl, openssl, sqlite3).
Устанавливает 3x-UI (если нет), которая включает Xray.
Включает сервис systemd для 3x-UI.
Генерирует самоподписанный сертификат RSA-2048 с SAN (DNS/IP).
Автоматически обновляет базу данных 3x-UI для настройки путей к сертификатам.
Перезапускает панель для применения изменений.

⚠️ Важно

Браузеры будут предупреждать о "недоверенном сертификате" — это нормально для self-signed.
Для production используйте Let's Encrypt.
Доступ к панели по HTTPS после установки (по умолчанию: https://<ваш_домен_или_IP>:54321).
Логин и пароль по умолчанию: admin/admin (измените их в панели).

📜 Лицензия
MIT
