// ── Custom Cursor ──
const cursor = document.getElementById('cursor');
const cursorRing = document.getElementById('cursorRing');
let mx = 0, my = 0, rx = 0, ry = 0;

document.addEventListener('mousemove', e => { mx = e.clientX; my = e.clientY; });

function animCursor() {
  cursor.style.left = (mx - 6) + 'px';
  cursor.style.top = (my - 6) + 'px';
  rx += (mx - rx) * 0.12;
  ry += (my - ry) * 0.12;
  cursorRing.style.left = (rx - 18) + 'px';
  cursorRing.style.top = (ry - 18) + 'px';
  requestAnimationFrame(animCursor);
}
animCursor();

// Delegate cursor hover for dynamic and static interactive elements
const HOVER_SELECTOR = 'a, button, label, .cat-card, .prod-card, .testi-card, .stat, .nav-cart, .qty-btn, .cart-item-remove, .cart-close-btn, .btn-shop-now';
document.addEventListener('mouseover', e => {
  if (e.target.closest(HOVER_SELECTOR)) {
    cursor.classList.add('hover');
    cursorRing.classList.add('hover');
  }
});
document.addEventListener('mouseout', e => {
  if (e.target.closest(HOVER_SELECTOR)) {
    cursor.classList.remove('hover');
    cursorRing.classList.remove('hover');
  }
});

// ── Ripple on click ──
document.addEventListener('click', e => {
  const r = document.createElement('div');
  r.className = 'ripple';
  r.style.cssText = `left:${e.clientX - 20}px;top:${e.clientY - 20}px;width:40px;height:40px;`;
  document.body.appendChild(r);
  setTimeout(() => r.remove(), 700);
});

// ── Scroll reveal ──
const reveals = document.querySelectorAll('.reveal');
const obs = new IntersectionObserver(entries => {
  entries.forEach(en => {
    if (en.isIntersecting) en.target.classList.add('visible');
  });
}, { threshold: 0.12 });
reveals.forEach(el => obs.observe(el));

// ── Scroll-to-top ──
const topBtn = document.getElementById('scrollTop');
window.addEventListener('scroll', () => topBtn.classList.toggle('show', window.scrollY > 400));
topBtn.addEventListener('click', () => window.scrollTo({ top: 0, behavior: 'smooth' }));

// ============================================================
//  Helpers & API
// ============================================================
const csrfToken = (document.querySelector('meta[name="csrf-token"]') || {}).content || '';

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function formatVND(num) {
  return Number(num).toLocaleString('vi-VN') + 'đ';
}

async function api(action, data = {}) {
  let res;
  try {
    res = await fetch('api.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrfToken },
      body: JSON.stringify({ action, ...data })
    });
  } catch (err) {
    throw new Error('Không thể kết nối máy chủ. Vui lòng thử lại.');
  }
  let json;
  try { json = await res.json(); } catch (err) { throw new Error('Máy chủ phản hồi không hợp lệ.'); }
  if (!json.ok) throw new Error(json.error || 'Có lỗi xảy ra.');
  return json;
}

// ============================================================
//  Cart (dữ liệu nằm trong DB: Carts / CartItems)
// ============================================================
let cart = { items: [], totals: { items: 0, subtotal: 0, shipping: 0, total: 0, remaining: 0, percent: 0 } };

const navCartBtn = document.getElementById('navCartBtn');
const cartBadgeCount = document.getElementById('cartBadgeCount');
const cartOverlay = document.getElementById('cartOverlay');
const cartCloseBtn = document.getElementById('cartCloseBtn');
const cartBody = document.getElementById('cartBody');
const cartTotalItemsCount = document.getElementById('cartTotalItemsCount');
const cartSubtotal = document.getElementById('cartSubtotal');
const cartTotal = document.getElementById('cartTotal');
const cartShipping = document.getElementById('cartShipping');
const freeshipText = document.getElementById('freeshipText');
const freeshipBarFill = document.getElementById('freeshipBarFill');
const btnCheckout = document.getElementById('btnCheckout');
const btnClearCart = document.getElementById('btnClearCart');
const toastContainer = document.getElementById('toastContainer');

