#!/bin/sh

# ============================================
# SOULSTURK ECHO WATCHER - PRO İZLEYİCİ (v1.1)
# (IP, CGNAT, KESİNTİ SÜRESİ + OTO GÜNCELLEME BİLDİRİMİ)
# ============================================

export PATH="/sbin:/usr/sbin:/bin:/usr/bin:/opt/sbin:/opt/bin:$PATH"

# --- Sürüm ve Güncelleme Ayarları ---
SCRIPT_VERSION="v1.1"
UPDATE_URL="https://raw.githubusercontent.com/soulsturk/soulsturk-echo-watcher/main/soulsturkechowatcher.sh"
UPDATE_CHECK_INTERVAL=86400 # 24 saatte bir kontrol eder (saniye)

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
LAST_LOG_FILE="/tmp/soulsturkechowatcher.lastlog"
STATE_FILE="/tmp/soulsturkechowatcher.state"
LAST_IP_FILE="/tmp/soulsturkechowatcher.lastip"
LAST_UPDATE_CHECK_FILE="/tmp/soulsturkechowatcher.lastupdate"

# --- Varsayılanlar ---
TG_TOKEN=""
TG_CHATID=""

[ -d "$CONF_DIR" ] || mkdir -p "$CONF_DIR"
[ -f "$CONF_FILE" ] && . "$CONF_FILE"

# ============================================
# YARDIMCI FONKSİYONLAR
# ============================================

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

get_downtime() {
    if [ -f "$STATE_FILE" ]; then
        START_TIME=$(cat "$STATE_FILE")
        END_TIME=$(date +%s)
        DIFF=$((END_TIME - START_TIME))
        M=$((DIFF / 60))
        S=$((DIFF % 60))
        if [ "$M" -gt 0 ]; then
            echo "${M} dk ${S} sn"
        else
            echo "${S} sn"
        fi
    else
        echo "Bilinmiyor"
    fi
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
        Bilinmiyor) echo "Bilinmiyor" ;;
        *) echo "Gerçek IP" ;;
    esac
}

check_update() {
    clear
    echo -e "${CYAN}${BOLD}[ GÜNCELLEME KONTROLÜ ]${NC}"
    echo -e "${YELLOW}Sunucuya bağlanılıyor...${NC}"
    
    TMP_FILE="/tmp/soulsturkechowatcher_update.sh"
    curl -s "$UPDATE_URL" -o "$TMP_FILE"
    
    if [ ! -f "$TMP_FILE" ] || [ ! -s "$TMP_FILE" ]; then
        echo -e "${RED}[!] Güncelleme sunucusuna ulaşılamadı.${NC}"
        rm -f "$TMP_FILE" 2>/dev/null
        sleep 3
        return
    fi
    
    REMOTE_VERSION=$(grep -m1 '^SCRIPT_VERSION=' "$TMP_FILE" 2>/dev/null | cut -d'"' -f2)
    
    if [ "$SCRIPT_VERSION" != "$REMOTE_VERSION" ] && [ -n "$REMOTE_VERSION" ]; then
        echo -e "${GREEN}[✔] Yeni sürüm bulundu! ($REMOTE_VERSION)${NC}"
        printf "Güncellemek ister misiniz? [E/h]: "
        read -r ans
        if [ "$ans" = "e" ] || [ "$ans" = "E" ] || [ -z "$ans" ]; then
            if status_check; then
                kill "$(cat "$PID_FILE")" 2>/dev/null
                rm -f "$PID_FILE"
            fi
            mv -f "$TMP_FILE" "$SCRIPT_PATH"
            chmod +x "$SCRIPT_PATH"
            echo -e "${GREEN}[✔] Güncellendi! Yeniden başlatılıyor...${NC}"
            sleep 2
            exec "$SCRIPT_PATH"
        else
            rm -f "$TMP_FILE"
        fi
    else
        echo -e "${GREEN}[✔] En güncel sürümü kullanıyorsunuz.${NC}"
        rm -f "$TMP_FILE"
        sleep 2
    fi
}

# ============================================
# DAEMON (ARKA PLAN İZLEYİCİ)
# ============================================
if [ "$1" = "--daemon" ]; then
    trap '' HUP 2>/dev/null

    # --- LOGREAD MODU ---
    if command -v logread >/dev/null 2>&1; then
        logread -f 2>/dev/null | while read -r line; do
            # Saatlik Güncelleme Kontrolü (Arka Planda)
            NOW=$(date +%s)
            LAST_CHECK=$(cat "$LAST_UPDATE_CHECK_FILE" 2>/dev/null || echo 0)
            if [ $((NOW - LAST_CHECK)) -ge $UPDATE_CHECK_INTERVAL ]; then
                echo "$NOW" > "$LAST_UPDATE_CHECK_FILE"
                REMOTE_V=$(curl -s "$UPDATE_URL" | grep -m1 '^SCRIPT_VERSION=' | cut -d'"' -f2)
                if [ -n "$REMOTE_V" ] && [ "$SCRIPT_VERSION" != "$REMOTE_V" ]; then
                    send_tg "📢 Güncelleme Mevcut! Soulsturk Echo Watcher için yeni bir sürüm ($REMOTE_V) yayınlandı. Menüden güncelleyebilirsiniz."
                fi
            fi

            case "$line" in
                *"No response to 3 echo-requests"*|*"LCP terminated"*)
                    date +%s > "$STATE_FILE"
                    send_tg "🚫 Olay: PPPoE Oturumu Koptu. ISS Echo yanıtı vermedi. Zaman: $(date "+%d.%m.%Y %H:%M:%S")"
                    ;;
                *"Internet access restored"*)
                    sleep 5
                    DOWNTIME=$(get_downtime)
                    NEW_IP=$(get_wan_info)
                    OLD_IP=$(cat "$LAST_IP_FILE" 2>/dev/null)
                    echo "$NEW_IP" > "$LAST_IP_FILE"
                    CGNAT_STAT=$(check_cgnat "$NEW_IP")
                    IP_MSG=$( [ "$OLD_IP" != "$NEW_IP" ] && echo "Değişti ($OLD_IP -> $NEW_IP)" || echo "Değişmedi" )
                    
                    send_tg "✅ Olay: İnternet Erişimi Sağlandı
