# Kibrit Ülkesi

Matematik defterine ülke çizip kibrit kutusu atarak oynadığımız oyunun Flutter sürümü.

## Kurallar

- Kibrit kutusunu at: **yatık 1**, **yan 3**, **dik 6** kare.
- Boş karelere dokun → ülkene ekle (sınırına bitişik olmalı).
- Rakibin sınırındaki karelere dokun → kes. Kestikçe içeri doğru ilerleyebilirsin.
- Başkente (★) bağlantısı kopan parçalar silinir.
- Başkent ancak tur başında sınırdaysa kesilebilir; kesilirse o ülke oyundan çıkar.
- Son kalan ya da 30. turda en büyük ülke kazanır.

## Şu anki sürüm

- Sen + 1–3 bot (kolay / orta / zor)
- Parmağı sürükleyerek kare seçme

## Sıradakiler

- İnternet üzerinden oda koduyla çok oyunculu (Android + iPhone + web)
- Aynı Wi‑Fi / Bluetooth ile internetsiz oyun
- Başlangıçta ülkeyi kendin çizme

## Derleme

Her `main` güncellemesinde GitHub Actions:

- testleri çalıştırır,
- web sürümünü GitHub Pages'e yükler,
- Android APK'sını **Releases** bölümüne koyar.

`android/`, `ios/`, `web/` klasörleri derleme sırasında `flutter create` ile oluşturulur.

## Dosyalar

| Dosya | İçerik |
| --- | --- |
| `lib/game/rules.dart` | Defter, ekleme/kesme, başkent, kopan topraklar |
| `lib/game/bot.dart` | Bot zekâsı |
| `lib/game/controller.dart` | Sıra, kibrit atışı, oyun akışı |
| `lib/ui/` | Menü, oyun ekranı, kibrit kutusu animasyonu, defter çizimi |
