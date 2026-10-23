
/* ======================= a página: desenho e som ======================= */
const $ = id => document.getElementById(id);
const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const guarda = (k, v) => { try{ localStorage.setItem('duvido-' + k, v); }catch(e){} };
const le = k => { try{ return localStorage.getItem('duvido-' + k); }catch(e){ return null; } };
const leJSON = (k, padrao) => { try{ const v = JSON.parse(le(k)); return v === null || v === undefined ? padrao : v; }catch(e){ return padrao; } };
const guardaJSON = (k, v) => guarda(k, JSON.stringify(v));
const reduz = matchMedia('(prefers-reduced-motion: reduce)').matches;
const dedoTela = matchMedia('(pointer: coarse)').matches;
const fmt2 = cs => (cs / 100).toFixed(2).replace('.', ',');
const fmt1 = cs => (Math.round(cs / 10) / 10).toFixed(1).replace('.', ',');
const F_TIT = '"Bungee","Arial Black",Impact,sans-serif', F_TXT = '"Rubik",system-ui,sans-serif', F_GIZ = '"Permanent Marker","Comic Sans MS","Chalkboard SE","Segoe Print",sans-serif';
const app = $('app'), cv = $('c'), ctx = cv.getContext('2d'), tiraCv = $('tira'), tctx = tiraCv.getContext('2d');

/* ---------- a tela: a coluna do mundo e a tira da direita ---------- */
let SW = 0, SH = 0, DPR = 1, K = 1, COLX = 0, COLW = 0, TIRAX = 0, TIRAW = 22, VH = 800;
function medeTela(){
  const r = app.getBoundingClientRect(); SW = Math.max(200, r.width); SH = Math.max(200, r.height);
  DPR = Math.min(window.devicePixelRatio || 1, 2);
  TIRAW = SW < 600 ? 22 : 26;
  if(SW < 600){ COLW = SW - TIRAW; COLX = 0; TIRAX = COLW; }
  else { COLW = Math.min(520, SW - 2 * (TIRAW + 34)); COLX = Math.round((SW - COLW) / 2); TIRAX = COLX + COLW + 14; }
  K = COLW / LARG; VH = SH / K;
  cv.width = Math.round(SW * DPR); cv.height = Math.round(SH * DPR);
  tiraCv.width = Math.round(TIRAW * DPR); tiraCv.height = Math.round(SH * DPR);
  app.style.setProperty('--col-x', COLX + 'px'); app.style.setProperty('--col-w', COLW + 'px');
  app.style.setProperty('--tira-x', TIRAX + 'px'); app.style.setProperty('--tira-w', TIRAW + 'px');
  ladrilhos.clear(); tiraCache = null; padroes.delete(ctx);
}

/* ---------- as texturas, feitas uma vez ---------- */
const CORES_GIZ = [[243, 238, 226], [255, 214, 74], [255, 111, 174], [108, 196, 255]];
const NOMES_COR = ['branco', 'amarelo', 'rosa', 'azul'];
function texAsfalto(){
  const c = document.createElement('canvas'); c.width = c.height = 256; const x = c.getContext('2d'), r = sorteio(4242);
  x.fillStyle = '#1C1B21'; x.fillRect(0, 0, 256, 256);
  for(let i = 0; i < 11000; i++){
    const claro = r() < .5, g = claro ? 34 + r() * 22 : 13 + r() * 9, quente = r() < .12 ? 10 : 0, s = r() < .88 ? 1 : 2;
    x.fillStyle = `rgba(${g + quente | 0},${g | 0},${g + 4 | 0},${.3 + r() * .55})`; x.fillRect(r() * 256 | 0, r() * 256 | 0, s, s);
  }
  for(let i = 0; i < 300; i++){ x.fillStyle = `rgba(${160 + r() * 60 | 0},${150 + r() * 50 | 0},${140 + r() * 40 | 0},${.06 + r() * .14})`; x.beginPath(); x.arc(r() * 256, r() * 256, .6 + r() * 1.5, 0, 7); x.fill(); }
  return c;
}
function texGiz(cor, sem){
  const c = document.createElement('canvas'); c.width = c.height = 64; const x = c.getContext('2d'), img = x.createImageData(64, 64), r = sorteio(sem);
  for(let i = 0; i < 4096; i++){
    const a = r(), al = a < .13 ? 0 : a < .3 ? 110 + r() * 60 : 205 + r() * 50, v = .92 + r() * .08;
    img.data[i * 4] = cor[0] * v; img.data[i * 4 + 1] = cor[1] * v; img.data[i * 4 + 2] = cor[2] * v; img.data[i * 4 + 3] = al;
  }
  x.putImageData(img, 0, 0); return c;
}
function texGrao(){
  const c = document.createElement('canvas'); c.width = c.height = 120; const x = c.getContext('2d'), r = sorteio(31);
  for(let i = 0; i < 1300; i++){ x.fillStyle = r() < .5 ? `rgba(255,255,255,${.015 + r() * .03})` : `rgba(0,0,0,${.05 + r() * .08})`; x.fillRect(r() * 120 | 0, r() * 120 | 0, 1, 1); }
  return c;
}
const TEX = { asfalto: texAsfalto(), giz: CORES_GIZ.map((c, i) => texGiz(c, 70 + i)) };
try{ document.documentElement.style.setProperty('--grao', `url(${texGrao().toDataURL()})`); }catch(e){}

/* ---------- a cena: a fase que tá na tela (traços com caixa, carimbos, a decoração) ---------- */
let CENA = null;
function montaCena(fase, F){
  const tracos = fase.tracos.map(t => { let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9; for(let i = 0; i < t.pts.length; i += 2){ x0 = Math.min(x0, t.pts[i]); x1 = Math.max(x1, t.pts[i]); y0 = Math.min(y0, t.pts[i + 1]); y1 = Math.max(y1, t.pts[i + 1]); } return { cor: t.cor, pts: t.pts, bb: [x0, y0, x1, y1] }; });
  let s = 7; for(const t of fase.tracos) s = (s * 31 + t.pts.length + (t.pts[1] || 0)) % 100003;
  CENA = { fase, F: F || compila(fase), tracos, sem: s, yMax: (F || null) ? F.yMax : null };
  CENA.yMax = CENA.F.yMax;
  ladrilhos.clear(); tiraCache = null;
}

