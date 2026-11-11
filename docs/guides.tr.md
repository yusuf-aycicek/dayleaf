# Dayleaf – Adım adım kılavuzlar

Komutlar Windows'ta **Git Bash** içindir. PowerShell'de aynı komutlar çalışır; yalnızca
ortam değişkeni ataması farklıdır (`$env:TEMP='C:\dev\tmp'`).

Windows'ta iki not:

- Kullanıcı klasörünün adında Türkçe karakter (ör. `ç`, `ş`) varsa Gradle'ın
  ve JDK'nın geçici klasörü ASCII bir yolda olmalı. Yoksa "Unable to establish
  loopback connection" hatası çıkar. Derlemeden önce:
  `export TEMP='C:\dev\tmp' TMP='C:\dev\tmp'`. Android Studio'dan derleyecekseniz bu
  iki değişkeni Windows ortam değişkenlerine kalıcı olarak ekleyin.
- Ağ yavaşsa ve DNS zaman zaman kopuyorsa (aralıklı "host bulunamadı" hataları),
  bütün ağ bağdaştırıcılarında güvenilir bir DNS (ör. 8.8.8.8 / 1.1.1.1) kullanın ve
  ağ hatasıyla biten indirmeleri yeniden deneyin.

## 1. Emülatörde çalıştırmak

```bash
emulator -list-avds                 # ör. Pixel_7_API_37
emulator -avd Pixel_7_API_37 &      # ya da Android Studio > Device Manager > ▶
flutter devices                     # emulator-5554 görünmeli
cd /c/dev/dailywall
flutter run                         # debug; r = hot reload, R = yeniden başlat, q = çık
```

İlk açılışta karşılama ekranı gelir: dil → ilgi alanları → (İngilizce seçildiyse)
seviye → nereye → stil → **Duvar kâğıdını ayarla**.

## 2. Kilit ve ana ekranda ayrı ayrı doğrulamak

1. Ayarlar → **Duvar kâğıdı nereye** → *Yalnızca kilit ekranı*. Bugün sekmesinde
   **Şimdi uygula**.
2. Ana ekrana dönün (emülatörün alt çubuğu ya da `adb shell input keyevent KEYCODE_HOME`):
   ana ekranın duvar kâğıdı **değişmemiş** olmalı.
3. Kilit ekranı: `adb shell input keyevent KEYCODE_POWER` (ekran kapanır), aynı
   komutla tekrar açın. Kilit ekranında günün duvar kâğıdı görünmeli; yazı saatin
   altında kalmalı.
4. Ayarlar → *Yalnızca ana ekran* → **Şimdi uygula**. Bu kez ana ekran değişmeli,
   kilit ekranı bir önceki adımdaki gibi kalmalı.
5. *İkisi de* → **Şimdi uygula**: iki ekran aynı görüntüyü göstermeli.

Kilit ekranı yalnızca bir ekran kilidi tanımlıysa görünür. Ayarın gerçekten açık
olduğunu şöyle kontrol edin; `true` çıkarsa kilit kapalıdır (Ayarlar → Güvenlik →
Ekran kilidi → Kaydırma):

```bash
adb shell cmd lock_settings get-disabled
```

Komut satırından da bakılabilir (iki ayrı duvar kâğıdı kimliği görünür; `mWhich=1`
ana ekran, `2` kilit ekranı, `3` ikisi):

```bash
adb shell dumpsys wallpaper | grep -iE "mWhich|mWallpaperId|FLAG_LOCK|FLAG_SYSTEM"
```

Not: Bazı Android sürümlerinde kilit ekranına ayrı bir duvar kâğıdı konmadığı sürece
kilit ekranı, ana ekranınkini kullanır. Kilit ekranını yalnız başına değiştirdiğinizde
bu bağ kopar; bu, sistemin beklenen davranışıdır.

## 3. Arka plan görevini beklemeden test etmek

Günlük görev WorkManager'ın periyodik işidir (`dayleaf.daily`, 6 saatte bir; bugünün
duvar kâğıdı zaten konmuşsa hemen çıkar).

**a) Uygulamanın içinden (debug derlemesi):** Ayarlar'ın en altındaki **Developer**
bölümü:

