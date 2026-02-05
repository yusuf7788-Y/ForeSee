# Cloudflare Workers Deployment Guide

## 1. Cloudflare Hesabı Oluştur

1. [Cloudflare Dashboard](https://dash.cloudflare.com/sign-up) → Ücretsiz hesap aç
2. Email doğrula

## 2. Wrangler CLI Kur

```bash
npm install -g wrangler
```

## 3. Cloudflare'e Login

```bash
wrangler login
```

Tarayıcı açılacak, "Allow" butonuna tıkla.

## 4. Worker'ı Deploy Et

```bash
cd cloudflare-worker
wrangler deploy
```

Deploy tamamlandıktan sonra şu çıktıyı alacaksın:

```
✨ Published foresee-openrouter-proxy
   https://foresee-openrouter-proxy.YOUR_USERNAME.workers.dev
```

**Bu URL'i kopyala!** Dart kodunda kullanacağız.

## 5. API Key'i Ekle

### Yöntem 1: Dashboard'dan (Önerilen)

1. [Cloudflare Dashboard](https://dash.cloudflare.com/) → Workers & Pages
2. `foresee-openrouter-proxy` worker'ına tıkla
3. **Settings** → **Variables**
4. **Add variable**:
   - Name: `OPENROUTER_API_KEY`
   - Value: `sk-or-v1-...` (OpenRouter API key'in)
   - Type: **Encrypted** (şifreli olsun)
5. **Save**

### Yöntem 2: CLI'dan

```bash
wrangler secret put OPENROUTER_API_KEY
# Prompt gelince API key'i yapıştır
```

## 6. Test Et

```bash
curl -X POST https://foresee-openrouter-proxy.YOUR_USERNAME.workers.dev \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemini-2.0-flash-exp:free",
    "messages": [{"role": "user", "content": "Merhaba"}],
    "stream": true
  }'
```

Eğer streaming cevap geliyorsa ✅ başarılı!

## 7. Dart Kodunu Güncelle

`lib/services/openrouter_service.dart` dosyasında:

```dart
// Eski
static const String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

// Yeni
static const String apiUrl = 'https://foresee-openrouter-proxy.YOUR_USERNAME.workers.dev';
```

**Authorization header'ı kaldır** (artık gerek yok, worker'da):

```dart
// Eski
headers: {
  'Authorization': 'Bearer ${dotenv.env['OPENROUTER_API_KEY']}',
  ...
}

// Yeni (Authorization yok!)
headers: {
  'Content-Type': 'application/json',
  'HTTP-Referer': 'https://foresee.app',
}
```

## 8. .env Dosyasını Temizle

```env
# OPENROUTER_API_KEY_1=xxx  # Artık kullanılmıyor
# OPENROUTER_API_KEY_2=xxx  # Artık kullanılmıyor
```

## Maliyet

- **Bedava Kota:** Günde 100,000 istek
- **Aşımda:** $0.50 / 1M istek
- **Bandwidth:** Sınırsız (!)

## Avantajlar

✅ API key APK'dan tamamen çıktı  
✅ Streaming çalışıyor  
✅ Firebase'den daha hızlı (edge computing)  
✅ Bedava kota çok yüksek  

## Sorun Giderme

### Hata: "API key not found"

```bash
wrangler secret list
# OPENROUTER_API_KEY görünmüyorsa tekrar ekle
```

### Logları İzle

```bash
wrangler tail
```

### Worker'ı Güncelle

```bash
wrangler deploy
```