/* ---------- os ladrilhos: o asfalto, a decoração e o giz, desenhados uma vez por pedaço ---------- */
const TH = 256;
const ladrilhos = new Map();
function ladrilho(t){
  const chave = t;
  let L = ladrilhos.get(chave); if(L) return L;
  const W = Math.round(COLW * DPR), H = Math.ceil(TH * K * DPR) + 2;
  L = document.createElement('canvas'); L.width = W; L.height = H;
  const x = L.getContext('2d');
  const pa = x.createPattern(TEX.asfalto, 'repeat');
  x.fillStyle = pa; x.fillRect(0, 0, W, H);
  x.setTransform(K * DPR, 0, 0, K * DPR, 0, -t * TH * K * DPR);
  if(CENA){
    for(let u = t - 1; u <= t + 1; u++) decora(x, u);
    faixas(x, t);
    tabua(x);
    const y0 = t * TH - 40, y1 = (t + 1) * TH + 40;
    CENA.tracos.forEach((tr, i) => { if(tr.bb[3] >= y0 && tr.bb[1] <= y1) gizTraco(x, tr.pts, tr.cor, i); });
  }
  ladrilhos.set(chave, L);
  if(ladrilhos.size > 28) ladrilhos.delete(ladrilhos.keys().next().value);
  return L;
}
// o giz: a poeira em volta, o miolo com grão e uma segunda passada, tudo com um tremidinho de mão
function caminhoGiz(x, pts, sem, amp){
  x.beginPath();
  let n = 0;
  for(let i = 0; i < pts.length; i += 2){
    if(i === 0){ x.moveTo(pts[0], pts[1]); continue; }
    const ax = pts[i - 2], ay = pts[i - 1], bx = pts[i], by = pts[i + 1], dx = bx - ax, dy = by - ay, l = Math.hypot(dx, dy) || 1, q = Math.max(1, Math.round(l / 7));
    for(let k = 1; k <= q; k++){
      const f = k / q, j = k === q ? 0 : (((Math.sin((n++ + sem) * 12.9898) * 43758.5453) % 1) - .5) * 2 * amp;
      x.lineTo(ax + dx * f - dy / l * j, ay + dy * f + dx / l * j);
    }
  }
}
const padroes = new WeakMap();
function padraoGiz(x, cor){
  let m = padroes.get(x); if(!m){ m = []; padroes.set(x, m); }
  if(!m[cor]){ m[cor] = x.createPattern(TEX.giz[cor] || TEX.giz[0], 'repeat'); try{ const s = 1 / (K * DPR); m[cor].setTransform(new DOMMatrix([s, 0, 0, s, 0, 0])); }catch(e){} }
  return m[cor];
}
function gizTraco(x, pts, cor, sem){
  const c = CORES_GIZ[cor] || CORES_GIZ[0];
  x.lineCap = 'round'; x.lineJoin = 'round';
  x.strokeStyle = `rgba(${c[0]},${c[1]},${c[2]},.09)`; x.lineWidth = 13; caminhoGiz(x, pts, sem, .8); x.stroke();
  x.strokeStyle = padraoGiz(x, cor); x.lineWidth = 7.4; caminhoGiz(x, pts, sem + 3, .55); x.stroke();
  x.globalAlpha = .55; x.lineWidth = 4.2; caminhoGiz(x, pts, sem + 9, .7); x.stroke(); x.globalAlpha = 1;
}
// a sujeira do asfalto: rachadura, mancha de óleo, faixa velha apagada, bueiro, giz velho e flor seca de ipê
function decora(x, t){
  const r = sorteio(t * 7919 + (CENA ? CENA.sem : 1) * 31 + 11), y0 = t * TH;
  if(r() < .5){
    let px = 20 + r() * 380, py = y0 + r() * TH; x.strokeStyle = 'rgba(8,8,10,.7)'; x.lineWidth = 1.6; x.lineCap = 'round'; x.beginPath(); x.moveTo(px, py);
    for(let k = 0; k < 9; k++){ px += (r() - .5) * 26; py += 4 + r() * 14; x.lineTo(px, py); } x.stroke();
    x.strokeStyle = 'rgba(255,255,255,.04)'; x.lineWidth = 1; x.stroke();
  }
  if(r() < .3){ const px = 40 + r() * 340, py = y0 + r() * TH, g = x.createRadialGradient(px, py, 2, px, py, 26 + r() * 20); g.addColorStop(0, 'rgba(5,5,8,.5)'); g.addColorStop(1, 'rgba(5,5,8,0)'); x.fillStyle = g; x.beginPath(); x.ellipse(px, py, 44, 26, r() * 3, 0, 7); x.fill(); }
  if(r() < .4){ const px = 150 + r() * 120, py = y0 + r() * TH; x.fillStyle = `rgba(255,201,60,${.05 + r() * .06})`; x.save(); x.translate(px, py); x.rotate((r() - .5) * .3); x.fillRect(-4, 0, 8, 50 + r() * 40); x.restore(); }
  if(r() < .07){
    const px = 60 + r() * 300, py = y0 + r() * TH; x.fillStyle = '#121116'; x.beginPath(); x.arc(px, py, 17, 0, 7); x.fill();
    x.strokeStyle = 'rgba(255,255,255,.1)'; x.lineWidth = 1.4; x.stroke(); x.save(); x.beginPath(); x.arc(px, py, 14, 0, 7); x.clip();
    x.strokeStyle = 'rgba(255,255,255,.07)'; for(let k = -14; k <= 14; k += 4){ x.beginPath(); x.moveTo(px - 15, py + k); x.lineTo(px + 15, py + k); x.stroke(); } x.restore();
  }
  if(r() < .18){
    // giz velho de outra brincadeira, quase apagado
    const px = 70 + r() * 280, py = y0 + 30 + r() * (TH - 60), tipo = r() * 4 | 0, cor = CORES_GIZ[r() * 4 | 0];
    x.save(); x.translate(px, py); x.rotate((r() - .5) * .5); x.strokeStyle = `rgba(${cor},.1)`; x.fillStyle = `rgba(${cor},.1)`; x.lineWidth = 3; x.lineCap = 'round';
    if(tipo === 0){ for(let k = 0; k < 3; k++) x.strokeRect(-14, -40 + k * 26, 28, 26); x.strokeRect(-28, 38, 28, 26); x.strokeRect(0, 38, 28, 26); }
    else if(tipo === 1){ x.beginPath(); x.moveTo(0, 12); x.bezierCurveTo(-26, -6, -12, -26, 0, -12); x.bezierCurveTo(12, -26, 26, -6, 0, 12); x.stroke(); }
    else if(tipo === 2){ x.font = '28px ' + F_GIZ; x.fillText(['VALEU', 'ZÉ', 'BIA', 'DUVIDO', 'FUI'][r() * 5 | 0], -30, 8); }
    else { x.beginPath(); x.moveTo(-12, -12); x.lineTo(12, 12); x.moveTo(12, -12); x.lineTo(-12, 12); x.stroke(); }
    x.restore();
  }
  const nf = r() < .5 ? 0 : 1 + (r() * 3 | 0);
  for(let k = 0; k < nf; k++){ const px = 10 + r() * 400, py = y0 + r() * TH, rosa = r() < .4; x.fillStyle = rosa ? 'rgba(232,110,170,.45)' : 'rgba(240,190,50,.42)'; x.beginPath(); x.ellipse(px, py, 2.6, 1.6, r() * 3, 0, 7); x.fill(); }
}
// as faixas amarelas da beira (o barranco tá logo depois)
function faixas(x, t){
  const y0 = t * TH, r = sorteio(t * 13 + 5);
  for(const bx of [4, LARG - 4]){
    for(let y = y0; y < y0 + TH; y += 8){ const a = r() < .08 ? .1 : .55 + r() * .3; x.fillStyle = `rgba(255,201,60,${a})`; x.fillRect(bx - 1.8, y, 3.6, 8.5); }
  }
}
// a tábua da largada: madeira de verdade em cima de dois tijolos
function tabua(x){
  const L = LARGADA, ax = L[2], ay = L[3], bx = L[4], by = L[5], dx = bx - ax, dy = by - ay, l = Math.hypot(dx, dy), ang = Math.atan2(dy, dx);
  x.save();
  // os tijolos embaixo da ponta de cima
  x.fillStyle = '#9C3F2A'; x.strokeStyle = '#4A1C12'; x.lineWidth = 1.2;
  for(let k = 0; k < 3; k++){ x.fillRect(2 + (k % 2) * 6, ay + 4 + k * 9, 22, 9); x.strokeRect(2 + (k % 2) * 6, ay + 4 + k * 9, 22, 9); }
  x.translate(ax, ay); x.rotate(ang);
  x.fillStyle = 'rgba(0,0,0,.35)'; x.fillRect(2, 4, l, 9);
  x.fillStyle = '#B9733A'; x.fillRect(0, -1, l + 4, 9); x.strokeStyle = '#5A3218'; x.lineWidth = 1.6; x.strokeRect(0, -1, l + 4, 9);
  x.strokeStyle = 'rgba(90,50,24,.55)'; x.lineWidth = 1; for(let k = 0; k < 3; k++){ x.beginPath(); x.moveTo(6, 1.5 + k * 2.5); x.bezierCurveTo(l * .3, k * 2.5 + 3, l * .6, k * 2.5, l, 2 + k * 2.4); x.stroke(); }
  x.fillStyle = '#E8D9B0'; x.fillRect(0, -1.5, l + 4, 1.8);
  x.fillStyle = '#2A2830'; [14, l - 10].forEach(p => { x.beginPath(); x.arc(p, 3.5, 1.3, 0, 7); x.fill(); });
  x.restore();
  // o batente de trás
  x.fillStyle = '#8E552A'; x.fillRect(L[0] - 2, L[1], 5, L[3] - L[1] + 2); x.strokeStyle = '#4A2A14'; x.lineWidth = 1.2; x.strokeRect(L[0] - 2, L[1], 5, L[3] - L[1] + 2);
  // LARGADA escrito a giz embaixo da tábua (em cima fica o relógio)
  x.save(); x.translate(38, 146); x.rotate(ang); x.fillStyle = 'rgba(243,238,226,.8)'; x.font = '17px ' + F_GIZ; x.fillText('LARGADA', 0, 0); x.restore();
}
// a faixa quadriculada no chão da chegada (a bandeira em si é desenhada a cada quadro, balançando)
function chegadaChao(x){
  const c = CENA && CENA.F.chegada; if(!c) return;
  x.save(); x.translate(c.x, c.y);
  for(let i = -5; i < 5; i++) for(let j = 0; j < 2; j++){ x.fillStyle = (i + j) % 2 ? 'rgba(243,238,226,.85)' : 'rgba(20,20,24,.9)'; x.fillRect(i * 4.4, 3 + j * 4.4, 4.4, 4.4); }
  x.fillStyle = 'rgba(243,238,226,.86)'; x.font = '15px ' + F_GIZ; x.textAlign = 'center'; x.fillText('CHEGADA', 0, 28);
  x.restore();
}