- *Run the background task now*: aynı kodla tek seferlik bir WorkManager işi kuyruğa
  atar. Birkaç saniye sonra *Background log* satırına dokunun.
- *Pretend it is tomorrow*: günü bir ileri alır; yeni içerik seçilir ve uygulanır.
  Bunu kullandıktan sonra *Reset day offset* ile sıfırlayın.

**b) Uygulama kapalıyken arka plan işi** (ayrı süreçte, ayrı Flutter motoruyla
çalıştığını görmek için; Pixel 7 API 37 emülatöründe denendi):

1. Uygulamada Ayarlar → Developer → *Run the background task in 1 minute*. Tek
   seferlik iş 1 dakika sonrasına kuyruğa girer.
2. Uygulamayı kapatın. `force-stop` **kullanmayın**: o, uygulamanın bütün zamanlanmış
   işlerini de siler.

   ```bash
   adb shell input keyevent KEYCODE_HOME
   adb shell am kill com.yusufaycicek.dayleaf
   adb shell pidof com.yusufaycicek.dayleaf    # boş çıkmalı
   ```

3. Bir dakika sonra:

   ```bash
   adb logcat -s flutter
   # dayleaf background task "applyDailyWallpaperNow": ApplyResult(...)
   adb shell pidof com.yusufaycicek.dayleaf    # yeni bir süreç kimliği
   adb shell dumpsys wallpaper | grep "id="       # duvar kâğıdı değiştiyse id artar
   ```

   Bugünün duvar kâğıdı zaten konmuşsa sonuç `alreadyApplied` olur ve duvar kâğıdı
   değişmez. Değişimi görmek için önce *Pretend it is tomorrow* kullanın ya da
   aşağıdaki (d) yolunu izleyin.

Periyodik işi (`dayleaf.daily`) adb ile **öne alamazsınız**. İşin kimliğini görmek
için:

```bash
adb shell dumpsys jobscheduler | grep "JOB androidx.work.systemjobscheduler" | grep dayleaf
# JOB androidx.work.systemjobscheduler:u0a235/3: ... -> kimlik 3
```

Android 14+'ta WorkManager işleri bir ad alanında tuttuğu için zorlama komutu `-n`
ister: `adb shell cmd jobscheduler run -f -n androidx.work.systemjobscheduler
com.yusufaycicek.dayleaf 3`. Ama WorkManager periyodik işi süresi dolmadan
çalıştırmaz; logcat'te `WM-WorkerWrapper: ... is ENQUEUED; not doing any work`
yazar. Bu yüzden (b)'deki tek seferlik iş kullanılır.

**c) WorkManager'ın kendi tanılama çıktısı** (debug derlemesi):

```bash
adb shell am broadcast -a "androidx.work.diagnostics.REQUEST_DIAGNOSTICS" -p com.yusufaycicek.dayleaf
adb logcat -s WM-DiagnosticsWrkr
```

**d) Ertesi günü saatle denemek:** emülatörün Ayarlar → Sistem → Tarih ve saat →
otomatik saati kapatıp tarihi bir gün ileri alın, sonra (b)'deki adımları izleyin
(bu yol ayrıca denenmedi). Bittiğinde otomatik saati geri açın.

## 4. Release derlemesi, imzalı AAB ve anahtarın güvenliği

Google Play, uygulamayı **yükleme anahtarınızla** imzalanmış bir AAB olarak ister.
Play App Signing açıkken asıl imzalama anahtarını Google saklar. Yükleme anahtarınızı
kaybederseniz Play Console'dan sıfırlama istenebilir, ama bu günler sürer. Bu yüzden
anahtarı iyi saklayın.

