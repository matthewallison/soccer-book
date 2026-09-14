# Reaction Trainer

A simple full-screen color reaction tool for training. Choose at least two colors, set how often the cue should change, then press **Start**. The next cue is always different from the current one.

<div class="rt-app" id="reaction-trainer">
  <div class="rt-panel">
    <h2>Choose colors</h2>
    <div class="rt-colors" role="group" aria-label="Colors">
      <label class="rt-color-option" style="--swatch:#e53935"><input type="checkbox" value="#e53935" data-name="Red" checked><span class="rt-swatch"></span><span>Red</span></label>
      <label class="rt-color-option" style="--swatch:#1e88e5"><input type="checkbox" value="#1e88e5" data-name="Blue" checked><span class="rt-swatch"></span><span>Blue</span></label>
      <label class="rt-color-option" style="--swatch:#43a047"><input type="checkbox" value="#43a047" data-name="Green" checked><span class="rt-swatch"></span><span>Green</span></label>
      <label class="rt-color-option" style="--swatch:#fdd835"><input type="checkbox" value="#fdd835" data-name="Yellow"><span class="rt-swatch"></span><span>Yellow</span></label>
      <label class="rt-color-option" style="--swatch:#fb8c00"><input type="checkbox" value="#fb8c00" data-name="Orange"><span class="rt-swatch"></span><span>Orange</span></label>
      <label class="rt-color-option" style="--swatch:#8e24aa"><input type="checkbox" value="#8e24aa" data-name="Purple"><span class="rt-swatch"></span><span>Purple</span></label>
      <label class="rt-color-option rt-light" style="--swatch:#ffffff"><input type="checkbox" value="#ffffff" data-name="White"><span class="rt-swatch"></span><span>White</span></label>
      <label class="rt-color-option" style="--swatch:#111111"><input type="checkbox" value="#111111" data-name="Black"><span class="rt-swatch"></span><span>Black</span></label>
    </div>

    <div class="rt-settings">
      <label for="rt-interval"><strong>Change every</strong></label>
      <div class="rt-interval-row">
        <input id="rt-interval" type="number" inputmode="decimal" min="0.2" max="60" step="0.1" value="1.0" aria-describedby="rt-interval-help">
        <span>seconds</span>
      </div>
      <div class="rt-help" id="rt-interval-help">Minimum 0.2 seconds.</div>
    </div>

    <div class="rt-message" id="rt-message" role="status" aria-live="polite"></div>
    <button class="md-button md-button--primary rt-start" id="rt-start" type="button">Start full-screen cues</button>
    <p class="rt-help">During the drill, tap anywhere on the color screen to stop. The page will try to keep your screen awake while the drill is running.</p>
  </div>

  <div class="rt-stage" id="rt-stage" hidden aria-label="Reaction cue screen">
    <div class="rt-stop-hint">Tap anywhere to stop</div>
  </div>
</div>