/* ---------- o fora da coluna (no computador): o barranco, escuro, com a beirada do asfalto esfarelando ---------- */
const hashI = n => { n = Math.imul(n ^ 0x9E3779B9, 0x85EBCA6B); n ^= n >>> 13; n = Math.imul(n, 0xC2B2AE35); return (n ^ n >>> 16) >>> 0; };
function desenhaFora(camY){
  if(COLX <= 0) return;
  ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
  ctx.fillStyle = '#08070B'; ctx.fillRect(0, 0, COLX, SH); ctx.fillRect(COLX + COLW, 0, SW - COLX - COLW, SH);
  for(const [x0, dir] of [[COLX, -1], [COLX + COLW, 1]]){
    // a terra roxa que aparece embaixo do asfalto, sumindo no escuro
    const g = ctx.createLinearGradient(x0, 0, x0 + dir * 120, 0); g.addColorStop(0, 'rgba(74,32,24,.5)'); g.addColorStop(.35, 'rgba(46,20,18,.28)'); g.addColorStop(1, 'rgba(20,10,10,0)');
    ctx.fillStyle = g; ctx.fillRect(Math.min(x0, x0 + dir * 120), 0, 120, SH);
    // os pedaços de asfalto quebrado e as pedrinhas, presos no mundo (andam junto com a ladeira)
    const passo = 16, y0 = Math.floor((camY - 30) / passo) * passo;
    for(let y = y0; y < camY + VH + 30; y += passo){
      const h = hashI(y * 3 + (dir > 0 ? 7 : 0)), sy = (y - camY) * K, w1 = 3 + h % 11, w2 = 2 + (h >>> 5) % 9, alt = passo * K * (.75 + ((h >>> 9) % 6) / 10);
      const tom = 26 + (h >>> 12) % 12;
      ctx.fillStyle = `rgb(${tom + 2},${tom},${tom + 5})`;
      ctx.beginPath(); ctx.moveTo(x0, sy); ctx.lineTo(x0 + dir * w1, sy + alt * .2); ctx.lineTo(x0 + dir * w2, sy + alt * .8); ctx.lineTo(x0, sy + alt); ctx.closePath(); ctx.fill();
      if(h % 5 === 0){ const px = x0 + dir * (18 + (h >>> 3) % 70), r = 1.5 + (h >>> 7) % 4; ctx.fillStyle = `rgba(${60 + (h >>> 4) % 30},${34 + (h >>> 6) % 16},${30},.5)`; ctx.beginPath(); ctx.ellipse(px, sy + 6, r * 1.4, r, (h % 7) / 3, 0, 7); ctx.fill(); }
      if(h % 11 === 0){ const px = x0 + dir * (10 + (h >>> 4) % 40); ctx.strokeStyle = 'rgba(176,138,72,.35)'; ctx.lineWidth = 1; ctx.beginPath(); for(let k = 0; k < 4; k++){ ctx.moveTo(px + k * 2 * dir, sy + 10); ctx.lineTo(px + (k * 2 + (k % 2 ? 3 : -2)) * dir, sy + 2 - (h >>> k) % 4); } ctx.stroke(); }
    }
    // a sombra da beirada
    const s2 = ctx.createLinearGradient(x0, 0, x0 + dir * 26, 0); s2.addColorStop(0, 'rgba(0,0,0,.55)'); s2.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = s2; ctx.fillRect(Math.min(x0, x0 + dir * 26), 0, 26, SH);
  }
  ctx.setTransform(1, 0, 0, 1, 0, 0);
}

