// Roda o núcleo do Duvido da versão web (as partes em JS) e grava o que o porte em Godot tem que dar igual:
// os códigos das ladeiras, as descidas (com e sem toques), as idas e voltas do código do link.
// Uso: node tests/gera_esperado.mjs [pasta das partes] > tests/esperado.json
import fs from 'fs'; import vm from 'vm'; import path from 'path';
const aqui = path.dirname(new URL(import.meta.url).pathname);
const partes = process.argv[2] || path.join(aqui, '../../../web/duvido/partes');
const src = ['nucleo.js', 'codigo.js', 'fases.js'].map(f => fs.readFileSync(path.join(partes, f), 'utf8')).join('\n');
const expo = ['compila', 'novoEstado', 'toca', 'solta', 'passo', 'simula', 'rodaGravado', 'resumo', 'codifica', 'decodifica', 'idFase',
  'sen', 'sorteio', 'serra', 'piloto', 'desceRobo', 'geraDia', 'ladeiraDoDia', 'PRONTAS', 'PASSO'];
const ctx = vm.createContext({ Math, Date, Float64Array, Int16Array, Int32Array, Array, Object, JSON, String, Error, Infinity });
vm.runInContext(src + '\n' + expo.map(n => `globalThis.${n} = ${n};`).join('\n'), ctx);
const J = ctx;

const hex = x => { const d = new DataView(new ArrayBuffer(8)); d.setFloat64(0, x, true); return Buffer.from(d.buffer).toString('hex'); };
const hexP = p => hex(p[0]) + hex(p[1]) + hex(p[2]) + hex(p[3]);
const limpa = f => ({ autor: f.autor || '', tracos: f.tracos.map(t => ({ cor: t.cor, pts: t.pts.slice() })), carimbos: f.carimbos.map(c => ({ ...c })), corrente: (f.corrente || []).map(c => ({ ...c })), fantasma: f.fantasma ? f.fantasma.slice() : null });

// uma descida gravada (toca, solta, toca... em passos), com o rastro a cada 120 passos
function desce(F, ev) {
  const S = J.novoEstado(F); let j = 0; const rastro = [];
  while (!S.fim) {
    while (j < ev.length && ev[j] <= S.passos) { if (j % 2 === 0) J.toca(S); else J.solta(S); j++; }
    S.ev.length = 0; J.passo(F, S);
    if (S.passos % 120 === 0) rastro.push(hexP(S.p));
  }
  const r = J.resumo(S);
  return { motivo: r.motivo, chegou: r.chegou, capotou: r.capotou, cs: r.cs, cambalhotas: r.cambalhotas, passos: r.passos, fimP: hexP(S.p), fimV: hexP(S.v), giro: hex(S.giro), rastro };
}
// os toques de mentira: um sorteio com semente, do jeito que um dedo faria
function toquesDe(sem, n, gapMin, gapMax, segMin, segMax) {
  const r = J.sorteio(sem), ev = []; let t = Math.floor(r() * 120);
  for (let i = 0; i < n; i++) { t += gapMin + Math.floor(r() * (gapMax - gapMin)); ev.push(t); t += segMin + Math.floor(r() * (segMax - segMin)); ev.push(t); }
  return ev;
}

