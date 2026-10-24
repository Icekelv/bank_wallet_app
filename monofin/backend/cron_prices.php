<?php
// Updates crypto prices from CoinGecko and records history for the charts.
// cPanel cron (every 10 minutes):   php /home/USER/public_html/monofin/cron_prices.php
// or over HTTP:                     https://your-site.com/monofin/cron_prices.php?key=YOUR_CRON_KEY

require_once __DIR__ . '/includes/functions.php';

if (PHP_SAPI !== 'cli') {
    header('Content-Type: text/plain');
    if (!isset($_GET['key']) || !hash_equals(CRON_KEY, (string) $_GET['key'])) {
        http_response_code(403);
        exit("Forbidden\n");
    }
}

try {
    $n = sync_prices_from_coingecko();
    echo "Updated $n prices\n";
} catch (Exception $e) {
    echo 'Error: ' . $e->getMessage() . "\n";
}
// Keep history from growing forever: drop points older than 30 days.
db_exec('DELETE FROM price_history WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)');
