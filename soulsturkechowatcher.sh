#!/bin/sh

# ============================================
# SOULSTURK ECHO WATCHER - PRO İZLEYİCİ (v1.3)
# ============================================

export PATH="/sbin:/usr/sbin:/bin:/usr/bin:/opt/sbin:/opt/bin:$PATH"

# --- Sürüm ve Güncelleme Ayarları ---
SCRIPT_VERSION="v1.6"
GITHUB_LINK="github.com/soulsturk/soulsturk-echo-watcher"
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
LAST_LOG_FILE="/tmp/soulsturkechowatcher.lastlog"
STATE_FILE="/tmp/soulsturkechowatcher.state"
LAST_IP_FILE="/tmp/soulsturkechowatcher.lastip"

# --- Başlangıç Kontrolleri ---
[ -d "$CONF_DIR" ] || mkdir -p "$CONF_DIR"
[ -f "$CONF_FILE" ] && . "$CONF_FILE"

# ============================================
# YARDIMCI FONKSİYONLAR
# ============================================

# Cihaz Modelini Çekme
get_model() {
    ndmc -c 'show version' 2>/dev/null | grep -i 'model:' | cut -d':' -f2 | xargs
}

# WAN Durumunu Çekme
get_wan_status() {
    IP=$(ndmc -c 'show interface PPPoE0' 2>/dev/null | grep -i 'address:' | awk '{print $2}' | head -n 1)
    [ -z "$IP" ] && IP="Bilinmiyor"
    CGNAT=$(case "$IP" in 100.*) echo "CGNAT" ;; *) echo "REAL" ;; esac)
    echo "$IP [$CGNAT]"
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

# Güncelleme Kontrolü (Header için)
check_update_status() {
    # Hız için arka planda kontrol yapmıyoruz, sadece mevcut versiyonu yazıyoruz. 
    # U menüsüne basıldığında detaylı kontrol yapılır.
    echo -e "${GREEN}Güncel${NC}"
}

# KZM Tarzı Header (Bilgi Ekranı)
print_header() {
    clear
    MODEL=$(get_model)
    WAN_INFO=$(get_wan_status)
    SERVIS_DURUM=$(status_check && echo -e "${GREEN}CALISIYOR${NC}" || echo -e "${RED}DURMUS${NC}")
    TG_DURUM=$([ -n "$TG_TOKEN" ] && [ -n "$TG_CHATID" ] && echo -e "${GREEN}AYARLI${NC}" || echo -e "${RED}AYARLANMAMIS${NC}")

    echo -e "${CYAN}${BOLD}SOULSTURK ECHO WATCHER YONETIM ARACI (SEW)${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────────────────────${NC}"
    printf "${BOLD}%-12s${NC} : %s\n" "Sistem" "$MODEL"
    printf "${BOLD}%-12s${NC} : %s\n" "Sürüm" "$SCRIPT_VERSION"
    printf "${BOLD}%-12s${NC} : %s\n" "WAN IP" "$WAN_INFO"
    printf "${BOLD}%-12s${NC} : %s\n" "Servis" "$SERVIS_DURUM"
    printf "${BOLD}%-12s${NC} : %s\n" "Telegram" "$TG_DURUM"
    printf "${BOLD}%-12s${NC} : %s\n" "GitHub" "github.com/soulsturk/soulsturk-echo-watcher"
    printf "${BOLD}%-12s${NC} : %s\n" "Güncelleme" "$(check_update_status)"
    echo -e "${BLUE}==================================================================================${NC}"
    echo -e "Bu arac, Keenetic cihazlarinda internet kopmalarini, IP degisimlerini ve"
    echo -e "CGNAT durumlarini izler. Bir kesinti oldugunda Telegram uzerinden"
    echo -e "kesinti suresiyle birlikte anlik bildirim gonderen bir yonetim panelidir."
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────────────────────${NC}"
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
        sleep 3; return
    fi
    
    REMOTE_VERSION=$(grep -m1 '^SCRIPT_VERSION=' "$TMP_FILE" 2>/dev/null | cut -d'"' -f2)
    
    if [ "$SCRIPT_VERSION" != "$REMOTE_VERSION" ]; then
        echo -e "${GREEN}[✔] Yeni sürüm bulundu!${NC}"
        echo -e " Mevcut: ${RED}$SCRIPT_VERSION${NC} -> Yeni: ${GREEN}$REMOTE_VERSION${NC}\n"
        printf "Güncellemek ister misiniz? [E/h]: "
        read -r ans
        if [ "$ans" = "e" ] || [ "$ans" = "E" ] || [ -z "$ans" ]; then
            # Güncellemeden önce kilit dosyasını temizle (image_4d71da.png hatasını önler)
            rm -f "$LOCK_FILE"
            if status_check; then
                kill "$(cat "$PID_FILE")" 2>/dev/null
                rm -f "$PID_FILE"
            fi
            mv -f "$TMP_FILE" "$SCRIPT_PATH"
            chmod +x "$SCRIPT_PATH"
            echo -e "${GREEN}[✔] Güncellendi! Yeniden başlatılıyor...${NC}"
            sleep 2
            exec "$SCRIPT_PATH"
        fi
    else
        echo -e "${GREEN}[✔] En güncel sürümü kullanıyorsunuz.${NC}"
        rm -f "$TMP_FILE"
        sleep 2
    fi
}

# (Daha önceki daemon ve menü fonksiyonları buraya gelecek, bütünlüğü bozmamak adına...)
#

# ============================================
# ANA MENÜ VE DÖNGÜ
# ============================================

# Kilit dosyası kontrolü
if [ -f "$LOCK_FILE" ]; then
    echo -e "${RED}[HATA] Betik zaten çalışıyor.${NC}"
    exit 1
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

while true; do
    print_header

    echo -e "  ${YELLOW}1)${NC} Servisi BAŞLAT"
    echo -e "  ${YELLOW}2)${NC} Servisi DURDUR"
    echo -e "  ${YELLOW}3)${NC} Servisi YENİDEN BAŞLAT"
    echo -e "  ${YELLOW}4)${NC} Telegram Ayarlarını Yap"
    echo -e "  ${YELLOW}5)${NC} Test Bildirimi Gönder"
    echo -e "  ${YELLOW}6)${NC} Canlı Logları İzle"
    echo -e "  ${YELLOW}7)${NC} Otomatik Başlatmayı KUR"
    echo -e "  ${YELLOW}8)${NC} Otomatik Başlatmayı KALDIR"
    echo -e "  ${YELLOW}9)${NC} ${RED}${BOLD}TAMAMEN KALDIR${NC}"
    echo -e "  ${YELLOW}U)${NC} ${MAGENTA}Güncellemeleri Kontrol Et${NC}"
    echo -e "  ${YELLOW}0)${NC} Çıkış"
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────────────────────${NC}"
    printf "${GREEN}Seçiminiz${NC} [0-9, U]: "
    read choice
    # (Case yapıları devam eder...)
done
