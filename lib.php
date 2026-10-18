<?php
// ============================================================
//  PaperCraft — lib.php  (hàm dùng chung cho index.php & api.php)
// ============================================================

function e($s) { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }
function vnd($n) { return number_format((float)$n, 0, ',', '.') . 'đ'; }

function start_secure_session(): void {
    if (session_status() === PHP_SESSION_ACTIVE) return;
    session_set_cookie_params([
        'lifetime' => 0,
        'path'     => '/',
        'httponly' => true,
        'samesite' => 'Lax',
        'secure'   => !empty($_SERVER['HTTPS']),
    ]);
    session_start();
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
}

// Độ dài chuỗi UTF-8 (không phụ thuộc extension mbstring)
function str_len(string $s): int {
    return function_exists('mb_strlen') ? mb_strlen($s, 'UTF-8') : strlen(utf8_decode($s));
}

// Chỉ cho phép link nội bộ / http(s) lấy từ DB
function safe_url($url): string {
    $url = trim((string)$url);
    return preg_match('#^(\#|/|https?://)#i', $url) ? $url : '#';
}

// "Ưu Đãi Đặc Biệt Cuối Tháng" => ["Ưu Đãi Đặc Biệt", "Cuối Tháng"]
function split_title(string $t): array {
    $w = preg_split('/\s+/u', trim($t), -1, PREG_SPLIT_NO_EMPTY);
    if (count($w) <= 2) return ['', trim($t)];
    $tail = array_splice($w, -2);
    return [implode(' ', $w), implode(' ', $tail)];
}

// Lấy thông báo lỗi nghiệp vụ (THROW 50xxx trong stored procedure) để hiển thị cho khách
function friendly_db_error(Throwable $ex): string {
    if ($ex instanceof PDOException && isset($ex->errorInfo[1])) {
        $code = (int)$ex->errorInfo[1];
        if ($code >= 50000 && preg_match('/\[SQL Server\](.+)$/su', $ex->getMessage(), $m)) {
            return trim($m[1]);
        }
        if ($code === 547) {
            return 'Số lượng không hợp lệ (tối đa 99 cho mỗi sản phẩm).';
        }
    }
    error_log('API error: ' . $ex->getMessage());
    if (defined('DEBUG') && DEBUG) return 'DEBUG: ' . $ex->getMessage();
    return 'Có lỗi xảy ra, vui lòng thử lại sau.';
}

/* ---------------- GIỎ HÀNG ---------------- */

// Giỏ hàng gắn với PHP session (khách chưa đăng nhập) -> bảng Carts.SessionId
function cart_id(PDO $c): int {
    $st = $c->prepare(
        'SET NOCOUNT ON;
         DECLARE @CartId INT;
         EXEC dbo.sp_GetOrCreateCart @SessionId = ?, @CustomerId = NULL, @CartId = @CartId OUTPUT;
         SELECT @CartId AS CartId;'
    );
    $st->execute([session_id()]);
    $id = (int)$st->fetchColumn();
    $st->closeCursor();
    return $id;
}

function cart_fetch(PDO $c, int $cartId): array {
    $st = $c->prepare('EXEC dbo.sp_GetCart @CartId = ?');
    $st->execute([$cartId]);
    $rows = $st->fetchAll();
    $st->nextRowset();
    $t = $st->fetch() ?: [];
    $st->closeCursor();

    $items = [];
    foreach ($rows as $r) {
        $items[] = [
            'id'    => $r['Code'],
            'name'  => $r['Name'],
            'img'   => $r['ImageUrl'],
            'cat'   => $r['ProductType'],
            'price' => (int)$r['Price'],
            'qty'   => (int)$r['Quantity'],
            'line'  => (int)$r['LineTotal'],
            'stock' => (int)$r['StockQty'],
        ];
    }
    return [
        'items'  => $items,
        'totals' => [
            'items'     => (int)($t['TotalItems'] ?? 0),
            'subtotal'  => (int)($t['Subtotal'] ?? 0),
            'shipping'  => (int)($t['ShippingFee'] ?? 0),
            'total'     => (int)($t['Total'] ?? 0),
            'remaining' => (int)($t['RemainingForFreeShip'] ?? 0),
            'percent'   => (int)($t['FreeShipPercent'] ?? 0),
        ],
    ];
}

/* ---------------- ĐƠN HÀNG & THANH TOÁN ---------------- */

function order_details(PDO $c, string $code): ?array {
    $st = $c->prepare(
        'SELECT OrderId, OrderCode, ReceiverName, Phone, Email, ShippingAddress, Note,
                Subtotal, ShippingFee, DiscountAmount, Total, PaymentMethod, PaymentStatus, Status, CreatedAt
         FROM dbo.Orders WHERE OrderCode = ?'
    );
    $st->execute([$code]);
    $o = $st->fetch();
    $st->closeCursor();
    if (!$o) return null;

    $st = $c->prepare('SELECT ProductName, UnitPrice, Quantity, LineTotal FROM dbo.OrderItems WHERE OrderId = ? ORDER BY OrderItemId');
    $st->execute([(int)$o['OrderId']]);
    $items = [];
    foreach ($st->fetchAll() as $i) {
        $items[] = [
            'name'  => $i['ProductName'],
            'qty'   => (int)$i['Quantity'],
            'price' => (int)$i['UnitPrice'],
            'line'  => (int)$i['LineTotal'],
        ];
    }
    $st->closeCursor();

    return [
        'code'           => $o['OrderCode'],
        'created_at'     => date('H:i d/m/Y', strtotime((string)$o['CreatedAt'])),
        'receiver'       => $o['ReceiverName'],
        'phone'          => $o['Phone'],
        'email'          => $o['Email'],
        'address'        => $o['ShippingAddress'],
        'note'           => $o['Note'],
        'method'         => $o['PaymentMethod'],
        'payment_status' => $o['PaymentStatus'],
        'status'         => $o['Status'],
        'subtotal'       => (int)$o['Subtotal'],
        'shipping'       => (int)$o['ShippingFee'],
        'discount'       => (int)$o['DiscountAmount'],
        'total'          => (int)$o['Total'],
        'items'          => $items,
    ];
}

// Thông tin chuyển khoản + ảnh QR (VietQR). Nội dung CK = mã đơn hàng để đối soát.
function build_payment(array $order): array {
    $amount  = (int)$order['total'];
    $content = $order['code'];
    $qr = 'https://img.vietqr.io/image/' . rawurlencode(BANK_ID) . '-' . rawurlencode(BANK_ACCOUNT_NO)
        . '-' . rawurlencode(QR_TEMPLATE) . '.png?'
        . http_build_query([
            'amount'      => $amount,
            'addInfo'     => $content,
            'accountName' => BANK_ACCOUNT_NAME,
        ], '', '&', PHP_QUERY_RFC3986);

    return [
        'bank_name'    => BANK_NAME,
        'account_no'   => BANK_ACCOUNT_NO,
        'account_name' => BANK_ACCOUNT_NAME,
        'amount'       => $amount,
        'content'      => $content,
        'qr_url'       => $qr,
    ];
}
