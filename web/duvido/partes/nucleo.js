/* ======================= o núcleo: física, fases e o código do link ======================= */
// Tudo daqui até o "fim do núcleo" é puro e determinístico. Na física só entra + − × ÷ e raiz quadrada
// (nada de seno nem cosseno do navegador, que muda no último dígito de um aparelho pro outro): a mesma
// fase com os mesmos toques dá o mesmo resultado em qualquer celular, e o fantasma do amigo desce igualzinho.

const PASSO = 1 / 120;          // a física anda em passos fixos
const G = 980;                  // gravidade forte, de ladeira
const LARG = 420;               // largura do mundo
const ALT_MAX = 5200;           // até onde dá pra desenhar (umas 6 telas)
const LB = 30;                  // distância entre os rolimãs
const RR = 10;                  // raio do rolimã que bate no giz (o rolimã de 6,5 mais a metade do traço)
const RH = 8.5;                 // a cabeça com o balde
const HC = 26;                  // altura da cabeça acima da tábua
const V0 = 90;                  // o empurrão da largada
const PULO = 350;
const VMAX = 780;
const ARRASTO = 0.00032;        // o vento na cara (cresce com a velocidade)
const ROLA = 16;                // rolimã quase não freia
const QUIQUE = 0.16, QUIQUE_MIN = 110;
const W_GIRO = 8.5, A_GIRO = 55, A_SOLTA = 60, SEG_MIN = 16;   // cambalhota: só segurando mais de 0,13 s
const AR_MIN = 22, PE_MIN = 0.14, COYOTE = 7;                 // pouso de pé: até uns 82 graus
const MOLA_L = 18, MOLA_V = 560;
const TURBO_V = 720, TURBO_R = 26;
const CAO_R = 11, CAO_VAI = 32, CAO_PER = 384;                 // o caramelo vai e volta em 3,2 s
const CHEG_L = 22, CHEG_A = 100;
const T_MAX = 14400, PARADO_MAX = 360;                         // 2 minutos; 3 s parado é empacou
const LARGADA = [4, 78, 4, 100, 128, 150];                     // o batente e a tábua da largada
// as 16 direções do turbo, de 22,5 em 22,5 graus (0 = direita, 4 = pra baixo), escritas à mão
const DIRS = [[1, 0], [0.9238795, 0.3826834], [0.7071068, 0.7071068], [0.3826834, 0.9238795], [0, 1], [-0.3826834, 0.9238795], [-0.7071068, 0.7071068], [-0.9238795, 0.3826834],
  [-1, 0], [-0.9238795, -0.3826834], [-0.7071068, -0.7071068], [-0.3826834, -0.9238795], [0, -1], [0.3826834, -0.9238795], [0.7071068, -0.7071068], [0.9238795, -0.3826834]];
const TIPOS = ['mola', 'turbo', 'cachorro', 'chegada'];

