/*
 * Marty's orbs, drawn with the engine of thinking-orbs 0.3.2
 * https://github.com/Jakubantalik/thinking-orbs
 * MIT License, Copyright (c) 2026 Jakub Antalik
 *
 * The framework-free `engine` entry is used (no React), so mobile stays light.
 * If the CDN fails, nothing is mounted and the CSS glow behind each slot remains.
 */
import { resolvePreset, MODE_FRAMES, paintFrame } from "https://esm.sh/thinking-orbs@0.3.2/engine";

const GOLD = { r: 227, g: 196, b: 143 };
const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
const dpr = Math.min(2, devicePixelRatio || 1);

function mount(slot) {
  const state = slot.dataset.orb || "working";
  const size = Math.round(slot.getBoundingClientRect().width) || 20;
  const preset = resolvePreset(state, size >= 48 ? 64 : 20);
  const draw = MODE_FRAMES[preset.mode];
  if (slot.dataset.opts && size >= 300) preset.opts = { ...preset.opts, ...JSON.parse(slot.dataset.opts) };
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = Math.round(size * dpr);
  canvas.style.width = canvas.style.height = size + "px";
  canvas.setAttribute("aria-hidden", "true");
  const ctx = canvas.getContext("2d");
  const paint = (t) => {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, size, size);
    paintFrame(ctx, draw(size, t, preset.opts), true, GOLD);
  };
  slot.appendChild(canvas);
  slot.classList.add("has-orb");
  if (reduce) { paint(0.6); return; }

  let raf = 0, running = false, visible = false;
  const loop = (now) => { paint((now / 1000) * preset.speed); if (running) raf = requestAnimationFrame(loop); };
  const start = () => { if (!running && visible && !document.hidden) { running = true; raf = requestAnimationFrame(loop); } };
  const stop = () => { running = false; cancelAnimationFrame(raf); };
  paint((performance.now() / 1000) * preset.speed);
  new IntersectionObserver(([e]) => { visible = e.isIntersecting; visible ? start() : stop(); }).observe(slot);
  document.addEventListener("visibilitychange", () => (document.hidden ? stop() : start()));
}

document.querySelectorAll("[data-orb]").forEach((slot) => {
  try { mount(slot); } catch (err) { /* keep the static fallback */ }
});
