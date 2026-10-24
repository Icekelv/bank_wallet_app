<?php
// Crypto assets: edit prices by hand, sync from CoinGecko, add / hide assets.
require __DIR__ . '/_init.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $action = $_POST['action'] ?? '';
    if ($action === 'sync') {
        try {
            $n = sync_prices_from_coingecko();
            flash("Updated $n prices from CoinGecko.");
        } catch (Exception $e) {
            flash($e->getMessage(), 'err');
        }
    } elseif ($action === 'save') {
        foreach ((array) ($_POST['price'] ?? array()) as $sym => $price) {
            $sym = strtoupper((string) $sym);
            $a = db_one('SELECT * FROM crypto_assets WHERE symbol = ?', array($sym));
            if (!$a) {
                continue;
            }
            $price = round((float) $price, 2);
            $change = round((float) ($_POST['change'][$sym] ?? $a['change_24h']), 2);
            $active = isset($_POST['active'][$sym]) ? 1 : 0;
            db_exec('UPDATE crypto_assets SET active = ? WHERE symbol = ?', array($active, $sym));
            if ($price > 0 && ($price != (float) $a['price'] || $change != (float) $a['change_24h'])) {
                record_price($sym, $price, $change);
            }
        }
        flash('Prices saved.');
    } elseif ($action === 'add') {
        $sym = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', (string) ($_POST['symbol'] ?? '')));
        $name = trim((string) ($_POST['name'] ?? ''));
        $price = round((float) ($_POST['new_price'] ?? 0), 2);
        $cg = trim((string) ($_POST['coingecko_id'] ?? ''));
        if ($sym === '' || $name === '' || $price <= 0) {
            flash('Symbol, name and a price are required.', 'err');
        } elseif (db_value('SELECT symbol FROM crypto_assets WHERE symbol = ?', array($sym))) {
            flash('That symbol already exists.', 'err');
        } else {
            $order = (int) db_value('SELECT COALESCE(MAX(sort_order),0)+1 FROM crypto_assets');
            db_exec(
                'INSERT INTO crypto_assets (symbol, name, price, coingecko_id, sort_order) VALUES (?, ?, ?, ?, ?)',
                array($sym, $name, money_str($price), $cg !== '' ? $cg : null, $order)
            );
            record_price($sym, $price);
            flash($sym . ' added.');
        }
    }
    redirect('crypto.php');
}

$assets = db_all('SELECT * FROM crypto_assets ORDER BY sort_order, symbol');
$cur = strtoupper(get_setting('price_currency', 'usd'));

admin_header('Crypto prices', 'crypto.php');
?>
<section class="card">
  <h2>Live prices</h2>
  <p class="muted">Prices are in <?= h($cur) ?>, the same currency as user balances. Pull them from CoinGecko now, or set up <code>cron_prices.php</code> to run every 10 minutes so charts build up history.</p>
  <form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="sync"><button class="btn">Sync from CoinGecko</button></form>
</section>

<section class="card">
  <h2>Assets</h2>
  <form method="post">
    <?= csrf_field() ?><input type="hidden" name="action" value="save">
    <div class="tablewrap"><table>
      <tr><th>Asset</th><th>Price (<?= h($cur) ?>)</th><th>24h change %</th><th>Shown in app</th><th>Updated</th></tr>
      <?php foreach ($assets as $a): $s = h($a['symbol']); ?>
      <tr>
        <td><strong><?= $s ?></strong> · <?= h($a['name']) ?></td>
        <td><input name="price[<?= $s ?>]" type="number" step="0.01" min="0" value="<?= h($a['price']) ?>" aria-label="<?= $s ?> price"></td>
        <td><input name="change[<?= $s ?>]" type="number" step="0.01" value="<?= h($a['change_24h']) ?>" aria-label="<?= $s ?> 24h change"></td>
        <td><input type="checkbox" name="active[<?= $s ?>]" value="1" <?= $a['active'] ? 'checked' : '' ?> aria-label="Show <?= $s ?>"></td>
        <td class="muted"><?= h(date('M j, H:i', strtotime($a['updated_at']))) ?></td>
      </tr>
      <?php endforeach; ?>
    </table></div>
    <button class="btn">Save changes</button>
  </form>
</section>

<section class="card">
  <h2>Add an asset</h2>
  <form method="post" class="stack">
    <?= csrf_field() ?><input type="hidden" name="action" value="add">
    <div class="row">
      <label>Symbol<input name="symbol" maxlength="10" placeholder="e.g. BNB" required></label>
      <label>Name<input name="name" maxlength="60" placeholder="e.g. BNB" required></label>
    </div>
    <div class="row">
      <label>Starting price<input name="new_price" type="number" step="0.01" min="0.01" required></label>
      <label>CoinGecko id (optional)<input name="coingecko_id" placeholder="e.g. binancecoin"></label>
    </div>
    <button class="btn">Add asset</button>
  </form>
</section>
<?php admin_footer();
