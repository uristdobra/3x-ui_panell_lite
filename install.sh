#!/usr/bin/env bash
# Установка XRAY + 3x-ui с автоподключением SSL
# После запуска панель будет доступна по https://<IP>:54321
set -euo pipefail

echo "=== Установка XRAY + 3x-ui с SSL ==="

# Проверка root
if [ "${EUID:-0}" -ne 0 ]; then
  echo "Скрипт нужно запускать от root (sudo bash install.sh)"
  exit 1
fi

# Установка зависимостей
apt update && apt install -y curl wget socat openssl sqlite3

# Установка 3x-ui
if ! command -v x-ui &> /dev/null; then
  echo "Устанавливаем 3x-ui..."
  bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh)
else
  echo "3x-ui уже установлена."
fi

# Включаем сервис
systemctl enable x-ui
systemctl stop x-ui || true

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

# Настройка панели на использование SSL
DB_PATH="/etc/x-ui/x-ui.db"
if [ -f "$DB_PATH" ]; then
  echo "Обновляем конфигурацию панели (SQLite)..."
  sqlite3 "$DB_PATH" "UPDATE setting SET value='$CERT_DIR/self_signed.crt' WHERE key='webCertFile';"
  sqlite3 "$DB_PATH" "UPDATE setting SET value='$CERT_DIR/self_signed.key' WHERE key='webKeyFile';"
  sqlite3 "$DB_PATH" "UPDATE setting SET value='1' WHERE key='webEnableTLS';"
else
  echo "ВНИМАНИЕ: База $DB_PATH не найдена, SSL может не примениться автоматически."
fi

# Перезапуск панели
systemctl start x-ui

IP="$(hostname -I | awk '{print $1}')"
echo "========================================"
echo " Установка завершена!"
echo " Панель доступна по адресу:"
echo "   https://$IP:54321"
echo ""
echo " Логин/пароль для входа были показаны установщиком 3x-ui."
echo "========================================"
