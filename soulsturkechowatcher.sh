#!/bin/sh

# ============================================
# SOULSTURK ECHO WATCHER - PRO İZLEYİCİ (IP, CGNAT, KESİNTİ SÜRESİ + OTO GÜNCELLEME)
# ============================================

export PATH="/sbin:/usr/sbin:/bin:/usr/bin:/opt/sbin:/opt/bin:$PATH"

# --- Sürüm ve Güncelleme Ayarları ---
SCRIPT_VERSION="v1"
# Güncelleme için GitHub RAW Linki
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
        echo -e "${RED}[!] Güncelleme sunucusuna ulaşılamadı veya dosya boş.${NC}"
        echo -e "${YELLOW}Not: UPDATE_URL ayarınızın doğruluğunu kontrol edin.${NC}"
        rm -f "$TMP_FILE" 2>/dev/null
        sleep 3
        return
    fi
    
    REMOTE_VERSION=$(grep -m1 '^SCRIPT_VERSION=' "$TMP_FILE" 2>/dev/null | cut -d'"' -f2)
    
    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${RED}[!] İndirilen dosyada sürüm bilgisi (SCRIPT_VERSION) bulunamadı.${NC}"
        rm -f "$TMP_FILE"
        sleep 3
        return
    fi
    
    if [ "$SCRIPT_VERSION" != "$REMOTE_VERSION" ]; then
        echo -e "${GREEN}[✔] Yeni sürüm bulundu!${NC}"
        echo -e " Mevcut Sürüm: ${RED}$SCRIPT_VERSION${NC}"
        echo -e " Yeni Sürüm:   ${GREEN}$REMOTE_VERSION${NC}\n"
        
        printf "Güncellemek ister misiniz? [E/h]: "
        read -r ans
        if [ "$ans" = "e" ] || [ "$ans" = "E" ] || [ -z "$ans" ]; then
            echo -e "${YELLOW}Güncelleniyor...${NC}"
            
            if status_check; then
                kill "$(cat "$PID_FILE")" 2>/dev/null
                rm -f "$PID_FILE"
            fi
            
            mv -f "$TMP_FILE" "$SCRIPT_PATH"
            chmod +x "$SCRIPT_PATH"
            
            echo -e "${GREEN}[✔] Güncelleme tamamlandı! Menü yeniden başlatılıyor...${NC}"
            sleep 2
            
            exec "$SCRIPT_PATH"
        else
            echo -e "${YELLOW}Güncelleme iptal edildi.${NC}"
            rm -f "$TMP_FILE"
            sleep 2
        fi
    else
        echo -e "${GREEN}[✔] Harika! Zaten en güncel sürümü kullanıyorsunuz ($SCRIPT_VERSION).${NC}"
        rm -f "$TMP_FILE"
        sleep 3
    fi
}

# ---------------------------------

print_header() {
    clear
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}    SOULSTURK ECHO WATCHER - PRO İZLEYİCİ [${YELLOW}$SCRIPT_VERSION${CYAN}]${NC}"
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e " ${YELLOW}•${NC} Log kaynağı: $(detect_log_source)"
    echo -e " ${YELLOW}•${NC} Telegram: $([ -n "$TG_TOKEN" ] && [ -n "$TG_CHATID" ] && echo "${GREEN}AYARLI${NC}" || echo "${RED}AYARLANMAMIŞ${NC}")"
    echo -e " ${YELLOW}•${NC} Servis durumu: $(status_check && echo "${GREEN}ÇALIŞIYOR${NC}" || echo "${RED}DURMUŞ${NC}")"
    echo -e " ${YELLOW}•${NC} Otomatik başlatma: $([ -f "$INIT_FILE" ] && echo "${GREEN}AKTİF${NC}" || echo "${RED}PASİF${NC}")"
    echo -e "${BLUE}${BOLD}────────────────────────────────────────────────────${NC}"
}

detect_log_source() {
    if command -v logread >/dev/null 2>&1; then
        echo "logread (canlı akış)"
    elif command -v ndmc >/dev/null 2>&1; then
        echo "ndmc show log (döngüsel)"
    else
        echo "bilinmiyor"
    fi
}

