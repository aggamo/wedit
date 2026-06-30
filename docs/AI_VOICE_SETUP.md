# دليل إعداد نظام الكول سنتر الذكي (AI Voice IVR)

## نظرة عامة
عند اكتمال الإعداد، سيتمكن الراكب من الاتصال برقم هاتف وطلب رحلة باللغة الأمهرية بالكامل بدون تدخل بشري.

---

## 1. Africa's Talking — خدمة الصوت

### أ. التفعيل
1. سجّل دخول على [africastalking.com](https://africastalking.com)
2. من Dashboard → **Voice** → **Phone Numbers** → اشترِ رقماً إثيوبياً أو دولياً
3. من إعدادات الرقم، عيّن **Callback URL**:
   ```
   https://<SUPABASE_PROJECT_REF>.supabase.co/functions/v1/handle-voice-session?step=incoming
   ```
4. أضف رصيداً كافياً لاختبار المكالمات (10 دولار للبدء)

### ب. اختبار الاتصال
اتصل بالرقم المشتراة وتحقق من وصول الطلب إلى `handle-voice-session`.

---

## 2. Google Cloud — خدمات الذكاء الاصطناعي

### أ. إنشاء مشروع
1. اذهب إلى [console.cloud.google.com](https://console.cloud.google.com)
2. أنشئ مشروعاً جديداً باسم `wedit-ai`

### ب. تفعيل واجهات برمجية (APIs)
فعّل جميع ما يلي من **APIs & Services → Library**:
- Cloud Speech-to-Text API
- Cloud Text-to-Speech API
- Geocoding API
- Dialogflow API

### ج. إنشاء Service Account
1. **IAM & Admin → Service Accounts → Create Service Account**
2. الاسم: `wedit-ai-service`
3. الأدوار: `Dialogflow API Client`, `Cloud Speech Client`, `Cloud Text-to-Speech Client`
4. اضغط **Create Key** → نوع JSON → احفظ الملف
5. حوّله إلى base64:
   ```bash
   base64 -i wedit-ai-service-account.json | tr -d '\n'
   ```
6. احفظ الناتج — ستحتاجه في Supabase Secrets

### د. Google Maps API Key للـ Geocoding
من **APIs & Services → Credentials → Create Credentials → API Key**:
- قيّد المفتاح لخدمة **Geocoding API** فقط
- احفظ المفتاح

---

## 3. Dialogflow ES — وكيل الأمهرية

### أ. إنشاء الوكيل
1. اذهب إلى [dialogflow.cloud.google.com](https://dialogflow.cloud.google.com)
2. اختر المشروع `wedit-ai`
3. **Create Agent** → اللغة: **am (Amharic)**
4. الاسم: `wedit-voice-agent`

### ب. إنشاء Intent: طلب رحلة
1. **Intents → Create Intent** → الاسم: `request_ride`
2. أضف **Training Phrases** (جمل تدريبية):
   ```
   ከቦሌ እስከ ፒያሳ
   ሴዳን ከሜክሲኮ ስኩዌር
   ሚኒቡስ ፈልጋለሁ ወደ ጉርድ ሾሌ
   ቦሌ ሮድ ወደ ቂርቆስ
   SUV ከቦሌ ቡልቡሎ
   ከ4 ኪሎ እስከ ሜርካቶ
   ```
3. أضف **Parameters**:

| Parameter Name | Entity Type | Required |
|----------------|-------------|----------|
| pickup_location | @sys.any | ✓ |
| destination | @sys.any | |
| vehicle_type | @vehicle-type (أنشئها) | |

4. أنشئ Entity **@vehicle-type**:
   - `sedan`: ሴዳን, sedan, ታክሲ
   - `minibus`: ሚኒቡስ, minibus
   - `suv`: SUV, ትልቅ መኪና
   - `vip`: VIP

5. فعّل **Fulfillment → Enable webhook for this intent**

### ج. ربط Webhook
من **Fulfillment → Webhook**:
```
URL: https://<SUPABASE_REF>.supabase.co/functions/v1/handle-voice-session?step=recording
Headers:
  X-Wedit-Secret: <AI_CALL_WEBHOOK_SECRET>
```

---

## 4. Supabase — الإعداد النهائي

### أ. Secrets جديدة
أضف في **Supabase Dashboard → Settings → Edge Functions → Secrets**:

```
AI_CALL_WEBHOOK_SECRET   = <اختر نصاً عشوائياً طويلاً مثل UUID>
GOOGLE_API_KEY           = <مفتاح Geocoding من الخطوة 2.د>
DIALOGFLOW_PROJECT_ID    = wedit-ai
DIALOGFLOW_CREDENTIALS_JSON = <base64 من الخطوة 2.ج>
```

### ب. Storage Bucket
1. **Supabase Dashboard → Storage → New Bucket**
2. الاسم: `ai-voice`
3. النوع: **Public**
4. ارفع ملفات الصوت:

| اسم الملف | المحتوى المطلوب |
|-----------|----------------|
| `greeting.mp3` | "እንኳን ደህና መጣህ ወደ ዊዲት፣ እባክህ ጉዞህን ተናገር ። ማሳወቅህን ስትጨርስ # ተጫን" |
| `retry.mp3` | "ይቅርታ፣ ቦታህን ግልጽ አልሆነም። እባክህ እንደገና ተናገር" |
| `location_unclear.mp3` | "ቦታህ ያልታወቀ ነው። እባክህ የአካባቢ ስምን ዝርዝር ተናገር" |
| `no_driver.mp3` | "ይቅርታ፣ አሁን ሹፌር አይገኝም። ከደቂቃ ቆይተህ ሞክር" |
| `driver_found.mp3` | "ሹፌር ተገኝቷል። ሲደርስ ይደውልልዎታል" |
| `error.mp3` | "ይቅርታ፣ ስህተት ተፈጥሯል። ቆይተህ ሞክር" |

> **نصيحة:** استخدم [Google TTS](https://cloud.google.com/text-to-speech) مع صوت `am-ET` لتوليد هذه الملفات مسبقاً.

### ج. نشر Edge Functions الجديدة
```bash
supabase functions deploy handle-voice-session
supabase functions deploy create-ai-ride
```

### د. تطبيق Migration
```bash
supabase db push
# أو من Supabase Dashboard → SQL Editor → تشغيل محتوى 015_ai_call_center.sql
```

---

## 5. اختبار الميزة

### اختبار أساسي بدون مكالمة حقيقية
```bash
# اختبار create-ai-ride مباشرة
curl -X POST \
  https://<SUPABASE_REF>.supabase.co/functions/v1/create-ai-ride \
  -H "Content-Type: application/json" \
  -H "X-Wedit-Secret: <AI_CALL_WEBHOOK_SECRET>" \
  -d '{
    "passenger_phone": "+251912345678",
    "pickup_lat": 9.0246,
    "pickup_lng": 38.7468,
    "pickup_text": "ቦሌ ሮድ",
    "vehicle_type": "sedan",
    "confidence_score": 0.90
  }'
```

### اختبار المكالمة الكاملة
1. تأكد من وجود سائق متصل (online) في قاعدة البيانات
2. اتصل بالرقم المشترى من AT
3. انتظر رسالة الترحيب
4. قل باللغة الأمهرية: "ከቦሌ እስከ ፒያሳ"
5. اضغط `#` لإنهاء التسجيل
6. يجب أن تسمع تأكيداً صوتياً
7. تحقق من:
   - وجود سجل في `ai_call_logs` بـ `status='dispatched'`
   - وجود رحلة جديدة في `rides` بـ `ride_type='ai_call'`
   - وصول إشعار FCM للسائق
   - ظهور المكالمة في `/dashboard/ai-call-logs`

---

## 6. معايير القبول

| # | المعيار | كيف نتحقق |
|---|---------|-----------|
| 1 | المكالمة تصل وتُشغّل رسالة الترحيب | نسمع الصوت |
| 2 | الأمهرية تُفهم بدقة ≥ 70% | نرى confidence_score ≥ 0.70 في ai_call_logs |
| 3 | الموقع يُحوَّل إلى إحداثيات | نرى pickup_lat/lng في السجل |
| 4 | رحلة تُنشأ بنوع ai_call | استعلام `SELECT * FROM rides WHERE ride_type='ai_call'` |
| 5 | السائق يستلم إشعاراً | يظهر dialog "المساعد الصوتي" في تطبيق السائق |
| 6 | تأكيد صوتي بالأمهرية | نسمع اسم السائق ووقت الوصول |
| 7 | لوحة المراقبة تعرض السجل | فتح `/dashboard/ai-call-logs` |
| 8 | زر "إعادة الإرسال" يعمل | نضغطه ونرى CallCenterPage معبّأاً مسبقاً |

---

## 7. تكاليف تقديرية لكل مكالمة

| الخدمة | التكلفة |
|--------|---------|
| Africa's Talking Voice (دقيقتان) | ~$0.03 |
| Google STT (30 ثانية) | ~$0.006 |
| Google TTS (التأكيد) | ~$0.004 |
| Google Geocoding (طلب واحد) | ~$0.005 |
| Dialogflow (طلب واحد) | ~$0.002 |
| **الإجمالي** | **~$0.047 / مكالمة** |
