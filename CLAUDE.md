# dailywall – Claude için çalışma notları

## İletişim dili

- Kullanıcıya **her zaman Türkçe** yazılır: özetler, sorular, açıklamalar, durum
  mesajları, adım sonu özetleri.
- İngilizce kalabilenler: komutlar, kod ve kod içi yorumlar, dosya ve klasör adları,
  commit mesajları, depodaki İngilizce belgeler (README.md, store listing'in İngilizce
  bölümü vb.).

## Proje

- İlgi alanlarına göre her gün yeni duvar kâğıdı üreten, tamamen çevrimdışı bir
  **Flutter** uygulaması. Yalnızca **Android** (minSdk 24); iOS kodu yazılmaz.
- Konum: `C:\dev\dailywall`, kendi git deposu (`main`). Paket adı
  `com.yusufaycicek.dailywall`, tek yerden değişir: `android/gradle.properties`.
- Geliştirici: Yusuf Ayçiçek, GitHub `yusuf-aycicek`. Commit e-postası GitHub noreply
  adresidir; kişisel e-posta depoya ya da commit'lere yazılmaz.
- Mimari, içerik ekleme ve testler: `README.md` / `README.tr.md`. Emülatör, arka plan
  görevi, imzalı AAB ve yayın kılavuzları: `docs/guides.tr.md`.
- Her adımın sonunda `flutter analyze` ve `flutter test` hatasız geçer, sonra commit
  atılır. Komut çıktısı `tail`/`grep`'e borulanmaz; çıkış kodu ayrıca denetlenir.
  Golden testler CI'da çalışmaz (`flutter test --exclude-tags golden`).

## Yayın: GitHub Pages

- Site: `https://yusuf-aycicek.github.io/dailywall/`, kaynak `main` dalındaki `docs/`
  klasörü (Jekyll, klasik "Deploy from a branch").
- Gizlilik politikası adresi **kalıcıdır**:
  `https://yusuf-aycicek.github.io/dailywall/privacy-policy`. Uygulama
  (`lib/core/app_config.dart`) ve Play Console bu adresi kullanır; yayımlanmış bir
  uygulamadaki bağlantı sonradan değiştirilemez.
- İleride React tanıtım sitesine geçilince de bu adres aynı kalmalı: derleme çıktısı
  `privacy-policy` yolunu sunmalı (ör. `privacy-policy/index.html` ya da
  `privacy-policy.html`), tr ve en metniyle. Geçişten önce ve sonra adresin 200
  döndüğü kontrol edilir. Kaynak o zaman büyük olasılıkla GitHub Actions'a taşınır.

## Ortam (Windows)

- Flutter: `C:\dev\flutter`. Android SDK: `C:\Android\Sdk` (NDK 28.2.13676358 elle
  kuruldu). `PUB_CACHE=C:\dev\pub-cache`, `GRADLE_USER_HOME=C:\dev\gradle`.
- Git Bash'te her komuttan önce:
  `export PATH="/c/dev/flutter/bin:$PATH" PUB_CACHE='C:\dev\pub-cache'`.
- Kullanıcı klasörünün adında Türkçe karakter var; bu yüzden
  yollar ASCII ve boşluksuz tutulur. Gradle, JDK ve Android CLI derlemelerinden önce
  `TEMP`/`TMP` `C:\dev\tmp` yapılır, yoksa "Unable to establish loopback connection"
  hatası çıkar.
- Emülatör: **Pixel 7, API 37**, Google Play'li x86_64 imaj, adb'de `emulator-5554`.

## Ağ (yavaş ve kesintili)

- Bağlantı yavaş ve **DNS zaman zaman kopuyor** (`getaddrinfo failed`, "Could not
  resolve dl.google.com"). Wi-Fi'nin DNS'i 8.8.8.8 / 1.1.1.1.
- Ağ hatasıyla biten indirme ve derlemeler **yeniden denenir**: önce DNS'in döndüğünü
  kontrol et, sonra tekrar çalıştır; uzun işleri arka planda birkaç denemeli çalıştır.
- Büyük dosyalar (Gradle dağıtımı, NDK) tek bağlantıyla çok yavaş iner; parçalı ve
  kaldığı yerden devam eden bir indiriciyle indirilip sağlama toplamı (SHA) doğrulanır.
- Sorun ağdan değilse (ör. derleme hatası) yeniden denemek yerine nedeni bulunur.