function openCart() { document.body.classList.add('cart-drawer-open'); }
function closeCart() { document.body.classList.remove('cart-drawer-open'); }

if (navCartBtn) navCartBtn.addEventListener('click', openCart);
if (cartCloseBtn) cartCloseBtn.addEventListener('click', closeCart);
if (cartOverlay) cartOverlay.addEventListener('click', closeCart);

document.addEventListener('keydown', e => {
  if (e.key !== 'Escape') return;
  if (document.body.classList.contains('checkout-open')) closeCheckout();
  else if (document.body.classList.contains('cart-drawer-open')) closeCart();
});

function triggerBadgeAnimation() {
  if (!navCartBtn) return;
  navCartBtn.classList.remove('badge-bounce');
  void navCartBtn.offsetWidth; // trigger reflow
  navCartBtn.classList.add('badge-bounce');
}

// msg là HTML đã được escape bởi nơi gọi
function showToast(msg, icon = '🛍️') {
  if (!toastContainer) return;
  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.innerHTML = `<span class="toast-icon">${icon}</span><span>${msg}</span>`;
  toastContainer.appendChild(toast);
  setTimeout(() => toast.remove(), 3000);
}

const toastError = err => showToast(esc(err.message), '⚠️');

function renderCart() {
  const t = cart.totals;

  if (cartBadgeCount) cartBadgeCount.textContent = t.items;
  if (cartTotalItemsCount) cartTotalItemsCount.textContent = `${t.items} sản phẩm`;

  // Thanh miễn phí vận chuyển (ngưỡng & phí ship lấy từ DB qua sp_GetCart)
  if (t.items > 0 && t.remaining === 0) {
    freeshipText.innerHTML = `🎉 Bạn đã đủ điều kiện <span>Miễn Phí Vận Chuyển</span>!`;
    freeshipBarFill.style.width = '100%';
  } else {
    freeshipText.innerHTML = `🚀 Mua thêm <strong>${formatVND(t.remaining)}</strong> để được <span>Miễn Phí Vận Chuyển</span>`;
    freeshipBarFill.style.width = `${t.percent}%`;
  }

  if (cartShipping) cartShipping.textContent = t.items === 0 ? '—' : (t.shipping === 0 ? 'Miễn phí' : formatVND(t.shipping));
  if (cartSubtotal) cartSubtotal.textContent = formatVND(t.subtotal);
  if (cartTotal) cartTotal.textContent = formatVND(t.total);

  if (cart.items.length === 0) {
    cartBody.innerHTML = `
      <div class="cart-empty-state">
        <div class="cart-empty-icon">🛍️</div>
        <div class="cart-empty-title">Giỏ hàng của bạn đang trống</div>
        <div class="cart-empty-sub">Hãy khám phá các sản phẩm văn phòng phẩm tinh tế của PaperCraft và thêm vào giỏ nhé!</div>
        <button class="btn-shop-now" id="btnShopNow">Khám Phá Sản Phẩm</button>
      </div>
    `;
    const btnShopNow = document.getElementById('btnShopNow');
    if (btnShopNow) {
      btnShopNow.addEventListener('click', () => {
        closeCart();
        const prodSection = document.getElementById('products');
        if (prodSection) prodSection.scrollIntoView({ behavior: 'smooth' });
      });
    }
    if (btnCheckout) btnCheckout.disabled = true;
    if (btnClearCart) btnClearCart.style.display = 'none';
  } else {
    if (btnCheckout) btnCheckout.disabled = false;
    if (btnClearCart) btnClearCart.style.display = 'block';

    cartBody.innerHTML = cart.items.map(item => `
      <div class="cart-item" data-id="${esc(item.id)}">
        <div class="cart-item-img">
          <img src="${esc(item.img)}" alt="${esc(item.name)}"/>
        </div>
        <div class="cart-item-info">
          <div class="cart-item-cat">${esc(item.cat || 'Văn phòng phẩm')}</div>
          <div class="cart-item-title">${esc(item.name)}</div>
          <div class="cart-item-price-wrap">
            <span class="cart-item-unit-price">${formatVND(item.price)}</span>
          </div>
          <div class="cart-item-controls">
            <div class="qty-control">
              <button class="qty-btn qty-minus" data-id="${esc(item.id)}" title="Giảm số lượng">-</button>
              <span class="qty-num">${item.qty}</span>
              <button class="qty-btn qty-plus" data-id="${esc(item.id)}" title="Tăng số lượng">+</button>
            </div>
          </div>
        </div>
        <button class="cart-item-remove" data-id="${esc(item.id)}" title="Xóa khỏi giỏ hàng">🗑️</button>
      </div>
    `).join('');
  }
}

