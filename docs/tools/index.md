# Reaction Trainer

A simple full-screen color reaction tool for training. Choose at least two colors, set how often the cue should change, then press **Start**. The next cue is always different from the current one.

<div class="rt-app" id="reaction-trainer">
  <div class="rt-panel">
    <h2>Choose colors</h2>
    <div class="rt-colors" id="rt-colors" role="group" aria-label="Colors">
      <button type="button" class="rt-color-option is-selected" data-color="#e53935" data-name="Red" aria-pressed="true" style="--swatch:#e53935"><span class="rt-swatch"></span><span>Red</span></button>
      <button type="button" class="rt-color-option is-selected" data-color="#1e88e5" data-name="Blue" aria-pressed="true" style="--swatch:#1e88e5"><span class="rt-swatch"></span><span>Blue</span></button>
      <button type="button" class="rt-color-option is-selected" data-color="#43a047" data-name="Green" aria-pressed="true" style="--swatch:#43a047"><span class="rt-swatch"></span><span>Green</span></button>
      <button type="button" class="rt-color-option" data-color="#fdd835" data-name="Yellow" aria-pressed="false" style="--swatch:#fdd835"><span class="rt-swatch"></span><span>Yellow</span></button>
      <button type="button" class="rt-color-option" data-color="#fb8c00" data-name="Orange" aria-pressed="false" style="--swatch:#fb8c00"><span class="rt-swatch"></span><span>Orange</span></button>
      <button type="button" class="rt-color-option" data-color="#8e24aa" data-name="Purple" aria-pressed="false" style="--swatch:#8e24aa"><span class="rt-swatch"></span><span>Purple</span></button>
      <button type="button" class="rt-color-option" data-color="#ffffff" data-name="White" aria-pressed="false" style="--swatch:#ffffff"><span class="rt-swatch"></span><span>White</span></button>
      <button type="button" class="rt-color-option" data-color="#111111" data-name="Black" aria-pressed="false" style="--swatch:#111111"><span class="rt-swatch"></span><span>Black</span></button>
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
.rt-app { margin:1.25rem 0 2rem; }
.rt-panel { max-width:44rem; }
.rt-colors { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:.65rem; margin:.6rem 0 1.35rem; }
.rt-color-option { --swatch:#888; appearance:none; -webkit-appearance:none; width:100%; display:flex; align-items:center; gap:.65rem; border:2px solid var(--md-default-fg-color--lightest); border-radius:.55rem; padding:.72rem .8rem; cursor:pointer; user-select:none; background:var(--md-default-bg-color); color:var(--md-default-fg-color); font:inherit; text-align:left; }
.rt-color-option.is-selected { border-color:var(--md-accent-fg-color); box-shadow:0 0 0 1px var(--md-accent-fg-color); background:color-mix(in srgb, var(--md-accent-fg-color) 10%, var(--md-default-bg-color)); }
.rt-color-option.is-selected::after { content:'✓'; margin-left:auto; font-weight:800; }
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
  if (!root || root.dataset.ready === '1') return;
  root.dataset.ready = '1';

  const stage = root.querySelector('#rt-stage');
  const startButton = root.querySelector('#rt-start');
  const intervalInput = root.querySelector('#rt-interval');
  const message = root.querySelector('#rt-message');
  const colorGroup = root.querySelector('#rt-colors');

  let timer = null;
  let current = null;
  let wakeLock = null;
  let running = false;

  function colorButtons() {
    return Array.from(root.querySelectorAll('.rt-color-option'));
  }

  function selectedColors() {
    return colorButtons()
      .filter(button => button.getAttribute('aria-pressed') === 'true')
      .map(button => ({ value: button.dataset.color, name: button.dataset.name }));
  }

  function showMessage(text) {
    message.textContent = text || '';
  }

  colorGroup.addEventListener('click', event => {
    const button = event.target.closest('.rt-color-option');
    if (!button || !colorGroup.contains(button)) return;
    const selected = button.getAttribute('aria-pressed') === 'true';
    button.setAttribute('aria-pressed', selected ? 'false' : 'true');
    button.classList.toggle('is-selected', !selected);
    showMessage('');
  });

  function chooseNext() {
    const colors = selectedColors();
    if (colors.length < 2) return;
    const choices = current ? colors.filter(color => color.value !== current.value) : colors;
    const next = choices[Math.floor(Math.random() * choices.length)];
    current = next;
    stage.style.backgroundColor = next.value;
    stage.setAttribute('aria-label', `${next.name} reaction cue`);
  }

  async function requestWakeLock() {
    try {
      if ('wakeLock' in navigator) wakeLock = await navigator.wakeLock.request('screen');
    } catch (_) {}
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
    } catch (_) {}
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