/* ---------- os carimbos, a cada quadro ---------- */
const RODA = 6.5;
function desenhaMola(x, m, comp){
  x.save(); x.translate(m.x, m.y);
  x.fillStyle = '#0B0A0E'; x.beginPath(); x.roundRect ? x.roundRect(-15, 1, 30, 19, 4) : x.rect(-15, 1, 30, 19); x.fill();
  const h = 15 * (1 - comp * .55); x.strokeStyle = '#C9CCD6'; x.lineWidth = 2.1; x.lineJoin = 'round'; x.beginPath(); x.moveTo(-9, 2.5);
  for(let k = 1; k <= 6; k++) x.lineTo(k % 2 ? 9 : -9, 2.5 + h * k / 6); x.stroke();
  x.fillStyle = '#3B3A44'; x.fillRect(-12, 2.5 + h, 24, 3);
  x.fillStyle = '#FF4F9A'; x.strokeStyle = '#7A1C44'; x.lineWidth = 1.2; x.beginPath(); x.roundRect ? x.roundRect(-MOLA_L - 1, -4 + comp * 4, MOLA_L * 2 + 2, 6, 3) : x.rect(-MOLA_L - 1, -4 + comp * 4, MOLA_L * 2 + 2, 6); x.fill(); x.stroke();
  x.fillStyle = 'rgba(255,255,255,.45)'; x.fillRect(-MOLA_L + 3, -3 + comp * 4, MOLA_L * 2 - 8, 1.4);
  x.restore();
}
function desenhaTurbo(x, tb, t){
  x.save(); x.translate(tb.x, tb.y); x.rotate(Math.atan2(tb.dy, tb.dx));
  const pulsa = reduz ? .5 : .5 + .5 * Math.sin(t * 6);
  x.strokeStyle = `rgba(255,201,60,${.25 + pulsa * .2})`; x.lineWidth = 2; x.setLineDash([4, 5]); x.beginPath(); x.arc(0, 0, TURBO_R - 2, 0, 7); x.stroke(); x.setLineDash([]);
  x.lineCap = 'round'; x.lineJoin = 'round';
  for(let k = 0; k < 3; k++){
    const o = reduz ? 0 : ((t * 22) % 12), xx = -14 + k * 11 + o * .5, al = .45 + k * .25;
    x.strokeStyle = `rgba(255,${150 + k * 30},${40 + k * 10},${al})`; x.lineWidth = 5; x.beginPath(); x.moveTo(xx - 5, -8); x.lineTo(xx + 3, 0); x.lineTo(xx - 5, 8); x.stroke();
  }
  x.restore();
}
// o vira-lata caramelo
function desenhaCao(x, px, py, dir, t, bravo, fase){
  x.save(); x.translate(px, py + CAO_R + 1); x.scale(dir, 1);
  const anda = reduz ? 0 : Math.sin(t * 13 + fase), rabo = reduz ? 0 : Math.sin(t * 18 + fase) * .5;
  x.strokeStyle = '#7A4416'; x.lineWidth = 2.6; x.lineCap = 'round';
  [[-8, anda], [-4, -anda], [6, -anda], [10, anda]].forEach(([lx, a]) => { x.beginPath(); x.moveTo(lx, -9); x.lineTo(lx + a * 3, -0.5); x.stroke(); });
  x.save(); x.translate(-12, -14); x.rotate(-.9 + rabo); x.strokeStyle = '#C8752E'; x.lineWidth = 3.2; x.beginPath(); x.moveTo(0, 0); x.quadraticCurveTo(-6, -4, -5, -10); x.stroke(); x.restore();
  x.fillStyle = '#D0833A'; x.beginPath(); x.ellipse(0, -13, 13, 6.6, 0, 0, 7); x.fill();
  x.fillStyle = '#EDB677'; x.beginPath(); x.ellipse(1, -10.5, 8, 3, 0, 0, 7); x.fill();
  x.fillStyle = '#D0833A'; x.beginPath(); x.ellipse(13, -19, 6.6, 6, 0, 0, 7); x.fill();
  x.fillStyle = '#EDB677'; x.beginPath(); x.ellipse(18.5, -17, 4.2, 3, 0, 0, 7); x.fill();
  x.fillStyle = '#1B1416'; x.beginPath(); x.arc(22.3, -18, 1.6, 0, 7); x.fill(); x.beginPath(); x.arc(14.5, -21, 1.15, 0, 7); x.fill();
  x.fillStyle = '#9A5520'; x.beginPath(); x.ellipse(9.5, -21, 2.8, 5.2, .5 + (bravo ? -.5 : 0), 0, 7); x.fill();
  if(bravo){ x.strokeStyle = '#1B1416'; x.lineWidth = 1.4; x.beginPath(); x.moveTo(17, -14.5); x.lineTo(22, -15.5); x.stroke(); }
  x.restore();
}
function desenhaBandeira(x, c, t){
  chegadaChao(x);
  x.save(); x.translate(c.x, c.y);
  x.strokeStyle = '#B7B9C2'; x.lineWidth = 2.6; x.beginPath(); x.moveTo(-16, 1); x.lineTo(-16, -94); x.stroke();
  x.fillStyle = '#FFC93C'; x.beginPath(); x.arc(-16, -95, 2.8, 0, 7); x.fill();
  const W = 36, H = 22, nx = 6, ny = 4;
  for(let i = 0; i < nx; i++) for(let j = 0; j < ny; j++){
    const u0 = i / nx, u1 = (i + 1) / nx, onda = a => reduz ? 0 : Math.sin(t * 5 - a * 4) * a * 4;
    x.fillStyle = (i + j) % 2 ? '#F3EEE2' : '#141218';
    x.beginPath(); x.moveTo(-16 + u0 * W, -92 + j * H / ny + onda(u0)); x.lineTo(-16 + u1 * W, -92 + j * H / ny + onda(u1)); x.lineTo(-16 + u1 * W, -92 + (j + 1) * H / ny + onda(u1)); x.lineTo(-16 + u0 * W, -92 + (j + 1) * H / ny + onda(u0)); x.closePath(); x.fill();
  }
  x.restore();
}