async function loadCart() {
  try {
    cart = (await api('cart_get')).cart;
  } catch (err) {
    toastError(err);
  }
  renderCart();
}

// ── Add to cart buttons ──
document.querySelectorAll('.prod-card').forEach(card => {
  const addBtn = card.querySelector('.add-btn');
  if (!addBtn || addBtn.disabled) return;

  addBtn.addEventListener('click', async e => {
    e.stopPropagation();
    if (addBtn.dataset.busy) return;
    addBtn.dataset.busy = '1';

    const id = card.dataset.id;
    const name = card.dataset.name;
    try {
      cart = (await api('cart_add', { code: id, qty: 1 })).cart;
      renderCart();
      triggerBadgeAnimation();
      showToast(`Đã thêm <strong>${esc(name)}</strong> vào giỏ!`);

      addBtn.textContent = '✓';
      addBtn.style.background = '#6b8c6b';
      setTimeout(() => {
        addBtn.textContent = '+';
        addBtn.style.background = '';
      }, 1000);
    } catch (err) {
      toastError(err);
    } finally {
      delete addBtn.dataset.busy;
    }
  });
});

// ── Cart body: +, -, delete ──
if (cartBody) {
  cartBody.addEventListener('click', async e => {
    const plusBtn = e.target.closest('.qty-plus');
    const minusBtn = e.target.closest('.qty-minus');
    const removeBtn = e.target.closest('.cart-item-remove');
    const btn = plusBtn || minusBtn || removeBtn;
    if (!btn || btn.dataset.busy) return;

    const id = btn.dataset.id;
    const item = cart.items.find(i => i.id === id);
    if (!item) return;

    btn.dataset.busy = '1';
    try {
      if (plusBtn) {
        cart = (await api('cart_set', { code: id, qty: item.qty + 1 })).cart;
      } else if (minusBtn) {
        cart = (await api('cart_set', { code: id, qty: item.qty - 1 })).cart;
        if (item.qty <= 1) showToast(`Đã xóa <strong>${esc(item.name)}</strong> khỏi giỏ!`);
      } else {
        cart = (await api('cart_remove', { code: id })).cart;
        showToast(`Đã xóa <strong>${esc(item.name)}</strong> khỏi giỏ!`);
      }
      renderCart();
      triggerBadgeAnimation();
    } catch (err) {
      toastError(err);
    } finally {
      delete btn.dataset.busy;
    }
  });
}

// ── Clear Cart ──
if (btnClearCart) {
  btnClearCart.addEventListener('click', async () => {
    if (cart.items.length === 0) return;
    if (!confirm('Bạn có chắc chắn muốn xóa toàn bộ sản phẩm khỏi giỏ hàng?')) return;
    try {
      cart = (await api('cart_clear')).cart;
      renderCart();
      triggerBadgeAnimation();
      showToast('Đã xóa toàn bộ giỏ hàng!');
    } catch (err) {
      toastError(err);
    }
  });
}

