#!/usr/bin/env bash
# =============================================================
# setup.sh — Wedit project setup script
# Sets up Flutter apps and prints Supabase configuration guide
# =============================================================
set -euo pipefail

# Terminal colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()    { echo -e "\n${BOLD}${CYAN}==> $*${RESET}"; }

# =============================================================
# Step 1: Check Flutter is installed
# =============================================================
log_step "Checking Flutter installation"

if ! command -v flutter &>/dev/null; then
  log_error "Flutter is not installed or not in PATH."
  log_error "Install Flutter from: https://docs.flutter.dev/get-started/install"
  exit 1
fi

FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -1)
log_success "Flutter found: ${FLUTTER_VERSION}"

# Check minimum Flutter version (3.x required for modern null safety)
FLUTTER_MAJOR=$(flutter --version 2>/dev/null | grep -oP 'Flutter \K[0-9]+' | head -1)
if [ -n "${FLUTTER_MAJOR}" ] && [ "${FLUTTER_MAJOR}" -lt 3 ]; then
  log_warn "Flutter ${FLUTTER_MAJOR}.x detected. Flutter 3.x or later is recommended."
fi

# Check Dart
if ! command -v dart &>/dev/null; then
  log_warn "Dart CLI not found separately (usually bundled with Flutter — this may be OK)."
else
  DART_VERSION=$(dart --version 2>/dev/null | head -1)
  log_success "Dart found: ${DART_VERSION}"
fi

# =============================================================
# Step 2: Flutter pub get for each app
# =============================================================
APPS=("passenger_app" "driver_app" "admin_app")

for app in "${APPS[@]}"; do
  app_dir="${SCRIPT_DIR}/${app}"
  log_step "Running flutter pub get in ${app}"

  if [ ! -d "${app_dir}" ]; then
    log_warn "Directory not found: ${app_dir} — skipping"
    continue
  fi

  if [ ! -f "${app_dir}/pubspec.yaml" ]; then
    log_warn "No pubspec.yaml found in ${app_dir} — skipping"
    continue
  fi

  (
    cd "${app_dir}"
    flutter pub get
  )
  log_success "flutter pub get completed for ${app}"
done

# =============================================================
# Step 3: flutter gen-l10n for each app
# =============================================================
log_step "Generating localizations (flutter gen-l10n)"

for app in "${APPS[@]}"; do
  app_dir="${SCRIPT_DIR}/${app}"

  if [ ! -d "${app_dir}" ]; then
    continue
  fi

  # Only run gen-l10n if l10n.yaml or arb files are present
  if [ -f "${app_dir}/l10n.yaml" ] || ls "${app_dir}/lib/l10n/"*.arb &>/dev/null 2>&1; then
    log_info "Generating localizations for ${app}..."
    (
      cd "${app_dir}"
      flutter gen-l10n
    ) && log_success "gen-l10n completed for ${app}" \
      || log_warn "gen-l10n failed for ${app} (may not be configured yet)"
  else
    log_warn "No l10n.yaml or .arb files found in ${app} — skipping gen-l10n"
  fi
done

# =============================================================
# Step 4: Check Supabase CLI
# =============================================================
log_step "Checking Supabase CLI"

if command -v supabase &>/dev/null; then
  SUPA_VERSION=$(supabase --version 2>/dev/null | head -1)
  log_success "Supabase CLI found: ${SUPA_VERSION}"
else
  log_warn "Supabase CLI not found. Install with:"
  log_warn "  npm install -g supabase"
  log_warn "  OR: brew install supabase/tap/supabase"
fi

# =============================================================
# Step 5: Print Supabase setup instructions
# =============================================================
log_step "Supabase Configuration Guide"

cat <<'INSTRUCTIONS'

========================================================
  WEDIT — Supabase Backend Setup Instructions
========================================================

