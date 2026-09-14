/// The page a phone loads to control the presenter.
///
/// One file with nothing to fetch: the phone is on a church network that may
/// have no internet, so every style and script is right here.
const remotePageHtml = r'''<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover,user-scalable=no">
<meta name="theme-color" content="#111214">
<meta name="apple-mobile-web-app-capable" content="yes">
<title>Introduce</title>
<style>
  :root { color-scheme: dark; --bg:#111214; --card:#1c1d21; --line:#2c2d33; --text:#f4f4f5;
    --muted:#9a9ba3; --accent:#0a84ff; --live:#ff3b30; --warn:#ff9f0a; }
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  html, body { margin: 0; height: 100%; background: var(--bg); color: var(--text);
    font: 16px/1.35 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
  body { display: flex; flex-direction: column; padding: env(safe-area-inset-top) 16px
    calc(env(safe-area-inset-bottom) + 12px); }
  header { display: flex; align-items: center; gap: 10px; padding: 14px 2px 10px; }
  .dot { width: 9px; height: 9px; border-radius: 50%; background: var(--warn); flex: none; }
  .dot.on { background: #30d158; }
  .name { flex: 1; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .pill { font-size: 12px; font-weight: 700; letter-spacing: .4px; padding: 4px 9px; border-radius: 99px;
    background: var(--card); color: var(--muted); border: 1px solid var(--line); }
  .pill.live { background: var(--live); color: #fff; border-color: var(--live); }
  main { flex: 1; display: flex; flex-direction: column; gap: 12px; min-height: 0; }
  .screen { background: #000; border: 2px solid var(--line); border-radius: 14px; padding: 18px;
    min-height: 34vh; display: flex; flex-direction: column; justify-content: center; text-align: center; }
  .screen.live { border-color: var(--live); }
  .screen .title { color: var(--muted); font-size: 13px; margin-bottom: 8px; }
  .screen .words { font-size: 21px; white-space: pre-line; }
  .screen .state { color: var(--muted); font-size: 17px; }
  .next { color: var(--muted); font-size: 14px; white-space: pre-line; padding: 0 4px;
    display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
  .next b { color: var(--text); font-weight: 600; font-size: 12px; letter-spacing: .5px; }
  .row { display: flex; gap: 10px; }
  button { font: inherit; color: var(--text); background: var(--card); border: 1px solid var(--line);
    border-radius: 14px; padding: 14px; flex: 1; font-weight: 600; touch-action: manipulation; }
  button:active { transform: scale(.98); background: #26272c; }
  button:disabled { opacity: .4; }
  .big { font-size: 20px; padding: 26px 10px; }
  .primary { background: var(--accent); border-color: var(--accent); color: #fff; }
  .on-live { background: var(--live); border-color: var(--live); color: #fff; }
  .on-blank { background: #3a3a3c; }
  .send { background: var(--warn); border-color: var(--warn); color: #111; }
  .list { background: var(--card); border: 1px solid var(--line); border-radius: 14px; overflow: auto;
    max-height: 32vh; }
  .list div { padding: 13px 14px; border-bottom: 1px solid var(--line); display: flex; gap: 10px; }
  .list div:last-child { border-bottom: 0; }
  .list div.cur { background: rgba(10,132,255,.16); }
  .list div.air::after { content: "●"; color: var(--live); margin-left: auto; }
  .list span.n { color: var(--muted); width: 22px; flex: none; text-align: right; }
  .hidden { display: none !important; }
  #pair { flex: 1; display: flex; flex-direction: column; justify-content: center; gap: 16px; text-align: center; }
  #pair h1 { font-size: 22px; margin: 0; }
  #pair p { color: var(--muted); margin: 0; }
  #pin { font: 600 34px/1 ui-monospace, Menlo, monospace; letter-spacing: 12px; text-align: center;
    background: var(--card); color: var(--text); border: 1px solid var(--line); border-radius: 14px;
    padding: 16px; width: 100%; }
  .error { color: var(--live); min-height: 20px; }
</style>
</head>
<body>
<section id="pair">
  <h1 data-t="pairTitle"></h1>
  <p data-t="pairHelp"></p>
  <input id="pin" inputmode="numeric" autocomplete="one-time-code" maxlength="6" placeholder="••••••">
  <button class="primary big" id="pairBtn" data-t="connect"></button>
  <div class="error" id="pairError"></div>
</section>

<section id="app" class="hidden" style="flex:1;display:flex;flex-direction:column;min-height:0">
  <header>
    <span class="dot" id="dot"></span>
    <span class="name" id="name">Introduce</span>
    <span class="pill" id="livePill"></span>
  </header>
  <main>
    <div class="screen" id="screen"></div>
    <div class="next" id="next"></div>
    <div class="row">
      <button class="big" id="prev">◀</button>
      <button class="big primary" id="nextBtn">▶</button>
    </div>
    <div class="row">
      <button id="live" data-t="live"></button>
      <button id="blank" data-t="blank"></button>
      <button id="take" class="send hidden" data-t="send"></button>
    </div>
    <div class="list" id="list"></div>
  </main>
</section>

<script>
(() => {
  const dict = {
    es: { pairTitle: 'Controlar Introduce', pairHelp: 'Escribe el PIN que aparece en la computadora.',
      connect: 'Conectar', wrong: 'PIN incorrecto.', locked: 'Demasiados intentos. Espera un minuto.',
      offline: 'No se pudo conectar. ¿Estás en la misma red Wi-Fi?', live: 'En vivo', onAir: 'EN VIVO',
      offAir: 'Apagado', blank: 'Negro', send: 'Enviar', next: 'SIGUE', black: 'Pantalla en negro',
      nothing: 'Nada en pantalla', waiting: 'Pantalla de espera', noCollection: 'Sin colección abierta' },
    en: { pairTitle: 'Control Introduce', pairHelp: 'Type the PIN shown on the computer.',
      connect: 'Connect', wrong: 'Wrong PIN.', locked: 'Too many tries. Wait a minute.',
      offline: 'Could not connect. Are you on the same Wi-Fi network?', live: 'Live', onAir: 'LIVE',
      offAir: 'Off', blank: 'Black', send: 'Send', next: 'NEXT', black: 'Screen is black',
      nothing: 'Nothing on screen', waiting: 'Waiting screen', noCollection: 'No collection open' },
  };
  let lang = (navigator.language || 'es').toLowerCase().startsWith('es') ? 'es' : 'en';
  const t = (k) => (dict[lang] || dict.es)[k] || k;
  const $ = (id) => document.getElementById(id);
  const translate = () => document.querySelectorAll('[data-t]').forEach((el) => { el.textContent = t(el.dataset.t); });
  translate();

  const storeKey = 'introduce.remote.' + location.host;
  let token = localStorage.getItem(storeKey);
  let socket, state, retry = 0, wakeLock;

  const show = (paired) => {
    $('pair').classList.toggle('hidden', paired);
    $('app').classList.toggle('hidden', !paired);
  };

  async function pair(pin) {
    $('pairError').textContent = '';
    try {
      const res = await fetch('/pair', { method: 'POST', body: JSON.stringify({ pin }),
        headers: { 'Content-Type': 'application/json' } });
      if (res.status === 429) { $('pairError').textContent = t('locked'); return; }
      if (!res.ok) { $('pairError').textContent = t('wrong'); return; }
      token = (await res.json()).token;
      localStorage.setItem(storeKey, token);
      connect();
    } catch (e) { $('pairError').textContent = t('offline'); }
  }

  function connect() {
    if (!token) { show(false); return; }
    show(true);
    const proto = location.protocol === 'https:' ? 'wss' : 'ws';
    socket = new WebSocket(`${proto}://${location.host}/ws?token=${encodeURIComponent(token)}`);
    socket.onopen = () => { retry = 0; $('dot').classList.add('on'); keepAwake(); };
    socket.onmessage = (event) => {
      const msg = JSON.parse(event.data);
      if (msg.type === 'state') { state = msg.state; render(); }
    };
    socket.onclose = (event) => {
      $('dot').classList.remove('on');
      // 4001: a new PIN was set on the computer. A refused upgrade never opens.
      if (event.code === 4001 || (event.code === 1006 && retry > 2 && !state)) {
        localStorage.removeItem(storeKey); token = null; state = null; show(false); return;
      }
      retry++;
      setTimeout(connect, Math.min(8000, 500 * retry));
    };
  }

  function send(message) {
    if (!socket || socket.readyState !== 1) return;
    if (navigator.vibrate) navigator.vibrate(8);
    socket.send(JSON.stringify(message));
  }

  async function keepAwake() {
    try { if ('wakeLock' in navigator && !wakeLock) {
      wakeLock = await navigator.wakeLock.request('screen');
      wakeLock.addEventListener('release', () => { wakeLock = null; });
    } } catch (e) {}
  }
  document.addEventListener('visibilitychange', () => { if (!document.hidden) keepAwake(); });

  function render() {
    if (!state) return;
    if (state.lang && dict[state.lang] && state.lang !== lang) { lang = state.lang; translate(); }
    $('name').textContent = state.collection || t('noCollection');
    const live = state.is_live;
    $('livePill').textContent = live ? t('onAir') : t('offAir');
    $('livePill').classList.toggle('live', live);

    const screen = $('screen');
    screen.classList.toggle('live', live && !state.blank);
    screen.replaceChildren();
    const add = (cls, text) => { const d = document.createElement('div'); d.className = cls; d.textContent = text; screen.append(d); };
    if (state.blank) add('state', t('black'));
    else if (state.waiting) add('state', t('waiting'));
    else if (state.text) { if (state.title) add('title', state.title); add('words', state.text); }
    else if (state.title) add('words', state.title);
    else add('state', t('nothing'));

    const next = $('next');
    next.replaceChildren();
    if (state.next) { const b = document.createElement('b'); b.textContent = t('next') + '  '; next.append(b, state.next); }

    $('live').classList.toggle('on-live', live);
    $('blank').classList.toggle('on-blank', state.blank);
    $('take').classList.toggle('hidden', !state.holding);

    const list = $('list');
    list.replaceChildren();
    state.items.forEach((item, i) => {
      const row = document.createElement('div');
      if (i === state.item) row.classList.add('cur');
      if (live && i === state.live_item) row.classList.add('air');
      const n = document.createElement('span'); n.className = 'n'; n.textContent = i + 1;
      const title = document.createElement('span'); title.textContent = item.title;
      row.append(n, title);
      row.onclick = () => send({ type: 'goto', item: i, slide: 0 });
      list.append(row);
    });
    // Only when the operator moves to another item: scrolling on every update
    // would snatch the list away from a thumb looking further down it.
    const current = list.children[state.item];
    if (current && render.lastItem !== state.item) { current.scrollIntoView({ block: 'nearest' }); }
    render.lastItem = state.item;
  }

  $('prev').onclick = () => send({ type: 'prev' });
  $('nextBtn').onclick = () => send({ type: 'next' });
  $('live').onclick = () => send({ type: 'live' });
  $('blank').onclick = () => send({ type: 'blank' });
  $('take').onclick = () => send({ type: 'take' });
  $('pairBtn').onclick = () => pair($('pin').value);
  $('pin').addEventListener('input', (e) => { if (e.target.value.length === 6) pair(e.target.value); });

  // The QR code on the computer carries the PIN after the #, which never
  // leaves the phone in the request itself.
  const fromCode = new URLSearchParams(location.hash.slice(1)).get('pin');
  if (fromCode) { history.replaceState(null, '', location.pathname); pair(fromCode); }
  else connect();
})();
</script>
</body>
</html>
''';