const saida = { fases: [], dias: [], codigos: [], invalidos: [], nomes: [] };
const testa = (nome, fase, extra) => {
  const F = J.compila(fase), o = { nome, cod: J.codifica(fase), id: J.idFase(fase), yMax: F.yMax, n: F.n, descidas: [] };
  o.descidas.push({ k: 'parado', ev: [], ...desce(F, []) });
  for (const antes of [0.28, 0.32, 0.36, 0.4]) { const r = J.desceRobo(F, { antes }); o.descidas.push({ k: 'robo' + antes, ev: r.ev, robo: { cs: r.r.cs, motivo: r.r.motivo }, ...desce(F, r.ev) }); }
  const seq = [[3, 4, 60, 200, 4, 40], [7, 8, 30, 120, 20, 140], [11, 12, 40, 90, 2, 10], [13, 3, 100, 300, 60, 200], [17, 20, 15, 60, 10, 30], [19, 6, 150, 400, 30, 90]];
  for (const [s, n, a, b, c, d] of seq) { const ev = toquesDe(s * 1000 + o.cod.length, n, a, b, c, d); o.descidas.push({ k: 'dedo' + s, ev, ...desce(F, ev) }); }
  // o simula com tempos em segundos (o arredondamento pra passo)
  const toques = [{ t: 0.513, tipo: 'toca' }, { t: 0.6, tipo: 'solta' }, { t: 2.0041, tipo: 'toca' }, { t: 2.4958, tipo: 'solta' }, { t: 3.3, tipo: 'toca' }, { t: 4.1, tipo: 'solta' }];
  const rs = J.simula(fase, toques);
  o.simula = { toques, motivo: rs.motivo, cs: rs.cs, cambalhotas: rs.cambalhotas, passos: rs.passos };
  Object.assign(o, extra || {});
  saida.fases.push(o);
};
J.PRONTAS.forEach((p, i) => testa('pronta' + i, p.fase));
const dias = [{ a: 2026, m: 10, d: 23 }, { a: 2026, m: 10, d: 22 }, { a: 2026, m: 10, d: 24 }, { a: 2025, m: 12, d: 25 }, { a: 2026, m: 1, d: 1 }, { a: 2026, m: 7, d: 4 }, { a: 2027, m: 2, d: 28 }, { a: 2024, m: 2, d: 29 }, { a: 2030, m: 5, d: 17 }];
for (const dia of dias) {
  const f = J.ladeiraDoDia(dia);
  saida.dias.push({ dia, cod: J.codifica(f), par: f.par === undefined ? null : f.par, robo: f.robo || null });
  testa('dia' + dia.a + '-' + dia.m + '-' + dia.d, f);
}
// uma ladeira de editor: traços tortos, todos os carimbos, turbo em toda direção
function ladeiraSorteada(sem) {
  const r = J.sorteio(sem), tracos = [], carimbos = [];
  let x = 128, y = 150;
  for (let k = 0; k < 7; k++) {
    const pts = [x, y]; const dir = k % 2 ? -1 : 1; let n = 3 + Math.floor(r() * 9);
    for (let i = 0; i < n; i++) { x = Math.max(0, Math.min(420, x + dir * (10 + Math.floor(r() * 40)))); y = Math.min(5200, y + Math.floor(r() * 30) - 4); pts.push(x, y); }
    tracos.push({ cor: Math.floor(r() * 4), pts });
    if (r() < 0.5) carimbos.push({ tipo: 'mola', x: Math.max(20, Math.min(400, x - dir * 60)), y: y - 3 });
    if (r() < 0.5) carimbos.push({ tipo: 'turbo', x: Math.max(20, Math.min(400, x - dir * 100)), y: y - 16, dir: Math.floor(r() * 16) });
    if (r() < 0.4) carimbos.push({ tipo: 'cachorro', x: Math.max(40, Math.min(380, x - dir * 140)), y });
    y += 70 + Math.floor(r() * 50); x = Math.max(0, Math.min(420, x - dir * 20));
  }
  carimbos.push({ tipo: 'chegada', x, y: y - 70 });
  return { autor: 'Teste', tracos, carimbos, corrente: [], fantasma: null };
}
for (const s of [101, 202, 303, 404]) testa('sorteada' + s, ladeiraSorteada(s));

// o código do link: autores com acento, corrente comprida, fantasma vazio e cheio
const base = J.PRONTAS[2].fase;
const casos = [
  { autor: 'Thales', corrente: [{ nome: 'Thales', cs: 1029 }], fantasma: [12, 40, 300, 330] },
  { autor: 'João Zé', corrente: [{ nome: 'João Zé', cs: 987 }, { nome: 'Bia', cs: 950 }], fantasma: [] },
  { autor: 'Ñandú ÿ~', corrente: [{ nome: 'a', cs: 0 }, { nome: 'bb', cs: 1 }, { nome: 'Cê', cs: 99999 }, { nome: 'd', cs: 512 }, { nome: 'e', cs: 513 }, { nome: 'f', cs: 14400 }, { nome: 'g', cs: 777 }], fantasma: null },
  { autor: 'Nome muito comprido demais', corrente: [], fantasma: [0] },
  { autor: 'Zé 😀 € 漢', corrente: [{ nome: '€uro', cs: 1500 }], fantasma: Array.from({ length: 50 }, (_, i) => i * 37 + (i % 3)) },
  { autor: '', corrente: [], fantasma: null },
];
for (const c of casos) {
  const f = { autor: c.autor, tracos: base.tracos, carimbos: base.carimbos, corrente: c.corrente, fantasma: c.fantasma };
  const cod = J.codifica(f), dec = J.decodifica(cod);
  saida.codigos.push({ entrada: limpa(f), cod, id: J.idFase(f), dec: dec ? limpa(dec) : null, recod: dec ? J.codifica(dec) : null });
}
for (const s of [101, 202]) { const f = ladeiraSorteada(s); f.corrente = [{ nome: 'Robô', cs: 1234 }]; f.fantasma = [5, 9]; const cod = J.codifica(f), dec = J.decodifica(cod); saida.codigos.push({ entrada: limpa(f), cod, id: J.idFase(f), dec: dec ? limpa(dec) : null, recod: dec ? J.codifica(dec) : null }); }
// os quebrados: cortado no meio, letra trocada, sem o dv1, letra que não existe
const bom = saida.codigos[0].cod;
const ruins = [bom.slice(0, bom.length - 3), bom.slice(0, 40), bom.slice(0, 3) + 'X' + bom.slice(4), bom.replace('dv1', 'dv2'), bom.slice(0, 10) + '!' + bom.slice(11), 'dv1', '', bom + 'A', bom.slice(0, -1) + (bom.slice(-1) === 'A' ? 'B' : 'A')];
for (const c of ruins) saida.invalidos.push({ cod: c, dec: J.decodifica(c) ? limpa(J.decodifica(c)) : null });
// o nome limpo (a mesma função da página)
function limpaNome(s) { return String(s || '').replace(/[^\x20-\x7E -ÿ]/g, '').replace(/\s+/g, ' ').trim().slice(0, 14); }
for (const s of ['Thales', '  João   da  Silva  ', 'Zé😀', 'Ñandú  x', 'abcdefghijklmnopqrstu', '\t tab\n', '€uro ÿ', '']) saida.nomes.push({ de: s, pra: limpaNome(s) });
process.stdout.write(JSON.stringify(saida));
