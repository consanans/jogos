
/* ---------- o código do link: a fase inteira em letras, dígitos, - e _ ---------- */
// é base64url sem "=": cada letra carrega 6 bits. Os números vão em Exp-Golomb (número pequeno, código curto)
// e os traços em diferenças de um ponto pro outro. Começa com "dv1" (a versão) e fecha com uma conferência de 12 bits,
// pra link cortado no meio do caminho (zap adora fazer isso) não abrir uma ladeira quebrada.
const ALFA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
const PREFIXO = 'dv1';
const NOME_MAX = 14, CORRENTE_MAX = 6;
function Escreve(){ this.b = []; }
Escreve.prototype.n = function(v, k){ for(let i = k - 1; i >= 0; i--) this.b.push((v >>> i) & 1); };
Escreve.prototype.eg = function(v, k){ const w = v + (1 << k); let nb = 0; for(let t = w; t > 0; t >>>= 1) nb++; for(let i = 0; i < nb - k - 1; i++) this.b.push(0); this.n(w, nb); };
Escreve.prototype.sz = function(v, k){ this.eg(v < 0 ? -2 * v - 1 : 2 * v, k); };
Escreve.prototype.txt = function(s){ const c = [...(s || '')].slice(0, NOME_MAX).map(ch => { const k = ch.codePointAt(0); return k > 31 && k < 256 ? k : 63; }); this.n(c.length, 4); c.forEach(k => this.n(k, 8)); };
const tamEG = (v, k) => { const w = v + (1 << k); let nb = 0; for(let t = w; t > 0; t >>>= 1) nb++; return 2 * nb - k - 1; };
const zz = v => v < 0 ? -2 * v - 1 : 2 * v;
function Le(bits){ this.b = bits; this.i = 0; }
Le.prototype.bit = function(){ if(this.i >= this.b.length) throw new Error('curto'); return this.b[this.i++]; };
Le.prototype.n = function(k){ let v = 0; for(let i = 0; i < k; i++) v = v * 2 + this.bit(); return v; };
Le.prototype.eg = function(k){ let z = 0; while(this.bit() === 0){ if(++z > 24) throw new Error('eg'); } let w = 1; for(let i = 0; i < z + k; i++) w = w * 2 + this.bit(); return w - (1 << k); };
Le.prototype.sz = function(k){ const u = this.eg(k); return u % 2 ? -(u + 1) / 2 : u / 2; };
Le.prototype.txt = function(){ const n = this.n(4); let s = ''; for(let i = 0; i < n; i++) s += String.fromCharCode(this.n(8)); return s; };
function soma12(b, ate){ let h = 0; for(let i = 0; i < ate; i++) h = (h * 31 + b[i] + 7) % 4093; return h; }

function codifica(fase){
  const w = new Escreve();
  const tr = (fase.tracos || []).filter(t => t.pts && t.pts.length >= 4);
  // o k que deixa os traços mais curtos
  let k = 2, melhor = Infinity;
  for(let kk = 0; kk <= 6; kk++){ let t = 0; for(const x of tr) for(let i = 2; i < x.pts.length; i++) t += tamEG(zz(x.pts[i] - x.pts[i - 2]), kk); if(t < melhor){ melhor = t; k = kk; } }
  // o fantasma pode ter zero toques (a descida sem encostar no dedo também é uma descida)
  const fant = Array.isArray(fase.fantasma) ? fase.fantasma : null;
  w.n(fant ? 1 : 0, 1); w.n(0, 3);
  w.txt(fase.autor || '');
  w.n(k, 3);
  w.eg(tr.length, 2);
  for(const t of tr){
    w.n(t.cor & 3, 2); w.eg(t.pts.length / 2 - 2, 3); w.n(t.pts[0], 9); w.n(t.pts[1], 13);
    for(let i = 2; i < t.pts.length; i++) w.sz(t.pts[i] - t.pts[i - 2], k);
  }
  const cs = fase.carimbos || [];
  w.eg(cs.length, 1);
  for(const c of cs){ const ti = TIPOS.indexOf(c.tipo); w.n(ti, 2); w.n(c.x, 9); w.n(c.y, 13); if(ti === 1) w.n(c.dir & 15, 4); }
  const co = (fase.corrente || []).slice(-CORRENTE_MAX);
  w.n(co.length, 3);
  for(const c of co){ w.txt(c.nome); w.eg(c.cs, 9); }
  if(fant){ w.eg(fant.length, 2); let a = 0; for(const n of fant){ w.eg(n - a, 4); a = n; } }
  w.n(soma12(w.b, w.b.length), 12);
  let s = PREFIXO;
  for(let i = 0; i < w.b.length; i += 6){ let v = 0; for(let j = 0; j < 6; j++) v = v * 2 + (w.b[i + j] || 0); s += ALFA[v]; }
  return s;
}
function decodifica(cod){
  try{
    if(typeof cod !== 'string' || cod.slice(0, 3) !== PREFIXO || cod.length > 12000) return null;
    const bits = [];
    for(let i = 3; i < cod.length; i++){ const v = ALFA.indexOf(cod[i]); if(v < 0) return null; for(let j = 5; j >= 0; j--) bits.push((v >> j) & 1); }
    const r = new Le(bits);
    const temFant = r.n(1); r.n(3);
    const autor = r.txt();
    const k = r.n(3);
    const nt = r.eg(2); if(nt > 400) return null;
    const tracos = []; let tot = 0;
    for(let i = 0; i < nt; i++){
      const cor = r.n(2), np = r.eg(3) + 2; tot += np; if(tot > 8000) return null;
      const pts = [r.n(9), r.n(13)];
      for(let j = 2; j < np * 2; j++) pts.push(pts[j - 2] + r.sz(k));
      for(let j = 0; j < pts.length; j += 2) if(pts[j] < 0 || pts[j] > LARG || pts[j + 1] < 0 || pts[j + 1] > ALT_MAX) return null;
      tracos.push({ cor, pts });
    }
    const nc = r.eg(1); if(nc > 80) return null;
    const carimbos = [];
    for(let i = 0; i < nc; i++){
      const ti = r.n(2), c = { tipo: TIPOS[ti], x: r.n(9), y: r.n(13) };
      if(ti === 1) c.dir = r.n(4);
      if(c.x > LARG || c.y > ALT_MAX) return null;
      carimbos.push(c);
    }
    const nco = r.n(3); if(nco > CORRENTE_MAX) return null;
    const corrente = [];
    for(let i = 0; i < nco; i++){ const nome = r.txt(), cs = r.eg(9); corrente.push({ nome, cs }); }
    let fantasma = null;
    if(temFant){ const ne = r.eg(2); if(ne > 4000) return null; fantasma = []; let a = 0; for(let i = 0; i < ne; i++){ a += r.eg(4); fantasma.push(a); } }
    const conta = soma12(bits, r.i);
    if(r.n(12) !== conta) return null;
    return { autor, tracos, carimbos, corrente, fantasma };
  }catch(e){ return null; }
}
// a identidade da ladeira (só o desenho): o recorde de cada uma mora aqui
function idFase(fase){
  const s = codifica({ autor: '', tracos: fase.tracos, carimbos: fase.carimbos, corrente: [], fantasma: null });
  let h = 2166136261;
  for(let i = 0; i < s.length; i++){ h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; }
  return h.toString(36);
}