// ============================================================
//  Checkout & Payment modal
// ============================================================
const coContent = document.getElementById('coContent');
const coOverlay = document.getElementById('coOverlay');
const coClose = document.getElementById('coClose');
let pollTimer = null;
let couponPreview = null;     // {coupon, discount, free_ship, shipping}

function stopPolling() {
  if (pollTimer) { clearInterval(pollTimer); pollTimer = null; }
}

function openCheckout() {
  if (cart.items.length === 0) return;
  closeCart();
  couponPreview = null;
  renderCheckoutForm();
  document.body.classList.add('checkout-open');
}

function closeCheckout() {
  document.body.classList.remove('checkout-open');
  stopPolling();
}

if (btnCheckout) btnCheckout.addEventListener('click', openCheckout);
if (coClose) coClose.addEventListener('click', closeCheckout);
if (coOverlay) coOverlay.addEventListener('click', e => { if (e.target === coOverlay) closeCheckout(); });

const linesHtml = items => items.map(i =>
  `<li class="co-line"><span class="co-line-name">${esc(i.name)} <em>× ${i.qty}</em></span><span>${formatVND(i.line)}</span></li>`
).join('');

function totalsHtml({ subtotal, shipping, discount, total }) {
  return `
    <div class="summary-row"><span>Tạm tính</span><span>${formatVND(subtotal)}</span></div>
    <div class="summary-row"><span>Phí vận chuyển</span><span>${shipping === 0 ? 'Miễn phí' : formatVND(shipping)}</span></div>
    ${discount > 0 ? `<div class="summary-row"><span>Giảm giá</span><span>-${formatVND(discount)}</span></div>` : ''}
    <div class="summary-row total-row"><span>Tổng cộng</span><span>${formatVND(total)}</span></div>`;
}

function formTotals() {
  const t = cart.totals;
  let shipping = t.shipping, discount = 0;
  if (couponPreview) {
    discount = couponPreview.discount;
    if (couponPreview.free_ship) shipping = 0;
  }
  return { subtotal: t.subtotal, shipping, discount, total: t.subtotal + shipping - discount };
}

function updateFormTotals() {
  const box = document.getElementById('coTotals');
  if (box) box.innerHTML = totalsHtml(formTotals());
}

// ── Bước 1: thông tin nhận hàng ──
function renderCheckoutForm() {
  coContent.innerHTML = `
    <div class="co-grid">
      <form class="co-form" id="coForm" novalidate>
        <h3 class="co-title" id="coTitle">Thông Tin Đặt Hàng</h3>
        <p class="co-sub">Điền thông tin nhận hàng, sau đó chọn cách thanh toán.</p>

        <div class="co-field">
          <label for="coName">Họ và tên</label>
          <input id="coName" name="receiver" maxlength="100" autocomplete="name" required />
        </div>
        <div class="co-row">
          <div class="co-field">
            <label for="coPhone">Số điện thoại</label>
            <input id="coPhone" name="phone" type="tel" maxlength="15" autocomplete="tel" required />
          </div>
          <div class="co-field">
            <label for="coEmail">Email (không bắt buộc)</label>
            <input id="coEmail" name="email" type="email" maxlength="150" autocomplete="email" />
          </div>
        </div>
        <div class="co-field">
          <label for="coAddress">Địa chỉ giao hàng</label>
          <input id="coAddress" name="address" maxlength="400" autocomplete="street-address" placeholder="Số nhà, đường, phường/xã, quận/huyện, tỉnh/thành" required />
        </div>
        <div class="co-field">
          <label for="coNote">Ghi chú (không bắt buộc)</label>
          <input id="coNote" name="note" maxlength="500" />
        </div>
        <div class="co-field">
          <label for="coCoupon">Mã giảm giá</label>
          <div class="co-coupon">
            <input id="coCoupon" name="coupon" maxlength="30" placeholder="Ví dụ: WELCOME10" autocomplete="off" />
            <button type="button" class="co-btn ghost" id="coApplyCoupon">Áp dụng</button>
          </div>
          <div class="co-hint" id="coCouponMsg" aria-live="polite"></div>
        </div>

        <div class="co-field">
          <label>Phương thức thanh toán</label>
          <div class="pay-options">
            <label class="pay-option">
              <input type="radio" name="payment_method" value="BankTransfer" checked />
              <span class="pay-box"><strong>Chuyển khoản QR</strong><small>Quét mã bằng app ngân hàng</small></span>
            </label>
            <label class="pay-option">
              <input type="radio" name="payment_method" value="COD" />
              <span class="pay-box"><strong>Thanh toán khi nhận hàng</strong><small>COD</small></span>
            </label>
          </div>
        </div>

        <div class="co-error" id="coError" role="alert" hidden></div>
        <button class="co-btn" id="coSubmit" type="submit">Đặt hàng</button>
      </form>

      <aside class="co-summary">
        <h4>Đơn hàng của bạn</h4>
        <ul class="co-lines">${linesHtml(cart.items)}</ul>
        <div class="co-totals" id="coTotals">${totalsHtml(formTotals())}</div>
      </aside>
    </div>`;
  setTimeout(() => { const n = document.getElementById('coName'); if (n) n.focus(); }, 300);
}

