#!/usr/bin/env bash
# Установка XRAY + 3x-ui с автоподключением SSL
# После запуска панель будет доступна по https://<IP>:<PORT>
set -euo pipefail

echo "=== Установка XRAY + 3x-ui с SSL ==="

# Проверка root
if [ "${EUID:-0}" -ne 0 ]; then
  echo "Скрипт нужно запускать от root (sudo bash install.sh)"
  exit 1
fi

# Установка зависимостей
export DEBIAN_FRONTEND=noninteractive
apt update && apt install -y curl wget socat openssl sqlite3 jq

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

# Определяем конфигурацию панели
CONFIG_PATH="/usr/local/x-ui/x-ui.json"
PORT=""
UPDATED=0

if [ -f "$CONFIG_PATH" ]; then
  echo "Получаем порт из конфигурации..."
  PORT=$(jq -r '.port // "54321"' "$CONFIG_PATH")
  echo "Обновляем конфигурацию панели через x-ui.json..."
  tmp=$(mktemp)
  jq \
    --arg crt "$CERT_DIR/self_signed.crt" \
    --arg key "$CERT_DIR/self_signed.key" \
    '.certificateFile=$crt | .keyFile=$key | .enableTLS=true' \
    "$CONFIG_PATH" > "$tmp" && mv "$tmp" "$CONFIG_PATH"
  UPDATED=1
else
  echo "ВНИМАНИЕ: Не найден x-ui.json — SSL не был настроен автоматически."
  PORT="54321" # Fallback port
fi

# Перезапуск панели
systemctl start x-ui

IP="$(hostname -I | awk '{print $1}')"
echo "========================================"
echo " Установка завершена!"
if [ $UPDATED -eq 1 ]; then
  echo " Панель настроена на HTTPS."
else
  echo " Панель установлена, но SSL не был прописан автоматически."
fi
echo " Доступ к панели:"
echo "   https://$IP:$PORT"
echo ""
echo " Логин/пароль для входа были показаны установщиком 3x-ui."
echo "========================================"