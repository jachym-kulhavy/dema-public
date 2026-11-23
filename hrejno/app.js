(function () {
  var P = {
    set:      { n: 'Zimní sada Hřejno', p: 890,  img: 'px-5691543-500.jpg' },
    set2:     { n: 'Dvě zimní sady Hřejno', p: 1590, img: 'px-14943497-500.jpg' },
    okno:     { n: 'Fólie na okna', p: 329, img: 'px-10505371-500.jpg' },
    radiator: { n: 'Fólie za radiátor', p: 179, img: 'px-12034871-500.jpg' },
    tesneni:  { n: 'Těsnění oken a dveří', p: 249, img: 'px-4819052-500.jpg' },
    dvere:    { n: 'Ucpávka pod dveře', p: 189, img: 'px-5806980-500.jpg' }
  };
  var cart = {};
  try { cart = JSON.parse(localStorage.getItem('hrejno-cart') || '{}'); } catch (e) {}
  Object.keys(cart).forEach(function (k) { if (!P[k]) delete cart[k]; });

  var $ = function (id) { return document.getElementById(id); };
  var drawer = $('drawer'), scrim = $('scrim'), lastFocus = null;
  var kc = function (n) { return n.toLocaleString('cs-CZ').replace(/ /g, ' ') + ' Kč'; };

  function render() {
    var ids = Object.keys(cart), sub = 0, cnt = 0, ul = $('items');
    ul.innerHTML = '';
    if (!ids.length) ul.innerHTML = '<li class="empty">Košík je prázdný.</li>';
    ids.forEach(function (k) {
      var q = cart[k], it = P[k]; sub += it.p * q; cnt += q;
      var li = document.createElement('li'); li.className = 'it';
      li.innerHTML = '<img src="assets/img/' + it.img + '" alt="" width="72" height="72">' +
        '<div><div class="n">' + it.n + '</div><div class="p">' + kc(it.p) + '</div>' +
        '<div class="qty"><button type="button" data-d="-1" data-k="' + k + '" aria-label="Méně">&minus;</button><span>' + q +
        '</span><button type="button" data-d="1" data-k="' + k + '" aria-label="Více">+</button></div></div>' +
        '<button class="rm" type="button" data-rm="' + k + '">Odebrat</button>';
      ul.appendChild(li);
    });
    var ship = !sub ? 0 : (sub >= 1200 ? 0 : 79);
    $('count').textContent = cnt;
    $('sub').textContent = kc(sub);
    $('ship').textContent = sub && !ship ? 'zdarma' : kc(ship);
    $('total').textContent = kc(sub + ship);
    $('free').textContent = !sub ? '' : (ship ? 'Do dopravy zdarma zbývá ' + kc(1200 - sub) + '.' : 'Doprava je zdarma.');
    $('checkout').disabled = !sub;
    try { localStorage.setItem('hrejno-cart', JSON.stringify(cart)); } catch (e) {}
  }

  function open() {
    lastFocus = document.activeElement;
    drawer.classList.add('on'); scrim.classList.add('on'); drawer.setAttribute('aria-hidden', 'false');
    $('notice').hidden = true;
    $('close-cart').focus();
  }
  function close() {
    drawer.classList.remove('on'); scrim.classList.remove('on'); drawer.setAttribute('aria-hidden', 'true');
    if (lastFocus) lastFocus.focus();
  }

  document.addEventListener('click', function (e) {
    var t = e.target.closest('button'); if (!t) return;
    if (t.dataset.add) { cart[t.dataset.add] = (cart[t.dataset.add] || 0) + 1; render(); open(); }
    else if (t.dataset.d) {
      var k = t.dataset.k; cart[k] += +t.dataset.d; if (cart[k] < 1) delete cart[k]; render();
    }
    else if (t.dataset.rm) { delete cart[t.dataset.rm]; render(); }
  });
  $('open-cart').addEventListener('click', open);
  $('close-cart').addEventListener('click', close);
  scrim.addEventListener('click', close);
  $('checkout').addEventListener('click', function () { $('notice').hidden = false; });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && drawer.classList.contains('on')) close();
    if (e.key === 'Tab' && drawer.classList.contains('on')) {
      var f = drawer.querySelectorAll('button:not([disabled])'); if (!f.length) return;
      var a = f[0], z = f[f.length - 1];
      if (e.shiftKey && document.activeElement === a) { e.preventDefault(); z.focus(); }
      else if (!e.shiftKey && document.activeElement === z) { e.preventDefault(); a.focus(); }
    }
  });
  render();
})();
