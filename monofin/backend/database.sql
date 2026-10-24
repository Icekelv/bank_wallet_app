-- monofin database schema (MySQL 5.7+ / MariaDB 10.3+)
-- Import this once in phpMyAdmin (or: mysql -u USER -p DBNAME < database.sql)

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS settings (
  skey   VARCHAR(64) NOT NULL PRIMARY KEY,
  svalue TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO settings (skey, svalue) VALUES
 ('app_mode', 'bank'),
 ('bank_name', 'mono'),
 ('wallet_name', 'mono wallet'),
 ('currency_symbol', '$'),
 ('price_currency', 'usd'),
 ('signup_enabled', '1'),
 ('deposit_instructions', 'To fund your account, contact support with your account number. Your balance updates as soon as the deposit is confirmed.');

CREATE TABLE IF NOT EXISTS admins (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  username      VARCHAR(60)  NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS users (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  full_name      VARCHAR(120) NOT NULL,
  email          VARCHAR(190) NOT NULL UNIQUE,
  phone          VARCHAR(30)  NULL,
  password_hash  VARCHAR(255) NOT NULL,
  account_number CHAR(10)     NOT NULL UNIQUE,
  balance        DECIMAL(16,2) NOT NULL DEFAULT 0.00,
  card_last4     CHAR(4)      NOT NULL,
  card_expiry    CHAR(5)      NOT NULL,
  card_frozen    TINYINT(1)   NOT NULL DEFAULT 0,
  mode_override  VARCHAR(10)  NULL,          -- NULL = follow global app_mode, else 'bank' / 'wallet'
  status         VARCHAR(12)  NOT NULL DEFAULT 'active', -- active | suspended
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS api_tokens (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  token      CHAR(64) NOT NULL UNIQUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used  DATETIME NULL,
  INDEX (user_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS fcm_tokens (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  token      VARCHAR(255) NOT NULL UNIQUE,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (user_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS transactions (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id       INT UNSIGNED NOT NULL,
  type          VARCHAR(20)  NOT NULL,   -- deposit, withdrawal, transfer_in, transfer_out, buy, sell, crypto_in, crypto_out
  direction     VARCHAR(3)   NOT NULL,   -- in | out (effect on the cash balance or the coin)
  amount        DECIMAL(16,2) NOT NULL,  -- cash value
  asset         VARCHAR(10)  NOT NULL DEFAULT 'USD',
  asset_amount  DECIMAL(24,8) NULL,
  price         DECIMAL(18,2) NULL,
  counterparty  VARCHAR(190) NULL,
  description   VARCHAR(255) NULL,
  balance_after DECIMAL(16,2) NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (user_id, created_at),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS crypto_assets (
  symbol       VARCHAR(10)  NOT NULL PRIMARY KEY,
  name         VARCHAR(60)  NOT NULL,
  price        DECIMAL(18,2) NOT NULL DEFAULT 0,
  change_24h   DECIMAL(7,2)  NOT NULL DEFAULT 0,
  coingecko_id VARCHAR(64)  NULL,
  sort_order   INT NOT NULL DEFAULT 0,
  active       TINYINT(1) NOT NULL DEFAULT 1,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO crypto_assets (symbol, name, price, change_24h, coingecko_id, sort_order) VALUES
 ('BTC',  'Bitcoin',  70000.00, 0, 'bitcoin',  1),
 ('ETH',  'Ethereum',  3000.00, 0, 'ethereum', 2),
 ('SOL',  'Solana',     150.00, 0, 'solana',   3),
 ('USDC', 'USD Coin',     1.00, 0, 'usd-coin', 4);

CREATE TABLE IF NOT EXISTS price_history (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  symbol     VARCHAR(10) NOT NULL,
  price      DECIMAL(18,2) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (symbol, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS holdings (
  user_id  INT UNSIGNED NOT NULL,
  symbol   VARCHAR(10)  NOT NULL,
  amount   DECIMAL(24,8) NOT NULL DEFAULT 0,
  avg_cost DECIMAL(18,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, symbol),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS notifications (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NULL,          -- NULL = sent to everyone
  title      VARCHAR(150) NOT NULL,
  body       VARCHAR(500) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
