# Firebase Cloud Functions Deployment Guide

## 1. İlk Kurulum

### Firebase CLI Yükle (Sadece bir kez)

```bash
npm install -g firebase-tools
```

### Firebase Login

```bash
firebase login
```

### Firebase Projesini Seç

```bash
firebase use --add
# Listeden projenizi seçin
```

## 2. API Anahtarını Firebase'e Kaydet

**ÖNEMLİ:** API anahtarı artık kodda olmayacak, Firebase'de saklanacak.

```bash
firebase functions:config:set openrouter.key="OPENROUTER_API_KEY_BURAYA_YAPIŞTIR"
```

## 3. Dependencies Yükle

```bash
cd functions
npm install
```

## 4. Deploy Et

```bash
firebase deploy --only functions
```

Deploy tamamlandıktan sonra konsola şu çıktı gelecek:

```
✔  functions[proxyOpenRouter(us-central1)] Successful create operation.
Function URL: https://us-central1-PROJE_ID.cloudfunctions.net/proxyOpenRouter
```

## 5. Test Et

Firebase Console'dan test et:

1. Firebase Console → Functions → `proxyOpenRouter`
2. "Test the function" butonuna tıkla
3. Şu JSON'u gönder:

```json
{
  "messages": [{"role": "user", "content": "Merhaba"}],
  "model": "google/gemini-2.0-flash-exp:free",
  "maxTokens": 100
}
```

## 6. Uygulama Güncellemesi

Dart kodundaki değişiklikler zaten yapıldı. Artık `.env` dosyasındaki API key'i sil veya yorum satırına al:

```env
# OPENROUTER_API_KEY_1=xxx  # Artık kullanılmıyor, Firebase'de
```

## Maliyet

- **Bedava Kota:** Aylık 2M istek, 5GB transfer
- **Aşımda:** $0.40 / 1M istek
- **Tahmin:** 1000 kullanıcı bile olsa aylık ~$5-10

## Sorun Giderme

### Hata: "OpenRouter API key not configured"

```bash
firebase functions:config:get
# openrouter.key görünmüyorsa tekrar set et
```

### Logları İzle

```bash
firebase functions:log --only proxyOpenRouter
```