# ============================================
# DAEMON (ARKA PLAN İZLEYİCİ)
# ============================================
if [ "$1" = "--daemon" ]; then
    trap '' HUP 2>/dev/null

    if command -v logread >/dev/null 2>&1; then
        logread -f 2>/dev/null | while read -r line; do
            case "$line" in
                *"disconnected"*)
                    continue
                    ;;
                *"No response to 3 echo-requests"*|*"LCP terminated"*)
                    date +%s > "$STATE_FILE"
                    TIME_NOW=$(date "+%d.%m.%Y %H:%M:%S")
                    MSG="🚫 Olay: PPPoE Oturumu Koptu
Durum: ISS tarafından 3 Echo yanıtı gelmediği için oturum yenilendi.
Zaman: $TIME_NOW"
                    send_tg "$MSG"
                    ;;
                *"Internet access restored"*)
                    sleep 5
                    TIME_NOW=$(date "+%d.%m.%Y %H:%M:%S")
                    DOWNTIME=$(get_downtime)
                    NEW_IP=$(get_wan_info)
                    OLD_IP=$(cat "$LAST_IP_FILE" 2>/dev/null)
                    echo "$NEW_IP" > "$LAST_IP_FILE"
                    
                    CGNAT_STAT=$(check_cgnat "$NEW_IP")
                    
                    IP_CHANGE="Değişmedi"
                    if [ "$OLD_IP" != "$NEW_IP" ] && [ -n "$OLD_IP" ]; then
                        IP_CHANGE="Değişti ($OLD_IP -> $NEW_IP)"
                    elif [ -z "$OLD_IP" ]; then
                        IP_CHANGE="Sisteme kaydedildi"
                    fi

                    MSG="✅ Olay: İnternet Erişimi Sağlandı
Durum: Bağlantı tekrar kuruldu.
Zaman: $TIME_NOW
⏱️ Kesinti Süresi: $DOWNTIME
🌐 IP Adresi: $NEW_IP ($CGNAT_STAT)
🔄 IP Durumu: $IP_CHANGE"
                    
                    send_tg "$MSG"
                    rm -f "$STATE_FILE"
                    ;;
            esac
        done
        exit 0
    fi

    if ! command -v ndmc >/dev/null 2>&1; then
        exit 1
    fi

    touch "$LAST_LOG_FILE"
    last_logs=""
    
    while true; do
        current_logs=$(ndmc -c 'show log' 2>/dev/null | tail -n 20)
        
        if [ "$current_logs" != "$last_logs" ]; then
            
            printf "%s\n" "$current_logs" | while IFS= read -r line; do
                case "$line" in
                    *"disconnected"*)
                        ;;
                    *"No response to 3 echo-requests"*|*"LCP terminated"*)
                        if ! grep -Fq "$line" "$LAST_LOG_FILE" 2>/dev/null; then
                            date +%s > "$STATE_FILE"
                            TIME_NOW=$(date "+%d.%m.%Y %H:%M:%S")
                            MSG="🚫 Olay: PPPoE Oturumu Koptu
Durum: ISS tarafından 3 Echo yanıtı gelmediği için oturum yenilendi.
Zaman: $TIME_NOW"
                            send_tg "$MSG"
                            echo "$line" >> "$LAST_LOG_FILE"
                        fi
                        ;;
                    *"Internet access restored"*)
                        if ! grep -Fq "$line" "$LAST_LOG_FILE" 2>/dev/null; then
                            sleep 5
                            TIME_NOW=$(date "+%d.%m.%Y %H:%M:%S")
                            DOWNTIME=$(get_downtime)
                            NEW_IP=$(get_wan_info)
                            OLD_IP=$(cat "$LAST_IP_FILE" 2>/dev/null)
                            echo "$NEW_IP" > "$LAST_IP_FILE"
                            
                            CGNAT_STAT=$(check_cgnat "$NEW_IP")
                            
                            IP_CHANGE="Değişmedi"
                            if [ "$OLD_IP" != "$NEW_IP" ] && [ -n "$OLD_IP" ]; then
                                IP_CHANGE="Değişti ($OLD_IP -> $NEW_IP)"
                            elif [ -z "$OLD_IP" ]; then
                                IP_CHANGE="Sisteme kaydedildi"
                            fi

                            MSG="✅ Olay: İnternet Erişimi Sağlandı
