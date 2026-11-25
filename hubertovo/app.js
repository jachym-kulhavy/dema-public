const nav = document.querySelector('.nav');
const sticky = document.querySelector('.sticky');
const onScroll = () => {
  const y = window.scrollY;
  nav.classList.toggle('solid', y > 40);
  sticky.classList.toggle('show', y > window.innerHeight * 0.8);
};
addEventListener('scroll', onScroll, { passive: true });
onScroll();

const io = new IntersectionObserver((entries) => {
  for (const e of entries) if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
}, { rootMargin: '0px 0px -8% 0px' });
document.querySelectorAll('.reveal').forEach((el) => io.observe(el));