/* ---------- o carrinho de rolimã e o piloto de balde ---------- */
const CAMISAS = ['#FF7A2F', '#4AA8FF', '#FF4F9A', '#FFC93C', '#B07CFF', '#F3EEE2'];
function rolima(x, cx, giro){
  x.fillStyle = '#AEB2BD'; x.beginPath(); x.arc(cx, 0, RODA, 0, 7); x.fill();
  x.strokeStyle = '#4A4D57'; x.lineWidth = 1.3; x.stroke();
  x.fillStyle = '#5E616C'; x.beginPath(); x.arc(cx, 0, 3.7, 0, 7); x.fill();
  x.fillStyle = '#E2E4EA'; for(let k = 0; k < 7; k++){ const a = giro + k * .8976; x.beginPath(); x.arc(cx + Math.cos(a) * 5.05, Math.sin(a) * 5.05, 1.05, 0, 7); x.fill(); }
  x.fillStyle = '#17161B'; x.beginPath(); x.arc(cx, 0, 1.5, 0, 7); x.fill();
  x.strokeStyle = 'rgba(255,255,255,.55)'; x.lineWidth = 1; x.beginPath(); x.arc(cx, 0, RODA - 1.2, 3.6, 4.6); x.stroke();
}
// pose: 0 sentado, 1 encolhido (cambalhota), 2 braço pra cima (voando)
function desenhaCarro(x, p, lado, giro, pose, cam, alpha){
  const mx = (p[0] + p[2]) / 2, my = (p[1] + p[3]) / 2, ang = Math.atan2(p[3] - p[1], p[2] - p[0]);
  x.save(); x.globalAlpha = alpha; x.translate(mx, my); x.rotate(ang); x.scale(lado, 1);
  // a sombra no chão
  x.fillStyle = 'rgba(0,0,0,.25)'; x.beginPath(); x.ellipse(0, 7, 22, 2.5, 0, 0, 7); x.fill();
  // os eixos e a tábua
  x.fillStyle = '#5A3218'; x.fillRect(-17.5, -7, 5, 7); x.fillRect(12.5, -7, 5, 7);
  rolima(x, -15, giro); rolima(x, 15, giro);
  x.fillStyle = '#C27D3E'; x.strokeStyle = '#5A3218'; x.lineWidth = 1.4;
  x.beginPath(); x.moveTo(-23, -11.5); x.lineTo(21, -11.5); x.lineTo(24, -9); x.lineTo(21, -6.5); x.lineTo(-23, -6.5); x.closePath(); x.fill(); x.stroke();
  x.strokeStyle = 'rgba(90,50,24,.5)'; x.lineWidth = .8; x.beginPath(); x.moveTo(-20, -9.5); x.lineTo(18, -9.2); x.stroke();
  x.fillStyle = '#F3EEE2'; x.font = '700 5px ' + F_TXT; x.fillText('7', -19.5, -7.5);
  // o piloto
  const camisa = CAMISAS[cam % CAMISAS.length];
  const enc = pose === 1;
  const hip = [-5, -12.5], ombro = enc ? [0, -18] : [-2.5, -20.5], cab = enc ? [3.5, -22.5] : [0, -25.5];
  const joelho = enc ? [5, -21] : [6, -18.5], pe = enc ? [5.5, -13] : [14, -12.5];
  x.lineCap = 'round'; x.lineJoin = 'round';
  x.strokeStyle = '#2E4A7A'; x.lineWidth = 4.4; x.beginPath(); x.moveTo(hip[0], hip[1]); x.lineTo(joelho[0], joelho[1]); x.lineTo(pe[0], pe[1]); x.stroke();
  x.fillStyle = '#F3EEE2'; x.beginPath(); x.ellipse(pe[0] + 1.5, pe[1] + .8, 3.2, 1.9, 0, 0, 7); x.fill();
  x.strokeStyle = camisa; x.lineWidth = 6.2; x.beginPath(); x.moveTo(hip[0], hip[1] - 1); x.lineTo(ombro[0], ombro[1]); x.stroke();
  // a corda da direção e o braço
  const mao = pose === 2 ? [-1, -31] : enc ? [6, -15] : [9, -16];
  if(pose !== 2){ x.strokeStyle = '#D9C8A0'; x.lineWidth = .9; x.beginPath(); x.moveTo(mao[0], mao[1]); x.quadraticCurveTo(15, -13, 19, -9); x.stroke(); }
  x.strokeStyle = camisa; x.lineWidth = 3; x.beginPath(); x.moveTo(ombro[0], ombro[1] + 1); x.lineTo(enc ? 4 : 3.5, enc ? -17 : -18); x.lineTo(mao[0], mao[1]); x.stroke();
  x.fillStyle = '#8A5A35'; x.beginPath(); x.arc(mao[0], mao[1], 1.6, 0, 7); x.fill();
  // a cabeça e o balde
  x.fillStyle = '#8A5A35'; x.beginPath(); x.arc(cab[0], cab[1], 4.6, 0, 7); x.fill();
  x.fillStyle = '#1B1416'; x.beginPath(); x.arc(cab[0] + 2.4, cab[1] - .3, .95, 0, 7); x.fill();
  x.strokeStyle = '#1B1416'; x.lineWidth = .9; x.beginPath(); x.arc(cab[0] + 2, cab[1] + 1.2, 1.6, .2, 1.6); x.stroke();
  x.save(); x.translate(cab[0] - .5, cab[1] - 2.2); x.rotate(-.12);
  x.fillStyle = '#E8402A'; x.strokeStyle = '#7A1A10'; x.lineWidth = 1.1;
  x.beginPath(); x.moveTo(-6.4, 0); x.lineTo(6.4, 0); x.lineTo(4.6, -8.4); x.lineTo(-4.6, -8.4); x.closePath(); x.fill(); x.stroke();
  x.fillStyle = '#F3EEE2'; x.fillRect(-5.8, -3.6, 11.6, 1.6);
  x.strokeStyle = '#C9CCD6'; x.lineWidth = .9; x.beginPath(); x.moveTo(-5.6, -.5); x.quadraticCurveTo(-1, 7, 5.6, -.5); x.stroke();
  x.restore();
  x.restore();
}
// os pedaços quando capota: a tábua, o piloto e o balde voando cada um pra um lado
function desenhaPedaco(x, d){
  x.save(); x.translate(d.x, d.y); x.rotate(d.a); x.globalAlpha = Math.min(1, d.vida);
  if(d.k === 'balde'){ x.fillStyle = '#E8402A'; x.strokeStyle = '#7A1A10'; x.lineWidth = 1.1; x.beginPath(); x.moveTo(-6.4, 4); x.lineTo(6.4, 4); x.lineTo(4.6, -4.4); x.lineTo(-4.6, -4.4); x.closePath(); x.fill(); x.stroke(); x.fillStyle = '#F3EEE2'; x.fillRect(-5.8, .4, 11.6, 1.6); }
  else if(d.k === 'piloto'){
    x.strokeStyle = '#2E4A7A'; x.lineWidth = 4.2; x.lineCap = 'round'; x.beginPath(); x.moveTo(0, 3); x.lineTo(7, 7); x.lineTo(10, 12); x.stroke();
    x.strokeStyle = CAMISAS[d.cam % CAMISAS.length]; x.lineWidth = 6; x.beginPath(); x.moveTo(0, 3); x.lineTo(-2, -5); x.stroke();
    x.lineWidth = 3; x.beginPath(); x.moveTo(-2, -4); x.lineTo(-8, -9); x.stroke(); x.beginPath(); x.moveTo(-1, -4); x.lineTo(5, -10); x.stroke();
    x.fillStyle = '#8A5A35'; x.beginPath(); x.arc(-3, -10, 4.6, 0, 7); x.fill();
  } else {
    x.fillStyle = '#C27D3E'; x.strokeStyle = '#5A3218'; x.lineWidth = 1.4; x.fillRect(-23, -3, 46, 5); x.strokeRect(-23, -3, 46, 5);
    x.translate(0, 6); rolima(x, -15, d.a * 3); rolima(x, 15, d.a * 3);
  }
  x.restore();
}

