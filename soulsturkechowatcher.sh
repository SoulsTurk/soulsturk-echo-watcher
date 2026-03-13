#!/bin/sh

# ============================================
# SOULSTURK ECHO WATCHER - PRO İZLEYİCİ (v1.3)
# ============================================

export PATH="/sbin:/usr/sbin:/bin:/usr/bin:/opt/sbin:/opt/bin:$PATH"

# --- Sürüm ve Güncelleme Ayarları ---
SCRIPT_VERSION="v1.3"
UPDATE_URL="https://raw.githubusercontent.com/soulsturk/soulsturk-echo-watcher/main/soulsturkechowatcher.sh"

# --- Renkler ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# --- Yollar ---
SCRIPT_PATH="/opt/lib/opkg/soulsturkechowatcher.sh"
PID_FILE="/opt/var/run/soulsturkechowatcher.pid"
CONF_DIR="/opt/etc/soulsturkechowatcher"
CONF_FILE="$CONF_DIR/soulsturkechowatcher.conf"
INIT_FILE="/opt/etc/init.d/S99soulsturkechowatcher"
LOCK_FILE="/tmp/soulsturkechowatcher.lock"
MENU_LOCK_FILE="/tmp/soulsturkechowatcher_menu.lock"
LAST_LOG_FILE="/tmp/soulsturkechowatcher.lastlog"
STATE_FILE="/tmp/soulsturkechowatcher.state"
LAST_IP_FILE="/tmp/soulsturkechowatcher.lastip"
UPDATE_CHECK_FILE="/tmp/soulsturkechowatcher.upd"

# --- Varsayılanlar ---
TG_TOKEN=""
TG_CHATID=""

[ -d "$CONF_DIR" ] || mkdir -p "$CONF_DIR"
[ -f "$CONF_FILE" ] && . "$CONF_FILE"

# ============================================
# YARDIMCI FONKSİYONLAR
# ============================================

create_shortcuts() {
    for cmd in souls soulsturk sew sem; do
        if [ ! -L "/opt/bin/$cmd" ]; then
            ln -sf "$SCRIPT_PATH" "/opt/bin/$cmd"
        fi
    done
}

send_tg() {
    [ -z "$TG_TOKEN" ] || [ -z "$TG_CHATID" ] && return
    {
        curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
            -d "chat_id=$TG_CHATID" -d "text=$1" >/dev/null 2>&1
    } &
}

status_check() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

get_wan_info() {
    IP=$(ndmc -c 'show interface PPPoE0' 2>/dev/null | grep -i 'address:' | awk '{print $2}' | head -n 1)
    if [ -z "$IP" ]; then
        IP=$(ndmc -c 'show interface' 2>/dev/null | grep -i 'address:' | grep -E '^(100\.|[1-9])' | grep -v '^192\.168\.' | grep -v '^10\.' | awk '{print $2}' | head -n 1)
    fi
    echo "${IP:-Bilinmiyor}"
}

check_cgnat() {
    case "$1" in
        100.*) echo "CGNAT (Havuz)" ;;
        *) echo "Gerçek IP" ;;
    esac
}

silent_update_check() {
    if [ -f "$UPDATE_CHECK_FILE" ]; then
        mtime=$(date -r "$UPDATE_CHECK_FILE" +%s)
        now=$(date +%s)
        [ $((now - mtime)) -lt 21600 ] && return
    fi
    
    REMOTE_V=$(curl -s "$UPDATE_URL" | grep -m1 '^SCRIPT_VERSION=' | cut -d'"' -f2)
    if [ -n "$REMOTE_V" ] && [ "$REMOTE_V" != "$SCRIPT_VERSION" ]; then
        echo -e "${MAGENTA}${BOLD}[!] YENİ SÜRÜM BULUNDU: $REMOTE_V (Mevcut: $SCRIPT_VERSION)${NC}"
        echo -e "${YELLOW}Güncellemek için 'U' tuşuna basın.${NC}\n"
        touch "$UPDATE_CHECK_FILE"
        sleep 2
    fi
}