// ── Bước 2: thông tin đơn hàng (dùng cho cả QR và COD) ──
function orderInfoHtml(o) {
  const pm = o.method === 'BankTransfer' ? 'Chuyển khoản ngân hàng (QR)' : 'Thanh toán khi nhận hàng (COD)';
  return `
    <section class="co-order">
      <h4>Thông tin đơn hàng</h4>
      <dl class="co-info">
        <dt>Mã đơn hàng</dt><dd><strong>${esc(o.code)}</strong></dd>
        <dt>Thời gian đặt</dt><dd>${esc(o.created_at)}</dd>
        <dt>Người nhận</dt><dd>${esc(o.receiver)}</dd>
        <dt>Số điện thoại</dt><dd>${esc(o.phone)}</dd>
        ${o.email ? `<dt>Email</dt><dd>${esc(o.email)}</dd>` : ''}
        <dt>Địa chỉ giao hàng</dt><dd>${esc(o.address)}</dd>
        ${o.note ? `<dt>Ghi chú</dt><dd>${esc(o.note)}</dd>` : ''}
        <dt>Thanh toán</dt><dd>${pm}</dd>
      </dl>
      <ul class="co-lines">${linesHtml(o.items)}</ul>
      <div class="co-totals">${totalsHtml(o)}</div>
    </section>`;
}

const bankRow = (label, value, opts = {}) => `
  <div class="co-bank-row">
    <div>
      <span class="co-bank-label">${label}</span>
      <span class="co-bank-value${opts.accent ? ' accent' : ''}">${esc(value)}</span>
    </div>
    ${opts.copy ? `<button type="button" class="copy-btn" data-copy="${esc(opts.copy)}">Sao chép</button>` : ''}
  </div>`;

