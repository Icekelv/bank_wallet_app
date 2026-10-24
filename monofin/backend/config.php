<?php
// ---------------------------------------------------------------
// monofin backend configuration — edit these values for your server
// ---------------------------------------------------------------

define('DB_HOST', 'localhost');
define('DB_USER', 'your_db_user');
define('DB_PASS', 'your_db_password');
define('DB_NAME', 'monofin');

// Firebase service account JSON (Firebase console > Project settings >
// Service accounts > Generate new private key). Upload it next to this file.
// The includes/.htaccess and the root .htaccess block web access to it.
define('FCM_SERVICE_ACCOUNT_FILE', __DIR__ . '/firebase-service-account.json');

// Secret used by cron_prices.php when called over HTTP (?key=...). Change it.
define('CRON_KEY', 'change-this-cron-key');

// Server timezone for dates shown in the app and admin panel.
define('APP_TIMEZONE', 'Africa/Lagos');

// Set to true only while debugging; shows PHP errors in API responses.
define('APP_DEBUG', false);