1. Anahtarı **depo dışında** oluşturun (JDK, Android Studio'nun içindeki `keytool`):

   ```bash
   mkdir -p /c/dev/keys
   "/c/Program Files/Android/Android Studio/jbr/bin/keytool" -genkeypair -v \
     -keystore /c/dev/keys/dailywall-upload.jks -storetype JKS \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   Sorulan parolaları bir parola yöneticisine kaydedin.

2. `android/key.properties.example` dosyasını `android/key.properties` adıyla
   kopyalayıp doldurun. Bu dosya ve `*.jks` `.gitignore`'dadır, **asla commit
   edilmez**:

   ```properties
   storeFile=C:/dev/keys/dailywall-upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```

3. Sürüm numarasını `pubspec.yaml` içinde artırın (`version: 1.0.0+1`; `+` sonrası
   her yüklemede büyümeli), sonra:

   ```bash
   export TEMP='C:\dev\tmp' TMP='C:\dev\tmp'
   flutter build appbundle --release
   # çıktı: build/app/outputs/bundle/release/app-release.aab
   ```

4. İmzayı ve izinleri kontrol edin:

   ```bash
   "/c/Program Files/Android/Android Studio/jbr/bin/keytool" -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
   grep -o 'android.permission.[A-Z_]*' build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml | sort -u
   ```

   Listede `INTERNET` **olmamalı**.

5. Anahtarın güvenliği:
   - `.jks` dosyasının ve parolaların birer yedeğini ayrı yerlerde tutun (ör. şifreli
     bir USB bellek ve bir parola yöneticisi). Aynı buluta, aynı klasöre koymayın.
   - `key.properties` dosyasını kimseyle paylaşmayın, ekran görüntüsüne girmesin.
   - `key.properties` yoksa release derlemesi debug anahtarıyla imzalanır. Böyle bir
     derleme denemek için çalışır, ama Play'e yüklenemez.

## 5. README ekran görüntüleri

Emülatörde uygulamayı istediğiniz duruma getirin, sonra:

```bash
cd /c/dev/dailywall
adb exec-out screencap -p > docs/screenshots/today.png
```

Önerilen dört görüntü: `onboarding.png` (ilk sayfa), `today.png` (Bugün sekmesi),
`lock.png` (kilit ekranı: güç tuşuyla kapatıp açın), `home.png` (ana ekran). Durum
çubuğunu temizlemek için demo modunu kullanabilirsiniz:

```bash
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0900
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
# bitince:
adb shell am broadcast -a com.android.systemui.demo -e command exit
```

Görüntüler 1080 piksel genişliğindedir. README'de tablo içinde küçültülerek görünür.

## 6. Herkese açık GitHub deposu olarak yayımlamak (yusuf-aycicek)

1. **Commit e-postası:** depodaki bütün commit'ler GitHub'ın noreply adresiyle
   yazılmıştır, kişisel e-posta herkese açık geçmişte görünmez. GitHub → Settings →
   Emails → *Block command line pushes that expose my email* seçeneğini de açarsanız
   yanlışlıkla başka bir adresle push edilemez. Kontrol:

   ```bash
   git log --format='%an <%ae> | %cn <%ce>' | sort -u
   ```

2. **Gizli bir şey kalmadığını kontrol edin:**

   ```bash
   git ls-files | grep -iE "key\.properties$|\.jks$|\.keystore$|local\.properties"   # boş çıkmalı
   ```

3. **Depoyu oluşturup gönderin** (GitHub CLI ile; yoksa github.com/new üzerinden
   *Public*, README'siz bir depo açıp `git remote add` kullanın):

   ```bash
   gh auth login
   gh repo create yusuf-aycicek/dayleaf --public --source . --push \
     --description "A new wallpaper every day, generated on-device. Offline, no ads."
   ```

4. **CI:** Actions sekmesinde *CI* iş akışı çalışır. README'deki rozet yeşile döner.

5. **Gizlilik politikasını GitHub Pages'te yayımlamak:** depo → Settings → Pages →
   *Build and deployment*: Source **Deploy from a branch**, Branch **main**, klasör
   **/docs** → Save. Birkaç dakika sonra
   `https://yusuf-aycicek.github.io/dayleaf/privacy-policy` açılır. Uygulamadaki
   bağlantı (`lib/core/app_config.dart`) ve Play Console'daki *Gizlilik politikası*
   alanı bu adresi kullanır.

6. İsteğe bağlı: depo açıklamasına konu etiketleri ekleyin (`flutter`, `android`,
   `wallpaper`, `offline`, `spaced-repetition`). *About* bölümüne Pages adresini
   koyun.
