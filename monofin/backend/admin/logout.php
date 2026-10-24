<?php
require __DIR__ . '/_init.php';
$_SESSION = array();
session_destroy();
redirect('index.php');
