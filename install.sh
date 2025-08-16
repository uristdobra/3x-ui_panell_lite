#!/usr/bin/env bash
set -euo pipefail

# === 3x-ui + self-signed SSL quick installer ==============================
# Repo: https://github.com/uristdobra/3x-ui_panell_lite
# ==========================================================================

if [[ $EUID -ne 0 ]]; then
  echo "❌ Пожалуйста, запустите скрипт от root (sudo -i)."
  exit 1
fi

# Определяем пакетный менеджер
UPDATE_CMD=""
INSTALL_CMD=""
if command -v apt-get >/dev/null 2>&1; then
  UPDATE_CMD="apt-get update -y"
  INSTALL_CMD="apt-get install -y"
elif command -v dnf >/dev/null 2>&1; then
  UPDATE_CMD="dnf -y makecache"
  INSTALL_CMD="dnf -y install"
elif command -v yum >/dev/null 2>&1; then
  UPDATE_CMD="yum -y makecache"
  INSTALL_CMD="yum -y install"
else
  echo "❌ Неподдерживаемый дистрибутив (нет apt/dnf/yum)."
  exit 1
fi

# Обновляем кэш и ставим зависимости
eval "$UPDATE_CMD"
eval "$INSTALL_CMD" curl openssl qrencode >/dev/null 2>&1 || {
  echo "❌ Не удалось установить зависимости (curl, openssl, qrencode)."
  exit 1
}

# Установка 3x-ui (если не установлен)
if ! command -v x-ui >/dev/null 2>&1; then
  XUI_INSTALL_URL="${XUI_INSTALL_URL:-https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh}"
  echo "📥 Устанавливаю 3x-ui из: $XUI_INSTALL_URL"
  bash <(curl -fsSL "$XUI_INSTALL_URL")
else
  echo "✅ 3x-ui уже установлен, пропускаю установку."
fi

# Стартуем сервис (если доступен systemd)
if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload || true
  systemctl enable --now x-ui || true
fi

# Генерация самоподписанного сертификата c SAN
CERT_DIR="/etc/ssl/3x-ui"
CERT_NAME="${CERT_NAME:-selfsigned}"
DAYS_VALID="${DAYS_VALID:-3650}"
CN="${XUI_CN:-$(hostname -f 2>/dev/null || echo localhost)}"
IP="${XUI_IP:-$(hostname -I 2>/dev/null | awk '{print $1}' || echo 127.0.0.1)}"

mkdir -p "$CERT_DIR"
chmod 700 "$CERT_DIR"

OPENSSL_CNF="$CERT_DIR/openssl.cnf"
cat > "$OPENSSL_CNF" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
x509_extensions = v3_req
distinguished_name = dn

[dn]
C = US
ST = State
L = City
O = 3x-ui
OU = SelfSigned
CN = $CN

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $CN
IP.1 = $IP
EOF

CRT_PATH="$CERT_DIR/$CERT_NAME.crt"
KEY_PATH="$CERT_DIR/$CERT_NAME.key"

openssl req -x509 -nodes -days "$DAYS_VALID" -newkey rsa:2048   -keyout "$KEY_PATH"   -out "$CRT_PATH"   -config "$OPENSSL_CNF" >/dev/null 2>&1

chmod 600 "$KEY_PATH"

echo
echo "=== ✅ Готово ============================================================="
echo "Сертификаты сгенерированы:"
echo "  CRT: $CRT_PATH"
echo "  KEY: $KEY_PATH"
echo
echo "👉 Дальше:"
echo "  1) Зайдите в панель 3x-ui."
echo "  2) В «Настройки панели» укажите эти пути."
echo "  3) Сохраните и перезапустите панель."
echo
echo "Подсказки по CLI:"
echo "  x-ui           # меню"
echo "  x-ui status    # статус"
echo "  x-ui start     # запуск"
echo "  x-ui enable    # автозапуск"
echo "========================================================================="