1. CREATE SUPABASE PROJECT
   Go to https://app.supabase.com and create a new project.
   Note your:
     - Project URL       (e.g. https://xxxx.supabase.co)
     - Anon/Public Key
     - Service Role Key
     - Database Password

2. LINK LOCAL PROJECT
   Run in this directory:
     supabase login
     supabase link --project-ref <your-project-ref>

3. RUN MIGRATIONS
   Apply all database migrations:
     supabase db push
   Or run them manually in the SQL editor in the Supabase dashboard:
     supabase/migrations/001_profiles.sql
     supabase/migrations/002_drivers_vehicles.sql
     supabase/migrations/003_rides_offers.sql
     supabase/migrations/004_subscriptions_payments.sql
     supabase/migrations/005_locations_notifications.sql
     supabase/migrations/006_referrals_points.sql
     supabase/migrations/007_competition_leaderboard.sql
     supabase/migrations/008_rls_complete.sql
     supabase/migrations/009_cron_jobs.sql

4. SET DATABASE SETTINGS (for cron jobs)
   In the Supabase SQL editor, run:
     ALTER DATABASE postgres SET "app.supabase_url" = 'https://xxxx.supabase.co';
     ALTER DATABASE postgres SET "app.service_role_key" = 'your-service-role-key';

5. DEPLOY EDGE FUNCTIONS
     supabase functions deploy send-notification
     supabase functions deploy chapa-webhook
     supabase functions deploy telebirr-webhook
     supabase functions deploy auto-renew-subscription
     supabase functions deploy close-competition-period
     supabase functions deploy run-raffle

6. SET EDGE FUNCTION SECRETS
   In Supabase Dashboard > Edge Functions > Secrets, add:

   Required:
     FCM_SERVICE_ACCOUNT_JSON   = <your-firebase-service-account-json>
     FCM_PROJECT_ID             = <your-firebase-project-id>
     CHAPA_SECRET_KEY           = <your-chapa-secret-key>
     CHAPA_WEBHOOK_SECRET       = <your-chapa-webhook-secret>
     TELEBIRR_WEBHOOK_SECRET    = <your-telebirr-webhook-secret>
     APP_DEEP_LINK_URL          = wedit://payment

   Or via CLI:
     supabase secrets set FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
     supabase secrets set FCM_PROJECT_ID=your-project-id
     supabase secrets set CHAPA_SECRET_KEY=your-key
     supabase secrets set CHAPA_WEBHOOK_SECRET=your-secret
     supabase secrets set TELEBIRR_WEBHOOK_SECRET=your-secret

7. CONFIGURE PAYMENT WEBHOOKS
   In Chapa dashboard, set webhook URL to:
     https://<project-ref>.supabase.co/functions/v1/chapa-webhook

   In Telebirr merchant portal, set notify URL to:
     https://<project-ref>.supabase.co/functions/v1/telebirr-webhook

8. SET APP ENVIRONMENT VARIABLES
   In each Flutter app, create a .env file or update lib/config/env.dart:
     SUPABASE_URL=https://xxxx.supabase.co
     SUPABASE_ANON_KEY=your-anon-key

9. ENABLE REALTIME
   In Supabase Dashboard > Database > Replication:
   Enable replication for: driver_locations, rides, ride_offers, notifications

10. CONFIGURE STORAGE BUCKETS
    Create the following buckets in Supabase Storage:
      - driver-documents     (private)
      - profile-avatars      (public)
      - bank-transfer-screenshots (private)

11. CONFIGURE GITHUB SECRETS (for backup workflow)
    In GitHub repository > Settings > Secrets, add:
      SUPABASE_DB_URL        = postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres
      AWS_ACCESS_KEY_ID      = your-aws-key
      AWS_SECRET_ACCESS_KEY  = your-aws-secret
      AWS_S3_BUCKET          = your-bucket-name
      AWS_REGION             = us-east-1  (or your region)
      SLACK_WEBHOOK_URL      = (optional) for failure alerts

12. LOCAL DEVELOPMENT
    Start local Supabase:
      supabase start

    Access local services:
      Studio:    http://localhost:54323
      API:       http://localhost:54321
      DB:        postgresql://postgres:postgres@localhost:54322/postgres
      Inbucket:  http://localhost:54324

========================================================
INSTRUCTIONS

log_success "Setup complete! Review the instructions above."
echo ""
