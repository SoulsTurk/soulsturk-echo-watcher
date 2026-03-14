# 📡 Soulsturk Echo Watcher

🚀 **Neden Bu Araca İhtiyaç Var?:**
Keenetic router'lar üzerinde çalışan standart Telegram botu, ISP kaynaklı 3 adet "Echo No Response" (LCP yankı yanıtı alınamaması) hatasını doğrudan "Bağlantı Koptu" olarak raporlar. Ancak çoğu durumda bu, hattın tamamen düşmesi değil, sadece anlık bir paket kaybı veya ISP tarafındaki geçici bir yanıtsızlık durumudur.
Soulsturk Echo Watcher, bu karmaşıklığı gidermek için geliştirilmiştir.

## ✨ Özellikler

* **🚫 Sıfır Flood Garantisi:** Sadece gerçek `"No response to 3 echo-requests"` veya `"LCP terminated"` durumlarında tetiklenir. Wi‑Fi kopmalarını internet kopması sanıp sizi mesaja boğmaz.
* **⏱️ Kesinti Süresi (Downtime) Hesaplama:** İnternetiniz geri geldiğinde, tam olarak kaç dakika/saniye çevrimdışı kaldığınızı hesaplar ve bildirime ekler.
* **🌐 IP Tespiti:** Bağlantı sağlandığında cihazın aldığı yeni IP adresini yakalar.
* **🔄 IP Değişim Kontrolü:** Sadece PPPoE oturumunuz mu yenilendi (IP değişti) yoksa fiziksel bir DSL kopması mı yaşandı, rahatlıkla takip edebilirsiniz.
* **📲 Dahili Güncelleme Sistemi:** Menü üzerinden tek tuşla GitHub'daki en güncel sürüme kendini otomatik olarak günceller.
* **🛠️ Kullanışlı Arayüz:** Telegram API, başlatma, durdurma ve test işlemlerini SSH üzerinden kolayca yapabileceğiniz interaktif bir konsol menüsüne sahiptir.

## 🖼️ Ekran Görüntüleri

**Ana menüde servis durumunu, Telegram ayarlarını ve otomatik başlatma durumunu tek bakışta görebilirsiniz.**

![Ana Menü](https://github.com/SoulsTurk/soulsturk-echo-watcher/raw/main/docs/images/main-menu.jpg)

**Güncelleme kontrolü yaparak en yeni sürümü anında kurabilirsiniz.**

![Güncelleme Kontrolü](https://github.com/SoulsTurk/soulsturk-echo-watcher/raw/main/docs/images/update.png)

**Güncelleme bulunduğunda size sorar ve onayınızla güncelleme işlemini gerçekleştirir.**

![Güncelleme Onay](https://github.com/SoulsTurk/soulsturk-echo-watcher/raw/main/docs/images/update2.png)

**Eğer aynı betik birden fazla kez çalıştırılmaya çalışılırsa, lock dosyası sayesinde uyarı verir ve çakışmayı engeller.**

![Lock Dosyası Uyarısı](https://github.com/SoulsTurk/soulsturk-echo-watcher/raw/main/docs/images/pidlock.jpg)

**Tamamen kaldırma işlemi sırasında tüm dosyaları ve kısayolları güvenle silebilirsiniz.**

![Tam Kaldırma](https://github.com/SoulsTurk/soulsturk-echo-watcher/raw/main/docs/images/delete.jpg)


## 🚀 Kurulum (Tek Tıkla)

Cihazınıza SSH ile bağlanın ve aşağıdaki komut bloğunu tek seferde kopyalayıp terminale yapıştırın. Bu işlem gerekli klasörleri oluşturacak, betiğin en güncel halini indirecek ve menüyü otomatik olarak başlatacaktır:

```bash
mkdir -p /opt/lib/opkg && curl -fsSL https://raw.githubusercontent.com/soulsturk/soulsturk-echo-watcher/main/soulsturkechowatcher.sh \
-o /opt/lib/opkg/soulsturkechowatcher.sh && \
chmod +x /opt/lib/opkg/soulsturkechowatcher.sh && \
/opt/lib/opkg/soulsturkechowatcher.sh
