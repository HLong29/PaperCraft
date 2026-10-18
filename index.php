<?php
// ============================================================
//  PaperCraft — index.php
//  Dữ liệu trang lấy từ SQL Server (PaperCraftDB). HTML bên dưới
//  giữ nguyên cấu trúc cũ.
// ============================================================
require __DIR__ . '/config.php';
require __DIR__ . '/db.php';
require __DIR__ . '/lib.php';
start_secure_session();

$siteName = 'PaperCraft';

$navLinks = [
    ['#categories', 'Danh Mục'],
    ['#products',   'Sản Phẩm'],
    ['#about',      'Về Chúng Tôi'],
    ['#contact',    'Liên Hệ'],
];
$footerSupport = ['Chính sách đổi trả', 'Hướng dẫn mua hàng', 'Theo dõi đơn hàng', 'Câu hỏi thường gặp'];

try {
    // SiteSettings
    $settings = $conn->query('SELECT SettingKey, SettingValue FROM dbo.SiteSettings')->fetchAll(PDO::FETCH_KEY_PAIR);

    // Banners: ticker + promo
    $tickerItems = $conn->query("SELECT Title FROM dbo.Banners WHERE Position = 'ticker' AND IsActive = 1 ORDER BY SortOrder")
                        ->fetchAll(PDO::FETCH_COLUMN);
    $promo = $conn->query("SELECT TOP 1 Title, SubTitle, LinkUrl FROM dbo.Banners WHERE Position = 'promo' AND IsActive = 1 ORDER BY SortOrder")
                  ->fetch();

    // vw_SiteStats
    $siteStats = $conn->query('SELECT TotalProducts, TotalCustomers, FoundedYear FROM dbo.vw_SiteStats')->fetch() ?: [];

    // vw_CategoryList (Categories + số sản phẩm)
    $categories = $conn->query('SELECT Name, ImageUrl, ProductCount FROM dbo.vw_CategoryList ORDER BY DisplayOrder, CategoryId')->fetchAll();

    // vw_ProductList (Products + Categories)
    $products = $conn->query(
        'SELECT TOP 6 Code, Name, ProductType, Price, OldPrice, DiscountPercent, ImageUrl, Badge, StockQty
         FROM dbo.vw_ProductList WHERE IsBestSeller = 1 ORDER BY SoldCount DESC, ProductId'
    )->fetchAll();

    // vw_FeaturedReviews (Reviews)
    $testimonials = $conn->query(
        'SELECT TOP 3 AuthorName, AuthorRole, AvatarEmoji, AvatarBg, Rating, Content
         FROM dbo.vw_FeaturedReviews ORDER BY CreatedAt, ReviewId'
    )->fetchAll();
} catch (PDOException $ex) {
    error_log('index.php query error: ' . $ex->getMessage());
    http_response_code(500);
    exit('Không tải được dữ liệu. Hãy chắc chắn đã chạy database.sql trên PaperCraftDB.');
}

$years = !empty($siteStats['FoundedYear']) ? max(0, (int)date('Y') - (int)$siteStats['FoundedYear']) : 0;
$stats = [
    [number_format((int)($siteStats['TotalProducts'] ?? 0), 0, ',', '.'),  'Sản phẩm đa dạng',        ''],
    ['20k', 'Khách hàng tin dùng', 'reveal-delay-2'],
    [$years . ' năm',                                                      'Kinh nghiệm thương hiệu', 'reveal-delay-4'],
];

$footerContact = [
    '📍 ' . ($settings['Address'] ?? ''),
    '📞 ' . ($settings['Hotline'] ?? ''),
    '✉️ ' . ($settings['ContactEmail'] ?? ''),
    '⏰ ' . ($settings['WorkingHours'] ?? ''),
];

$catDelays  = ['', 'reveal-delay-2', 'reveal-delay-3', 'reveal-delay-4'];
$prodDelays = ['', 'reveal-delay-2', 'reveal-delay-3'];
?>
<!DOCTYPE html>
<html lang="vi">