Durum: Bağlantı tekrar kuruldu.
Zaman: $TIME_NOW
⏱️ Kesinti Süresi: $DOWNTIME
🌐 IP Adresi: $NEW_IP ($CGNAT_STAT)
🔄 IP Durumu: $IP_CHANGE"
                            send_tg "$MSG"
                            echo "$line" >> "$LAST_LOG_FILE"
                            rm -f "$STATE_FILE"
                        fi
                        ;;
                esac
            done
            
            if [ -f "$LAST_LOG_FILE" ]; then
                tail -n 50 "$LAST_LOG_FILE" > "$LAST_LOG_FILE.tmp"
                mv "$LAST_LOG_FILE.tmp" "$LAST_LOG_FILE"
            fi
            
            last_logs="$current_logs"
        fi
        sleep 5
    done
    exit 0
fi

# ============================================
# ANA MENÜ
# ============================================

if [ -f "$LOCK_FILE" ]; then
    echo -e "${RED}[HATA] Betik zaten çalışıyor.${NC}"
    exit 1
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

while true; do
    print_header

    echo -e "${CYAN}${BOLD}  ANA MENÜ${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────${NC}"
    echo -e "  ${YELLOW}1)${NC} Servisi BAŞLAT"
    echo -e "  ${YELLOW}2)${NC} Servisi DURDUR"
    echo -e "  ${YELLOW}3)${NC} Servisi YENİDEN BAŞLAT"
    echo -e "  ${YELLOW}4)${NC} Telegram Ayarlarını Yap"
    echo -e "  ${YELLOW}5)${NC} Test Bildirimi Gönder"
    echo -e "  ${YELLOW}6)${NC} Canlı Logları İzle (elle)"
    echo -e "  ${YELLOW}7)${NC} Otomatik Başlatmayı KUR (init.d)"
    echo -e "  ${YELLOW}8)${NC} Otomatik Başlatmayı KALDIR"
    echo -e "  ${YELLOW}9)${NC} ${RED}${BOLD}TAMAMEN KALDIR (tüm dosyalar)${NC}"
    echo -e "  ${YELLOW}U)${NC} ${MAGENTA}Güncellemeleri Kontrol Et${NC}"
    echo -e "  ${YELLOW}0)${NC} Çıkış"
    echo -e "${BLUE}────────────────────────────────────────────────────${NC}"
    printf "${GREEN}Seçiminiz${NC} [0-9, U]: "
    read choice

    case "$choice" in
        1)
            if [ -z "$TG_TOKEN" ] || [ -z "$TG_CHATID" ]; then
                echo -e "${RED}[!] Önce Telegram ayarlarını yapın (menü 4).${NC}"
            elif status_check; then
                echo -e "${YELLOW}[!] Servis zaten çalışıyor.${NC}"
            else
                "$SCRIPT_PATH" --daemon >/dev/null 2>&1 &
                echo $! > "$PID_FILE"
                echo -e "${GREEN}[✔] Servis başlatıldı.${NC}"
            fi
            sleep 2
            ;;
        2)
            if status_check; then
                kill "$(cat "$PID_FILE")" 2>/dev/null
                rm -f "$PID_FILE"
                echo -e "${GREEN}[✔] Servis durduruldu.${NC}"
            else
                rm -f "$PID_FILE"
                echo -e "${RED}[!] Servis zaten çalışmıyor.${NC}"
            fi
            sleep 2
            ;;
        3)
            if status_check; then
                kill "$(cat "$PID_FILE")" 2>/dev/null
                rm -f "$PID_FILE"
                sleep 1
            fi
            "$SCRIPT_PATH" --daemon >/dev/null 2>&1 &
            echo $! > "$PID_FILE"
            echo -e "${GREEN}[✔] Servis yeniden başlatıldı.${NC}"
            sleep 2
            ;;
        4)
            clear
            echo -e "${CYAN}${BOLD}[ TELEGRAM AYARLARI ]${NC}"
            echo -e " Mevcut Token: ${TG_TOKEN:-${RED}[BOŞ]${NC}}"
            echo -e " Mevcut ChatID: ${TG_CHATID:-${RED}[BOŞ]${NC}}"
            echo ""
            printf "Yeni Bot Token (boş geç = değişmez): "
            read new_token
            [ -n "$new_token" ] && TG_TOKEN="$new_token"
            printf "Yeni Chat ID (boş geç = değişmez): "
            read new_chatid
            [ -n "$new_chatid" ] && TG_CHATID="$new_chatid"
            cat > "$CONF_FILE" <<CONFEOF