/* ---------- as partículas: poeira de giz, confete, os textos que sobem ---------- */
const parts = [], pedacos = [];
function poeira(px, py, n, forca, cor){
  if(reduz) n = Math.ceil(n / 3);
  for(let i = 0; i < n; i++){ const a = -Math.PI / 2 + (Math.random() - .5) * 2.4; parts.push({ k: 'p', x: px + (Math.random() - .5) * 10, y: py, vx: Math.cos(a) * forca * (.4 + Math.random()), vy: Math.sin(a) * forca * (.3 + Math.random() * .7), r: 1.2 + Math.random() * 2.4, vida: .5 + Math.random() * .5, v0: 1, c: cor || '243,238,226' }); }
}
const CORES_CONFETE = ['#FFC93C', '#FF4F9A', '#4AA8FF', '#FF7A2F', '#F3EEE2', '#B07CFF'];
function confete(px, py, n){
  if(reduz) n = Math.min(n, 18);
  for(let i = 0; i < n; i++){ const a = -Math.PI / 2 + (Math.random() - .5) * 2.2, v = 180 + Math.random() * 380; parts.push({ k: 'c', x: px, y: py, vx: Math.cos(a) * v, vy: Math.sin(a) * v, a: Math.random() * 6, va: (Math.random() - .5) * 18, w: 3 + Math.random() * 3, h: 5 + Math.random() * 4, c: CORES_CONFETE[i % CORES_CONFETE.length], vida: 2.2 + Math.random() * 1.2 }); }
}
function textoSobe(px, py, txt, cor){ parts.push({ k: 't', x: px, y: py, vy: -60, txt, c: cor || '#FFC93C', vida: 1.3 }); }
function passoParticulas(dt){
  for(let i = parts.length - 1; i >= 0; i--){
    const q = parts[i]; q.vida -= dt;
    if(q.vida <= 0){ parts.splice(i, 1); continue; }
    if(q.k === 'p'){ q.x += q.vx * dt; q.y += q.vy * dt; q.vy += 160 * dt; q.vx *= 1 - dt * 3; }
    else if(q.k === 'c'){ q.x += q.vx * dt; q.y += q.vy * dt; q.vy += 520 * dt; q.vx *= 1 - dt * 1.6; q.vy *= 1 - dt * 1.2; q.a += q.va * dt; q.x += Math.sin(q.vida * 9 + q.a) * 20 * dt; }
    else if(q.k === 't'){ q.y += q.vy * dt; q.vy *= 1 - dt * 2; }
  }
  if(parts.length > 500) parts.splice(0, parts.length - 500);
  for(const d of pedacos){
    d.vy += G * dt; d.x += d.vx * dt; d.y += d.vy * dt; d.a += d.va * dt; d.vida -= dt * .25;
    if(CENA && d.y < CENA.F.yFundo + 400){
      const P = [d.x, d.y]; if(empurra(CENA.F, P, 0, d.r)){ const nx = CN[0], ny = CN[1], vn = d.vx * nx + d.vy * ny; if(vn < 0){ d.vx -= nx * vn * 1.4; d.vy -= ny * vn * 1.4; d.vx *= .82; d.vy *= .82; d.va *= .7; } d.x = P[0]; d.y = P[1]; }
    }
  }
}
// a poeira vai atrás do carrinho; confete, texto e os pedaços vão na frente
function desenhaPoeira(x){
  for(const q of parts) if(q.k === 'p'){ x.fillStyle = `rgba(${q.c},${Math.min(.6, q.vida)})`; x.beginPath(); x.arc(q.x, q.y, q.r, 0, 7); x.fill(); }
}
function desenhaParticulas(x){
  for(const q of parts){
    if(q.k === 'c'){ x.save(); x.translate(q.x, q.y); x.rotate(q.a); x.globalAlpha = Math.min(1, q.vida); x.fillStyle = q.c; x.fillRect(-q.w / 2, -q.h / 2, q.w, q.h * Math.abs(Math.cos(q.a * 1.7))); x.restore(); }
  }
  x.textAlign = 'center';
  for(const q of parts){
    if(q.k !== 't') continue;
    x.globalAlpha = Math.min(1, q.vida * 1.5); x.font = '15px ' + F_TIT;
    x.lineWidth = 4; x.strokeStyle = 'rgba(0,0,0,.8)'; x.strokeText(q.txt, q.x, q.y); x.fillStyle = q.c; x.fillText(q.txt, q.x, q.y); x.globalAlpha = 1;
  }
  x.textAlign = 'left';
  for(const d of pedacos) desenhaPedaco(x, d);
}

