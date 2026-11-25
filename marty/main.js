const WAITLIST_URL = "#"; // TODO: Google Form URL

(() => {
  const doc = document.documentElement;
  doc.classList.add("js");
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Waitlist button
  document.querySelectorAll("[data-waitlist]").forEach((a) => { a.href = WAITLIST_URL; });

  // Hero entrance
  requestAnimationFrame(() => requestAnimationFrame(() => doc.classList.add("is-loaded")));

  // Nav background after scroll
  const nav = document.getElementById("nav");
  const onScroll = () => nav.classList.toggle("is-scrolled", scrollY > 40);
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // Section reveal
  const revealEls = document.querySelectorAll(".sec .wrap > *, .split > *, .safe > *, .steps > li, .trio > div");
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => { if (e.isIntersecting) { e.target.classList.add("is-in"); io.unobserve(e.target); } });
  }, { rootMargin: "0px 0px -10% 0px" });
  revealEls.forEach((el) => { el.classList.add("reveal"); io.observe(el); });

  // 24h dial: the night from 22:00 to 7:00, work blocks light up, then the morning report
  const NS = "http://www.w3.org/2000/svg";
  const C = 200, R = 150;
  const ang = (h) => (h / 24) * 360;
  const pt = (h, r) => {
    const a = (ang(h) - 90) * Math.PI / 180;
    return [C + r * Math.cos(a), C + r * Math.sin(a)];
  };
  const ticks = document.getElementById("dial-ticks");
  for (let i = 0; i < 96; i++) {
    const h = i / 4, major = i % 4 === 0;
    const [x1, y1] = pt(h, 170), [x2, y2] = pt(h, major ? 160 : 165);
    const l = document.createElementNS(NS, "line");
    l.setAttribute("x1", x1); l.setAttribute("y1", y1); l.setAttribute("x2", x2); l.setAttribute("y2", y2);
    l.setAttribute("class", "dial__tick" + (major ? " dial__tick--major" : ""));
    ticks.appendChild(l);
  }
  const blocks = [[22.5, 23.75], [0.5, 2], [3, 4.25], [5.25, 6.5]];
  const blockG = document.getElementById("dial-blocks");
  const arcs = blocks.map(([a, b]) => {
    const [x1, y1] = pt(a, R), [x2, y2] = pt(b, R);
    const p = document.createElementNS(NS, "path");
    p.setAttribute("d", `M${x1} ${y1} A${R} ${R} 0 0 1 ${x2} ${y2}`);
    p.setAttribute("class", "dial__block");
    blockG.appendChild(p);
    return p;
  });
  const hand = document.getElementById("dial-hand");
  const timeEl = document.getElementById("dial-time");
  const night = document.getElementById("night");
  const items = [...document.querySelectorAll("#report li")];
  const START = 22, END = 31; // 31 = 7:00 next morning
  const fmt = (h) => { const m = Math.round((h % 24) * 60); return `${Math.floor(m / 60)}:${String(m % 60).padStart(2, "0")}`; };
  const setTime = (h) => {
    hand.style.transform = `rotate(${ang(h % 24)}deg)`;
    timeEl.textContent = fmt(h);
    blocks.forEach(([a, b], i) => {
      const end = b < START ? b + 24 : b;
      arcs[i].classList.toggle("is-on", h >= end);
    });
  };
  const finish = () => {
    setTime(END);
    items.forEach((li) => li.classList.add("is-in"));
    night.classList.add("is-done");
  };
  if (reduce) { finish(); return; }
  setTime(START);
  const run = () => {
    const dur = 4200;
    let t0;
    const step = (t) => {
      t0 ??= t;
      const k = Math.min(1, (t - t0) / dur);
      const e = 1 - Math.pow(1 - k, 2.2);
      setTime(START + (END - START) * e);
      if (k < 1) requestAnimationFrame(step);
      else items.forEach((li, i) => setTimeout(() => li.classList.add("is-in"), 180 * i + 150));
    };
    requestAnimationFrame(step);
  };
  const nio = new IntersectionObserver((entries) => {
    if (entries[0].isIntersecting) { nio.disconnect(); run(); }
  }, { threshold: 0.45 });
  nio.observe(night);
})();

// Approval demo (nothing is ever sent, it is only a preview)
(() => {
  const box = document.getElementById("approve");
  const state = document.getElementById("approve-state");
  box.addEventListener("click", (e) => {
    const b = e.target.closest("[data-approve]");
    if (!b) return;
    const ok = b.dataset.approve === "ok";
    box.classList.toggle("is-ok", ok);
    state.textContent = ok ? "Schváleno. Teprve teď by e-mail odešel. (Ukázka, nic se neposílá.)" : "Zamítnuto. Draft zůstane uložený, nic neodešlo.";
  });
})();

// Copy-to-clipboard for the install command
document.querySelectorAll("[data-copy]").forEach((b) => {
  b.addEventListener("click", async () => {
    const text = document.querySelector(b.dataset.copy).textContent.trim();
    try { await navigator.clipboard.writeText(text); } catch {
      const r = document.createRange(); r.selectNodeContents(document.querySelector(b.dataset.copy));
      getSelection().removeAllRanges(); getSelection().addRange(r); document.execCommand("copy");
    }
    const old = b.textContent; b.textContent = "Zkopírováno ✓";
    setTimeout(() => { b.textContent = old; }, 1600);
  });
});