function renderPayment(o, p) {
  coContent.innerHTML = `
    <div class="co-head">
      <div>
        <h3 class="co-title" id="coTitle">Thanh toán đơn hàng</h3>
        <p class="co-sub">Quét mã QR bằng ứng dụng ngân hàng hoặc chuyển khoản thủ công theo thông tin bên cạnh.</p>
      </div>
      <span class="co-pill" id="coPill" data-state="waiting"><i></i><span id="coPillText">Chờ thanh toán</span></span>
    </div>

    <div class="co-grid pay">
      <div class="co-qr">
        <img id="coQrImg" src="${esc(p.qr_url)}" alt="Mã QR chuyển khoản đơn ${esc(o.code)}" width="300" height="300" />
        <p class="co-qr-fallback" id="coQrFallback" hidden>Không tải được mã QR. Vui lòng chuyển khoản thủ công theo thông tin bên cạnh.</p>
        <p class="co-qr-hint">Mở app ngân hàng → Quét mã QR</p>
        <div class="co-qr-amount">${formatVND(p.amount)}</div>
      </div>

      <div class="co-right">
        <div class="co-bank">
          ${bankRow('Ngân hàng thụ hưởng', p.bank_name)}
          ${bankRow('Số tài khoản', p.account_no, { copy: p.account_no })}
          ${bankRow('Chủ tài khoản', p.account_name)}
          ${bankRow('Số tiền thanh toán', formatVND(p.amount), { copy: String(p.amount), accent: true })}
          ${bankRow('Nội dung chuyển khoản', p.content, { copy: p.content })}
        </div>
        <p class="co-notice">Vui lòng nhập <strong>đúng số tiền</strong> và <strong>nội dung chuyển khoản</strong> để đơn hàng được xác nhận nhanh nhất.</p>
        ${orderInfoHtml(o)}
      </div>
    </div>

    <div class="co-actions">
      <button class="co-btn" id="coPaid" type="button">Tôi đã chuyển khoản</button>
      <button class="co-btn ghost" id="coContinue" type="button">Tiếp tục mua sắm</button>
    </div>
    <p class="co-paid-note" id="coPaidNote" hidden>Cảm ơn bạn! Đơn hàng sẽ được xác nhận ngay khi chúng tôi nhận được tiền (thường trong vài phút).</p>`;

  const img = document.getElementById('coQrImg');
  img.addEventListener('error', () => {
    img.hidden = true;
    document.getElementById('coQrFallback').hidden = false;
  });
  coContent.scrollTop = 0;
  document.getElementById('coModal').scrollTop = 0;
  startPolling(o.code);
}

function renderCodSuccess(o) {
  coContent.innerHTML = `
    <div class="co-success">
      <div class="co-success-icon">✓</div>
      <h3 class="co-title" id="coTitle">Đặt hàng thành công!</h3>
      <p class="co-sub">Bạn sẽ thanh toán <strong>${formatVND(o.total)}</strong> khi nhận hàng. Chúng tôi sẽ liên hệ xác nhận trong thời gian sớm nhất.</p>
    </div>
    ${orderInfoHtml(o)}
    <div class="co-actions">
      <button class="co-btn" id="coContinue" type="button">Tiếp tục mua sắm</button>
    </div>`;
  document.getElementById('coModal').scrollTop = 0;
}

function markPaid() {
  const pill = document.getElementById('coPill');
  if (!pill) return;
  pill.dataset.state = 'paid';
  document.getElementById('coPillText').textContent = 'Đã thanh toán';
  const paidBtn = document.getElementById('coPaid');
  if (paidBtn) paidBtn.hidden = true;
  const note = document.getElementById('coPaidNote');
  if (note) { note.hidden = false; note.textContent = '🎉 Chúng tôi đã nhận được thanh toán. Cảm ơn bạn đã mua hàng tại PaperCraft!'; }
  showToast('Đã nhận được thanh toán của bạn!', '✅');
}

// Hỏi server mỗi 5 giây (tối đa 15 phút) xem đơn đã được ghi nhận "Paid" chưa
function startPolling(code) {
  stopPolling();
  let tries = 0;
  pollTimer = setInterval(async () => {
    if (++tries > 180) return stopPolling();
    try {
      const r = await api('order_status', { code });
      if (r.payment_status === 'Paid') { stopPolling(); markPaid(); }
    } catch (err) { /* bỏ qua, thử lại lần sau */ }
  }, 5000);
}

async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
  } catch (err) {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.cssText = 'position:fixed;opacity:0;';
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    ta.remove();
  }
}

