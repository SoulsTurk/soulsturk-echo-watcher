#!/bin/sh

# ============================================

# SOULSTURK ECHO WATCHER - PRO İZLEYİCİ

# ============================================

export PATH="/sbin:/usr/sbin:/bin:/usr/bin:/opt/sbin:/opt/bin:$PATH"

SCRIPT_VERSION="v1.1"
UPDATE_URL="https://raw.githubusercontent.com/soulsturk/soulsturk-echo-watcher/main/soulsturkechowatcher.sh"

# --- Yollar ---

SCRIPT_PATH="/opt/lib/opkg/soulsturkechowatcher.sh"
PID_FILE="/opt/var/run/soulsturkechowatcher.pid"
CONF_DIR="/opt/etc/soulsturkechowatcher"
CONF_FILE="$CONF_DIR/soulsturkechowatcher.conf"
INIT_FILE="/opt/etc/init.d/S99soulsturkechowatcher"
LOCK_FILE="/tmp/soulsturkechowatcher.lock"

# ============================================

# KOMUT KISAYOLLARI (OTOMATİK)

# ============================================

mkdir -p /opt/bin 2>/dev/null

ln -sf "$SCRIPT_PATH" /opt/bin/souls
ln -sf "$SCRIPT_PATH" /opt/bin/soulsturk
ln -sf "$SCRIPT_PATH" /opt/bin/sew
ln -sf "$SCRIPT_PATH" /opt/bin/sem

# ============================================

# RENKLER

# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# ============================================

# VARSAYILANLAR

# ============================================

TG_TOKEN=""
TG_CHATID=""

[ -d "$CONF_DIR" ] || mkdir -p "$CONF_DIR"
[ -f "$CONF_FILE" ] && . "$CONF_FILE"

# ============================================

# TELEGRAM GÖNDER

# ============================================

send_tg() {
[ -z "$TG_TOKEN" ] || [ -z "$TG_CHATID" ] && return
{
curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" 
-d "chat_id=$TG_CHATID" -d "text=$1" >/dev/null 2>&1
} &
}

status_check() {
if [ -f "$PID_FILE" ]; then
PID=$(cat "$PID_FILE")
if kill -0 "$PID" 2>/dev/null; then
return 0
fi
fi
return 1
}

# ============================================

# DAEMON

# ============================================

if [ "$1" = "--daemon" ]; then

```
while true
do
    sleep 5
done

exit 0
```

fi

# ============================================

# MENÜ

# ============================================

if [ -f "$LOCK_FILE" ]; then
echo "Betik zaten çalışıyor"
exit 1
fi

touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

while true
do

clear

echo "════════════════════════════════════"
echo " SOULSTURK ECHO WATCHER $SCRIPT_VERSION"
echo "════════════════════════════════════"

echo "1) Servisi Başlat"
echo "2) Servisi Durdur"
echo "3) Servisi Yeniden Başlat"
echo "4) Telegram Ayarları"
echo "5) Test Bildirimi"
echo "6) Log İzle"
echo "7) Otomatik Başlatma Kur"
echo "8) Otomatik Başlatma Kaldır"
echo "9) TAMAMEN KALDIR"
echo "0) Çıkış"

read secim

case "$secim" in

1.

if status_check
then
echo "Servis zaten çalışıyor"
else
"$SCRIPT_PATH" --daemon &
echo $! > "$PID_FILE"
echo "Servis başlatıldı"
fi
;;

2.

if status_check
then
kill "$(cat "$PID_FILE")"
rm -f "$PID_FILE"
echo "Servis durduruldu"
else
echo "Servis çalışmıyor"
fi
;;

3.

if status_check
then
kill "$(cat "$PID_FILE")"
rm -f "$PID_FILE"
fi

"$SCRIPT_PATH" --daemon &
echo $! > "$PID_FILE"
echo "Servis yeniden başlatıldı"

;;

4.

echo "Bot Token:"
read TG_TOKEN

echo "Chat ID:"
read TG_CHATID

cat > "$CONF_FILE" <<EOF
TG_TOKEN="$TG_TOKEN"
TG_CHATID="$TG_CHATID"
EOF

echo "Kaydedildi"

;;

5.

send_tg "Soulsturk Echo Watcher test bildirimi"

echo "Gönderildi"

;;

7.

cat > "$INIT_FILE" <<EOF
#!/bin/sh
case "$1" in
start)
$SCRIPT_PATH --daemon &
echo $! > $PID_FILE
;;
stop)
kill $(cat $PID_FILE)
rm -f $PID_FILE
;;
esac
EOF

chmod +x "$INIT_FILE"

echo "Otomatik başlatma kuruldu"

;;

8.

rm -f "$INIT_FILE"

echo "Otomatik başlatma kaldırıldı"

;;

9.

echo "EVET yazarsanız tamamen kaldırılır"
read confirm

if [ "$confirm" = "EVET" ]
then

kill "$(cat "$PID_FILE")" 2>/dev/null
rm -f "$PID_FILE"

rm -f "$INIT_FILE"
rm -rf "$CONF_DIR"

rm -f /opt/bin/souls
rm -f /opt/bin/soulsturk
rm -f /opt/bin/sew
rm -f /opt/bin/sem

rm -f "$SCRIPT_PATH"

echo "Tamamen kaldırıldı"

exit 0
fi

;;

0.

exit 0

;;

esac

read
done
