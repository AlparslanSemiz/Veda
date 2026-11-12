<p align="center"><img src="assets/icon.png" width="128" alt="Veda simgesi"></p>

<h1 align="center">Veda</h1>
<p align="center"><i>Son pencere veda edince uygulama da gider.</i></p>

Veda, macOS'ta bir uygulamanın **son penceresini kapattığında uygulamayı da kapatan** küçük bir menü çubuğu aracıdır. Windows ve GNOME'daki gibi davranır.

Swift Quit ve Last Window Quits gibi araçlar macOS 26+ üzerinde çalışmıyor, çünkü pencere kapanınca gelmesi gereken Erişilebilirlik bildirimleri hiç tetiklenmiyor. Veda bildirim beklemek yerine pencereleri saniyede yaklaşık 8 kez kontrol eder. Uygulama son penceresi kapandıktan yaklaşık 0,3 saniye sonra kapanır.

## Özellikler

- **Doğru ayrım:** Pencereyi küçültmek, uygulamayı gizlemek (⌘H) ya da pencereyi başka bir Space'e taşımak uygulamayı **kapatmaz**. Sadece gerçekten kapatılan son pencere uygulamayı kapatır.
- **Menü çubuğu simgesi:** Duraklat/devam ettir, son kapatılanları tek tıkla yeniden aç, öndeki uygulamayı kara listeye ekle.
- **Kara liste:** `~/.config/veda/blacklist.txt` dosyasına her satıra bir bundle id yazılır. Finder ve Discord her zaman hariç tutulur.
- **Kayıt:** `~/Library/Logs/veda.log`

## Kurulum

```sh
git clone <bu depo>
cd Veda
./build.sh
```

Ardından **Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik** bölümünde **Veda**'yı aç.

`build.sh` uygulamayı `~/Applications/Veda.app` konumuna kurar ve bir LaunchAgent ile girişte başlatır. Menüden "Veda'dan çık" dersen kapalı kalır, çökerse kendiliğinden yeniden açılır.

> **İzin her derlemede sıfırlanmasın:** Kurulumdan önce bir kez `./scripts/make_signing_cert.sh` çalıştır. Bu, yerel bir imza sertifikası oluşturur ve `build.sh` Veda'yı hep onunla imzalar. Sertifika yoksa uygulama ad-hoc imzalanır ve macOS her yeniden derlemede Erişilebilirlik iznini sıfırlar.

## Kaldırma

```sh
launchctl bootout gui/$(id -u)/local.$(whoami).veda
rm -rf ~/Applications/Veda.app ~/Library/LaunchAgents/local.$(whoami).veda.plist ~/.config/veda
```

## Gereksinimler

macOS 14+ ve Xcode Command Line Tools (`xcode-select --install`).

## Lisans

MIT
