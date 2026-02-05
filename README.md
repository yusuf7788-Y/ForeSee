##Türkçe

# ForeSee AI - Prodüktivite ve Yapay Zeka Platformu

## Geliştirici Bilgileri

- **Geliştirici:** [Yusuf7788-Y](https://github.com/yusuf7788-Y)

---

> [!CAUTION]
> **ÖNEMLİ LİSANS VE İSİMLENDİRME UYARISI:**
> Bu projeyi çatallayacak (fork) veya kullanacak kişiler **"ForeSee"**, **"Ufine"**, **"ForWeb"**, **"ForeWeb"** gibi isimleri ve logoları kullanamazlar. Bu isimler ticari haklara tabidir ve lisans gereği değiştirilmesi zorunludur. Ayrıca uygulamanın kullandığı `.fsa` dosya uzantısını da kendi projenizde kullanmamanız, değiştirmeniz gerekmektedir.

## Proje Hakkında

**ForeSee**, Ufine çatısı altında geliştirilmiş, üretkenliği ve yapay zeka deneyimini tek bir çatı altında toplayan kapsamlı bir platformdur.

**Dikkat: Bu depo (repository) içerisindeki kodlar "Olduğu Gibi" paylaşılmıştır.**

### Bilmeniz Gerekenler

- **Profesyonellik:** Kod yapısı yer yer karmaşık olabilir ve temiz kod (clean code) prensiplerine her zaman sadık kalınmamıştır (Çoğunlukla kalınmamıştır.). Mobil kullanıcılar için kurcalanmadığı sürece stabil çalışmaktadır.
- **AI Tarafından Yazılmış Kod:** Projenin büyük bir kısmı AI Agent'lar (yapay zeka asistanları) yardımıyla geliştirilmiştir. Eğer kodlama konusunda uzman değilseniz, geliştirmelere bir AI asistanı ile devam etmeniz önerilir.
- **Ölü Kodlar:** Proje içerisinde kullanılmayan paketler (packages), ölü kod blokları ve dosya kalıntıları bulunabilir.
- **Proje Boyutu:** Proje dosyaları ve varlıkları (assets) ile birlikte yaklaşık **1.7GB** civarındadır.
- **Uygulama Boyutu:** Yaklaşık **100MB** civarındadır. (Verisiz APK dosyası örnek alınmıştır.)
- **İşlevsellik:** Repo içerisindeki AI özellikleri, geçerli bir API anahtarı girilmediği sürece çalışmamaktadır. Mevcut APK dosyasındaki AI özellikleri de aktif değildir.
- **Dil** Uygulama tamamen Türkçe olarak tasarlanmıştır.

## Kurulum ve Çalıştırma

### 1. Gereksinimler

- Flutter SDK (En güncel sürüm önerilir)
- Dart SDK
- Android Studio / VS Code

### 2. Ortak Değişkenler (.env)

Proje kök dizininde bir `.env` dosyası gerektirir. Örnek yapı için `.env.example` dosyasını inceleyin.

```bash
cp .env.example .env
```

Ardından içindeki API anahtarlarını (OpenRouter, ElevenLabs vb.) kendi anahtarlarınızla doldurun.

### 3. Uygulamayı Başlatma

```bash
flutter clean
flutter pub get
flutter run
```

Veya

```bash
flutter clean; flutter pub get; flutter run
```

## Ekran Görüntüleri

### 🌙 Dark Mode
<p align="center">
  <img src="github-assets/darkchat.png" width="300" alt="Chat"/>
  <img src="github-assets/darksidebar.png" width="300" alt="Sidebar"/>
  <img src="github-assets/darksearch.png" width="300" alt="Search"/>
  <img src="github-assets/darktrash.png" width="300" alt="Trash"/>
  <img src="github-assets/darksettingsup.png" width="300" alt="Settings Up"/>
  <img src="github-assets/darksettingsdown.png" width="300" alt="Settings Down"/>
</p>

### ☀️ Light Mode
<p align="center">
  <img src="github-assets/lightchat.png" width="300" alt="Chat"/>
  <img src="github-assets/lightsidebar.png" width="300" alt="Sidebar"/>
  <img src="github-assets/lightsearch.png" width="300" alt="Search"/>
  <img src="github-assets/lighttrash.png" width="300" alt="Trash"/>
  <img src="github-assets/lightsettingsup.png" width="300" alt="Settings Up"/>
  <img src="github-assets/lightsettingsdown.png" width="300" alt="Settings Down"/>
</p>

## Güvenlik

Bu proje üzerinden paylaşılan kodlarda hiçbir hassas API anahtarı yer almamaktadır. Tüm anahtarlar `.env` üzerinden yönetilmektedir.

## Lisans

Bu proje **MIT Lisansı** ile korunmaktadır. Ancak isim ve logo hakları saklıdır (Bkz: Lisans ve İsimlendirme Uyarısı).

---
*Geliştirici Notu: Clean code odaklı değil, işlev odaklı bir denemedir.*

##English
# ForeSee AI – Productivity & Artificial Intelligence Platform

## Developer Information

- **Developer:** [Yusuf7788-Y](https://github.com/yusuf7788-Y)

---

> [!CAUTION]
> **IMPORTANT LICENSE & NAMING NOTICE:**  
> Anyone who forks or uses this project **may NOT use** the names **"ForeSee"**, **"Ufine"**, **"ForWeb"**, **"ForeWeb"**, or any related logos.  
> These names are protected by commercial rights and **must be changed** according to the license terms.  
> Additionally, the custom file extension `.fsa` used by this application **must not be reused** in derivative projects and must be renamed.

## About the Project

**ForeSee** is a comprehensive platform developed under the **Ufine** brand, designed to bring productivity tools and artificial intelligence experiences together under a single, unified interface.

**Notice: The source code in this repository is shared “AS IS”.**

## Important Notes

- **Professionalism:**  
  The code structure may be inconsistent in places, and clean code principles are **not always followed** (in fact, mostly not).  
  However, for mobile users, the application works stably as long as it is not heavily modified.

- **AI-Generated Code:**  
  A large portion of this project was developed with the assistance of AI agents.  
  If you are not experienced in software development, it is recommended to continue development with the help of an AI assistant.

- **Dead Code:**  
  The project may contain unused packages, dead code blocks, and leftover files.

- **Project Size:**  
  The total repository size, including assets, is approximately **1.7GB**.

- **Application Size:**  
  The application size is approximately **100MB** (based on an APK without embedded data).

- **Functionality:**  
  AI-related features in this repository will **not work** unless valid API keys are provided.  
  AI features in the prebuilt APK are also **disabled**.

- **Language:**  
  The application is fully designed in **Turkish**.

## Installation & Running the Project

### 1. Requirements

- Flutter SDK (latest version recommended)
- Dart SDK
- Android Studio / VS Code

### 2. Environment Variables (.env)

A `.env` file is required in the project root directory.  
Refer to `.env.example` for the sample structure.

```bash
cp .env.example .env
```

Then fill in your own API keys (OpenRouter, ElevenLabs, etc.).

3. Running the Application
bash
Kodu kopyala
flutter clean
flutter pub get
flutter run
Or:

bash
Kodu kopyala
flutter clean; flutter pub get; flutter run
Screenshots

🌙 Dark Mode
<p align="center"> <img src="github-assets/darkchat.png" width="300" alt="Chat"/> <img src="github-assets/darksidebar.png" width="300" alt="Sidebar"/> <img src="github-assets/darksearch.png" width="300" alt="Search"/> <img src="github-assets/darktrash.png" width="300" alt="Trash"/> <img src="github-assets/darksettingsup.png" width="300" alt="Settings Up"/> <img src="github-assets/darksettingsdown.png" width="300" alt="Settings Down"/> </p>
☀️ Light Mode
<p align="center"> <img src="github-assets/lightchat.png" width="300" alt="Chat"/> <img src="github-assets/lightsidebar.png" width="300" alt="Sidebar"/> <img src="github-assets/lightsearch.png" width="300" alt="Search"/> <img src="github-assets/lighttrash.png" width="300" alt="Trash"/> <img src="github-assets/lightsettingsup.png" width="300" alt="Settings Up"/> <img src="github-assets/lightsettingsdown.png" width="300" alt="Settings Down"/> </p>

Security

No sensitive API keys are included in this repository.
All keys are managed via the .env file.

License
This project is licensed under the MIT License.
However, name and logo rights are reserved (see License & Naming Notice).

Developer Note: This is a functionality-focused experiment, not a clean-code-oriented project.
