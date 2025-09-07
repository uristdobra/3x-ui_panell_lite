#!/bin/bash

# Этот скрипт устанавливает панель 3x-UI (включает Xray), генерирует самоподписанные SSL-сертификаты и автоматически настраивает их в панели.
# Запускать от root (sudo -i).
# Поддерживает переменные окружения: XUI_INSTALL_URL, CERT_NAME, DAYS_VALID, XUI_CN, XUI_IP.

# Установка зависимостей: curl, openssl, sqlite3.
if ! command -v curl &> /dev/null || ! command -v openssl &> /dev/null || ! command -v sqlite3 &> /dev/null; then
  sudo apt update && sudo apt install -y curl openssl sqlite3
  if [ $? -ne 0 ]; then
    echo "Ошибка установки зависимостей."
    exit 1
  fi
fi

# Установка 3x-UI, если не установлена. Использует переменную XUI_INSTALL_URL или дефолтный URL.
XUI_INSTALL_URL=${XUI_INSTALL_URL:-"https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh"}
if ! command -v x-ui &> /dev/null; then
  bash <(curl -Ls $XUI_INSTALL_URL)
  if [ $? -ne 0 ]; then
    echo "Ошибка установки 3x-UI."
    exit 1
  fi
else
  echo "3x-UI уже установлен."
fi

# Включение и запуск сервиса 3x-UI через systemd.
systemctl daemon-reload
if systemctl list-units --full -all | grep -Fq 'x-ui.service'; then
  systemctl enable x-ui
  systemctl start x-ui
else
  x-ui
fi

# Генерация самоподписанного сертификата RSA-2048 с SAN (Subject Alternative Name) для DNS и IP.
CERT_DIR="/etc/ssl/self_signed_cert"
CERT_NAME=${CERT_NAME:-"selfsigned"}
DAYS_VALID=${DAYS_VALID:-3650}
XUI_CN=${XUI_CN:-$(hostname -f)}
XUI_IP=${XUI_IP:-$(hostname -I | awk '{print $1}')}
mkdir -p "$CERT_DIR"
CERT_PATH="$CERT_DIR/$CERT_NAME.crt"
KEY_PATH="$CERT_DIR/$CERT_NAME.key"

# Команда генерации сертификата с SAN: добавляет DNS и IP в расширения.
openssl req -x509 -nodes -days $DAYS_VALID -newkey rsa:2048 \
  -keyout "$KEY_PATH" \
  -out "$CERT_PATH" \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=$XUI_CN" \
  -addext "subjectAltName = DNS:$XUI_CN,IP:$XUI_IP"

if [ $? -ne 0 ]; then
  echo "Ошибка генерации сертификата."
  exit 1
fi

# Автоматическое размещение путей к сертификатам в настройках панели 3x-UI (обновление SQLite базы данных).
DB_PATH="/usr/local/x-ui/x-ui.db"
if [ -f "$DB_PATH" ]; then
  sqlite3 "$DB_PATH" "UPDATE settings SET value='$CERT_PATH' WHERE key='certFile';"
  sqlite3 "$DB_PATH" "UPDATE settings SET value='$KEY_PATH' WHERE key='keyFile';"
else
  echo "Ошибка: база данных $DB_PATH не найдена. Проверьте установку 3x-UI."
  exit 1
fi

# Перезапуск панели 3x-UI для применения изменений.
systemctl restart x-ui

# Вывод информации о завершении.
echo "============================================================"
echo "Установка завершена!"
echo "Xray и панель 3x-UI установлены."
echo "Сертификаты сгенерированы и автоматически настроены в панели."
echo "Пути: Публичный ключ - $CERT_PATH, Приватный ключ - $KEY_PATH"
echo "Доступ к панели: https://$XUI_CN:54321 (или по IP: https://$XUI_IP:54321)"
echo "Логин и пароль по умолчанию: admin/admin (измените их в панели)."
echo "============================================================"