/* ---------- o som: tudo sintetizado na hora ---------- */
let ac = null, mestre = null, ruidoB = null, ronco = null, gizSom = null, somOn = le('som') !== '0';
function audio(){
  if(ac){ if(ac.state === 'suspended') ac.resume().catch(() => {}); return; }
  const AC = window.AudioContext || window.webkitAudioContext; if(!AC) return;
  try{ ac = new AC(); }catch(e){ ac = null; return; }
  mestre = ac.createGain(); mestre.gain.value = somOn ? .9 : 0;
  const comp = ac.createDynamicsCompressor(); comp.threshold.value = -16; comp.ratio.value = 5;
  mestre.connect(comp); comp.connect(ac.destination);
  const n = ac.sampleRate * 2; ruidoB = ac.createBuffer(1, n, ac.sampleRate); const d = ruidoB.getChannelData(0); for(let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
  // o ronco do rolimã: ruído com o tom pela velocidade, as bolinhas batendo (a modulação) e um grave
  ronco = { g: ac.createGain(), f: ac.createBiquadFilter(), s: ac.createBufferSource(), am: ac.createGain(), lfo: ac.createOscillator(), lg: ac.createGain(), o: ac.createOscillator(), og: ac.createGain() };
  ronco.s.buffer = ruidoB; ronco.s.loop = true; ronco.f.type = 'bandpass'; ronco.f.frequency.value = 400; ronco.f.Q.value = 1.3;
  ronco.s.connect(ronco.f); ronco.f.connect(ronco.am); ronco.am.connect(ronco.g); ronco.g.connect(mestre); ronco.g.gain.value = 0; ronco.am.gain.value = .65;
  ronco.lfo.type = 'square'; ronco.lfo.frequency.value = 20; ronco.lg.gain.value = .35; ronco.lfo.connect(ronco.lg); ronco.lg.connect(ronco.am.gain);
  ronco.o.type = 'triangle'; ronco.o.frequency.value = 55; ronco.o.connect(ronco.og); ronco.og.connect(mestre); ronco.og.gain.value = 0;
  ronco.s.start(); ronco.lfo.start(); ronco.o.start();
  // o giz riscando o asfalto
  gizSom = { g: ac.createGain(), h: ac.createBiquadFilter(), f: ac.createBiquadFilter(), s: ac.createBufferSource() };
  gizSom.s.buffer = ruidoB; gizSom.s.loop = true; gizSom.h.type = 'highpass'; gizSom.h.frequency.value = 1300; gizSom.f.type = 'peaking'; gizSom.f.frequency.value = 3400; gizSom.f.gain.value = 9;
  gizSom.s.connect(gizSom.h); gizSom.h.connect(gizSom.f); gizSom.f.connect(gizSom.g); gizSom.g.connect(mestre); gizSom.g.gain.value = 0; gizSom.s.start();
}
function poeSom(on, inicial){
  somOn = on; if(!inicial) guarda('som', on ? '1' : '0');
  document.querySelectorAll('.bt-som').forEach(b => { b.setAttribute('aria-pressed', String(on)); b.setAttribute('aria-label', on ? 'Som ligado' : 'Som desligado'); });
  // o som só nasce no primeiro toque (antes disso o navegador nem deixa)
  if(inicial) return;
  audio(); if(mestre) mestre.gain.setTargetAtTime(on ? .9 : 0, ac.currentTime, .05);
}
function atualizaRonco(vel, noChao, giz){
  if(!ac) return;
  const t = ac.currentTime, s = clamp(vel / VMAX, 0, 1), anda = noChao && vel > 6;
  ronco.g.gain.setTargetAtTime(anda ? .05 + s * .2 : 0, t, anda ? .05 : .03);
  ronco.f.frequency.setTargetAtTime(240 + s * 1250, t, .06);
  ronco.lfo.frequency.setTargetAtTime(7 + s * 62, t, .06);
  ronco.og.gain.setTargetAtTime(anda ? s * .09 : 0, t, .06); ronco.o.frequency.setTargetAtTime(46 + s * 80, t, .06);
  gizSom.g.gain.setTargetAtTime(clamp(giz, 0, 1) * .16, t, .03);
}
const gan = (o = mestre) => { const g = ac.createGain(); g.connect(o); return g; };
const env = (g, t, a, v, d) => { g.gain.setValueAtTime(.0001, t); g.gain.exponentialRampToValueAtTime(Math.max(.0002, v), t + a); g.gain.exponentialRampToValueAtTime(.0001, t + a + d); };
const osc = (tipo, f, t, dur, o) => { const s = ac.createOscillator(); s.type = tipo; s.frequency.setValueAtTime(f, t); s.connect(o); s.start(t); s.stop(t + dur + .05); return s; };
const ruid = (t, dur, o) => { const s = ac.createBufferSource(); s.buffer = ruidoB; s.connect(o); s.start(t, Math.random() * 1.5); s.stop(t + dur + .05); return s; };
const filt = (tipo, f, q, o) => { const b = ac.createBiquadFilter(); b.type = tipo; b.frequency.value = f; b.Q.value = q; b.connect(o); return b; };
const SFX = {
  pulo(){ const t = ac.currentTime; const g = gan(); env(g, t, .004, .22, .15); const s = osc('square', 200, t, .2, filt('lowpass', 1700, 1, g)); s.frequency.exponentialRampToValueAtTime(600, t + .11); const g2 = gan(); env(g2, t, .003, .12, .1); ruid(t, .12, filt('bandpass', 2600, 1, g2)); },
  pouso(f){ const t = ac.currentTime, v = clamp(f / 600, .18, 1); const g = gan(); env(g, t, .003, .32 * v, .17); osc('sine', 125, t, .2, g).frequency.exponentialRampToValueAtTime(46, t + .15); const g2 = gan(); env(g2, t, .002, .16 * v, .11); ruid(t, .13, filt('lowpass', 950, .8, g2));
    for(let i = 0; i < 3; i++){ const g3 = gan(); env(g3, t + .025 + i * .03, .001, .045 * v, .04); osc('triangle', 2300 + Math.random() * 1900, t + .025 + i * .03, .05, g3); } },
  mola(){ const t = ac.currentTime; const g = gan(); env(g, t, .004, .3, .5); const s = osc('sine', 150, t, .55, g); s.frequency.exponentialRampToValueAtTime(560, t + .15); s.frequency.exponentialRampToValueAtTime(290, t + .5);
    const l = ac.createOscillator(); l.frequency.value = 17; const lg = ac.createGain(); lg.gain.value = 45; l.connect(lg); lg.connect(s.frequency); l.start(t); l.stop(t + .55);
    const g2 = gan(); env(g2, t, .003, .1, .3); osc('triangle', 330, t, .35, g2).frequency.exponentialRampToValueAtTime(1150, t + .2); },
  turbo(){ const t = ac.currentTime; const g = gan(); env(g, t, .02, .2, .45); osc('sawtooth', 110, t, .5, filt('lowpass', 1700, 3, g)).frequency.exponentialRampToValueAtTime(460, t + .4);
    const g2 = gan(); env(g2, t, .05, .2, .4); const f = filt('bandpass', 800, 1.2, g2); ruid(t, .5, f); f.frequency.exponentialRampToValueAtTime(5200, t + .4); },
  latido(){ const t = ac.currentTime; [0, .19].forEach((d, i) => { const tt = t + d; const g = gan(); env(g, tt, .006, .3, .11); osc('sawtooth', 470 - i * 35, tt, .14, filt('bandpass', 1150 + i * 130, 2.2, g)).frequency.exponentialRampToValueAtTime(250, tt + .12); const g2 = gan(); env(g2, tt, .002, .13, .06); ruid(tt, .07, filt('bandpass', 1700, 1.4, g2)); }); },
  capotou(){ const t = ac.currentTime; const g = gan(); env(g, t, .004, .5, .5); const f = filt('lowpass', 1700, .9, g); ruid(t, .55, f); f.frequency.exponentialRampToValueAtTime(220, t + .5);
    const g2 = gan(); env(g2, t, .003, .42, .3); osc('sine', 112, t, .35, g2).frequency.exponentialRampToValueAtTime(38, t + .3);
    [523, 1187, 1712, 2390].forEach((fr, i) => { const g3 = gan(); env(g3, t + .07, .002, .16 / (i + 1), .55 - i * .09); osc('sine', fr, t + .07, .65, g3); }); },
  chegada(){ const t = ac.currentTime;
    [523, 659, 784, 1047].forEach((f, i) => { const fim = i === 3, d = fim ? .8 : .16; const g = gan(); env(g, t + i * .09, .006, .17, d); osc('square', f, t + i * .09, d + .05, filt('lowpass', 2600, 1, g)); const g2 = gan(); env(g2, t + i * .09, .006, .09, d); osc('sawtooth', f / 2, t + i * .09, d + .05, filt('lowpass', 1300, 1, g2)); });
    [659, 784, 1047].forEach(f => { const g = gan(); env(g, t + .36, .02, .07, .9); osc('triangle', f, t + .36, 1, g); });
    const g4 = gan(); env(g4, t + .3, .25, .05, 1.2); ruid(t + .3, 1.5, filt('bandpass', 1400, .5, g4)); },
  cambalhota(n){ const t = ac.currentTime; for(let i = 0; i < 3 + n; i++){ const g = gan(); env(g, t + i * .055, .003, .12, .22); osc('triangle', 880 * Math.pow(1.26, i), t + i * .055, .26, g); } },
  clique(){ const t = ac.currentTime; const g = gan(); env(g, t, .001, .08, .04); osc('square', 1500, t, .05, filt('bandpass', 1900, 3, g)); },
  carimbo(){ const t = ac.currentTime; const g = gan(); env(g, t, .002, .32, .14); osc('sine', 150, t, .16, g).frequency.exponentialRampToValueAtTime(60, t + .12); const g2 = gan(); env(g2, t, .001, .11, .05); ruid(t, .06, filt('lowpass', 2100, 1, g2)); },
  apaga(){ const t = ac.currentTime; const g = gan(); env(g, t, .02, .1, .18); ruid(t, .22, filt('bandpass', 950, .7, g)); },
  desfaz(){ const t = ac.currentTime; const g = gan(); env(g, t, .004, .11, .14); osc('triangle', 720, t, .16, g).frequency.exponentialRampToValueAtTime(340, t + .12); },
  copia(){ const t = ac.currentTime; [784, 1175, 1568].forEach((f, i) => { const g = gan(); env(g, t + i * .07, .004, .12, .2); osc('triangle', f, t + i * .07, .22, g); }); },
  vai(){ const t = ac.currentTime; const g = gan(); env(g, t, .004, .16, .22); osc('square', 988, t, .26, filt('lowpass', 2400, 1, g)); },
  erro(){ const t = ac.currentTime; const g = gan(); env(g, t, .004, .14, .2); osc('square', 140, t, .24, filt('lowpass', 900, 1, g)); },
  recorde(){ const t = ac.currentTime; [1047, 1319, 1568, 2093].forEach((f, i) => { const g = gan(); env(g, t + .5 + i * .07, .004, .1, .3); osc('triangle', f, t + .5 + i * .07, .32, g); }); }
};
const SONS = [];   // os últimos sons pedidos (pros testes)
const som = (k, v) => { SONS.push(k); if(SONS.length > 60) SONS.shift(); if(ac && somOn && SFX[k]) try{ SFX[k](v); }catch(e){} };
