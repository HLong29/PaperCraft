<?php
$server = 'localhost'; // Hoặc localhost\SQLEXPRESS
$database = 'PaperCraftDB';

// Điền tài khoản SQL Server của bạn
$username = 'sa';
$password = '12345';

try {
    $dsn = "sqlsrv:Server=$server;Database=$database;TrustServerCertificate=1";

    $conn = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);

} catch (PDOException $e) {
    error_log('SQL Server connection error: ' . $e->getMessage());
    http_response_code(500);
    if (defined('API_MODE')) {
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['ok' => false, 'error' => 'Không kết nối được cơ sở dữ liệu.'], JSON_UNESCAPED_UNICODE);
    } else {
        echo 'Kết nối thất bại. Hãy kiểm tra cấu hình SQL Server, tài khoản và mật khẩu.';
    }
    exit;
}
