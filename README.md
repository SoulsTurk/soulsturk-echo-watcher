# 📡 Soulsturk Echo Watcher

Keenetic cihazlar (ve log/ndmc altyapısını destekleyen sistemler) için geliştirilmiş, **flood korumalı**, akıllı bir PPPoE/WAN bağlantı izleme ve Telegram bildirim betiğidir. 

Klasik izleyicilerin aksine, "client disconnected" (Wi-Fi kopmaları) gibi önemsiz logları filtreler ve sadece gerçek internet kesintilerinde devreye girer.

## ✨ Özellikler

* **🚫 Sıfır Flood Garantisi:** Sadece gerçek "No response to 3 echo-requests" veya "LCP terminated" durumlarında tetiklenir. Wi-Fi kopmalarını internet kopması sanıp sizi mesaja boğmaz.
* **⏱️ Kesinti Süresi (Downtime) Hesaplama:** İnternetiniz geri geldiğinde, tam olarak kaç dakika/saniye çevrimdışı kaldığınızı hesaplar ve bildirime ekler.
* **🌐 IP & CGNAT Tespiti:** Bağlantı sağlandığında cihazın aldığı yeni IP adresini yakalar. Bu IP'nin **CGNAT (Havuz)** mu yoksa **Gerçek IP** mi olduğunu analiz eder.
* **🔄 IP Değişim Kontrolü:** Sadece PPPoE oturumunuz mu yenilendi (IP değişti) yoksa fiziksel bir DSL kopması mı yaşandı, rahatlıkla takip edebilirsiniz.
* **📲 Dahili Güncelleme Sistemi:** Menü üzerinden tek tuşla GitHub'daki en güncel sürüme kendini otomatik olarak günceller.
* **🛠️ Kullanışlı Arayüz:** Telegram API, başlatma, durdurma ve test işlemlerini SSH üzerinden kolayca yapabileceğiniz interaktif bir konsol menüsüne sahiptir.

![Ana Menü](https://github.com/SoulsTurk/soulsturk-echo-watcher/raw/main/docs/images/main-menu.png)

## 🚀 Kurulum (Tek Tıkla)

Cihazınıza SSH ile bağlanın ve aşağıdaki komut bloğunu tek seferde kopyalayıp terminale yapıştırın. Bu işlem gerekli klasörleri oluşturacak, betiğin en güncel halini indirecek ve menüyü otomatik olarak başlatacaktır:

```bash
mkdir -p /opt/lib/opkg && curl -fsSL https://raw.githubusercontent.com/soulsturk/soulsturk-echo-watcher/main/soulsturkechowatcher.sh \
-o /opt/lib/opkg/soulsturkechowatcher.sh && \
chmod +x /opt/lib/opkg/soulsturkechowatcher.sh && \
/opt/lib/opkg/soulsturkechowatcher.sh