/* ---------- a fase compilada: os segmentos numa grade, os carimbos prontos ---------- */
const CEL = 40, GX0 = -2, GCOLS = 16;
function compila(fase){
  const S = [], T = [];
  const seg = (x1, y1, x2, y2, t) => { if(x1 === x2 && y1 === y2) return; S.push(x1, y1, x2, y2); T.push(t); };
  for(let i = 2; i < LARGADA.length; i += 2) seg(LARGADA[i - 2], LARGADA[i - 1], LARGADA[i], LARGADA[i + 1], -1);
  let yMax = 150;
  for(const tr of fase.tracos){
    const p = tr.pts;
    for(let i = 2; i < p.length; i += 2) seg(p[i - 2], p[i - 1], p[i], p[i + 1], -1);
    for(let i = 1; i < p.length; i += 2) if(p[i] > yMax) yMax = p[i];
  }
  const molas = [], turbos = [], caes = []; let chegada = null;
  for(const c of fase.carimbos){
    if(c.y > yMax) yMax = c.y;
    if(c.tipo === 'mola'){ molas.push({ x: c.x, y: c.y }); seg(c.x - MOLA_L, c.y, c.x + MOLA_L, c.y, molas.length - 1); }
    else if(c.tipo === 'turbo'){ const d = DIRS[c.dir & 15]; turbos.push({ x: c.x, y: c.y, dx: d[0], dy: d[1], dir: c.dir & 15 }); }
    else if(c.tipo === 'cachorro') caes.push({ x: c.x, y: c.y });
    else if(c.tipo === 'chegada') chegada = { x: c.x, y: c.y };
  }
  const F = { segs: Float64Array.from(S), tipo: Int16Array.from(T), n: T.length, molas, turbos, caes, chegada, yMax, yFundo: yMax + 500 };
  montaGrade(F);
  // o caramelo anda no chão que tem embaixo dele
  caes.forEach((c, i) => { c.cam = caminhoCao(F, c); c.fase = (i * 97) % CAO_PER; });
  return F;
}
function montaGrade(F){
  const rows = Math.floor((F.yFundo + 600) / CEL) + 8;
  const cells = new Array(GCOLS * rows), m = 14, s = F.segs;
  const cl = (v, a, b) => v < a ? a : v > b ? b : v;
  for(let k = 0; k < F.n; k++){
    const o = k * 4, xa = Math.min(s[o], s[o + 2]) - m, xb = Math.max(s[o], s[o + 2]) + m, ya = Math.min(s[o + 1], s[o + 3]) - m, yb = Math.max(s[o + 1], s[o + 3]) + m;
    const c0 = cl(Math.floor(xa / CEL) - GX0, 0, GCOLS - 1), c1 = cl(Math.floor(xb / CEL) - GX0, 0, GCOLS - 1);
    const r0 = cl(Math.floor(ya / CEL) + 4, 0, rows - 1), r1 = cl(Math.floor(yb / CEL) + 4, 0, rows - 1);
    for(let r = r0; r <= r1; r++) for(let c = c0; c <= c1; c++){ const i = r * GCOLS + c; (cells[i] || (cells[i] = [])).push(k); }
  }
  F.rows = rows; F.cells = cells; F.marca = new Int32Array(F.n); F.q = 0; F.lista = new Int32Array(Math.max(1, F.n));
}
// os segmentos perto de um ponto (sem repetir), na ordem de sempre: o resultado fica em F.lista
function consulta(F, x, y, r){
  const q = ++F.q, cl = (v, a, b) => v < a ? a : v > b ? b : v;
  const c0 = cl(Math.floor((x - r) / CEL) - GX0, 0, GCOLS - 1), c1 = cl(Math.floor((x + r) / CEL) - GX0, 0, GCOLS - 1);
  const r0 = cl(Math.floor((y - r) / CEL) + 4, 0, F.rows - 1), r1 = cl(Math.floor((y + r) / CEL) + 4, 0, F.rows - 1);
  let n = 0;
  for(let rr = r0; rr <= r1; rr++) for(let c = c0; c <= c1; c++){
    const cell = F.cells[rr * GCOLS + c]; if(!cell) continue;
    for(let j = 0; j < cell.length; j++){ const k = cell[j]; if(F.marca[k] !== q){ F.marca[k] = q; F.lista[n++] = k; } }
  }
  return n;
}
// o chão logo abaixo de um ponto (pra pôr cachorro, mola e bandeira em cima do giz)
function chaoEmbaixo(F, x, y0, alcance){
  let melhor = null; const s = F.segs;
  for(let k = 0; k < F.n; k++){
    if(F.tipo[k] >= 0) continue;
    const o = k * 4, x1 = s[o], y1 = s[o + 1], x2 = s[o + 2], y2 = s[o + 3];
    if(x1 === x2 || x < Math.min(x1, x2) || x > Math.max(x1, x2)) continue;
    const y = y1 + (y2 - y1) * (x - x1) / (x2 - x1);
    if(y >= y0 && y <= y0 + alcance && (melhor === null || y < melhor)) melhor = y;
  }
  return melhor;
}
function caminhoCao(F, c){
  const pts = [];
  for(let k = 0; k <= 8; k++){ const x = c.x - CAO_VAI + k * CAO_VAI / 4, y = chaoEmbaixo(F, x, c.y - 24, 90); pts.push(x, y === null ? c.y : y); }
  return pts;
}
// onde o caramelo tá no passo n: vai e volta, sem seno
const PC = new Float64Array(3);
function posCao(c, n){
  const m = (n + c.fase) % CAO_PER, h = CAO_PER / 2, u = m < h ? m / h : 2 - m / h, f = u * 8;
  const i = f >= 8 ? 7 : Math.floor(f), r = f - i, p = c.cam;
  PC[0] = p[i * 2] + (p[i * 2 + 2] - p[i * 2]) * r;
  PC[1] = p[i * 2 + 1] + (p[i * 2 + 3] - p[i * 2 + 1]) * r - CAO_R - 1;
  PC[2] = m < h ? 1 : -1;
  return PC;
}

