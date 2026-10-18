<?php
// ============================================================
//  PaperCraft — api.php
//  Endpoint JSON duy nhất: POST {action: "...", ...}
//  Gọi các stored procedure có sẵn trong database.sql
// ============================================================
define('API_MODE', true);
header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Cache-Control: no-store');

// Luôn trả JSON sạch: chặn mọi cảnh báo/lỗi PHP in lẫn vào phản hồi
ini_set('display_errors', '0');
ob_start();

const JSON_FLAGS = JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE | JSON_PARTIAL_OUTPUT_ON_ERROR;

// Lỗi nghiêm trọng (fatal) không bắt được bằng try/catch -> vẫn trả JSON
register_shutdown_function(function () {
    $err = error_get_last();
    if ($err && in_array($err['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
        error_log('API fatal: ' . $err['message'] . ' @ ' . $err['file'] . ':' . $err['line']);
        while (ob_get_level() > 0) ob_end_clean();
        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
        $msg = (defined('DEBUG') && DEBUG)
            ? 'DEBUG: ' . $err['message'] . ' (' . basename($err['file']) . ':' . $err['line'] . ')'
            : 'Có lỗi xảy ra, vui lòng thử lại sau.';
        echo json_encode(['ok' => false, 'error' => $msg], JSON_FLAGS);
    }
});

require __DIR__ . '/config.php';
require __DIR__ . '/lib.php';
start_secure_session();
require __DIR__ . '/db.php';

function respond(array $data, int $status = 200): void {
    $stray = ob_get_level() > 0 ? ob_get_clean() : '';
    if (trim((string)$stray) !== '') error_log('API stray output: ' . substr($stray, 0, 500));
    http_response_code($status);
    $json = json_encode($data, JSON_FLAGS);
    echo $json !== false ? $json : '{"ok":false,"error":"Không mã hóa được phản hồi."}';
    exit;
}
function fail(string $msg, int $status = 400): void {
    respond(['ok' => false, 'error' => $msg], $status);
}
function product_code($v): string {
    $v = trim((string)$v);
    if (!preg_match('/^[A-Za-z0-9_-]{1,20}$/', $v)) fail('Mã sản phẩm không hợp lệ.');
    return $v;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('Method not allowed', 405);

// Chống CSRF: token được in ở <meta name="csrf-token"> trong index.php
if (!hash_equals($_SESSION['csrf'] ?? '', $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '')) {
    fail('Phiên làm việc đã hết hạn, vui lòng tải lại trang.', 403);
}

$in = json_decode(file_get_contents('php://input'), true);
if (!is_array($in)) fail('Dữ liệu không hợp lệ.');
$action = (string)($in['action'] ?? '');

try {
    switch ($action) {

        // ---------- Giỏ hàng (Carts / CartItems) ----------
        case 'cart_get':
            respond(['ok' => true, 'cart' => cart_fetch($conn, cart_id($conn))]);

        case 'cart_add':
            $code = product_code($in['code'] ?? '');
            $qty  = max(1, min(99, (int)($in['qty'] ?? 1)));
            $st = $conn->prepare('EXEC dbo.sp_AddToCart @ProductCode = ?, @Quantity = ?, @SessionId = ?, @CustomerId = NULL');
            $st->execute([$code, $qty, session_id()]);
            $st->closeCursor();
            respond(['ok' => true, 'cart' => cart_fetch($conn, cart_id($conn))]);

        case 'cart_set':
            $code   = product_code($in['code'] ?? '');
            $qty    = max(0, min(99, (int)($in['qty'] ?? 0)));
            $cartId = cart_id($conn);
            $st = $conn->prepare('EXEC dbo.sp_UpdateCartItem @CartId = ?, @ProductCode = ?, @Quantity = ?');
            $st->execute([$cartId, $code, $qty]);
            $st->closeCursor();
            respond(['ok' => true, 'cart' => cart_fetch($conn, $cartId)]);

        case 'cart_remove':
            $code   = product_code($in['code'] ?? '');
            $cartId = cart_id($conn);
            $st = $conn->prepare('EXEC dbo.sp_RemoveCartItem @CartId = ?, @ProductCode = ?');
            $st->execute([$cartId, $code]);
            $st->closeCursor();
            respond(['ok' => true, 'cart' => cart_fetch($conn, $cartId)]);

        case 'cart_clear':
            $cartId = cart_id($conn);
            $st = $conn->prepare('EXEC dbo.sp_ClearCart @CartId = ?');
            $st->execute([$cartId]);
            $st->closeCursor();
            respond(['ok' => true, 'cart' => cart_fetch($conn, $cartId)]);

        // ---------- Mã giảm giá (Coupons) ----------
        case 'coupon_check':
            $coupon = strtoupper(trim((string)($in['code'] ?? '')));
            if (!preg_match('/^[A-Z0-9_-]{1,30}$/', $coupon)) fail('Mã giảm giá không hợp lệ.');
            $cart = cart_fetch($conn, cart_id($conn));
            $sub  = $cart['totals']['subtotal'];
            if ($sub <= 0) fail('Giỏ hàng đang trống.');

            $st = $conn->prepare('EXEC dbo.sp_ValidateCoupon @Code = ?, @Subtotal = ?');
            $st->execute([$coupon, $sub]);
            $r = $st->fetch();
            $st->closeCursor();

            $discount = (int)$r['DiscountAmount'];
            $free     = (int)$r['FreeShip'] === 1;
            $ship     = $free ? 0 : $cart['totals']['shipping'];
            respond([
                'ok'       => true,
                'coupon'   => $coupon,
                'discount' => $discount,
                'free_ship'=> $free,
                'shipping' => $ship,
                'total'    => $sub + $ship - $discount,
            ]);

        // ---------- Đặt hàng (Orders / OrderItems) ----------
        case 'checkout':
            $name    = trim((string)($in['receiver'] ?? ''));
            $phone   = preg_replace('/[\s.\-]/', '', (string)($in['phone'] ?? ''));
            $email   = trim((string)($in['email'] ?? ''));
            $address = trim((string)($in['address'] ?? ''));
            $note    = trim((string)($in['note'] ?? ''));
            $method  = (string)($in['payment_method'] ?? 'BankTransfer');
            $coupon  = strtoupper(trim((string)($in['coupon'] ?? '')));

            if ($name === '' || str_len($name) > 100)             fail('Vui lòng nhập họ tên (tối đa 100 ký tự).');
            if (!preg_match('/^(\+84|0)\d{9,10}$/', $phone))         fail('Số điện thoại không hợp lệ.');
            if ($email !== '' && (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 150)) fail('Email không hợp lệ.');
            if (str_len($address) < 8 || str_len($address) > 400) fail('Vui lòng nhập địa chỉ giao hàng đầy đủ.');
            if (str_len($note) > 500)                               fail('Ghi chú tối đa 500 ký tự.');
            if (!in_array($method, ['BankTransfer', 'COD'], true))    fail('Phương thức thanh toán không hợp lệ.');
            if ($coupon !== '' && !preg_match('/^[A-Z0-9_-]{1,30}$/', $coupon)) fail('Mã giảm giá không hợp lệ.');

            $cartId = cart_id($conn);
            $st = $conn->prepare(
                'EXEC dbo.sp_Checkout @CartId = ?, @ReceiverName = ?, @Phone = ?, @Email = ?, @ShippingAddress = ?,
                                      @PaymentMethod = ?, @CouponCode = ?, @Note = ?, @CustomerId = NULL'
            );
            $st->execute([
                $cartId, $name, $phone,
                $email === '' ? null : $email,
                $address, $method,
                $coupon === '' ? null : $coupon,
                $note === '' ? null : $note,
            ]);
            $res = $st->fetch();
            $st->closeCursor();
            if (!$res) fail('Không tạo được đơn hàng.', 500);

            $orderCode = (string)$res['OrderCode'];
            $_SESSION['orders'][$orderCode] = time();   // chỉ phiên này mới xem được trạng thái đơn

            $order = order_details($conn, $orderCode);
            respond([
                'ok'      => true,
                'order'   => $order,
                'payment' => $method === 'BankTransfer' ? build_payment($order) : null,
            ]);

        // ---------- Trạng thái thanh toán (JS gọi định kỳ khi đang hiện QR) ----------
        case 'order_status':
            $code = strtoupper(trim((string)($in['code'] ?? '')));
            if (!preg_match('/^[A-Z0-9]{6,20}$/', $code) || !isset($_SESSION['orders'][$code])) {
                fail('Không tìm thấy đơn hàng.', 404);
            }
            $st = $conn->prepare('SELECT PaymentStatus, Status FROM dbo.Orders WHERE OrderCode = ?');
            $st->execute([$code]);
            $r = $st->fetch();
            $st->closeCursor();
            if (!$r) fail('Không tìm thấy đơn hàng.', 404);
            respond(['ok' => true, 'payment_status' => $r['PaymentStatus'], 'status' => $r['Status']]);

        // ---------- Newsletter (NewsletterSubscribers) ----------
        case 'newsletter':
            $email = trim((string)($in['email'] ?? ''));
            if (strlen($email) > 150) fail('Email không hợp lệ.');
            $st = $conn->prepare('EXEC dbo.sp_SubscribeNewsletter @Email = ?');
            $st->execute([$email]);
            $r = $st->fetch();
            $st->closeCursor();
            respond(['ok' => true, 'message' => ($r['Message'] ?? 'Đăng ký thành công!') . ' 🎉']);

        default:
            fail('Hành động không hợp lệ.', 404);
    }
} catch (Throwable $ex) {
    fail(friendly_db_error($ex), 400);
}