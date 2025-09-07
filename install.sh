#!/usr/bin/env bash
# Установка XRAY + 3x-ui с автоподключением SSL
# После запуска панель будет доступна по https://<IP>:<PORT>/<WebBasePath>
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

# Установка 3x-ui с захватом вывода для получения порта и WebBasePath
if ! command -v x-ui &> /dev/null; then
  echo "Устанавливаем 3x-ui..."
  INSTALL_LOG=$(mktemp)
  bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh) | tee "$INSTALL_LOG"
else
  echo "3x-ui уже установлена."
fi

# Включаем сервис
systemctl enable x-ui.service
systemctl stop x-ui.service || true

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
CONFIG_PATH="/etc/x-ui/x-ui.json"
PORT=""
WEB_BASE_PATH=""
UPDATED=0

# Извлекаем порт и WebBasePath из лога установки
if [ -n "${INSTALL_LOG:-}" ] && [ -f "$INSTALL_LOG" ]; then
  PORT=$(grep "Port: " "$INSTALL_LOG" | awk '{print $2}' | head -n 1)
  WEB_BASE_PATH=$(grep "WebBasePath: " "$INSTALL_LOG" | awk '{print $2}' | head -n 1)
fi

# Если порт или WebBasePath не найдены, пытаемся извлечь из конфигурации
if [ -z "$PORT" ] && [ -f "$CONFIG_PATH" ]; then
  PORT=$(jq -r '.port // "54321"' "$CONFIG_PATH")
fi
if [ -z "$WEB_BASE_PATH" ] && [ -f "$CONFIG_PATH" ]; then
  WEB_BASE_PATH=$(jq -r '.webBasePath // ""' "$CONFIG_PATH")
fi

# Если порт не найден, используем значение по умолчанию
PORT=${PORT:-54321}
# Если WebBasePath не найден, оставляем пустым
WEB_BASE_PATH=${WEB_BASE_PATH:-}

# Настройка SSL в конфигурации
if [ -f "$CONFIG_PATH" ]; then
  echo "Обновляем конфигурацию панели через $CONFIG_PATH..."
  tmp=$(mktemp)
  jq \
    --arg crt "$CERT_DIR/self_signed.crt" \
    --arg key "$CERT_DIR/self_signed.key" \
    '.certificateFile=$crt | .keyFile=$key | .enableTLS=true' \
    "$CONFIG_PATH" > "$tmp" && mv "$tmp" "$CONFIG_PATH"
  UPDATED=1
else
  echo "ВНИМАНИЕ: Не найден $CONFIG_PATH — SSL не был настроен автоматически."
fi

# Перезапуск панели
systemctl start x-ui.service

IP="$(hostname -I | awk '{print $1}')"
echo "========================================"
echo " Установка завершена!"
if [ $UPDATED -eq 1 ]; then
  echo " Панель настроена на HTTPS."
else
  echo " Панель установлена, но SSL не был прописан автоматически."
fi
echo " Доступ к панели:"
if [ -n "$WEB_BASE_PATH" ]; then
  echo "   https://$IP:$PORT/$WEB_BASE_PATH"
else
  echo "   https://$IP:$PORT"
fi
echo ""
echo " Логин/пароль для входа были показаны установщиком 3x-ui."
echo "========================================"

# Очистка временного лога
[ -n "${INSTALL_LOG:-}" ] && [ -f "$INSTALL_LOG" ] && rm -f "$INSTALL_LOG"