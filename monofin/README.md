# mono — bank + crypto wallet in one app

One Flutter Android app with two experiences. From the admin panel you choose whether users see the **Bank app** (balance, card, transfers) or the **Wallet app** (crypto portfolio, buy, sell, send). You can switch everyone at once or set it per user. Open apps switch within seconds through a silent push.

```
backend/   procedural PHP + MySQL: JSON API for the app, admin panel, push sender
app/       Flutter app (Android)
tool/      helper scripts the GitHub build uses
.github/workflows/build-apk.yml   builds the APK on GitHub
```

Money in the app is a ledger kept in your database. Balances change only through admin credits/debits, transfers between users, and crypto trades at the prices stored in the database. It is not connected to a real bank or blockchain.

---

## 1. Backend (PHP + MySQL)

Needs PHP 7.4+ (8.x recommended) with `mysqli`, `curl`, `openssl`, and MySQL 5.7+ or MariaDB. Works on normal cPanel hosting.

1. Create a MySQL database and user.
2. Import `backend/database.sql` (phpMyAdmin › Import).
3. Edit `backend/config.php`: database details, change `CRON_KEY`, and the timezone if you need to.
4. Upload the **contents** of `backend/` to a folder on your site, e.g. `public_html/monofin/`.
   Your API base URL is then `https://your-site.com/monofin`.
5. Open `https://your-site.com/monofin/admin/` — on the first visit it asks you to create the admin account.
6. Use HTTPS. If you must use plain `http://`, the build allows it automatically.

**Live crypto prices (optional).** Admin › Crypto prices › *Sync from CoinGecko*, or add a cron job every 10 minutes so charts build history:
```
php /home/USER/public_html/monofin/cron_prices.php
```
You can also type prices by hand on the same page. Prices are kept in the same currency as balances (set in Admin › Settings).

## 2. Firebase (push notifications)

1. In the [Firebase console](https://console.firebase.google.com) create a project and add an **Android app**. Pick a package name, e.g. `com.yourname.mono`.
2. Download **google-services.json** (you'll paste it into GitHub in the next step).
3. Project settings › **Service accounts** › *Generate new private key*. Rename the file to `firebase-service-account.json` and upload it next to `config.php` on your server. (The included `.htaccess` blocks web access to it.)
4. Admin › Settings › *Send test push to all* confirms it works once someone has installed the app.

## 3. Build the APK on GitHub

1. Create a **private** GitHub repository and push this whole folder to the `main` branch.
2. In the repo: **Settings › Secrets and variables › Actions**
   - **Variables** tab
     - `API_BASE_URL` = `https://your-site.com/monofin` (required)
     - `APP_NAME` = the name under the app icon, e.g. `mono` (optional)
   - **Secrets** tab
     - `GOOGLE_SERVICES_JSON` = paste the full contents of google-services.json
     - `DEBUG_KEYSTORE_BASE64` = see step 4
3. Open the **Actions** tab › *Build APK* › **Run workflow** (it also runs on every push to `main`).
4. **Signing key, once:** the first build makes a signing key and uploads it as the `signing-key` artifact. Download it, open the `.txt` file inside and save its text as the secret `DEBUG_KEYSTORE_BASE64`. After that every build is signed with the same key, so new APKs install over old ones without uninstalling.
5. Download the APK from the run's **Artifacts** (`apk`) or from the repo's **Releases** page — Releases is easiest on a phone. Open it on Android and allow "install unknown apps" when asked.

The Android app ID is taken from google-services.json, so it always matches your Firebase app.

## 4. Using the admin panel

| Page | What you can do |
|---|---|
| Dashboard | **Switch Bank ⇄ Wallet for everyone**, see totals and latest transactions |
| Users | Search users; open one to set a **per-user mode override**, credit/debit balance, send a push, reset password, suspend |
| Notifications | Push a message to all users (also saved in each user's in-app inbox) |
| Crypto prices | Sync from CoinGecko, edit prices, hide coins, add new coins |
| Settings | App names, currency symbol, price currency, top-up instructions, allow sign-ups, test push, admin password |

New users sign up in the app. Fund them from Users › user › *Credit or debit balance* (they get a push).

## 5. API (for reference)

All endpoints are under `/api/`, return `{"ok": true, ...}` or `{"ok": false, "error": "..."}`, accept JSON or form posts, and take the session token as `Authorization: Bearer <token>` (also `X-Auth-Token`, for hosts that strip Authorization).

`app_config` · `register` · `login` · `logout` · `me` · `fcm_token` · `transactions` · `lookup_account` · `transfer` · `card_toggle` · `bank_summary` · `notifications` · `crypto_assets` · `crypto_trade` · `crypto_send`

## 6. Building on your own computer (optional)

```
cd app
flutter create --org com.monofin --project-name monofin --platforms android .
APP_NAME=mono APP_ID=com.yourname.mono python3 ../tool/patch_android.py
python3 ../tool/gen_firebase_options.py path/to/google-services.json lib/firebase_options.dart
flutter build apk --release --dart-define=API_BASE_URL=https://your-site.com/monofin
```