TG_TOKEN="$TG_TOKEN"
TG_CHATID="$TG_CHATID"
CONFEOF
            echo -e "${GREEN}[✔] Ayarlar kaydedildi.${NC}"
            sleep 2
            ;;
        5)
            if [ -z "$TG_TOKEN" ] || [ -z "$TG_CHATID" ]; then
                echo -e "${RED}[!] Önce Telegram ayarlarını yapın.${NC}"
            else
                TIME_NOW=$(date "+%d.%m.%Y %H:%M:%S")
                MSG="🔔 Olay: Test Bildirimi
Durum: Soulsturk Echo Watcher bildirim sistemi sorunsuz çalışıyor.
Zaman: $TIME_NOW"
                send_tg "$MSG"
                echo -e "${GREEN}[✔] Test mesajı gönderildi.${NC}"
            fi
            sleep 2
            ;;
        6)
            echo -e "${CYAN}[ CANLI LOG İZLEME - Çıkmak için q tuşuna basın ]${NC}"
            if command -v logread >/dev/null 2>&1; then
                logread -f | less
            elif command -v ndmc >/dev/null 2>&1; then
                TMP_LOG="/tmp/soulsturkechowatcher_log.$$"
                ndmc -c 'show log' > "$TMP_LOG"
                less "$TMP_LOG"
                rm -f "$TMP_LOG"
            else
                echo -e "${RED}Log kaynağı bulunamadı.${NC}"
                sleep 2
            fi
            ;;
        7)
            cat > "$INIT_FILE" <<INITEOF
#!/bin/sh
case "\$1" in
    start) $SCRIPT_PATH --daemon >/dev/null 2>&1 & echo \$! > $PID_FILE ;;
    stop)  kill \$(cat $PID_FILE) 2>/dev/null; rm -f $PID_FILE ;;
esac
INITEOF
            chmod +x "$INIT_FILE"
            echo -e "${GREEN}[✔] Otomatik başlatma kuruldu.${NC}"
            sleep 2
            ;;
        8)
            rm -f "$INIT_FILE"
            echo -e "${GREEN}[✔] Otomatik başlatma kaldırıldı.${NC}"
            sleep 2
            ;;
        9)
            echo -e "${RED}${BOLD}════════════════════════════════════════════════════${NC}"
            echo -e "${RED}${BOLD}        TAMAMEN KALDIRMA İŞLEMİ${NC}"
            echo -e "${RED}${BOLD}════════════════════════════════════════════════════${NC}"
            echo -e " Bu işlem:"
            echo -e " • Çalışan servisi durdurur"
            echo -e " • PID dosyasını siler"
            echo -e " • init.d dosyasını siler"
            echo -e " • Konfigürasyon klasörünü (${CONF_DIR}) siler"
            echo -e " • /opt/bin/soulsturkechowatcher kısayolunu siler"
            echo -e " • VE SON OLARAK bu betik dosyasını (${SCRIPT_PATH}) siler"
            echo ""
            printf "Devam etmek için ${RED}${BOLD}EVET${NC} yazın (iptal için boş bırakın): "
            read confirm
            if [ "$confirm" = "EVET" ]; then
                if status_check; then
                    kill "$(cat "$PID_FILE")" 2>/dev/null
                    rm -f "$PID_FILE"
                fi
                rm -f "$INIT_FILE"
                rm -rf "$CONF_DIR"
                rm -f /opt/bin/soulsturkechowatcher
                echo -e "${GREEN}[✔] Tüm dosyalar silindi. Betik sonlanıyor.${NC}"
                rm -f "$LOCK_FILE"
                rm -f "$SCRIPT_PATH"
                exit 0
            else
                echo -e "${YELLOW}İşlem iptal edildi.${NC}"
                sleep 2
            fi
            ;;
        u|U)
            check_update
            ;;
        0)
            echo -e "${GREEN}Çıkılıyor...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}[!] Geçersiz seçim.${NC}"
            sleep 1
            ;;
    esac
done