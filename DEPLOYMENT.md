# دليل نشر منصة Wedit

> آخر تحديث: 2026-05-31  
> يغطي: driver_app · passenger_app · admin_app · Supabase · Edge Functions · SMS · AWS Backup

---

## جدول المحتويات

1. [المتطلبات الأساسية](#1-المتطلبات-الأساسية)
2. [Supabase — قاعدة البيانات والـ Backend](#2-supabase)
3. [Firebase — الإشعارات والتحليلات](#3-firebase)
4. [Google Maps API](#4-google-maps-api)
5. [SMS — Africa's Talking](#5-sms--africas-talking)
6. [AWS S3 — النسخ الاحتياطي](#6-aws-s3--النسخ-الاحتياطي)
7. [بناء التطبيقات (Build)](#7-بناء-التطبيقات)
8. [نشر Admin App على Vercel](#8-نشر-admin-app-على-vercel)
9. [Google Play Store](#9-google-play-store)
10. [Apple App Store](#10-apple-app-store)
11. [متغيرات البيئة الكاملة](#11-متغيرات-البيئة-الكاملة)
12. [قائمة التحقق قبل الإطلاق](#12-قائمة-التحقق-قبل-الإطلاق)

---

## 1. المتطلبات الأساسية

### على جهازك المحلي
```bash
flutter --version      # يجب أن يكون 3.x أو أحدث
dart --version
supabase --version     # Supabase CLI: npm install -g supabase
flutterfire --version  # FlutterFire CLI: dart pub global activate flutterfire_cli
node --version         # Node 18+ لبعض الأدوات
```

### حسابات مطلوبة
| الخدمة | الرسوم | الرابط |
|--------|--------|--------|
| Supabase | مجاني (Starter) | https://supabase.com |
| Firebase | مجاني (Spark) | https://firebase.google.com |
| Google Cloud (Maps) | مجاني $200/شهر كرصيد | https://console.cloud.google.com |
| Africa's Talking (SMS) | ادفع عند الاستخدام | https://africastalking.com |
| AWS (S3 Backup) | ~$0.023/GB/شهر | https://aws.amazon.com |
| Google Play Developer | $25 مرة واحدة | https://play.google.com/console |
| Apple Developer | $99/سنة | https://developer.apple.com |
| Vercel (Admin Web) | مجاني | https://vercel.com |

---

## 2. Supabase

### أ. إنشاء مشروع جديد (إن لم يكن موجوداً)
1. اذهب إلى https://supabase.com/dashboard → New Project
2. اختر اسماً (مثل `wedit-production`) ومنطقة قريبة من إثيوبيا (Frankfurt أو Bahrain)
3. احفظ كلمة سر قاعدة البيانات في مكان آمن

### ب. تطبيق الـ Migrations

**⚠️ مهم: الملف 012 يُعدّل `profiles.role` constraint. إن كانت لديك بيانات موجودة، تحقق من قيم الـ role قبل التطبيق.**

```bash
cd /path/to/wedit

# سجّل الدخول
supabase login

# اربط المشروع
supabase link --project-ref YOUR_PROJECT_REF
# تجد الـ project-ref في: Settings → General → Reference ID

# طبّق جميع الـ migrations بالترتيب
supabase db push

# أو طبّق ملفاً محدداً
psql "$SUPABASE_DB_URL" -f supabase/migrations/001_profiles.sql
# ... كرر لـ 002 → 012
```

ترتيب التطبيق:
```
001_profiles.sql
002_drivers_vehicles.sql
003_rides_offers.sql
004_subscriptions_payments.sql
005_locations_notifications.sql
006_referrals_points.sql
007_competition_leaderboard.sql
008_rls_complete.sql
009_cron_jobs.sql
010_surge_pricing.sql
011_street_hail.sql
012_fleet_owner.sql          ← يشمل legal_documents + fleet tables
```

### ج. نشر Edge Functions

```bash
# نشر جميع الدوال
supabase functions deploy send-notification
supabase functions deploy send-sms
supabase functions deploy chapa-webhook
supabase functions deploy telebirr-webhook
supabase functions deploy auto-renew-subscription
supabase functions deploy close-competition-period
supabase functions deploy run-raffle
supabase functions deploy invite-fleet-driver

# تعيين المتغيرات البيئية
supabase secrets set SMS_PROVIDER=africastalking
supabase secrets set SMS_AT_USERNAME=YOUR_AT_USERNAME
supabase secrets set SMS_API_KEY=YOUR_AT_API_KEY
supabase secrets set SMS_SENDER_ID=Wedit
supabase secrets set CHAPA_SECRET_KEY=YOUR_CHAPA_KEY
supabase secrets set TELEBIRR_APP_KEY=YOUR_TELEBIRR_KEY
supabase secrets set TELEBIRR_APP_SECRET=YOUR_TELEBIRR_SECRET
```

### د. تفعيل pg_cron
في Supabase Dashboard → Database → Extensions، فعّل `pg_cron`.
ثم نفّذ الـ cron jobs من ملف `009_cron_jobs.sql` يدوياً في SQL Editor.

### هـ. إعداد Storage Buckets
في Supabase Dashboard → Storage:
- `driver-documents` — Private
- `payment-receipts` — Private
- `avatars` — Public

### و. تحديث مفاتيح التطبيقات
عدّل الملفين:
- `driver_app/lib/core/constants/app_constants.dart`
- `passenger_app/lib/core/constants/app_constants.dart`
- `admin_app/lib/core/constants/app_constants.dart`

```dart
static const String supabaseUrl = 'https://YOUR_PROJECT_REF.supabase.co';
static const String supabaseAnonKey = 'YOUR_ANON_KEY';
```

---

## 3. Firebase

### أ. إنشاء مشروع Firebase
1. https://console.firebase.google.com → Add project → `wedit-production`
2. فعّل Google Analytics داخل المشروع

### ب. إضافة تطبيقات للمشروع
أضف 4 تطبيقات: (passenger Android, passenger iOS, driver Android, driver iOS)

**Package names الموصى بها:**
| التطبيق | Android | iOS Bundle ID |
|---------|---------|---------------|
| Passenger | com.wedit.passenger | com.wedit.passenger |
| Driver | com.wedit.driver | com.wedit.driver |

### ج. تفعيل FlutterFire CLI
```bash
# تثبيت
dart pub global activate flutterfire_cli

# من مجلد driver_app
cd driver_app
flutterfire configure --project=wedit-production

# من مجلد passenger_app
cd ../passenger_app
flutterfire configure --project=wedit-production
```

هذا يولّد `lib/firebase_options.dart` تلقائياً ويضع:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### د. تفعيل خدمات Firebase
في Firebase Console:
- **Authentication** → Phone (لاحقاً إن أردت 2FA)
- **Cloud Messaging** → مفعّل تلقائياً
- **Analytics** → مفعّل تلقائياً
- **Crashlytics** → Add `firebase_crashlytics` للـ pubspec (اختياري)

### هـ. FCM Server Key لـ Edge Function
في Firebase Console → Project Settings → Cloud Messaging:
- انسخ **Server key (legacy)** أو استخدم Service Account JSON لـ FCM v1
```bash
supabase secrets set FCM_SERVER_KEY=YOUR_SERVER_KEY
# أو للـ v1:
supabase secrets set FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

---

## 4. Google Maps API

### أ. إنشاء المشروع والمفاتيح
1. https://console.cloud.google.com → New Project → `wedit-maps`
2. فعّل Billing (بطاقة ائتمانية مطلوبة، لكن $200 رصيد مجاني شهرياً)
3. APIs & Services → Enable:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Directions API
   - Places API
   - Distance Matrix API
   - Geocoding API

4. Credentials → Create Credentials → API Key (أنشئ 3 مفاتيح منفصلة):

**مفتاح Android:**
- Application restrictions: Android apps
- أضف SHA-1 fingerprint (انظر الخطوة التالية)
- API restrictions: Maps SDK for Android, Directions, Places, Distance Matrix

**مفتاح iOS:**
- Application restrictions: iOS apps
- Bundle IDs: `com.wedit.passenger`, `com.wedit.driver`
- API restrictions: Maps SDK for iOS, Directions, Places

**مفتاح Web (للـ admin app):**
- HTTP referrers: `https://your-vercel-domain.vercel.app/*`

### ب. الحصول على SHA-1 للـ Android
```bash
# Debug keystore
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release keystore (بعد إنشائه)
keytool -list -v -keystore wedit-release.keystore -alias wedit
```

### ج. إضافة المفاتيح للتطبيقات

**Android** — في `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ANDROID_MAPS_KEY"/>
```

**iOS** — في `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_IOS_MAPS_KEY")
```

---

## 5. SMS — Africa's Talking

### أ. إنشاء حساب
1. https://africastalking.com → Sign Up
2. اختر Ethiopia كـ market
3. اذهب إلى Sandbox لأغراض الاختبار أولاً

### ب. الحصول على بيانات API
في لوحة تحكم Africa's Talking:
- **Username**: اسم تطبيقك (مثل `wedit`)
- **API Key**: من Settings → API Key

### ج. تفعيل Sender ID
- في Production، قدّم طلب Sender ID باسم `Wedit` (قد يستغرق أياماً)
- في Sandbox، استخدم `sandbox` كـ username واختبر مجاناً

### د. تعيين المتغيرات
```bash
supabase secrets set SMS_PROVIDER=africastalking
supabase secrets set SMS_AT_USERNAME=wedit
supabase secrets set SMS_API_KEY=YOUR_AT_API_KEY
supabase secrets set SMS_SENDER_ID=Wedit
```

### هـ. اختبار الإرسال
```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/send-sms \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"message_type":"ride_start","phone_number":"0912345678","driver_name":"Ahmed","plate_number":"AA-12345"}'
```

---

## 6. AWS S3 — النسخ الاحتياطي

### أ. إنشاء S3 Bucket
1. https://console.aws.amazon.com → S3 → Create bucket
2. Name: `wedit-backup-prod`
3. Region: اختر الأقرب (مثل `eu-central-1`)
4. Block all public access: ✅

**Lifecycle rule** (احتفظ بآخر 30 نسخة):
- Management → Lifecycle rules → Create
- Rule: Expiration after 30 days

### ب. إنشاء IAM User
1. IAM → Users → Create user: `wedit-backup`
2. Attach policy (Custom JSON):
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::wedit-backup-prod",
      "arn:aws:s3:::wedit-backup-prod/*"
    ]
  }]
}
```
3. Security credentials → Create access key → Application access

### ج. إضافة Secrets لـ GitHub
في GitHub → Settings → Secrets and variables → Actions:

| Secret | القيمة |
|--------|--------|
| `AWS_ACCESS_KEY_ID` | من IAM |
| `AWS_SECRET_ACCESS_KEY` | من IAM |
| `AWS_S3_BUCKET` | `wedit-backup-prod` |
| `SUPABASE_DB_URL` | `postgresql://postgres:PASSWORD@db.REF.supabase.co:5432/postgres` |

| Variable | القيمة |
|----------|--------|
| `AWS_REGION` | `eu-central-1` (أو منطقتك) |

### د. تشغيل يدوي للتحقق
GitHub → Actions → Daily Supabase Backup → Run workflow

---

## 7. بناء التطبيقات

### Android Release APK/AAB

**خطوة 1: إنشاء Keystore**
```bash
keytool -genkey -v \
  -keystore keystore/wedit-driver-release.keystore \
  -alias wedit-driver \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Wedit Technologies, O=Wedit, C=ET"

# لـ passenger
keytool -genkey -v \
  -keystore keystore/wedit-passenger-release.keystore \
  -alias wedit-passenger \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Wedit Technologies, O=Wedit, C=ET"
```

**خطوة 2: إنشاء key.properties**
```bash
# driver_app/android/key.properties
echo "storePassword=YOUR_PASS
keyPassword=YOUR_PASS
keyAlias=wedit-driver
storeFile=../../keystore/wedit-driver-release.keystore" > driver_app/android/key.properties

# passenger_app/android/key.properties
echo "storePassword=YOUR_PASS
keyPassword=YOUR_PASS
keyAlias=wedit-passenger
storeFile=../../keystore/wedit-passenger-release.keystore" > passenger_app/android/key.properties
```

**خطوة 3: البناء**
```bash
# Driver app
cd driver_app
flutter build appbundle --release   # للـ Play Store
flutter build apk --release         # للتوزيع المباشر

# Passenger app
cd ../passenger_app
flutter build appbundle --release
flutter build apk --release
```

الملفات الناتجة:
- `driver_app/build/app/outputs/bundle/release/app-release.aab`
- `passenger_app/build/app/outputs/bundle/release/app-release.aab`

### iOS IPA

**المتطلبات:**
- جهاز macOS مع Xcode 15+
- حساب Apple Developer مفعّل
- Provisioning Profile لكل تطبيق

```bash
cd driver_app
flutter build ios --release

# افتح Xcode
open ios/Runner.xcworkspace
# Product → Archive → Distribute App → App Store Connect
```

---

## 8. نشر Admin App على Vercel

### أ. ربط المشروع
```bash
cd admin_app

# تثبيت Vercel CLI
npm install -g vercel

# تسجيل الدخول ونشر
vercel login
vercel --prod
```

### ب. من لوحة تحكم Vercel
1. New Project → Import from GitHub → `aggamo/wedit`
2. Root directory: `admin_app`
3. Build command: `flutter build web --release --base-href=/`
4. Output directory: `build/web`
5. Environment variables: أضف SUPABASE_URL إن احتجته

### ج. Custom Domain (لاحقاً)
1. Settings → Domains → Add domain: `admin.wedit.et`
2. أضف CNAME record لـ DNS الخاص بالدومين

---

## 9. Google Play Store

### أ. إنشاء حساب مطور
1. https://play.google.com/console/signup
2. رسوم تسجيل: **$25** (مرة واحدة)
3. قدم بيانات Developer profile كاملة

### ب. إنشاء التطبيقات
لكل تطبيق (passenger + driver):
1. All apps → Create app
2. App name: "Wedit Passenger" / "Wedit Driver"
3. Category: Maps & Navigation
4. قبول سياسات Play

### ج. إعداد قائمة المتجر
- Short description (80 حرف): `تنقل ذكي في أديس أبابا — اطلب رحلتك بلمسة`
- Full description (4000 حرف): اطلبها من صاحب المشروع
- Screenshots: 8 screenshots على الأقل (2-5 أجهزة مختلفة)
- Feature graphic: 1024×500 px
- Icon: 512×512 px (احتياجك من الشعار)

### د. رفع الـ AAB
1. Release → Production → Create release
2. ارفع ملف `.aab`
3. أضف release notes بالعربية والإنجليزية
4. Start rollout → Review → تنتظر مراجعة Google (1-7 أيام)

**نصيحة:** ابدأ بـ Internal testing أو Closed testing لاختبار سريع.

---

## 10. Apple App Store

### أ. إنشاء حساب Apple Developer
1. https://developer.apple.com/programs/enroll/
2. رسوم: **$99/سنة**
3. تحتاج: Apple ID، بيانات شخصية أو شركة، بطاقة ائتمانية

### ب. إعداد في Xcode
1. Signing & Capabilities → Automatically manage signing ✅
2. Bundle Identifier: `com.wedit.driver` / `com.wedit.passenger`
3. Team: اختر حساب Developer

### ج. Certificates & Profiles
Xcode يدير هذا تلقائياً مع "Automatically manage signing". إن احتجت يدوياً:
1. https://developer.apple.com/account → Certificates
2. اصنع iOS Distribution Certificate
3. اصنع App Store Provisioning Profile لكل تطبيق

### د. رفع على App Store Connect
```bash
# من Terminal على Mac
cd driver_app
flutter build ipa --release

# استخدم Transporter لرفع الـ IPA
# أو من Xcode: Product → Archive → Distribute
```

1. https://appstoreconnect.apple.com → My Apps → New App
2. أضف معلومات التطبيق (الاسم، الوصف، Keywords)
3. Screenshots: للـ 6.5" و 5.5" iPhones على الأقل
4. Submit for Review

---

## 11. متغيرات البيئة الكاملة

### Flutter Apps (app_constants.dart)
| المتغير | الملف | القيمة |
|---------|-------|--------|
| `supabaseUrl` | جميع التطبيقات | `https://REF.supabase.co` |
| `supabaseAnonKey` | جميع التطبيقات | من Supabase → Settings → API |
| `googleMapsApiKey` | driver/passenger | مفتاح Android |

### Supabase Edge Functions (supabase secrets set)
| المتغير | الوصف |
|---------|-------|
| `SUPABASE_SERVICE_ROLE_KEY` | من Supabase → Settings → API |
| `FCM_SERVICE_ACCOUNT_JSON` | Firebase Service Account JSON |
| `SMS_PROVIDER` | `africastalking` |
| `SMS_AT_USERNAME` | اسم مستخدم Africa's Talking |
| `SMS_API_KEY` | API Key من Africa's Talking |
| `SMS_SENDER_ID` | `Wedit` |
| `CHAPA_SECRET_KEY` | من Chapa Dashboard |
| `CHAPA_WEBHOOK_SECRET` | سر التحقق من Webhook |
| `TELEBIRR_APP_KEY` | من Telebirr Portal |
| `TELEBIRR_APP_SECRET` | من Telebirr Portal |
| `TELEBIRR_SHORT_CODE` | رقم التاجر |

### GitHub Actions Secrets
| Secret | الوصف |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM User Access Key |
| `AWS_SECRET_ACCESS_KEY` | IAM User Secret |
| `AWS_S3_BUCKET` | اسم الـ bucket |
| `SUPABASE_DB_URL` | Connection string لـ PostgreSQL |

### GitHub Actions Variables (ليست secrets)
| Variable | القيمة |
|----------|--------|
| `AWS_REGION` | `eu-central-1` |

---

## 12. قائمة التحقق قبل الإطلاق

### قاعدة البيانات
- [ ] جميع الـ 12 migration مطبّقة بدون أخطاء
- [ ] RLS policies مفعّلة على جميع الجداول
- [ ] Storage buckets منشأة بـ policies صحيحة
- [ ] pg_cron jobs مفعّلة (daily trips reset, subscription renewal)
- [ ] بيانات أولية: خطط الاشتراكات، إعدادات المسابقة

### Edge Functions
- [ ] جميع الدوال منشورة
- [ ] جميع الـ secrets معيّنة
- [ ] send-sms مختبر بـ sandbox
- [ ] send-notification مختبر بـ FCM token حقيقي

### Firebase
- [ ] google-services.json موجود في driver_app و passenger_app
- [ ] GoogleService-Info.plist موجود في كلا التطبيقين
- [ ] FCM token يُحفظ في قاعدة البيانات عند تسجيل الدخول
- [ ] إشعار اختباري يصل بنجاح

### خرائط Google
- [ ] Maps API مفعّل لـ Android و iOS
- [ ] مفاتيح API مقيّدة بالتطبيقات المناسبة
- [ ] الخريطة تظهر في Addis Ababa صحيحاً

### SMS
- [ ] رسالة اختبار وصلت لرقم إثيوبي حقيقي
- [ ] Sender ID `Wedit` مفعّل (Production)

### البناء
- [ ] APK Release يبنى بدون أخطاء
- [ ] AAB Release يبنى بدون أخطاء
- [ ] IPA Release يبنى بدون أخطاء
- [ ] Admin web يبنى بدون أخطاء

### النشر
- [ ] Admin app يعمل على Vercel
- [ ] النسخ الاحتياطي اليومي يعمل (GitHub Actions)

### قبل الرفع على المتاجر
- [ ] سياسة الخصوصية متاحة على رابط عام
- [ ] شروط الاستخدام متاحة على رابط عام
- [ ] الشعار والأيقونات بالأبعاد المطلوبة
- [ ] Screenshots جاهزة لكل متجر
- [ ] اختبار تدفق كامل: طلب رحلة → قبول → إتمام → تقييم

---

## جداول Supabase الهامة

| الجدول | الوصف |
|--------|-------|
| `profiles` | بيانات جميع المستخدمين (دور، رقم، اسم) |
| `drivers` | السائقون (بيانات تقني + fleet fields) |
| `fleet_owners` | مالكو الأساطيل |
| `fleet_vehicles` | مركبات الأسطول |
| `fleet_driver_invitations` | دعوات السائقين |
| `rides` | جميع الرحلات |
| `ride_offers` | عروض السائقين لكل رحلة |
| `driver_locations` | تتبع الوقت الحقيقي |
| `driver_subscriptions` | اشتراكات السائقين |
| `fleet_owner_settlements` | تسويات مالكي الأساطيل |
| `legal_documents` | وثائق الشروط والأحكام |
| `legal_document_acceptances` | سجل قبول الشروط |
| `competition_settings` | إعدادات المسابقات |
| `competition_rankings` | ترتيب السائقين |
| `sms_logs` | سجل رسائل SMS |
| `notifications` | سجل الإشعارات |

---

## دعم ما بعد الإطلاق

في حال ظهور أخطاء بعد النشر:
1. تحقق من **Supabase Logs** → Edge Function Logs
2. تحقق من **Firebase Crashlytics** (بعد إضافته)
3. تحقق من **Vercel Logs** للـ admin app
4. افتح Issue في GitHub مع وصف المشكلة وخطوات التكرار
