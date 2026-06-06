// レンダラー：タップ位置にランダムな反応を出す
(() => {
  const stage = document.getElementById('stage');

  // パレット
  const COLORS = [
    '#FF5E5B', '#FFB400', '#FFE156', '#7BE495', '#3CC3F2',
    '#7C5CFF', '#FF7BD5', '#FF9F45', '#5BE7C4', '#FF4D80',
  ];
  const ANIMALS = ['🐶','🐱','🐰','🐼','🦁','🐯','🐸','🐵','🦊','🐧','🐥','🐮','🐷','🐨','🦄','🐙','🐠','🐳','🐢','🦋','🐝','🐞','🦒','🐘'];
  const FRUITS  = ['🍎','🍌','🍓','🍇','🍊','🍉','🍑','🥝','🍍','🥕','🍒','🍋'];
  const FACES   = ['😀','😆','😍','🤩','😎','🤗','😺','🥳','😋','🤖','👶','✨','💖','⭐️','🌈','🎈','🎉','🎵','🌟','🌸','🌻','🍭'];
  const HIRA    = ['あ','い','う','え','お','か','き','く','け','こ','さ','し','す','せ','そ','な','は','ま','や','ら','わ'];
  const ALPHA   = ['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'];
  const NUMBERS = ['1','2','3','4','5','6','7','8','9','10'];

  const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];

  // Web Audio：効果音をプロシージャル生成
  let audioCtx = null;
  function ensureAudio() {
    if (audioCtx) return audioCtx;
    const Ctx = window.AudioContext || window.webkitAudioContext;
    audioCtx = new Ctx();
    return audioCtx;
  }

  // 音色プリセット
  function playTone({ freq = 440, type = 'sine', dur = 0.18, gain = 0.15, sweepTo = null }) {
    const ctx = ensureAudio();
    const t0 = ctx.currentTime;
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t0);
    if (sweepTo !== null) {
      osc.frequency.exponentialRampToValueAtTime(Math.max(1, sweepTo), t0 + dur);
    }
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(gain, t0 + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(g).connect(ctx.destination);
    osc.start(t0);
    osc.stop(t0 + dur + 0.02);
  }

  function playChord(freqs, type = 'triangle', dur = 0.35) {
    freqs.forEach((f, i) => {
      setTimeout(() => playTone({ freq: f, type, dur, gain: 0.1 }), i * 40);
    });
  }

  function playSparkle() {
    // 高めの音を連続で
    const base = 800 + Math.random() * 400;
    for (let i = 0; i < 4; i++) {
      setTimeout(() => playTone({
        freq: base * (1 + i * 0.25),
        type: 'sine',
        dur: 0.12,
        gain: 0.08,
      }), i * 50);
    }
  }

  function playPop() {
    playTone({ freq: 600 + Math.random() * 400, type: 'square', dur: 0.08, gain: 0.12, sweepTo: 200 });
  }

  function playBoing() {
    const start = 200 + Math.random() * 200;
    playTone({ freq: start, type: 'triangle', dur: 0.35, gain: 0.15, sweepTo: start * 3 });
  }

  function playHappy() {
    // ドミソ風
    const roots = [
      [523.25, 659.25, 783.99],   // C E G
      [392.00, 493.88, 587.33],   // G B D
      [440.00, 554.37, 659.25],   // A C# E
      [349.23, 440.00, 523.25],   // F A C
    ];
    playChord(pick(roots), 'triangle', 0.4);
  }

  const SOUNDS = [playPop, playBoing, playSparkle, playHappy];

  // ステージ要素を作るヘルパ
  function place(el, x, y) {
    el.style.left = x + 'px';
    el.style.top = y + 'px';
    stage.appendChild(el);
    el.addEventListener('animationend', () => el.remove(), { once: true });
  }

  // 反応：図形パーティクルが飛び散る
  function reactShapes(x, y) {
    const burst = document.createElement('div');
    burst.className = 'burst shape-burst';
    burst.style.left = x + 'px';
    burst.style.top = y + 'px';
    const n = 10 + Math.floor(Math.random() * 8);
    const shapes = ['circle', 'square', 'triangle', 'star', 'heart'];
    const shapeKind = pick(shapes);
    const color = pick(COLORS);
    for (let i = 0; i < n; i++) {
      const p = document.createElement('div');
      const isText = shapeKind === 'star' || shapeKind === 'heart';
      p.className = 'particle ' + shapeKind;
      const angle = (i / n) * Math.PI * 2 + Math.random() * 0.4;
      const dist = 80 + Math.random() * 220;
      const size = 24 + Math.random() * 40;
      p.style.setProperty('--dx', Math.cos(angle) * dist + 'px');
      p.style.setProperty('--dy', Math.sin(angle) * dist + 'px');
      p.style.setProperty('--rot', (Math.random() * 720 - 360) + 'deg');
      p.style.setProperty('--size', size + 'px');
      p.style.setProperty('--color', color);
      if (isText) {
        p.textContent = shapeKind === 'star' ? '★' : '♥';
      } else {
        p.style.background = color;
      }
      burst.appendChild(p);
    }
    stage.appendChild(burst);
    // パーティクルの最後のanimationendで親も削除
    let ended = 0;
    burst.querySelectorAll('.particle').forEach((p) => {
      p.addEventListener('animationend', () => {
        ended++;
        if (ended >= n) burst.remove();
      }, { once: true });
    });
    playPop();
  }

  // 反応：動物/フルーツ/顔文字がドンと出る
  function reactEmoji(x, y) {
    const pool = pick([ANIMALS, FRUITS, FACES]);
    const el = document.createElement('div');
    el.className = 'burst emoji-pop';
    el.textContent = pick(pool);
    place(el, x, y);
    playBoing();
  }

  // 反応：文字（ひらがな・アルファベット・数字）
  function reactText(x, y) {
    const pool = pick([HIRA, ALPHA, NUMBERS]);
    const el = document.createElement('div');
    el.className = 'burst text-pop';
    el.textContent = pick(pool);
    el.style.setProperty('--color', pick(COLORS));
    place(el, x, y);
    playHappy();
  }

  // 反応：波紋＋キラキラ
  function reactRipple(x, y) {
    const ripple = document.createElement('div');
    ripple.className = 'burst ripple';
    ripple.style.setProperty('--color', pick(COLORS));
    place(ripple, x, y);

    // キラキラを散らす
    const sparkleChars = ['✨','⭐️','💫','🌟'];
    const count = 4 + Math.floor(Math.random() * 4);
    for (let i = 0; i < count; i++) {
      const s = document.createElement('div');
      s.className = 'burst sparkle';
      s.textContent = pick(sparkleChars);
      const ox = (Math.random() - 0.5) * 220;
      const oy = (Math.random() - 0.5) * 220;
      place(s, x + ox, y + oy);
    }
    playSparkle();
  }

  const REACTIONS = [reactShapes, reactEmoji, reactText, reactRipple, reactShapes, reactEmoji];

  function trigger(x, y) {
    // たまに複数反応をまとめて出す
    const combo = Math.random() < 0.2 ? 2 : 1;
    for (let i = 0; i < combo; i++) {
      const fn = pick(REACTIONS);
      const ox = (Math.random() - 0.5) * 40 * i;
      const oy = (Math.random() - 0.5) * 40 * i;
      fn(x + ox, y + oy);
    }
  }

  // 画面上のランダムな位置を返す
  function randomPoint() {
    const margin = 80;
    const x = margin + Math.random() * Math.max(1, window.innerWidth - margin * 2);
    const y = margin + Math.random() * Math.max(1, window.innerHeight - margin * 2);
    return { x, y };
  }

  // pointerdownで反応（マウス・タッチ・ペン共通）
  window.addEventListener('pointerdown', (e) => {
    trigger(e.clientX, e.clientY);
  });

  // マルチタッチも個別に拾う
  window.addEventListener('touchstart', (e) => {
    for (const t of e.changedTouches) {
      trigger(t.clientX, t.clientY);
    }
    e.preventDefault();
  }, { passive: false });

  // ドラッグでも反応（ベイビーが擦るような動きにも対応）
  let lastTrigger = 0;
  window.addEventListener('pointermove', (e) => {
    if (e.pressure === 0 && e.buttons === 0) return;
    const now = performance.now();
    if (now - lastTrigger < 90) return;
    lastTrigger = now;
    trigger(e.clientX, e.clientY);
  });

  // 右クリックメニュー無効化（独自メニューはダブルクリック経由で出す）
  window.addEventListener('contextmenu', (e) => e.preventDefault());

  // キーボードのどのキーでも反応する。修飾キー単独や Cmd 系は除外。
  // 同じキーを押しっぱなしの OS リピートには反応しない
  window.addEventListener('keydown', (e) => {
    if (e.repeat) return;
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (['Meta', 'Control', 'Alt', 'Shift'].includes(e.key)) return;
    const { x, y } = randomPoint();
    trigger(x, y);
  });

  // ダブルクリックで終了用コンテキストメニューを開く
  window.addEventListener('dblclick', (e) => {
    if (window.babyApp && typeof window.babyApp.showContextMenu === 'function') {
      window.babyApp.showContextMenu();
    }
    e.preventDefault();
  });

  // 時々画面を横切る絵文字
  const CROSS_POOL = [...ANIMALS, ...FRUITS, '🚗','🚂','✈️','🚀','🛸','⛵️','🐳','🦋','🌈','🎈','☁️','⭐️'];
  function spawnCrossing() {
    const el = document.createElement('div');
    el.className = 'crossing';
    el.textContent = pick(CROSS_POOL);
    const fromLeft = Math.random() < 0.5;
    const top = 40 + Math.random() * Math.max(1, window.innerHeight - 160);
    const size = 60 + Math.random() * 80;
    const duration = 6 + Math.random() * 5;
    el.style.top = top + 'px';
    el.style.fontSize = size + 'px';
    el.style.animationDuration = duration + 's';
    el.style.animationName = fromLeft ? 'cross-lr' : 'cross-rl';
    document.body.appendChild(el);
    el.addEventListener('animationend', () => el.remove(), { once: true });
  }
  function scheduleCrossing() {
    const next = 3500 + Math.random() * 5000;
    setTimeout(() => {
      spawnCrossing();
      scheduleCrossing();
    }, next);
  }
  scheduleCrossing();
})();