/* ---------- a física do carrinho ---------- */
function novoEstado(F){
  const ax = LARGADA[2], ay = LARGADA[3], bx = LARGADA[4], by = LARGADA[5];
  const dx = bx - ax, dy = by - ay, l = Math.sqrt(dx * dx + dy * dy), ux = dx / l, uy = dy / l, nx = uy, ny = -ux;
  const p = new Float64Array([ax + ux * 20 + nx * RR, ay + uy * 20 + ny * RR, ax + ux * (20 + LB) + nx * RR, ay + uy * (20 + LB) + ny * RR]);
  return { p, pa: Float64Array.from(p), v: new Float64Array([ux * V0, uy * V0, ux * V0, uy * V0]),
    c0: 1, c1: 1, nx, ny, coyote: COYOTE, ar: 0, frente: 1, giro: 0, cambalhotas: 0, segura: false, segT: 0,
    passos: 0, parado: 0, fim: null, cdT: new Int16Array(F.turbos.length), cdM: new Int16Array(F.molas.length), ev: [] };
}
// o dedo encostou: no chão é pulo (na direção do chão); no ar, segurando, vira cambalhota
function toca(S){
  if(S.fim || S.segura) return;
  S.segura = true; S.segT = 0;
  if(S.coyote > 0){
    const v = S.v; v[0] += S.nx * PULO; v[1] += S.ny * PULO; v[2] += S.nx * PULO; v[3] += S.ny * PULO;
    S.coyote = 0; S.ev.push('pulo', 0);
  }
}
function solta(S){ S.segura = false; }
const CN = new Float64Array(3);
// empurra um círculo pra fora do giz; devolve se encostou (a normal média e a mola, se for, ficam em CN)
function empurra(F, p, i, r){
  let cx = p[i], cy = p[i + 1], nx = 0, ny = 0, mola = -1, hit = 0;
  const n = consulta(F, cx, cy, r + 2), s = F.segs, L = F.lista, r2 = r * r;
  for(let j = 0; j < n; j++){
    const k = L[j], o = k * 4, x1 = s[o], y1 = s[o + 1], dx = s[o + 2] - x1, dy = s[o + 3] - y1, l2 = dx * dx + dy * dy;
    let u = ((cx - x1) * dx + (cy - y1) * dy) / l2; if(u < 0) u = 0; else if(u > 1) u = 1;
    const ex = cx - (x1 + dx * u), ey = cy - (y1 + dy * u), d2 = ex * ex + ey * ey;
    if(d2 >= r2) continue;
    let d = Math.sqrt(d2), mx, my;
    if(d > 1e-9){ mx = ex / d; my = ey / d; }
    else { const l = Math.sqrt(l2); mx = dy / l; my = -dx / l; if(my > 0){ mx = -mx; my = -my; } d = 0; }
    cx += mx * (r - d); cy += my * (r - d); nx += mx; ny += my; hit = 1;
    if(F.tipo[k] >= 0) mola = F.tipo[k];
  }
  if(!hit) return 0;
  p[i] = cx; p[i + 1] = cy;
  const nl = Math.sqrt(nx * nx + ny * ny);
  if(nl > 1e-9){ CN[0] = nx / nl; CN[1] = ny / nl; } else { CN[0] = 0; CN[1] = -1; }
  CN[2] = mola;
  return 1;
}
function encosta(F, x, y, r){
  const n = consulta(F, x, y, r), s = F.segs, L = F.lista, r2 = r * r;
  for(let j = 0; j < n; j++){
    const o = L[j] * 4, x1 = s[o], y1 = s[o + 1], dx = s[o + 2] - x1, dy = s[o + 3] - y1;
    let u = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy); if(u < 0) u = 0; else if(u > 1) u = 1;
    const ex = x - (x1 + dx * u), ey = y - (y1 + dy * u);
    if(ex * ex + ey * ey < r2) return true;
  }
  return false;
}
function barra(p){ const dx = p[2] - p[0], dy = p[3] - p[1], d = Math.sqrt(dx * dx + dy * dy), k = (d - LB) / d * 0.5; p[0] += dx * k; p[1] += dy * k; p[2] -= dx * k; p[3] -= dy * k; }
// o rolimã no chão: tira o que entra no chão, quica um tiquinho e quase não freia
function contato(v, i, nx, ny, ox, oy){
  const vn = v[i] * nx + v[i + 1] * ny;
  if(vn < 0){ v[i] -= nx * vn; v[i + 1] -= ny * vn; }
  const on = ox * nx + oy * ny;
  if(on < -QUIQUE_MIN){ const q = -on * QUIQUE; v[i] += nx * q; v[i + 1] += ny * q; }
  const tx = -ny, ty = nx, vt = v[i] * tx + v[i + 1] * ty, d = ROLA * PASSO;
  if(vt > d){ v[i] -= tx * d; v[i + 1] -= ty * d; } else if(vt < -d){ v[i] += tx * d; v[i + 1] += ty * d; } else { v[i] -= tx * vt; v[i + 1] -= ty * vt; }
}
// o quanto a barra girou num passo (atan2 pra ângulo pequeno, só com conta e raiz)
function anguloPasso(sn, cs){
  if(cs <= 0) return sn >= 0 ? 1.5707963267948966 : -1.5707963267948966;
  let z = sn / cs;
  z = z / (1 + Math.sqrt(1 + z * z));
  const z2 = z * z;
  return 2 * z * (1 - z2 * (1 / 3 - z2 * (1 / 5 - z2 * (1 / 7 - z2 / 9))));
}
function acaba(S, motivo){
  S.fim = { motivo, passos: S.passos, cs: motivo === 'chegou' ? Math.max(0, Math.round(S.passos * 100 / 120) - 50 * S.cambalhotas) : null };
  S.ev.push('fim', 0);
}
function passo(F, S){
  if(S.fim) return;
  S.passos++;
  const p = S.p, v = S.v, pa = S.pa, dt = PASSO;
  pa[0] = p[0]; pa[1] = p[1]; pa[2] = p[2]; pa[3] = p[3];
  v[1] += G * dt; v[3] += G * dt;
  let bx = p[2] - p[0], by = p[3] - p[1], bl = Math.sqrt(bx * bx + by * by);
  const ux = bx / bl, uy = by / bl, upx = uy, upy = -ux;
  if(S.segura) S.segT++;
  // no ar: segurando, gira pra trás (a frente sobe); soltou, o giro morre rápido
  if(!S.c0 && !S.c1 && S.ar >= 2){
    const w = ((v[2] - v[0]) * upx + (v[3] - v[1]) * upy) / LB;
    let alvo = 0, a = A_SOLTA;
    if(S.segura && S.segT >= SEG_MIN){ alvo = (S.frente === 1 ? 1 : -1) * W_GIRO; a = A_GIRO; }
    let dw = alvo - w; const lim = a * dt; if(dw > lim) dw = lim; else if(dw < -lim) dw = -lim;
    const k = dw * LB / 2;
    v[2] += upx * k; v[3] += upy * k; v[0] -= upx * k; v[1] -= upy * k;
  }
  for(let i = 0; i < 4; i += 2){ const sp = Math.sqrt(v[i] * v[i] + v[i + 1] * v[i + 1]), f = 1 - ARRASTO * sp * dt; v[i] *= f; v[i + 1] *= f; }
  const o0x = v[0], o0y = v[1], o1x = v[2], o1y = v[3];
  p[0] += v[0] * dt; p[1] += v[1] * dt; p[2] += v[2] * dt; p[3] += v[3] * dt;
  let c0 = 0, c1 = 0, n0x = 0, n0y = 0, n1x = 0, n1y = 0, m0 = -1, m1 = -1;
  for(let it = 0; it < 3; it++){
    barra(p);
    if(empurra(F, p, 0, RR)){ c0 = 1; n0x = CN[0]; n0y = CN[1]; if(CN[2] >= 0) m0 = CN[2]; }
    if(empurra(F, p, 2, RR)){ c1 = 1; n1x = CN[0]; n1y = CN[1]; if(CN[2] >= 0) m1 = CN[2]; }
  }
  v[0] = (p[0] - pa[0]) / dt; v[1] = (p[1] - pa[1]) / dt; v[2] = (p[2] - pa[2]) / dt; v[3] = (p[3] - pa[3]) / dt;
  let impacto = 0;
  if(c0){ contato(v, 0, n0x, n0y, o0x, o0y); impacto = -(o0x * n0x + o0y * n0y); }
  if(c1){ contato(v, 2, n1x, n1y, o1x, o1y); impacto = Math.max(impacto, -(o1x * n1x + o1y * n1y)); }
  // a mola: pisou por cima, voa
  for(let k = 0; k < S.cdM.length; k++) if(S.cdM[k] > 0) S.cdM[k]--;
  const mk = m0 >= 0 ? m0 : m1, mny = m0 >= 0 ? n0y : n1y;
  if(mk >= 0 && S.cdM[mk] === 0 && mny < -0.5){ v[1] = -MOLA_V; v[3] = -MOLA_V; S.cdM[mk] = 24; S.ev.push('mola', mk); c0 = c1 = 0; }
  for(let i = 0; i < 4; i += 2){ const s2 = v[i] * v[i] + v[i + 1] * v[i + 1]; if(s2 > VMAX * VMAX){ const f = VMAX / Math.sqrt(s2); v[i] *= f; v[i + 1] *= f; } }
  bx = p[2] - p[0]; by = p[3] - p[1]; bl = Math.sqrt(bx * bx + by * by);
  const ux2 = bx / bl, uy2 = by / bl;
  if(!c0 && !c1){
    S.giro += anguloPasso(ux * uy2 - uy * ux2, ux * ux2 + uy * uy2);
    S.ar++; if(S.coyote > 0) S.coyote--;
  } else {
    let nx = (c0 ? n0x : 0) + (c1 ? n1x : 0), ny = (c0 ? n0y : 0) + (c1 ? n1y : 0);
    const nl = Math.sqrt(nx * nx + ny * ny);
    if(nl > 1e-9){ nx /= nl; ny /= nl; } else { nx = 0; ny = -1; }
    if(S.ar >= AR_MIN){
      // pousou: de pé conta as cambalhotas; torto demais, capotou
      if(uy2 * nx - ux2 * ny < PE_MIN){ S.c0 = c0; S.c1 = c1; return acaba(S, 'torto'); }
      const voltas = Math.floor((Math.abs(S.giro) + 3.141592653589793) / 6.283185307179586);
      if(voltas > 0){ S.cambalhotas += voltas; S.ev.push('cambalhota', voltas); }
      S.ev.push('pouso', impacto);
    } else if(impacto > 160) S.ev.push('pouso', impacto);
    S.giro = 0; S.ar = 0; S.coyote = COYOTE; S.nx = nx; S.ny = ny;
    const vb = ((v[0] + v[2]) * ux2 + (v[1] + v[3]) * uy2) / 2;
    if(vb > 25) S.frente = 1; else if(vb < -25) S.frente = 0;
  }
  S.c0 = c0; S.c1 = c1;
  const mx = (p[0] + p[2]) / 2, my = (p[1] + p[3]) / 2, hx = mx + uy2 * HC, hy = my - ux2 * HC;
  // a cabeça no chão: capotou
  if(encosta(F, hx, hy, RH)) return acaba(S, 'capotou');
  // o caramelo
  for(let i = 0; i < F.caes.length; i++){
    const c = posCao(F.caes[i], S.passos), cx = c[0], cy = c[1];
    const perto = (x, y, r) => (x - cx) * (x - cx) + (y - cy) * (y - cy) < r * r;
    if(perto(p[0], p[1], CAO_R + 6.5) || perto(p[2], p[3], CAO_R + 6.5) || perto(hx, hy, CAO_R + 7) || perto(mx + uy2 * 12, my - ux2 * 12, CAO_R + 9)) return acaba(S, 'cachorro');
  }
  // o turbo: passou por dentro, ganha velocidade pro lado da seta
  for(let i = 0; i < F.turbos.length; i++){
    const t = F.turbos[i];
    if(S.cdT[i] > 0) S.cdT[i]--;
    const dx = mx - t.x, dy = my - t.y;
    if(dx * dx + dy * dy < TURBO_R * TURBO_R){
      if(S.cdT[i] === 0){
        for(let j = 0; j < 4; j += 2){ const a = v[j] * t.dx + v[j + 1] * t.dy; if(a < TURBO_V){ v[j] += t.dx * (TURBO_V - a); v[j + 1] += t.dy * (TURBO_V - a); } }
        S.ev.push('turbo', i);
      }
      S.cdT[i] = 30;
    }
  }
  const ch = F.chegada;
  if(ch && mx >= ch.x - CHEG_L && mx <= ch.x + CHEG_L && my >= ch.y - CHEG_A && my <= ch.y + 16) return acaba(S, 'chegou');
  if(mx < -8 || mx > LARG + 8) return acaba(S, 'barranco');
  if(my > F.yFundo) return acaba(S, 'caiu');
  const vx = (v[0] + v[2]) / 2, vy = (v[1] + v[3]) / 2;
  if((c0 || c1) && vx * vx + vy * vy < 64) S.parado++; else S.parado = 0;
  if(S.parado > PARADO_MAX) return acaba(S, 'empacou');
  if(S.passos >= T_MAX) return acaba(S, 'tempo');
}
// desce a fase com uma lista de toques ({t em segundos, tipo 'toca' ou 'solta'}); puro e determinístico
function simula(fase, toques){
  const F = fase && fase.segs ? fase : compila(fase);
  const S = novoEstado(F);
  const evs = (toques || []).map((e, i) => ({ n: Math.max(0, Math.round(e.t / PASSO)), k: e.tipo === 'toca' ? 1 : 0, i })).sort((a, b) => a.n - b.n || a.i - b.i);
  let j = 0;
  while(!S.fim){
    while(j < evs.length && evs[j].n <= S.passos){ if(evs[j].k) toca(S); else solta(S); j++; }
    S.ev.length = 0;
    passo(F, S);
  }
  return resumo(S);
}
// o mesmo, com os toques gravados em passos (é assim que o fantasma viaja no link): toca, solta, toca...
function rodaGravado(F, eventos, S){
  S = S || novoEstado(F); let j = 0;
  while(!S.fim){
    while(j < eventos.length && eventos[j] <= S.passos){ if(j % 2 === 0) toca(S); else solta(S); j++; }
    S.ev.length = 0; passo(F, S);
  }
  return resumo(S);
}
function resumo(S){
  const m = S.fim.motivo;
  return { chegou: m === 'chegou', tempo: S.fim.cs === null ? null : S.fim.cs / 100, cs: S.fim.cs, capotou: m === 'capotou' || m === 'torto' || m === 'cachorro', motivo: m, cambalhotas: S.cambalhotas, passos: S.passos };
}