// ── Sự kiện trong modal (event delegation) ──
if (coContent) {
  coContent.addEventListener('click', async e => {
    const copyBtn = e.target.closest('.copy-btn');
    if (copyBtn) {
      await copyText(copyBtn.dataset.copy);
      copyBtn.textContent = 'Đã chép ✓';
      setTimeout(() => { copyBtn.textContent = 'Sao chép'; }, 1500);
      return;
    }

    if (e.target.closest('#coContinue')) {
      closeCheckout();
      const prodSection = document.getElementById('products');
      if (prodSection) prodSection.scrollIntoView({ behavior: 'smooth' });
      return;
    }

    if (e.target.closest('#coPaid')) {
      e.target.closest('#coPaid').disabled = true;
      document.getElementById('coPillText').textContent = 'Đang chờ xác nhận';
      document.getElementById('coPaidNote').hidden = false;
      return;
    }

    if (e.target.closest('#coApplyCoupon')) {
      const input = document.getElementById('coCoupon');
      const msg = document.getElementById('coCouponMsg');
      const code = input.value.trim();
      couponPreview = null;
      msg.className = 'co-hint';
      if (!code) { msg.textContent = ''; updateFormTotals(); return; }
      try {
        const r = await api('coupon_check', { code });
        couponPreview = r;
        msg.classList.add('ok');
        msg.textContent = r.free_ship ? 'Đã áp dụng: miễn phí vận chuyển.' : `Đã áp dụng: giảm ${formatVND(r.discount)}.`;
      } catch (err) {
        msg.classList.add('bad');
        msg.textContent = err.message;
      }
      updateFormTotals();
    }
  });

  // Sửa mã giảm giá sau khi đã áp dụng -> bỏ xem trước
  coContent.addEventListener('input', e => {
    if (e.target.id === 'coCoupon' && couponPreview) {
      couponPreview = null;
      const msg = document.getElementById('coCouponMsg');
      msg.textContent = '';
      msg.className = 'co-hint';
      updateFormTotals();
    }
  });

  coContent.addEventListener('submit', async e => {
    if (e.target.id !== 'coForm') return;
    e.preventDefault();

    const form = e.target;
    const errBox = document.getElementById('coError');
    const submit = document.getElementById('coSubmit');
    const fd = new FormData(form);
    const payload = {
      receiver: String(fd.get('receiver') || '').trim(),
      phone: String(fd.get('phone') || '').trim(),
      email: String(fd.get('email') || '').trim(),
      address: String(fd.get('address') || '').trim(),
      note: String(fd.get('note') || '').trim(),
      coupon: String(fd.get('coupon') || '').trim(),
      payment_method: String(fd.get('payment_method') || 'BankTransfer')
    };

    const showErr = msg => { errBox.textContent = msg; errBox.hidden = false; };
    errBox.hidden = true;

    if (!payload.receiver) return showErr('Vui lòng nhập họ và tên.');
    if (!/^(\+84|0)\d{9,10}$/.test(payload.phone.replace(/[\s.\-]/g, ''))) return showErr('Số điện thoại không hợp lệ.');
    if (payload.address.length < 8) return showErr('Vui lòng nhập địa chỉ giao hàng đầy đủ.');

    submit.disabled = true;
    submit.textContent = 'Đang xử lý...';
    try {
      const r = await api('checkout', payload);
      await loadCart();                 // giỏ cũ đã CheckedOut -> giỏ mới trống
      triggerBadgeAnimation();
      if (r.payment) renderPayment(r.order, r.payment);
      else renderCodSuccess(r.order);
    } catch (err) {
      showErr(err.message);
      submit.disabled = false;
      submit.textContent = 'Đặt hàng';
    }
  });
}

// ── Newsletter (NewsletterSubscribers) ──
const nlBtn = document.querySelector('.nl-btn');
if (nlBtn) {
  nlBtn.addEventListener('click', async () => {
    const inp = document.querySelector('.nl-input');
    const email = inp ? inp.value.trim() : '';
    if (!email) return;
    nlBtn.disabled = true;
    try {
      const r = await api('newsletter', { email });
      inp.value = '';
      showToast(esc(r.message), '🎉');
    } catch (err) {
      toastError(err);
    } finally {
      nlBtn.disabled = false;
    }
  });
}

// Initial render on load
loadCart();
