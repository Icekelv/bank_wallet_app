<?php
// Database connection and small query helpers (procedural mysqli).

require_once __DIR__ . '/../config.php';

date_default_timezone_set(APP_TIMEZONE);
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

function db()
{
    static $conn = null;
    if ($conn === null) {
        $conn = mysqli_connect(DB_HOST, DB_USER, DB_PASS, DB_NAME);
        mysqli_set_charset($conn, 'utf8mb4');
        // Keep MySQL timestamps in the same timezone as PHP.
        $offset = (new DateTime())->format('P');
        mysqli_query($conn, "SET time_zone = '" . $offset . "'");
    }
    return $conn;
}

// Run a prepared statement. $params is a plain array; types are detected.
function db_run($sql, $params = array())
{
    $stmt = mysqli_prepare(db(), $sql);
    if ($params) {
        $types = '';
        foreach ($params as $p) {
            if (is_int($p)) {
                $types .= 'i';
            } elseif (is_float($p)) {
                $types .= 'd';
            } else {
                $types .= 's';
            }
        }
        mysqli_stmt_bind_param($stmt, $types, ...$params);
    }
    mysqli_stmt_execute($stmt);
    return $stmt;
}

function db_all($sql, $params = array())
{
    $stmt = db_run($sql, $params);
    $res = mysqli_stmt_get_result($stmt);
    $rows = $res ? mysqli_fetch_all($res, MYSQLI_ASSOC) : array();
    mysqli_stmt_close($stmt);
    return $rows;
}

function db_one($sql, $params = array())
{
    $rows = db_all($sql, $params);
    return $rows ? $rows[0] : null;
}

function db_value($sql, $params = array())
{
    $row = db_one($sql, $params);
    return $row ? reset($row) : null;
}

// INSERT / UPDATE / DELETE. Returns affected rows.
function db_exec($sql, $params = array())
{
    $stmt = db_run($sql, $params);
    $n = mysqli_stmt_affected_rows($stmt);
    mysqli_stmt_close($stmt);
    return $n;
}

function db_insert_id()
{
    return (int) mysqli_insert_id(db());
}

function db_begin()
{
    mysqli_begin_transaction(db());
}

function db_commit()
{
    mysqli_commit(db());
}

function db_rollback()
{
    mysqli_rollback(db());
}
