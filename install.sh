#!/usr/bin/env bash
# Установка XRAY + 3x-ui с автоподключением SSL и извлечением URL
# Исправлена проблема с отсутствующим "/" между портом и WebBasePath
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
  # сохраняем вывод установщика в лог
  bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh) | tee "$INSTALL_LOG"
else
  echo "3x-ui уже установлена."
  x-ui stop || true
  # если панели не устанавливали в этой сессии, постараемся найти существующий лог
  if [ ! -f "$INSTALL_LOG" ]; then
    echo "(INFO) Файл лога установки не найден: $INSTALL_LOG"
    # создаём пустой файл, чтобы последующие grep не падали
    : > "$INSTALL_LOG"
  fi
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

# Прописываем сертификаты в SQLite (таблица settings) — безопасно: UPDATE если есть, иначе INSERT
DB_PATH="/etc/x-ui/x-ui.db"
if [ -f "$DB_PATH" ]; then
  echo "Прописываем SSL в базу $DB_PATH..."
  # webCertFile
  cnt=$(sqlite3 "$DB_PATH" "SELECT COUNT(1) FROM settings WHERE key='webCertFile';")
  if [ "$cnt" -gt 0 ]; then
    sqlite3 "$DB_PATH" "UPDATE settings SET value='$CERT_DIR/self_signed.crt' WHERE key='webCertFile';"
  else
    sqlite3 "$DB_PATH" "INSERT INTO settings (key, value) VALUES ('webCertFile', '$CERT_DIR/self_signed.crt');"
  fi
  # webKeyFile
  cnt=$(sqlite3 "$DB_PATH" "SELECT COUNT(1) FROM settings WHERE key='webKeyFile';")
  if [ "$cnt" -gt 0 ]; then
    sqlite3 "$DB_PATH" "UPDATE settings SET value='$CERT_DIR/self_signed.key' WHERE key='webKeyFile';"
  else
    sqlite3 "$DB_PATH" "INSERT INTO settings (key, value) VALUES ('webKeyFile', '$CERT_DIR/self_signed.key');"
  fi
  # webEnableTLS
  cnt=$(sqlite3 "$DB_PATH" "SELECT COUNT(1) FROM settings WHERE key='webEnableTLS';")
  if [ "$cnt" -gt 0 ]; then
    sqlite3 "$DB_PATH" "UPDATE settings SET value='1' WHERE key='webEnableTLS';"
  else
    sqlite3 "$DB_PATH" "INSERT INTO settings (key, value) VALUES ('webEnableTLS', '1');"
  fi
else
  echo "ВНИМАНИЕ: база $DB_PATH не найдена, SSL не был прописан автоматически."
fi

# Перезапускаем панель
systemctl restart x-ui || {
  echo "Ошибка при рестарте x-ui. Посмотрите 'systemctl status x-ui' и логи."
}

# Извлекаем данные из лога у