<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta name="csrf-token" content="<?= e($_SESSION['csrf']) ?>" />
  <title><?= e($siteName) ?> — Văn Phòng Phẩm</title>
  <link rel="icon" type="image/png" href="icon.png">
  <link
    href="https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,700;1,400&family=DM+Sans:wght@300;400;500&display=swap"
    rel="stylesheet" />
  <link rel="stylesheet" href="styles.css" />
</head>

<body>

  <!-- Custom Cursor -->
  <div class="cursor" id="cursor"></div>
  <div class="cursor-ring" id="cursorRing"></div>

  <!-- NAV -->
  <nav>
    <a href="#" class="logo">Paper<span>Craft</span></a>
    <ul>
      <?php foreach ($navLinks as [$href, $label]): ?>
      <li><a href="<?= e($href) ?>"><?= e($label) ?></a></li>
      <?php endforeach; ?>
    </ul>
    <button class="nav-cart" id="navCartBtn">🛒 Giỏ Hàng <span class="cart-badge" id="cartBadgeCount">0</span></button>
  </nav>

  <!-- HERO -->
  <section class="hero">
    <div class="hero-text">
      <div class="hero-tag">✦ Bộ sưu tập <?= date('Y') ?></div>
      <h1 class="hero-title">Văn Phòng Phẩm<br><em>Tinh Tế &amp; Sang Trọng</em></h1>
      <p class="hero-desc">Nâng tầm không gian làm việc của bạn với những sản phẩm văn phòng phẩm được chọn lọc kỹ lưỡng
        — từ bút cao cấp đến sổ tay thủ công.</p>
      <div class="hero-actions">
        <a href="#products" class="btn-primary">Khám Phá Ngay →</a>
        <a href="#categories" class="btn-ghost">Xem Danh Mục</a>
      </div>
    </div>
    <div class="hero-visual">
      <div class="hero-board">
        <img src="banhoc02.png" alt="Không gian làm việc PaperCraft" />
        <div class="hero-board-overlay"></div>
        <div class="sticker sticker-1">Mới về!</div>
        <div class="sticker sticker-2">–20%</div>
      </div>
    </div>
  </section>

  <!-- TICKER (Banners: ticker) -->
  <div class="ticker">
    <div class="ticker-track">
      <?php for ($i = 0; $i < 2; $i++): ?>
        <?php foreach ($tickerItems as $item): ?>
      <span class="ticker-item"><?= e($item) ?></span>
        <?php endforeach; ?>
      <?php endfor; ?>
    </div>
  </div>

  <!-- STATS (vw_SiteStats) -->
  <div class="stats">
    <?php foreach ($stats as [$num, $label, $delay]): ?>
    <div class="stat reveal <?= e($delay) ?>">
      <div class="stat-num"><?= e($num) ?></div>
      <div class="stat-label"><?= e($label) ?></div>
    </div>
    <?php endforeach; ?>
  </div>

  <!-- CATEGORIES (vw_CategoryList) -->
  <section class="section" id="categories">
    <div class="section-header reveal">
      <h2 class="section-title">Danh Mục<br><span>Nổi Bật</span></h2>
      <a href="#" class="section-link">Xem tất cả →</a>
    </div>
    <div class="cat-grid">
      <?php foreach ($categories as $i => $c): ?>
      <div class="cat-card reveal <?= e($catDelays[$i % 4]) ?>">
        <div class="cat-bg">
          <img src="<?= e($c['ImageUrl']) ?>" alt="<?= e($c['Name']) ?>" />
        </div>
        <div class="cat-info">
          <div class="cat-name"><?= e($c['Name']) ?></div>
          <div class="cat-count"><?= (int)$c['ProductCount'] ?> sản phẩm</div>
        </div>
      </div>
      <?php endforeach; ?>
    </div>
  </section>

  <!-- PRODUCTS (vw_ProductList) -->
  <section class="section" id="products" style="padding-top:0;">
    <div class="section-header reveal">
      <h2 class="section-title">Sản Phẩm<br><span>Bán Chạy</span></h2>
      <a href="#" class="section-link">Xem tất cả →</a>
    </div>
    <div class="prod-grid">
      <?php foreach ($products as $i => $p):
        $soldOut = (int)$p['StockQty'] <= 0; ?>
      <div class="prod-card reveal <?= e($prodDelays[$i % 3]) ?><?= $soldOut ? ' sold-out' : '' ?>"
           data-id="<?= e($p['Code']) ?>"
           data-name="<?= e($p['Name']) ?>">
        <div class="prod-img">
          <img src="<?= e($p['ImageUrl']) ?>" alt="<?= e($p['Name']) ?>" />
          <?php if ($p['Badge'] === 'new'): ?>
          <span class="badge new">Mới</span>
          <?php elseif ($p['Badge'] === 'sale'): ?>
          <span class="badge sale">–<?= (int)$p['DiscountPercent'] ?>%</span>
          <?php endif; ?>
        </div>
        <div class="prod-body">
          <div class="prod-cat"><?= e($p['ProductType']) ?></div>
          <div class="prod-name"><?= e($p['Name']) ?></div>
          <div class="prod-foot">
            <div>
              <span class="prod-price"><?= vnd($p['Price']) ?></span>
              <?php if ($p['OldPrice'] !== null && (int)$p['OldPrice'] > (int)$p['Price']): ?><span class="prod-old"><?= vnd($p['OldPrice']) ?></span><?php endif; ?>
            </div>
            <button class="add-btn"<?= $soldOut ? ' disabled title="Hết hàng"' : '' ?>><?= $soldOut ? '✕' : '+' ?></button>
          </div>
        </div>
      </div>
      <?php endforeach; ?>
    </div>
  </section>

  <!-- BANNER (Banners: promo) -->
  <?php if ($promo):
    [$promoHead, $promoTail] = split_title($promo['Title']); ?>
  <div class="banner reveal">
    <div>
      <div class="banner-title"><?= $promoHead !== '' ? e($promoHead) . '<br>' : '' ?><em><?= e($promoTail) ?></em> 🎉</div>
      <div class="banner-sub"><?= e($promo['SubTitle']) ?></div>
    </div>
    <a href="<?= e(safe_url($promo['LinkUrl'])) ?>" class="banner-btn">Mua Ngay →</a>
  </div>
  <?php endif; ?>

  <!-- TESTIMONIALS (vw_FeaturedReviews) -->
  <section class="section" id="about">
    <div class="section-header reveal">
      <h2 class="section-title">Khách Hàng<br><span>Nói Gì</span></h2>
    </div>
    <div class="testi-grid">
      <?php foreach ($testimonials as $i => $t):
        $rating = max(1, min(5, (int)$t['Rating']));
        $bg = preg_match('/^#[0-9a-fA-F]{3,8}$/', (string)$t['AvatarBg']) ? $t['AvatarBg'] : '#e8e0d4'; ?>
      <div class="testi-card reveal <?= e($prodDelays[$i % 3]) ?>">
        <div class="stars"><?= str_repeat('★', $rating) . str_repeat('☆', 5 - $rating) ?></div>
        <div class="testi-text">"<?= e($t['Content']) ?>"</div>
        <div class="testi-author">
          <div class="testi-avatar" style="background:<?= e($bg) ?>;"><?= e($t['AvatarEmoji']) ?></div>
          <div>
            <div class="testi-name"><?= e($t['AuthorName']) ?></div>
            <div class="testi-role"><?= e($t['AuthorRole']) ?></div>
          </div>
        </div>
      </div>
      <?php endforeach; ?>
    </div>
  </section>

  <!-- NEWSLETTER (NewsletterSubscribers) -->
  <div class="newsletter reveal" id="contact">
    <h2 class="newsletter-title">Nhận Ưu Đãi<br>Mỗi Tuần</h2>
    <p class="newsletter-sub">Đăng ký để nhận thông tin về sản phẩm mới và khuyến mãi độc quyền từ PaperCraft.</p>
    <div class="nl-form">
      <input class="nl-input" type="email" placeholder="Email của bạn..." />
      <button class="nl-btn">Đăng Ký</button>
    </div>
  </div>

  <!-- FOOTER -->
  <footer>
    <div class="footer-grid">
      <div class="footer-brand">
        <span class="logo">Paper<span>Craft</span></span>
        <p class="footer-desc">Chúng tôi mang đến những sản phẩm văn phòng phẩm chất lượng cao, giúp bạn làm việc sáng
          tạo và hiệu quả hơn mỗi ngày.</p>
      </div>
      <div class="footer-col">
        <h4>Sản Phẩm</h4>
        <ul>
          <?php foreach ($categories as $c): ?><li><a href="#products"><?= e($c['Name']) ?></a></li>
          <?php endforeach; ?>
        </ul>
      </div>
      <div class="footer-col">
        <h4>Hỗ Trợ</h4>
        <ul>
          <?php foreach ($footerSupport as $l): ?><li><a href="#"><?= e($l) ?></a></li>
          <?php endforeach; ?>
        </ul>
      </div>
      <div class="footer-col">
        <h4>Liên Hệ</h4>
        <ul>
          <?php foreach ($footerContact as $l): ?><li><a href="#"><?= e($l) ?></a></li>
          <?php endforeach; ?>
        </ul>
      </div>
    </div>
    <div class="footer-bottom">© <?= date('Y') ?> <span>PaperCraft</span>. Thiết kế với ❤️ tại Việt Nam.</div>
  </footer>

  <!-- CART OVERLAY & DRAWER -->
  <div class="cart-overlay" id="cartOverlay"></div>
  <aside class="cart-drawer" id="cartDrawer">
    <div class="cart-header">
      <div class="cart-title-wrap">
        <h3>Giỏ Hàng Của Bạn</h3>
        <span class="cart-item-count-tag" id="cartTotalItemsCount">0 sản phẩm</span>
      </div>
      <button class="cart-close-btn" id="cartCloseBtn">✕</button>
    </div>

    <div class="freeship-box">
      <div class="freeship-text" id="freeshipText"></div>
      <div class="freeship-bar-bg">
        <div class="freeship-bar-fill" id="freeshipBarFill"></div>
      </div>
    </div>

    <div class="cart-body" id="cartBody"></div>

    <div class="cart-footer">
      <div class="cart-summary">
        <div class="summary-row">
          <span>Tạm tính</span>
          <span id="cartSubtotal">0đ</span>
        </div>
        <div class="summary-row">
          <span>Phí vận chuyển</span>
          <span id="cartShipping">—</span>
        </div>
        <div class="summary-row total-row">
          <span>Tổng cộng</span>
          <span id="cartTotal">0đ</span>
        </div>
      </div>
      <div class="cart-actions">
        <button class="btn-checkout" id="btnCheckout">Thanh Toán</button>
        <button class="btn-clear-cart" id="btnClearCart">Xóa hết</button>
      </div>
    </div>
  </aside>

  <!-- CHECKOUT / PAYMENT MODAL (nội dung do main.js dựng) -->
  <div class="co-overlay" id="coOverlay">
    <div class="co-modal" id="coModal" role="dialog" aria-modal="true" aria-labelledby="coTitle">
      <button class="co-close" id="coClose" type="button" aria-label="Đóng">✕</button>
      <div id="coContent"></div>
    </div>
  </div>

  <!-- TOAST CONTAINER -->
  <div class="toast-container" id="toastContainer"></div>

  <button id="scrollTop">↑</button>

  <script src="main.js"></script>
</body>

</html>
