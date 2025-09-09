#!/usr/bin/env bash
# Установка XRAY + 3x-ui с автоподключением SSL и извлечением URL
set -euo pipefail

echo "=== Установка XRAY + 3x-ui с SSL ==="

if [ "${EUID:-0}" -ne 0 ]; then
  echo "Скрипт нужно запускать от root (sudo bash install.sh)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt update && apt install -y curl wget socat openssl sqlite3 jq

# Лог установки
INSTALL_LOG="/var/log/x-ui-install.log"

if ! command -v x-ui &> /dev/null; then
  echo "Устанавливаем 3x-ui..."
  bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh) | tee "$INSTALL_LOG"
else
  echo "3x-ui уже установлена."
  x-ui stop || true
fi

# Генерация сертификата
CERT_DIR="/etc/ssl/self_signed_cert"
mkdir -p "$CERT_DIR"
CERT_CN="$(hostname -f 2>/dev/null || hostname)"
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout "$CERT_DIR/self_signed.key" \
  -out "$CERT_DIR/self_signed.crt" \
  -subj "/C=RU/ST=Unknown/L=Unknown/O=3x-ui/OU=IT/CN=${CERT_CN}"

echo "Сертификат создан:"
echo " - $CERT_DIR/self_signed.crt"
echo " - $CERT_DIR/self_signed.key"

# Прописываем сертификаты в SQLite (таблица settings)
DB_PATH="/etc/x-ui/x-ui.db"
if [ -f "$DB_PATH" ]; then
  echo "Прописываем SSL в базу $DB_PATH..."
  sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO settings (id, key, value)
    VALUES ((SELECT id FROM settings WHERE key='webCertFile'),'webCertFile','$CERT_DIR/self_signed.crt');"
  sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO settings (id, key, value)
    VALUES ((SELECT id FROM settings WHERE key='webKeyFile'),'webKeyFile','$CERT_DIR/self_signed.key');"
  sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO settings (id, key, value)
    VALUES ((SELECT id FROM settings WHERE key='webEnableTLS'),'webEnableTLS','1');"
else
  echo "ВНИМАНИЕ: база $DB_PATH не найдена, SSL не был прописан автоматически."
fi

# Перезапускаем панель
systemctl restart x-ui

# Извлекаем данные из лога установки
USERNAME=$(grep -m1 "Username:" "$INSTALL_LOG" | awk '{print $2}')
PASSWORD=$(grep -m1 "Password:" "$INSTALL_LOG" | awk '{print $2}')
PORT=$(grep -m1 "Port:" "$INSTALL_LOG" | awk '{print $2}')
WEBPATH=$(grep -m1 "WebBasePath:" "$INSTALL_LOG" | awk '{print $2}')
IP=$(hostname -I | awk '{print $1}')

# Итог
echo "========================================"
echo " Установка завершена!"
echo " Панель доступна по адресу:"
echo "   https://$IP:$PORT$WEBPATH"
echo ""
echo " Логин:    $USERNAME"
echo " Пароль:   $PASSWORD"
echo "========================================"