check_update() {
    clear
    echo -e "${CYAN}${BOLD}[ GÜNCELLEME KONTROLÜ ]${NC}"
    echo -e "${YELLOW}Sunucuya bağlanılıyor...${NC}"
    
    TMP_FILE="/tmp/soulsturkechowatcher_update.sh"
    curl -s "$UPDATE_URL" -o "$TMP_FILE"
    
    if [ ! -s "$TMP_FILE" ]; then
        echo -e "${RED}[!] Sunucuya ulaşılamadı.${NC}"
        rm -f "$TMP_FILE"
        sleep 3
        return
    fi
    
    REMOTE_VERSION=$(grep -m1 '^SCRIPT_VERSION=' "$TMP_FILE" | cut -d'"' -f2)
    
    if [ "$SCRIPT_VERSION" != "$REMOTE_VERSION" ]; then
        echo -e "${GREEN}[✔] Yeni sürüm bulundu: $REMOTE_VERSION${NC}"
        printf "Güncellemek ister misiniz? [E/h]: "
        read -r ans
        if [ "$ans" = "e" ] || [ "$ans" = "E" ] || [ -z "$ans" ]; then
            [ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null
            mv -f "$TMP_FILE" "$SCRIPT_PATH"
            chmod +x "$SCRIPT_PATH"
            echo -e "${GREEN}[✔] Güncellendi! Yeniden başlatılıyor...${NC}"
            rm -f "$MENU_LOCK_FILE"
            sleep 2
            exec "$SCRIPT_PATH"
        fi
    else
        echo -e "${GREEN}[✔] En güncel sürümü kullanıyorsunuz.${NC}"
    fi
    rm -f "$TMP_FILE"
    sleep 2
}

# ============================================
# DAEMON (ARKA PLAN SERVİSİ)
# ============================================
if [ "$1" = "--daemon" ]; then
    LAST_UPD_CHECK=0
    logread -f 2>/dev/null | while read -r line; do
        NOW=$(date +%s)
        if [ $((NOW - LAST_UPD_CHECK)) -gt 43200 ]; then
             REMOTE_V=$(curl -s "$UPDATE_URL" | grep -m1 '^SCRIPT_VERSION=' | cut -d'"' -f2)
             if [ -n "$REMOTE_V" ] && [ "$REMOTE_V" != "$SCRIPT_VERSION" ]; then
                 send_tg "🆕 Yeni Sürüm Mevcut! ($REMOTE_V)"
             fi
             LAST_UPD_CHECK=$NOW
        fi

        case "$line" in
            *"No response to 3 echo-requests"*|*"LCP terminated"*)
                date +%s > "$STATE_FILE"
                send_tg "🚫 Olay: PPPoE Oturumu Koptu"
                ;;
            *"Internet access restored"*)
                sleep 5
                NEW_IP=$(get_wan_info)
                send_tg "✅ Olay: İnternet Erişimi Sağlandı\n🌐 IP: $NEW_IP ($(check_cgnat "$NEW_IP"))"
                rm -f "$STATE_FILE"
                ;;
        esac
    done
    exit 0
fi

# ============================================
# OTURUM KONTROLÜ (KZM STİLİ)
# ============================================
if [ -f "$MENU_LOCK_FILE" ]; then
    OLD_MENU_PID=$(cat "$MENU_LOCK_FILE" 2>/dev/null)
    if [ -n "$OLD_MENU_PID" ] && kill -0 "$OLD_MENU_PID" 2>/dev/null; then
        echo -e "${YELLOW}⚠️ Betik zaten başka bir oturumda açık (PID: $OLD_MENU_PID).${NC}"
        printf "${CYAN}Eski oturumu kapatıp buradan devam etmek ister misiniz? [e/H]: ${NC}"
        read -r force_open
        if [ "$force_open" = "e" ] || [ "$force_open" = "E" ]; then
            kill -9 "$OLD_MENU_PID" 2>/dev/null
            rm -f "$MENU_LOCK_FILE"
            echo -e "${GREEN}Eski oturum sonlandırıldı. Yeni oturum açılıyor...${NC}"
            sleep 1
        else
            echo -e "${RED}İşlem iptal edildi.${NC}"
            exit 1
        fi
    else
        # PID dosyası var ama süreç yoksa temizle
        rm -f "$MENU_LOCK_FILE"
    fi
fi

# Yeni oturum için kilit oluştur
echo $$ > "$MENU_LOCK_FILE"
trap 'rm -f "$MENU_LOCK_FILE"' EXIT

# ============================================
# ANA BAŞLANGIÇ
# ============================================
create_shortcuts
silent_update_check

while true; do
    clear
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}    SOULSTURK ECHO WATCHER - PRO İZLEYİCİ [${YELLOW}$SCRIPT_VERSION${CYAN}]${NC}"
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "  1) Servisi BAŞLAT      4) Telegram Ayarları     7) Oto-Başlat KUR"
    echo -e "  2) Servisi DURDUR      5) Test Bildirimi        8) Oto-Başlat KALDIR"
    echo -e "  3) Servisi YENİDEN     6) Logları İzle          9) TAMAMEN KALDIR"
    echo -e "  U) GÜNCELLEMELERİ KONTROL ET                    0) ÇIKIŞ"
    echo -e "${BLUE}────────────────────────────────────────────────────${NC}"
    printf "${GREEN}Seçiminiz:${NC} "
    read choice

    case "$choice" in
        1) "$SCRIPT_PATH" --daemon >/dev/null 2>&1 & echo $! > "$PID_FILE"; sleep 2 ;;
        2) kill "$(cat "$PID_FILE")" 2>/dev/null; rm -f "$PID_FILE"; sleep 2 ;;
        3) kill "$(cat "$PID_FILE")" 2>/dev/null; sleep 1; "$SCRIPT_PATH" --daemon >/dev/null 2>&1 & echo $! > "$PID_FILE"; sleep 2 ;;
        4) 
            printf "Bot Token: "; read token; [ -n "$token" ] && TG_TOKEN="$token"
            printf "Chat ID: "; read cid; [ -n "$cid" ] && TG_CHATID="$cid"
            echo "TG_TOKEN=\"$TG_TOKEN\"" > "$CONF_FILE"
            echo "TG_CHATID=\"$TG_CHATID\"" >> "$CONF_FILE"
            ;;
        9)
            rm -f /opt/bin/souls /opt/bin/soulsturk /opt/bin/sew /opt/bin/sem
            rm -f "$INIT_FILE" "$SCRIPT_PATH" "$MENU_LOCK_FILE"
            echo "Her şey silindi."; exit 0 ;;
        u|U) check_update ;;
        0) exit 0 ;;
        *) sleep 1 ;;
    esac
done