<style>
.rt-app { margin: 1.25rem 0 2rem; }
.rt-panel { max-width: 44rem; }
.rt-colors { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:.65rem; margin:.6rem 0 1.35rem; }
.rt-color-option { --swatch:#888; display:flex; align-items:center; gap:.65rem; border:1px solid var(--md-default-fg-color--lightest); border-radius:.55rem; padding:.72rem .8rem; cursor:pointer; user-select:none; }
.rt-color-option:has(input:checked) { border-color:var(--md-accent-fg-color); box-shadow:0 0 0 1px var(--md-accent-fg-color); }
.rt-color-option input { width:1.15rem; height:1.15rem; margin:0; }
.rt-swatch { width:1.7rem; height:1.7rem; border-radius:50%; background:var(--swatch); border:1px solid rgba(127,127,127,.45); flex:none; }
.rt-settings { margin:1rem 0; }
.rt-interval-row { display:flex; align-items:center; gap:.55rem; margin-top:.35rem; }
.rt-interval-row input { width:7rem; font:inherit; padding:.55rem .65rem; border:1px solid var(--md-default-fg-color--lightest); border-radius:.4rem; background:var(--md-default-bg-color); color:var(--md-default-fg-color); }
.rt-help { font-size:.82rem; color:var(--md-default-fg-color--light); margin-top:.35rem; }
.rt-message { min-height:1.5rem; margin:.6rem 0; font-weight:700; }
.rt-start { font-size:1rem; padding:.7rem 1.15rem; }
.rt-stage { position:fixed; inset:0; width:100vw; height:100vh; height:100dvh; z-index:99999; background:#111; cursor:pointer; touch-action:manipulation; }
.rt-stage[hidden] { display:none !important; }
.rt-stop-hint { position:absolute; left:50%; bottom:max(1.1rem,env(safe-area-inset-bottom)); transform:translateX(-50%); padding:.45rem .75rem; border-radius:999px; background:rgba(0,0,0,.38); color:white; font:600 .75rem/1.2 system-ui,-apple-system,sans-serif; opacity:.72; white-space:nowrap; }
@media (min-width:40rem) { .rt-colors { grid-template-columns:repeat(4,minmax(0,1fr)); } }
</style>

<script>
(() => {
  const root = document.getElementById('reaction-trainer');
  if (!root || root.dataset.ready) return;
  root.dataset.ready = '1';

  const stage = document.getElementById('rt-stage');
  const startButton = document.getElementById('rt-start');
  const intervalInput = document.getElementById('rt-interval');
  const message = document.getElementById('rt-message');
  const checks = [...root.querySelectorAll('.rt-color-option input[type="checkbox"]')];

  let timer = null;
  let current = null;
  let wakeLock = null;
  let running = false;

  const selectedColors = () => checks.filter(c => c.checked).map(c => ({ value: c.value, name: c.dataset.name }));

  function showMessage(text) { message.textContent = text || ''; }

  function chooseNext() {
    const colors = selectedColors();
    const choices = current ? colors.filter(c => c.value !== current.value) : colors;
    const next = choices[Math.floor(Math.random() * choices.length)];
    current = next;
    stage.style.backgroundColor = next.value;
    stage.setAttribute('aria-label', `${next.name} reaction cue`);
  }

  async function requestWakeLock() {
    try {
      if ('wakeLock' in navigator) wakeLock = await navigator.wakeLock.request('screen');
    } catch (_) { /* Wake Lock is optional. */ }
  }

  async function releaseWakeLock() {
    try { if (wakeLock) await wakeLock.release(); } catch (_) {}
    wakeLock = null;
  }

  async function start() {
    const colors = selectedColors();
    const seconds = Number(intervalInput.value);

    if (colors.length < 2) {
      showMessage('Choose at least two colors.');
      return;
    }
    if (!Number.isFinite(seconds) || seconds < 0.2) {
      showMessage('Choose an interval of at least 0.2 seconds.');
      return;
    }

    showMessage('');
    current = null;
    running = true;
    stage.hidden = false;
    document.documentElement.style.overflow = 'hidden';
    chooseNext();
    timer = window.setInterval(chooseNext, seconds * 1000);
    await requestWakeLock();

    try {
      if (stage.requestFullscreen && !document.fullscreenElement) await stage.requestFullscreen();
    } catch (_) { /* iPhone Safari may not allow element fullscreen; fixed viewport is the fallback. */ }
  }

  async function stop() {
    if (!running) return;
    running = false;
    if (timer) window.clearInterval(timer);
    timer = null;
    stage.hidden = true;
    stage.style.backgroundColor = '#111';
    document.documentElement.style.overflow = '';
    await releaseWakeLock();
    try {
      if (document.fullscreenElement && document.exitFullscreen) await document.exitFullscreen();
    } catch (_) {}
  }

  startButton.addEventListener('click', start);
  stage.addEventListener('click', stop);
  document.addEventListener('keydown', event => { if (event.key === 'Escape') stop(); });
  document.addEventListener('visibilitychange', async () => {
    if (running && document.visibilityState === 'visible' && !wakeLock) await requestWakeLock();
  });
})();
</script>
