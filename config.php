<?php
// ============================================================
//  PaperCraft — config.php
//  Thông tin tài khoản NHẬN TIỀN. Hãy đổi sang tài khoản thật của shop.
// ============================================================

// Mã ngân hàng theo VietQR (https://api.vietqr.io/v2/banks): MB, VCB, TCB, ACB, BIDV, VPB, TPB, CTG...
// Cũng có thể dùng mã BIN (vd: 970422 cho MB Bank).
const BANK_ID           = 'MB';
const BANK_NAME         = 'MB Bank (Ngân hàng TMCP Quân đội)';
const BANK_ACCOUNT_NO   = '56579829092006';            // <-- đổi thành số tài khoản thật
const BANK_ACCOUNT_NAME = 'Bui Hoang Long';    // <-- tên chủ tài khoản, viết HOA không dấu

// Giao diện ảnh QR của img.vietqr.io: compact2 | compact | qr_only | print
const QR_TEMPLATE       = 'compact2';

// Bật true khi cần tìm lỗi: web sẽ hiện nguyên văn lỗi kỹ thuật. NHỚ tắt (false) khi chạy thật.
const DEBUG = false;
