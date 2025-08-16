#!/bin/bash

# Устанавливаем 3x-ui панель для VLESS и самоподписные сертификаты на 10 лет

# Установка OpenSSL
if ! command -v openssl &> /dev/null; then
  sudo apt update && sudo apt install -y openssl
  if [ $? -ne 0 ]; then
    exit 1
  fi
fi

# Установка qrencode
if ! command -v qrencode &> /dev/null; then
  sudo apt update && sudo apt install -y qrencode
  if [ $? -ne 0 ]; then
    exit 1
  fi
fi

# Функция ожидания нажатия Enter
wait_for_enter() {
  echo -e "Нажмите Enter, чтобы продолжить..."
  read -r
}

# Установка 3X-UI
if ! command -v x-ui &> /dev/null; then
  bash <(curl -Ls curl https://raw.githubusercontent.com/jameszeroX/XKeen/main/install.sh)
    if [ $? -ne 0 ]; then
    exit 1
  fi
else
  echo "3X-UI уже установлен."
fi

# Запуск 3X-UI
systemctl daemon-reload
if systemctl list-units --full -all | grep -Fq 'x-ui.service'; then
  systemctl enable x-ui
  systemctl start x-ui
else
  x-ui
fi

# Генерация сертификата
CERT_DIR="/etc/ssl/self_signed_cert"
CERT_NAME="self_signed"
DAYS_VALID=3650
mkdir -p "$CERT_DIR"
CERT_PATH="$CERT_DIR/$CERT_NAME.crt"
KEY_PATH="$CERT_DIR/$CERT_NAME.key"

openssl req -x509 -nodes -days $DAYS_VALID -newkey rsa:2048 \
  -keyout "$KEY_PATH" \
  -out "$CERT_PATH" \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=example.com"

if [ $? -eq 0 ]; then
  echo "SSL CERTIFICATE PATH: $CERT_PATH"
  echo "SSL KEY PATH: $KEY_PATH"
else
  exit 1
fi

# Финальное сообщение
echo "   Установка завершена, ключи сгенерированы!"
echo "   Пропишите ключи самоподписных сертификатов в панели управления 3x-ui"
echo "1) Зайдите по ссылке в панель 3x-ui, введите логин и пароль"
echo "2) После успешной авторизации перейдите в Настройки панели"
echo "3) Путь к файлу ПУБЛИЧНОГО ключа сертификата - сюда вставить путь /etc/ssl/self_signed_cert/self_signed.crt"
echo "4) Путь к файлу ПРИВАТНОГО ключа сертификата - сюда вставить путь /etc/ssl/self_signed_cert/self_signed.key"
echo "5) Нажмить сохранить и потом нажмите перегрузить панель"
echo "Удачного использования!"