Zaman: $(date "+%d.%m.%Y %H:%M:%S")
⏱️ Kesinti: $DOWNTIME
🌐 IP: $NEW_IP ($CGNAT_STAT)
🔄 Durum: $IP_MSG"
                    rm -f "$STATE_FILE"
                    ;;
            esac
        done
        exit 0
    fi

    # --- NDMC MODU (Alternatif) ---
    while true; do
        # Arka Plan Güncelleme Kontrolü
        NOW=$(date +%s)
        LAST_CHECK=$(cat "$LAST_UPDATE_CHECK_FILE" 2>/dev/null || echo 0)
        if [ $((NOW - LAST_CHECK)) -ge $UPDATE_CHECK_INTERVAL ]; then
            echo "$NOW" > "$LAST_UPDATE_CHECK_FILE"
            REMOTE_V=$(curl -s "$UPDATE_URL" | grep -m1 '^SCRIPT_VERSION=' | cut -d'"' -f2)
            if [ -n "$REMOTE_V" ] && [ "$SCRIPT_VERSION" != "$REMOTE_V" ]; then
                send_tg "📢 Güncelleme Mevcut! ($REMOTE_V)"
            fi
        fi

        # Log İzleme Mantığı
        current_logs=$(ndmc -c 'show log' 2>/dev/null | tail -n 10)
        # (Burada mevcut log karşılaştırma mantığınız devam eder...)
        
        sleep 10
    done
fi

# ============================================
# ANA MENÜ
# ============================================

print_header() {
    clear
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}    SOULSTURK ECHO WATCHER - PRO İZLEYİCİ [${YELLOW}$SCRIPT_VERSION${CYAN}]${NC}"
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e " ${YELLOW}•${NC} Telegram: $([ -n "$TG_TOKEN" ] && echo "${GREEN}AYARLI${NC}" || echo "${RED}YOK${NC}") | Servis: $(status_check && echo "${GREEN}ÇALIŞIYOR${NC}" || echo "${RED}DURMUŞ${NC}")"
    echo -e "${BLUE}${BOLD}────────────────────────────────────────────────────${NC}"
}

while true; do
    print_header
    echo -e "  ${YELLOW}1)${NC} Servisi BAŞLAT"
    echo -e "  ${YELLOW}2)${NC} Servisi DURDUR"
    echo -e "  ${YELLOW}3)${NC} Servisi YENİDEN BAŞLAT"
    echo -e "  ${YELLOW}4)${NC} Telegram Ayarlarını Yap"
    echo -e "  ${YELLOW}5)${NC} Test Bildirimi Gönder"
    echo -e "  ${YELLOW}U)${NC} ${MAGENTA}Güncellemeleri Kontrol Et${NC}"
    echo -e "  ${YELLOW}9)${NC} ${RED}TAMAMEN KALDIR${NC}"
    echo -e "  ${YELLOW}0)${NC} Çıkış"
    echo -ne "\n${GREEN}Seçiminiz:${NC} "
    read choice

    case "$choice" in
        1) "$SCRIPT_PATH" --daemon >/dev/null 2>&1 & echo $! > "$PID_FILE"; sleep 1 ;;
        2) kill "$(cat "$PID_FILE")" 2>/dev/null; rm -f "$PID_FILE"; sleep 1 ;;
        3) kill "$(cat "$PID_FILE")" 2>/dev/null; "$SCRIPT_PATH" --daemon >/dev/null 2>&1 & echo $! > "$PID_FILE"; sleep 1 ;;
        4) 
            echo -n "Bot Token: "; read TG_TOKEN; echo -n "Chat ID: "; read TG_CHATID
            echo -e "TG_TOKEN=\"$TG_TOKEN\"\nTG_CHATID=\"$TG_CHATID\"" > "$CONF_FILE"
            ;;
        5) send_tg "🔔 Test Mesajı: Soulsturk Echo Watcher aktif!";;
        [uU]) check_update ;;
        9) 
            echo -e "${RED}Her şey siliniyor...${NC}"
            kill "$(cat "$PID_FILE")" 2>/dev/null
            rm -rf "$CONF_DIR" "$INIT_FILE" "$PID_FILE" "$SCRIPT_PATH"
            exit 0 ;;
        0) exit 0 ;;
    esac
done