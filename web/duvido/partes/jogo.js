
/* ======================= a página: telas, descida, editor ======================= */
const TINTA_MAX = 4200;                    // o giz do editor: segura o tamanho da ladeira e do link
const LIM = { mola: 8, turbo: 8, cachorro: 8, chegada: 1 };
let tela = 'inicio', JOGO = null, DEMO = null, DESAFIO = null, camY = -40, TEMPO = 0, tremor = 0, acc = 0, alfa = 0;
const fila = [];
let nome = limpaNome(le('nome') || '');
const recs = leJSON('recs', {}), fants = leJSON('fant', {});
const casaCache = {};

function limpaNome(s){ return String(s || '').replace(/[^\x20-\x7E -ÿ]/g, '').replace(/\s+/g, ' ').trim().slice(0, NOME_MAX); }
const corDe = s => { let h = 7; for(const ch of String(s || '')) h = (h * 31 + ch.charCodeAt(0)) % 9973; return h; };
function tempoCasa(i){
  if(casaCache[i]) return casaCache[i];
  const p = PRONTAS[i], F = compila(p.fase); let best = null;
  for(const antes of [.28, .32, .36, .4]){ const x = desceRobo(F, { antes }); if(x.r.chegou && (!best || x.r.cs < best.cs)) best = { cs: x.r.cs, ev: x.ev }; }
  return (casaCache[i] = best);
}
let DIA = null;
function doDia(){ const d = diaHoje(); if(!DIA || DIA.dia.d !== d.d || DIA.dia.m !== d.m || DIA.dia.a !== d.a) DIA = ladeiraDoDia(d); return DIA; }
const dd = n => String(n).padStart(2, '0');

/* ---------- os cartões e os avisos ---------- */
const CARTOES = ['inicio', 'desafio', 'cola', 'nome', 'fim', 'manda'];
let usouTeclado = false;
addEventListener('keydown', e => { if(e.key === 'Tab') usouTeclado = true; }, true);
function soCartao(id, foco){
  CARTOES.forEach(c => { $(c).hidden = c !== id; });
  $('veu').hidden = !id;
  if(id){ const el = $(id); el.scrollTop = 0; const f = foco ? $(foco) : el.querySelector('.bt-vai, .bt-rosa'); if(f && (foco ? !dedoTela : usouTeclado)) setTimeout(() => { try{ f.focus({ preventScroll: true }); }catch(e){} }, 30); }
}
let avisoT = 0;
function aviso(txt, seg){ const a = $('aviso'); a.textContent = txt; a.hidden = false; avisoT = seg || 2.6; }
function carimbo(txt, sub, tipo, seg){
  const c = $('carimbo'); $('carT').textContent = txt; $('carS').textContent = sub || ''; $('carS').hidden = !sub;
  c.className = 'carimbo ' + (tipo || ''); void c.offsetWidth; c.classList.add('bate'); c.hidden = false; carimboT = seg || 0;
}
let carimboT = 0;
function mostraUI(){
  const jogando = tela === 'jogo', editando = tela === 'editor';
  $('hud').hidden = !jogando; app.classList.toggle('editando', editando);
  ['edTopo', 'edFerr'].forEach(id => $(id).hidden = !editando);
  $('cores').hidden = !editando || ED.ferr !== 'lapis';
  if(!editando){ $('edDica').hidden = true; $('apagaTudo').hidden = true; }
  if(!jogando){ $('carimbo').hidden = true; $('pos').hidden = true; $('dicaJogo').hidden = true; }
}

/* ---------- a entrada ---------- */
function miniatura(c, fase){
  const x = c.getContext('2d'), W = c.width, H = c.height, F = compila(fase);
  const alt = Math.max(F.yMax + 30, 400), s = Math.min(W / LARG, H / (alt + 20)), ox = (W - LARG * s) / 2;
  x.fillStyle = '#121116'; x.fillRect(0, 0, W, H);
  x.save(); x.translate(ox, 6); x.scale(s, s);
  x.strokeStyle = 'rgba(255,201,60,.35)'; x.lineWidth = 1 / s; x.strokeRect(0, 0, LARG, alt);
  x.lineCap = 'round'; x.lineJoin = 'round';
  x.strokeStyle = '#B9733A'; x.lineWidth = 7; x.beginPath(); x.moveTo(LARGADA[2], LARGADA[3]); x.lineTo(LARGADA[4], LARGADA[5]); x.stroke();
  for(const t of fase.tracos){ const c2 = CORES_GIZ[t.cor] || CORES_GIZ[0]; x.strokeStyle = `rgb(${c2})`; x.lineWidth = Math.max(5, 1.6 / s); x.beginPath(); for(let i = 0; i < t.pts.length; i += 2) i ? x.lineTo(t.pts[i], t.pts[i + 1]) : x.moveTo(t.pts[0], t.pts[1]); x.stroke(); }
  for(const cb of fase.carimbos){
    x.fillStyle = { mola: '#FF4F9A', turbo: '#FFC93C', cachorro: '#D0833A', chegada: '#F3EEE2' }[cb.tipo];
    x.beginPath(); x.arc(cb.x, cb.y - (cb.tipo === 'chegada' ? 20 : 8), cb.tipo === 'chegada' ? 16 : 12, 0, 7); x.fill();
  }
  x.restore();
}
function montaLista(){
  const L = $('iFases'); L.innerHTML = '';
  const dia = doDia(), linhas = [{ tipo: 'dia', fase: dia, nome: 'Ladeira do dia', sub: 'Muda à meia-noite, igual pra todo mundo · ' + dd(dia.dia.d) + '/' + dd(dia.dia.m), casa: dia.par ? { cs: dia.par } : null }];
  PRONTAS.forEach((p, i) => linhas.push({ tipo: 'pronta', i, fase: p.fase, nome: (i + 1) + '. ' + p.nome, sub: p.sub, casa: null }));
  for(const l of linhas){
    const b = document.createElement('button'); b.className = 'fase' + (l.tipo === 'dia' ? ' dia' : '');
    const c = document.createElement('canvas'); c.width = 96; c.height = 120; c.setAttribute('aria-hidden', 'true');
    const id = idFase(l.fase), r = recs[id];
    b.innerHTML = `<span class="txt"><b></b><small></small></span><em></em>`;
    b.prepend(c);
    b.querySelector('b').textContent = l.nome; b.querySelector('small').textContent = l.sub;
    b.querySelector('em').innerHTML = r !== undefined ? `${fmt2(r)} s<span>teu recorde</span>` : `—<span>sem tempo</span>`;
    b.setAttribute('aria-label', l.nome + '. ' + l.sub + (r !== undefined ? '. Teu recorde: ' + fmt2(r) + ' segundos' : ''));
    b.addEventListener('click', () => { audio(); som('clique'); jogaFase(l.fase, l.tipo, l.tipo === 'pronta' ? { i: l.i } : { dia: l.fase.dia }); });
    L.appendChild(b); miniatura(c, l.fase);
  }
}
function mostraInicio(){
  tela = 'inicio'; JOGO = null; soltaTrava();
  $('iQuem').hidden = !nome; $('iNome').textContent = nome;
  montaLista(); soCartao('inicio'); mostraUI();
  const d = doDia(); iniciaDemo(d, d.robo || null);
}

/* ---------- a demonstração atrás dos cartões (o robô descendo, ou o fantasma de quem mandou o desafio) ---------- */
function iniciaDemo(fase, eventos){
  const F = compila(fase); montaCena(fase, F);
  DEMO = { F, fase, S: novoEstado(F), ev: eventos, j: 0, espera: 0, vis: novoVis(), cam: corDe(nome || 'demo') };
  camY = -40;
}
function passoDemo(dt){
  const D = DEMO; if(!D) return;
  if(D.S.fim){ D.espera += dt; if(D.espera > 1.4){ D.S = novoEstado(D.F); D.j = 0; D.espera = 0; D.vis = novoVis(); } }
  else {
    acc += dt; let n = 0;
    while(acc >= PASSO && n < 30){
      if(D.ev){ while(D.j < D.ev.length && D.ev[D.j] <= D.S.passos){ if(D.j % 2 === 0) toca(D.S); else solta(D.S); D.j++; } }
      else { const a = piloto(D.F, D.S); if(a === 1) toca(D.S); else if(a === 0) solta(D.S); }
      D.S.ev.length = 0; passo(D.F, D.S); acc -= PASSO; n++;
      if(D.S.fim) break;
    }
    if(n >= 30) acc = 0;
  }
  passoVis(D.vis, D.S, dt);
  seguir(D.S, dt, D.S.fim ? 1 : acc / PASSO);
}

/* ---------- a descida ---------- */
function tituloDe(origem, extra, fase){
  if(origem === 'pronta') return PRONTAS[extra.i].nome;
  if(origem === 'dia') return 'Ladeira do dia · ' + dd(extra.dia.d) + '/' + dd(extra.dia.m);
  if(origem === 'teste') return 'Tua ladeira';
  return fase.autor ? 'Ladeira de ' + fase.autor : 'Ladeira do desafio';
}
function jogaFase(fase, origem, extra){
  audio();
  const F = compila(fase);
  JOGO = { fase, F, origem, extra: extra || {}, id: idFase(fase), S: null, G: null, gEv: null, gNome: '', ev: [], sessao: null, tentativas: 0 };
  JOGO.titulo = tituloDe(origem, JOGO.extra, fase);
  DEMO = null; montaCena(fase, F);
  defineFantasma(JOGO);
  tela = 'jogo'; soCartao(null); mostraUI();
  comecaDescida(); pedeTrava();
}
// o fantasma: no desafio, quem mandou; senão, o teu melhor; senão, a casa (o robô)
function defineFantasma(J){
  J.gEv = null; J.gNome = '';
  if(J.origem === 'desafio' && J.fase.fantasma && J.fase.corrente && J.fase.corrente.length){ J.gEv = J.fase.fantasma; J.gNome = J.fase.corrente[J.fase.corrente.length - 1].nome; }
  else if(fants[J.id]){ J.gEv = fants[J.id]; J.gNome = 'teu recorde'; }
  else if(J.origem === 'pronta'){ const c = tempoCasa(J.extra.i); if(c){ J.gEv = c.ev; J.gNome = 'a casa'; } }
  else if(J.origem === 'dia' && J.fase.robo){ J.gEv = J.fase.robo; J.gNome = 'a casa'; }
}
function novoVis(){ return { giro: 0, lado: 1, pose: 0, arT: 0 }; }
function comecaDescida(){
  const J = JOGO;
  J.S = novoEstado(J.F); J.ev = []; J.tentativas++;
  J.G = J.gEv ? novoEstado(J.F) : null; J.gj = 0; J.gAlfa = .42;
  J.vis = novoVis(); J.gVis = novoVis(); J.fimT = 0; J.podeReiniciar = false; J.mostrouFim = false; J.latiu = []; J.molaT = [];
  fila.length = 0; acc = 0; parts.length = 0; pedacos.length = 0; tremor = 0;
  camY = -40;
  $('carimbo').hidden = true; $('pos').hidden = true; soCartao(null); mostraUI();
  atualizaAlvo();
  const primeira = !le('dica-jogo');
  $('dicaTx').innerHTML = dedoTela ? '<b>Toca</b>: pula · <b>Segura</b> no ar: cambalhota' : '<b>Espaço</b>: pula · <b>segura</b> no ar: cambalhota · <b>R</b> recomeça';
  $('dicaJogo').hidden = !(primeira || J.tentativas === 1);
  if(J.tentativas === 1){ carimbo('VAI!', '', 'vai', .6); som('vai'); }
}
function atualizaAlvo(){
  const J = JOGO, r = recs[J.id];
  let h = '';
  if(J.origem === 'desafio' && J.fase.corrente && J.fase.corrente.length){ const u = J.fase.corrente[J.fase.corrente.length - 1]; h = `<b>${esc(u.nome)}</b>: ${fmt2(u.cs)}`; }
  else if(J.origem === 'pronta'){ const c = tempoCasa(J.extra.i); if(c) h = `casa: ${fmt2(c.cs)}`; }
  else if(J.origem === 'dia' && J.fase.par) h = `casa: ${fmt2(J.fase.par)}`;
  if(r !== undefined) h += (h ? ' · ' : '') + `teu: ${fmt2(r)}`;
  $('alvo').innerHTML = h;
}
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
function apertou(){
  if(tela !== 'jogo' || !JOGO) return;
  audio();
  const S = JOGO.S;
  if(S.fim){ if(JOGO.podeReiniciar && S.fim.motivo !== 'chegou') reinicia(); return; }
  fila.push(1);
  if(!$('dicaJogo').hidden && S.passos > 30){ $('dicaJogo').hidden = true; guarda('dica-jogo', '1'); }
}
function soltou(){ if(tela === 'jogo' && JOGO && !JOGO.S.fim) fila.push(0); }
function aplicaFila(){
  const S = JOGO.S;
  while(fila.length){ const k = fila.shift(); if(k === 1 && !S.segura){ toca(S); JOGO.ev.push(S.passos); } else if(k === 0 && S.segura){ solta(S); JOGO.ev.push(S.passos); } }
}
function passoFantasma(){
  const J = JOGO, G = J.G; if(!G || G.fim) return;
  while(J.gj < J.gEv.length && J.gEv[J.gj] <= G.passos){ if(J.gj % 2 === 0) toca(G); else solta(G); J.gj++; }
  G.ev.length = 0; passo(J.F, G);
}
function passoJogo(dt){
  const J = JOGO, S = J.S;
  acc += dt; let n = 0;
  while(acc >= PASSO && n < 30){
    if(!S.fim){ S.ev.length = 0; if(J.agenda) while(J.agenda.length && J.agenda[0].n <= S.passos) fila.push(J.agenda.shift().k); aplicaFila(); passo(J.F, S); trataEventos(S); if(S.fim) fimDaDescida(); }
    passoFantasma();
    acc -= PASSO; n++;
  }
  if(n >= 30) acc = 0;
  alfa = S.fim ? 1 : acc / PASSO;
  if(S.fim){
    J.fimT += dt;
    if(!J.podeReiniciar && J.fimT > .32 && S.fim.motivo !== 'chegou'){ J.podeReiniciar = true; $('pos').hidden = false; }
    if(S.fim.motivo === 'chegou' && J.fimT > 1 && !J.mostrouFim){ J.mostrouFim = true; mostraFim(); }
  }
  if(J.G){ if(J.G.fim && J.G.fim.motivo !== 'chegou') J.gAlfa = Math.max(0, J.gAlfa - dt * .8); passoVis(J.gVis, J.G, dt); }
  passoVis(J.vis, S, dt);
  // o caramelo late quando o carrinho chega perto
  if(!S.fim) J.F.caes.forEach((c, i) => {
    const q = posCao(c, S.passos), mx = (S.p[0] + S.p[2]) / 2, my = (S.p[1] + S.p[3]) / 2;
    if(Math.abs(q[0] - mx) < 120 && Math.abs(q[1] - my) < 60 && TEMPO - (J.latiu[i] || -9) > 1.6){ J.latiu[i] = TEMPO; som('latido'); textoSobe(q[0] + 10, q[1] - 22, 'AU!', '#F3EEE2'); }
  });
  for(let i = 0; i < J.molaT.length; i++) if(J.molaT[i] > 0) J.molaT[i] -= dt;
  // correndo no chão, o rolimã levanta pó de giz atrás
  if(!S.fim && (S.c0 || S.c1)){ const vx = (S.v[0] + S.v[2]) / 2, vy = (S.v[1] + S.v[3]) / 2, sp = Math.sqrt(vx * vx + vy * vy); J.poT = (J.poT || 0) + dt * sp / 90; if(sp > 300 && J.poT > 1 && !reduz){ J.poT = 0; const tr = S.frente === 1 ? 0 : 2; parts.push({ k: 'p', x: S.p[tr] - S.nx * RR, y: S.p[tr + 1] - S.ny * RR, vx: -vx * .15 + (Math.random() - .5) * 30, vy: -20 - Math.random() * 30, r: 1 + Math.random() * 1.8, vida: .35 + Math.random() * .3, c: '243,238,226' }); } }
  seguir(S, dt, alfa);
  $('relogio').innerHTML = fmt2(tempoAtual(S)) + '<small>s</small>';
}
function tempoAtual(S){ if(S.fim && S.fim.cs !== null) return S.fim.cs; return Math.max(0, Math.round(S.passos * 100 / 120) - 50 * S.cambalhotas); }
function trataEventos(S){
  const ev = S.ev, p = S.p;
  for(let i = 0; i < ev.length; i += 2){
    const k = ev[i], v = ev[i + 1];
    if(k === 'pulo'){ som('pulo'); chaoPoeira(S, 8, 90); }
    else if(k === 'pouso'){ if(v > 130){ som('pouso', v); chaoPoeira(S, Math.min(16, v / 40 | 0), Math.min(160, v * .3)); if(v > 420) tremor = Math.max(tremor, .12); } }
    else if(k === 'mola'){ som('mola'); JOGO.molaT[v] = .32; }
    else if(k === 'turbo'){ som('turbo'); poeira((p[0] + p[2]) / 2, (p[1] + p[3]) / 2, 10, 160, '255,201,60'); }
    else if(k === 'cambalhota'){ som('cambalhota', v); textoSobe((p[0] + p[2]) / 2, (p[1] + p[3]) / 2 - 46, '+' + v + (v > 1 ? ' CAMBALHOTAS' : ' CAMBALHOTA'), '#FFC93C'); textoSobe((p[0] + p[2]) / 2, (p[1] + p[3]) / 2 - 28, '−' + fmt1(v * 50) + ' s', '#F3EEE2'); }
  }
}
function chaoPoeira(S, n, f){ const p = S.p, nx = S.nx, ny = S.ny; for(const i of [0, 2]) poeira(p[i] - nx * RR, p[i + 1] - ny * RR, Math.ceil(n / 2), f); }
// o carrinho na tela: os rolimãs girando, o lado que ele olha virando devagar, a pose do piloto
function passoVis(V, S, dt){
  const v = S.v, p = S.p, ux = (p[2] - p[0]) / LB, uy = (p[3] - p[1]) / LB, vb = ((v[0] + v[2]) * ux + (v[1] + v[3]) * uy) / 2;
  V.giro += vb * dt / RODA;
  const alvo = S.frente === 1 ? 1 : -1;
  if(reduz) V.lado = alvo; else V.lado += clamp(alvo - V.lado, -dt * 11, dt * 11);
  const noAr = !S.c0 && !S.c1;
  V.arT = noAr ? V.arT + dt : 0;
  V.pose = S.fim ? 0 : noAr && S.segura && S.segT >= SEG_MIN ? 1 : V.arT > .45 ? 2 : 0;
}
function seguir(S, dt, a){
  const p = S.p, pa = S.pa, my = (pa[1] + pa[3]) / 2 + ((p[1] + p[3]) / 2 - (pa[1] + pa[3]) / 2) * a, vy = (S.v[1] + S.v[3]) / 2;
  let alvo = my - VH * .38 + clamp(vy * .22, -VH * .1, VH * .18);
  alvo = Math.max(alvo, -40);
  if(my - 34 < alvo + VH * .1) alvo = my - 34 - VH * .1;
  alvo = Math.min(alvo, Math.max(-40, (CENA ? CENA.yMax + 150 - VH : 0), my - VH * .62));
  camY += (alvo - camY) * (1 - Math.exp(-dt * 5.5));
}
const TITULO = { capotou: 'CAPOTOU!', torto: 'CAPOTOU!', cachorro: 'CAPOTOU!', barranco: 'BARRANCO!', caiu: 'DESPENCOU!', empacou: 'EMPACOU!', tempo: 'DEMOROU!' };
const FRASES = {
  capotou: ['Beijou o asfalto.', 'O balde aguentou. Tu, nem tanto.', 'Ralou até a alma.', 'Capacete de balde salvou.'],
  torto: ['Pousou de cara no chão.', 'Pousou torto demais.', 'Faltou girar mais um tiquinho.'],
  cachorro: ['O caramelo não deixou.', 'Cachorro do vizinho: 1. Tu: 0.', 'Ele só queria brincar.'],
  barranco: ['Saiu da pista.', 'Foi pro mato.', 'O barranco agradece a visita.'],
  caiu: ['Lá embaixo não tem nada.', 'Faltou chão.'],
  empacou: ['Parou no meio do caminho.', 'Sem embalo não desce.'],
  tempo: ['Dois minutos e nada.']
};
function fimDaDescida(){
  const J = JOGO, S = J.S, m = S.fim.motivo, mx = (S.p[0] + S.p[2]) / 2, my = (S.p[1] + S.p[3]) / 2;
  fila.length = 0; $('dicaJogo').hidden = true;
  if(m === 'chegou'){
    const cs = S.fim.cs, run = { cs, ev: J.ev.slice(), camb: S.cambalhotas };
    J.ultimo = run;
    const ant = recs[J.id]; J.recorde = ant === undefined || cs < ant; J.antes = ant;
    if(J.recorde){ recs[J.id] = cs; guardaJSON('recs', recs); fants[J.id] = run.ev; podaFants(); }
    if(!J.sessao || cs < J.sessao.cs) J.sessao = run;
    if(J.origem === 'teste'){ if(ED.validado !== J.id || !ED.melhor || cs < ED.melhor.cs){ ED.melhor = run; } ED.validado = J.id; salvaRascunho(); }
    carimbo('CHEGOU!', fmt2(cs) + ' s' + (S.cambalhotas ? ' · ' + S.cambalhotas + (S.cambalhotas > 1 ? ' cambalhotas' : ' cambalhota') : ''), 'ok');
    som('chegada'); if(J.recorde && ant !== undefined) som('recorde');
    confete(mx, my - 30, 140); if(!reduz) setTimeout(() => { if(JOGO === J) confete(mx, my - 80, 70); }, 260);
  } else {
    const fr = FRASES[m] || ['Deu ruim.'];
    let sub = fr[(J.tentativas - 1) % fr.length];
    if(J.origem === 'teste' && !J.F.chegada && (m === 'caiu' || m === 'empacou')) sub = 'Falta a CHEGADA: põe a bandeira no fim.';
    carimbo(TITULO[m] || 'DEU RUIM', sub, '');
    $('posTx').textContent = dedoTela ? 'Toca pra tentar de novo' : 'Clica ou aperta espaço pra tentar de novo';
    $('pEditor').hidden = J.origem !== 'teste';
    if(m === 'capotou' || m === 'torto' || m === 'cachorro'){
      som('capotou'); tremor = .45; soltaPedacos(S);
      try{ if(navigator.vibrate) navigator.vibrate([60, 40, 90]); }catch(e){}
      if(m === 'cachorro') setTimeout(() => som('latido'), 120);
    } else som('erro');
  }
}
function soltaPedacos(S){
  const p = S.p, mx = (p[0] + p[2]) / 2, my = (p[1] + p[3]) / 2, vx = (S.v[0] + S.v[2]) / 2, vy = (S.v[1] + S.v[3]) / 2;
  const ux = (p[2] - p[0]) / LB, uy = (p[3] - p[1]) / LB, hx = mx + uy * HC, hy = my - ux * HC, lado = S.frente === 1 ? 1 : -1;
  const ang = Math.atan2(p[3] - p[1], p[2] - p[0]);
  pedacos.push({ k: 'tabua', x: mx, y: my, vx: vx * .6, vy: vy * .5 - 120, a: ang, va: (Math.random() - .5) * 8, r: 9, vida: 4 });
  pedacos.push({ k: 'piloto', x: (mx + hx) / 2, y: (my + hy) / 2, vx: vx * .8 + lado * 60, vy: vy * .4 - 300, a: ang, va: lado * (6 + Math.random() * 5), r: 8, vida: 4, cam: JOGO ? corDe(nome) : 0 });
  pedacos.push({ k: 'balde', x: hx, y: hy - 4, vx: vx * .9 - lado * 40, vy: vy * .3 - 480, a: 0, va: (Math.random() < .5 ? -1 : 1) * (12 + Math.random() * 8), r: 6, vida: 4 });
}
function podaFants(){ const ks = Object.keys(fants); while(ks.length > 40){ delete fants[ks.shift()]; } guardaJSON('fant', fants); }
function reinicia(){ if(tela === 'jogo' && JOGO){ som('clique'); comecaDescida(); } }
function saiDoJogo(){
  if(!JOGO) return mostraInicio();
  const J = JOGO;
  if(J.origem === 'teste') return abreEditor();
  if(J.origem === 'desafio') return abreDesafio(J.fase);
  mostraInicio();
}

/* ---------- o resultado ---------- */
function mostraFim(){
  const J = JOGO, run = J.ultimo, cs = run.cs;
  $('fOlho').textContent = J.titulo;
  $('fTempo').innerHTML = fmt2(cs) + '<small>s</small>';
  $('fT').textContent = 'Chegou em ' + fmt2(cs) + ' segundos';
  $('fBonus').hidden = !run.camb; $('fBonus').textContent = run.camb ? `${run.camb} ${run.camb > 1 ? 'cambalhotas' : 'cambalhota'}: −${fmt2(run.camb * 50)} s no tempo` : '';
  const cmp = $('fCompara'); cmp.className = 'compara';
  if(J.origem === 'desafio' && J.fase.corrente && J.fase.corrente.length){
    const u = J.fase.corrente[J.fase.corrente.length - 1], dif = u.cs - cs, eu = u.nome === nome;
    if(eu){ cmp.innerHTML = dif > 0 ? `Bateu o teu próprio tempo por <em>${fmtDif(dif)}</em>.` : `Teu tempo no link é <em>${fmt2(u.cs)} s</em>.`; }
    else if(dif > 0) cmp.innerHTML = `Ganhou de <em>${esc(u.nome)}</em> por <em>${fmtDif(dif)}</em>.`;
    else if(dif === 0) cmp.innerHTML = `Empatou com <em>${esc(u.nome)}</em>. No centésimo!`;
    else { cmp.classList.add('perdeu'); cmp.innerHTML = `Faltou <em>${fmtDif(-dif)}</em> pra pegar ${esc(u.nome)}.`; }
  } else if(J.origem === 'pronta' || J.origem === 'dia'){
    const c = J.origem === 'pronta' ? tempoCasa(J.extra.i) : (J.fase.par ? { cs: J.fase.par } : null);
    if(c){ const dif = c.cs - cs; if(dif > 0) cmp.innerHTML = `Ganhou da casa por <em>${fmtDif(dif)}</em>.`; else if(dif === 0) cmp.innerHTML = `Empatou com a casa: <em>${fmt2(c.cs)} s</em>. Pula, gira, tira uns centésimos.`; else { cmp.classList.add('perdeu'); cmp.innerHTML = `A casa desceu em <em>${fmt2(c.cs)} s</em>. Faltou ${fmtDif(-dif)}.`; } }
    else cmp.textContent = '';
  } else cmp.innerHTML = 'Chegou! Agora é tua vez de <em>duvidar</em> alguém.';
  $('fRec').textContent = J.recorde ? (J.antes === undefined ? 'Primeiro tempo teu nessa ladeira.' : `Recorde teu! O de antes era ${fmt2(J.antes)} s.`) : `Teu recorde aqui: ${fmt2(recs[J.id])} s.`;
  const fm = $('fManda'); fm.hidden = false;
  fm.textContent = J.origem === 'teste' ? 'Mandar o desafio' : J.origem === 'desafio' ? 'Devolver' : 'Duvidar alguém';
  $('fEditor').hidden = J.origem !== 'teste';
  $('fMenu').textContent = J.origem === 'desafio' ? 'Voltar pro desafio' : J.origem === 'teste' ? 'Começo' : 'Outra ladeira';
  soCartao('fim');
}
const fmtDif = c => c >= 10 ? fmt1(c) + ' s' : fmt2(c) + ' s';

/* ---------- o link, a mensagem e o nome ---------- */
function linkBase(){
  let solto = false; try{ solto = window.self === window.top; }catch(e){ solto = false; }
  if(solto) return location.href.split('#')[0];
  return LINK_DO_ARTEFATO ? LINK_DO_ARTEFATO.split('#')[0] : '';
}
function faseParaMandar(base, corrente, ev){ return { autor: base.autor || '', tracos: base.tracos, carimbos: base.carimbos, corrente, fantasma: Array.isArray(ev) ? ev.slice() : null }; }
function mensagem(tipo, fase, cs, outro){
  const cod = codifica(fase), b = linkBase(), link = b ? b + '#' + cod : '';
  let tx;
  if(tipo === 'devolve'){
    tx = outro && outro.cs > cs ? `${outro.nome} fez ${fmt1(outro.cs)} s. Eu fiz ${fmt1(cs)} s. Duvido tu bater.` : `Desci essa ladeira de rolimã em ${fmt1(cs)} s. Duvido tu bater.`;
  } else tx = `Duvido tu descer essa ladeira de rolimã. Eu desci em ${fmt1(cs)} s.`;
  return { cod, link, texto: link ? tx + '\n' + link : tx + '\nAbre o Duvido, toca em "Tenho um desafio" e cola esse código:\n' + cod };
}
function precisaNome(depois){
  if(nome){ depois(); return; }
  pedeNome(depois, 'Antes de mandar');
}
let depoisDoNome = null, voltaDoNome = null;
function pedeNome(depois, olho){
  depoisDoNome = depois; voltaDoNome = { tela, cartao: CARTOES.find(c => !$(c).hidden) || null };
  $('nOlho').textContent = olho || 'Teu nome'; $('nCampo').value = nome; $('nErro').hidden = true;
  soCartao('nome', 'nCampo');
}
function confirmaNome(){
  const n = limpaNome($('nCampo').value);
  if(!n){ $('nErro').hidden = false; $('nErro').textContent = 'Escreve um nome (ou apelido) pra ir junto no desafio.'; som('erro'); return; }
  nome = n; guarda('nome', n); som('clique');
  const f = depoisDoNome; depoisDoNome = null;
  if(f) f(); else mostraInicio();
}
function voltaNome(){
  const v = voltaDoNome; depoisDoNome = null;
  if(v && v.cartao && v.cartao !== 'nome') soCartao(v.cartao); else if(tela === 'editor') soCartao(null); else mostraInicio();
}
let MANDA = null;
function abreManda(msg, volta){
  MANDA = { msg, volta };
  const b = $('mBolha'); b.textContent = '';
  const linhas = msg.texto.split('\n');
  linhas.forEach((l, i) => { const s = document.createElement('span'); if(/^https?:|^dv1/.test(l)) s.className = 'lk'; s.textContent = l; b.appendChild(s); if(i < linhas.length - 1) b.appendChild(document.createTextNode('\n')); });
  $('mTexto').hidden = true; $('mTexto').value = msg.texto; $('mOk').hidden = true;
  let solto = false; try{ solto = window.self === window.top; }catch(e){}
  $('mShare').hidden = !(solto && navigator.share);
  soCartao('manda');
}
function copia(){
  const tx = MANDA.msg.texto;
  const ok = () => { $('mOk').hidden = false; $('mOk').textContent = 'Copiado! Agora cola no zap e duvida.'; som('copia'); };
  const naMao = () => {
    const t = $('mTexto'); t.hidden = false; t.value = tx; t.focus(); t.select(); try{ t.setSelectionRange(0, tx.length); }catch(e){}
    let foi = false; try{ foi = document.execCommand('copy'); }catch(e){ foi = false; }
    if(foi) ok(); else { $('mOk').hidden = false; $('mOk').textContent = 'Seleciona o texto aí em cima e copia na mão.'; }
  };
  try{
    if(navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(tx).then(ok, naMao);
    else naMao();
  }catch(e){ naMao(); }
}
function mandaDoEditor(){
  if(!editorLiberado()) return;
  const f = faseParaMandar({ autor: nome, tracos: ED.tracos, carimbos: ED.carimbos }, [{ nome, cs: ED.melhor.cs }], ED.melhor.ev);
  abreManda(mensagem('desafio', f, ED.melhor.cs), tela === 'jogo' ? 'fim' : 'editor');
}
function melhorDaqui(J){
  const r = recs[J.id], ev = fants[J.id];
  if(r !== undefined && ev) return { cs: r, ev };
  return J.sessao;
}
function devolve(){
  const J = JOGO, m = melhorDaqui(J); if(!m) return;
  const co = (J.fase.corrente || []).filter(c => c.nome !== nome);
  const remet = (J.fase.corrente || []).slice(-1)[0] || null;
  co.push({ nome, cs: m.cs });
  let nova = co;
  if(co.length > CORRENTE_MAX){ const ai = co.findIndex(c => c.nome === J.fase.autor); nova = ai >= 0 && ai < co.length - CORRENTE_MAX ? [co[ai], ...co.slice(-(CORRENTE_MAX - 1))] : co.slice(-CORRENTE_MAX); }
  const f = faseParaMandar(J.fase, nova, m.ev);
  abreManda(mensagem('devolve', f, m.cs, remet && remet.nome !== nome ? remet : null), 'fim');
}
function duvidaPronta(){
  const J = JOGO, m = melhorDaqui(J); if(!m) return;
  const f = faseParaMandar({ autor: J.origem === 'dia' ? 'Ladeira do dia' : 'Duvido', tracos: J.fase.tracos, carimbos: J.fase.carimbos }, [{ nome, cs: m.cs }], m.ev);
  abreManda(mensagem('desafio', f, m.cs), 'fim');
}

/* ---------- o desafio que chegou ---------- */
function abreCodigo(txt){
  const m = String(txt || '').match(/dv1[A-Za-z0-9_-]+/g);
  if(m) for(const c of m){ const f = decodifica(c); if(f){ abreDesafio(f); return true; } }
  return false;
}
function abreDesafio(fase){
  DESAFIO = fase; tela = 'desafio'; JOGO = null; soltaTrava();
  const co = fase.corrente || [], ult = co[co.length - 1];
  $('dQuem').textContent = ult ? ult.nome : (fase.autor || 'Alguém');
  const ord = co.map((c, i) => ({ ...c, i })).sort((a, b) => a.cs - b.cs || a.i - b.i), L = $('dCorrente'); L.innerHTML = '';
  ord.forEach((c, k) => { const li = document.createElement('li'); if(k === 0) li.className = 'melhor'; if(c.nome === nome) li.classList.add('eu'); const s = document.createElement('span'); s.textContent = c.nome + (c.nome === fase.autor ? ' (fez a ladeira)' : ''); const t = document.createElement('b'); t.textContent = fmt2(c.cs) + ' s'; li.append(s, t); L.appendChild(li); });
  L.hidden = !co.length;
  const id = idFase(fase), r = recs[id];
  $('dEu').hidden = r === undefined; if(r !== undefined) $('dEu').textContent = 'Teu melhor aqui: ' + fmt2(r) + ' s.';
  miniatura($('dMini'), fase);
  soCartao('desafio'); mostraUI();
  iniciaDemo(fase, fase.fantasma || null);
}

/* ---------- o editor ---------- */
const ED = { tracos: [], carimbos: [], ferr: 'lapis', cor: 0, desfaz: [], camY: -40, validado: null, melhor: null, traco: null, gesto: null, dedos: new Map(), pan: null, tela: null, cursor: null, dica: 0, risca: 0, dicaT: 0 };
(function leRascunho(){
  const r = leJSON('rascunho', null);
  if(r && Array.isArray(r.tracos) && Array.isArray(r.carimbos)){
    ED.tracos = r.tracos.filter(t => t && Array.isArray(t.pts) && t.pts.length >= 4).map(t => ({ cor: (t.cor | 0) & 3, pts: t.pts.map(v => Math.round(+v || 0)) }));
    ED.carimbos = r.carimbos.filter(c => c && TIPOS.includes(c.tipo)).map(c => ({ tipo: c.tipo, x: Math.round(+c.x || 0), y: Math.round(+c.y || 0), ...(c.tipo === 'turbo' ? { dir: (c.dir | 0) & 15 } : {}) }));
    ED.validado = r.validado || null; ED.melhor = r.melhor && r.melhor.ev ? r.melhor : null;
  }
})();
let rascunhoT = 0;
function salvaRascunho(){ clearTimeout(rascunhoT); rascunhoT = setTimeout(() => guardaJSON('rascunho', { tracos: ED.tracos, carimbos: ED.carimbos, validado: ED.validado, melhor: ED.melhor }), 250); }
const faseDoEditor = () => ({ autor: nome || '', tracos: ED.tracos, carimbos: ED.carimbos, corrente: [], fantasma: null });
function tintaUsada(extra){ let s = 0; for(const t of ED.tracos){ for(let i = 2; i < t.pts.length; i += 2) s += Math.hypot(t.pts[i] - t.pts[i - 2], t.pts[i + 1] - t.pts[i - 1]); } return s + (extra || 0); }
let tintaCache = 0;
function editorLiberado(){ return !!(ED.melhor && ED.validado && ED.validado === ED.id); }
function mudouEditor(soCarimbo){
  ED.id = idFase(faseDoEditor());
  if(soCarimbo && CENA){ CENA.fase = faseDoEditor(); CENA.F = compila(CENA.fase); CENA.yMax = CENA.F.yMax; }
  else montaCena(faseDoEditor(), compila(faseDoEditor()));
  tintaCache = tintaUsada();
  atualizaTinta(); atualizaManda(); salvaRascunho(); dicaEditor();
}
function atualizaTinta(extra){
  const resta = Math.max(0, 1 - (tintaCache + (extra || 0)) / TINTA_MAX);
  $('tintaBar').style.width = (resta * 100).toFixed(1) + '%';
  $('tinta').classList.toggle('pouca', resta < .15);
  $('tinta').querySelector('small').textContent = 'Giz: ' + Math.round(resta * 100) + '%';
  $('tinta').setAttribute('aria-label', 'Sobra ' + Math.round(resta * 100) + '% do giz');
}
function atualizaManda(){ const ok = editorLiberado(); const b = $('eManda'); b.setAttribute('aria-disabled', String(!ok)); b.title = ok ? 'Mandar o desafio' : 'Desce até a chegada primeiro'; }
function abreEditor(fase){
  if(fase){ guardaDesfaz(); ED.tracos = JSON.parse(JSON.stringify(fase.tracos)); ED.carimbos = JSON.parse(JSON.stringify(fase.carimbos)); ED.validado = null; ED.melhor = null; ED.camY = -40; }
  tela = 'editor'; JOGO = null; DEMO = null; soltaTrava(); pedeTrava();
  soCartao(null); mostraUI(); escolheFerr(ED.ferr, true);
  mudouEditor(); camY = ED.camY;
  ED.dica = 0; mostraDicaEd(true);
}
function guardaDesfaz(){ ED.desfaz.push(JSON.stringify({ t: ED.tracos, c: ED.carimbos })); if(ED.desfaz.length > 80) ED.desfaz.shift(); }
function desfaz(){
  if(tela !== 'editor') return;
  const s = ED.desfaz.pop(); if(!s){ aviso('Nada pra desfazer.', 1.4); return; }
  const o = JSON.parse(s); ED.tracos = o.t; ED.carimbos = o.c; som('desfaz'); mudouEditor();
}
function limiteEditor(){ const ym = CENA ? CENA.yMax : 150; return Math.min(ALT_MAX + 60 - VH, Math.max(VH * .5, ym + VH * .55)); }
function rolaEditor(dy){ ED.camY = clamp(ED.camY + dy, -40, Math.max(-40, limiteEditor())); camY = ED.camY; }
function escolheFerr(f, quieto){
  ED.ferr = f; document.querySelectorAll('.ferr').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.f === f)));
  $('cores').hidden = tela !== 'editor' || f !== 'lapis';
  if(!quieto){ som('clique'); mostraDicaEd(true); }
}
function montaCores(){
  const C = $('cores'); C.innerHTML = '';
  CORES_GIZ.forEach((c, i) => { const b = document.createElement('button'); b.className = 'cor'; b.style.setProperty('--c', `rgb(${c})`); b.setAttribute('aria-label', 'Giz ' + NOMES_COR[i]); b.setAttribute('aria-pressed', String(i === ED.cor)); b.innerHTML = '<i></i>'; b.addEventListener('click', () => { ED.cor = i; C.querySelectorAll('.cor').forEach((x, j) => x.setAttribute('aria-pressed', String(j === i))); som('clique'); }); C.appendChild(b); });
}
// as dicas escritas a giz no alto do editor
function mostraDicaEd(forca){
  if(tela !== 'editor') return;
  const d = $('edDica'); let t = '';
  const temChegada = ED.carimbos.some(c => c.tipo === 'chegada');
  if(ED.ferr === 'borracha') t = 'Passa o dedo no giz ou no carimbo pra apagar.';
  else if(ED.ferr === 'turbo') t = 'Toca pra pôr o turbo e arrasta pra apontar.';
  else if(ED.ferr === 'mola') t = 'A mola joga o carrinho pro alto. Põe no chão.';
  else if(ED.ferr === 'cachorro') t = 'O caramelo vai e volta. Encostou, capotou.';
  else if(ED.ferr === 'chegada') t = 'Só tem uma bandeira. Toca onde a ladeira acaba.';
  else if(!ED.tracos.length) t = 'Desenha a ladeira com o dedo, saindo da tábua.';
  else if(ED.tracos.length === 1 && !temChegada) t = 'Tirou o dedo, ficou buraco: vira pulo.';
  else if(!temChegada) t = 'Põe a CHEGADA lá embaixo.';
  else if(!editorLiberado()) t = 'Agora desce tu primeiro: Testar.';
  else t = 'Liberou! Manda o desafio.';
  if(t !== d.textContent || forca){ d.textContent = t; d.hidden = false; ED.dicaT = 4.5; }
}
function dicaEditor(){ mostraDicaEd(false); }
function mundoDe(e){ const r = cv.getBoundingClientRect(); const sx = e.clientX - r.left, sy = e.clientY - r.top; return { x: (sx - COLX) / K, y: sy / K + camY, sx, sy }; }
function carimboEm(w, raio){ let m = null, md = raio * raio; ED.carimbos.forEach((c, i) => { const cy = c.tipo === 'chegada' ? c.y - 40 : c.tipo === 'cachorro' ? c.y - 12 : c.y; const d = (c.x - w.x) ** 2 + (cy - w.y) ** 2; const d2 = c.tipo === 'chegada' ? Math.min(d, (c.x - w.x) ** 2 + (c.y - w.y) ** 2) : d; if(d2 < md){ md = d2; m = i; } }); return m; }
function chaoPra(x, y){ const ch = chaoEmbaixo(CENA.F, x, y - 30, 110); return ch; }
function encaixa(c, w){
  c.x = Math.round(clamp(w.x, 6, LARG - 6));
  if(c.tipo === 'turbo'){ c.y = Math.round(clamp(w.y, 0, ALT_MAX)); return; }
  const ch = chaoPra(c.x, w.y);
  const y = ch === null ? w.y : ch;
  c.y = Math.round(clamp(c.tipo === 'mola' ? y - 3 : y, 0, ALT_MAX));
}
function edDown(e){
  if(tela !== 'editor') return;
  audio(); e.preventDefault();
  try{ cv.setPointerCapture(e.pointerId); }catch(er){}
  ED.dedos.set(e.pointerId, { x: e.clientX, y: e.clientY });
  if(ED.dedos.size >= 2){
    // dois dedos: rola a ladeira (o traço que tinha acabado de começar vai embora)
    if(ED.traco){ if(ED.traco.len < 30 || performance.now() - ED.traco.t0 < 260) ED.traco = null; else fechaTraco(); }
    ED.gesto = null; ED.pan = { y: mediaDedos(), cam: ED.camY }; return;
  }
  if(e.button === 1 || e.button === 2){ ED.pan = { y: e.clientY, cam: ED.camY }; return; }
  $('apagaTudo').hidden = true;
  const w = mundoDe(e); ED.tela = { sx: w.sx, sy: w.sy }; ED.cursor = w;
  $('edDica').hidden = true;
  const f = ED.ferr;
  if(f === 'lapis'){
    if(TINTA_MAX - tintaCache < 6){ semGiz(); return; }
    const im = imaPonta(w.x, w.y);
    ED.traco = { cor: ED.cor, pts: im ? [im[0], im[1]] : [clamp(w.x, 0, LARG), clamp(w.y, 0, ALT_MAX)], len: 0, t0: performance.now() };
  } else if(f === 'borracha'){ ED.gesto = { k: 'apaga', mexeu: false }; apagaEm(w); }
  else {
    const i = carimboEm(w, 24);
    if(i !== null && (ED.carimbos[i].tipo === f || f !== 'turbo')){
      const c = ED.carimbos[i];
      ED.gesto = { k: c.tipo === 'turbo' && f === 'turbo' ? 'mira' : 'move', i, antes: JSON.stringify({ t: ED.tracos, c: ED.carimbos }), mexeu: false, w0: w };
    } else {
      const n = ED.carimbos.filter(c => c.tipo === f).length;
      const antes = JSON.stringify({ t: ED.tracos, c: ED.carimbos });
      if(f === 'chegada' && n >= 1){ const c = ED.carimbos.find(c => c.tipo === 'chegada'); encaixa(c, w); ED.gesto = { k: 'move', i: ED.carimbos.indexOf(c), antes, mexeu: true }; som('carimbo'); mudouEditor(true); return; }
      if(n >= LIM[f]){ aviso(`No máximo ${LIM[f]} desse por ladeira.`, 2); som('erro'); return; }
      const c = { tipo: f, x: 0, y: 0 }; if(f === 'turbo') c.dir = 0;
      encaixa(c, w); ED.carimbos.push(c);
      ED.gesto = { k: f === 'turbo' ? 'mira' : 'move', i: ED.carimbos.length - 1, antes, mexeu: true, novo: true, w0: w };
      som('carimbo'); mudouEditor(true);
    }
  }
}
// a ponta mais perto (de um traço ou da tábua) a menos de um dedinho: o traço novo começa colado nela
function imaPonta(x, y){
  const lim = Math.max(10, 14 / K); let m = null, md = lim * lim;
  const ve = (px, py) => { const d = (px - x) ** 2 + (py - y) ** 2; if(d < md){ md = d; m = [px, py]; } };
  ve(LARGADA[4], LARGADA[5]);
  for(const t of ED.tracos){ ve(t.pts[0], t.pts[1]); ve(t.pts[t.pts.length - 2], t.pts[t.pts.length - 1]); }
  return m;
}
function mediaDedos(){ let s = 0; for(const d of ED.dedos.values()) s += d.y; return s / ED.dedos.size; }
function edMove(e){
  if(tela !== 'editor') return;
  if(ED.dedos.has(e.pointerId)) ED.dedos.set(e.pointerId, { x: e.clientX, y: e.clientY });
  if(ED.pan){ const y = ED.dedos.size >= 2 ? mediaDedos() : e.clientY; ED.camY = ED.pan.cam - (y - ED.pan.y) / K; rolaEditor(0); return; }
  const w = mundoDe(e); ED.cursor = w;
  if(!ED.dedos.has(e.pointerId)) return;
  ED.tela = { sx: w.sx, sy: w.sy };
  if(ED.traco) somaPonto(w);
  else if(ED.gesto){
    const g = ED.gesto, c = ED.carimbos[g.i];
    if(g.k === 'apaga') apagaEm(w);
    else if(g.k === 'move' && c){ encaixa(c, w); g.mexeu = true; mudouEditor(true); }
    else if(g.k === 'mira' && c){ const dx = w.x - c.x, dy = w.y - c.y; if(dx * dx + dy * dy > 14 * 14){ const d = dirDe(Math.atan2(dy, dx) / GRAU); if(d !== c.dir){ c.dir = d; g.mexeu = true; mudouEditor(true); } } }
  }
}
function edUp(e){
  if(tela !== 'editor') return;
  ED.dedos.delete(e.pointerId);
  if(ED.pan){ if(ED.dedos.size === 0) ED.pan = null; return; }
  if(ED.traco) fechaTraco();
  if(ED.gesto){
    const g = ED.gesto; ED.gesto = null;
    if(g.k === 'mira' && !g.mexeu && !g.novo){ const c = ED.carimbos[g.i]; if(c){ c.dir = (c.dir + 2) & 15; g.mexeu = true; som('clique'); } }
    if(g.mexeu){ if(g.antes){ ED.desfaz.push(g.antes); if(ED.desfaz.length > 80) ED.desfaz.shift(); } mudouEditor(true); }
  }
  ED.tela = null;
}
function somaPonto(w){
  const t = ED.traco, n = t.pts.length, lx = t.pts[n - 2], ly = t.pts[n - 1];
  let x = clamp(w.x, 0, LARG), y = clamp(w.y, 0, ALT_MAX);
  const d = Math.hypot(x - lx, y - ly); if(d < 2.5) return;
  const resta = TINTA_MAX - tintaCache - t.len;
  if(d > resta){ if(resta < 2){ fechaTraco(); semGiz(); return; } x = lx + (x - lx) * resta / d; y = ly + (y - ly) * resta / d; t.pts.push(x, y); t.len += resta; fechaTraco(); semGiz(); return; }
  t.pts.push(x, y); t.len += d; ED.risca = Math.min(1, ED.risca + d / 30);
  atualizaTinta(t.len);
}
function semGiz(){ aviso('Acabou o giz. Apaga alguma coisa pra desenhar mais.', 2.6); som('erro'); const b = $('tinta'); b.classList.remove('treme'); void b.offsetWidth; b.classList.add('treme'); }
// fecha o traço: tira os pontos que não fazem falta (Douglas-Peucker) e arredonda pro inteiro
function simplifica(pts, eps){
  const n = pts.length / 2; if(n < 3) return pts.slice();
  const manter = new Uint8Array(n); manter[0] = manter[n - 1] = 1;
  const pilha = [[0, n - 1]];
  while(pilha.length){
    const [a, b] = pilha.pop(); const ax = pts[a * 2], ay = pts[a * 2 + 1], bx = pts[b * 2], by = pts[b * 2 + 1], dx = bx - ax, dy = by - ay, l = Math.hypot(dx, dy) || 1;
    let md = -1, mi = -1;
    for(let i = a + 1; i < b; i++){ const d = Math.abs((pts[i * 2] - ax) * dy - (pts[i * 2 + 1] - ay) * dx) / l; if(d > md){ md = d; mi = i; } }
    if(md > eps){ manter[mi] = 1; pilha.push([a, mi], [mi, b]); }
  }
  const o = []; for(let i = 0; i < n; i++) if(manter[i]) o.push(pts[i * 2], pts[i * 2 + 1]); return o;
}
function fechaTraco(){
  const t = ED.traco; ED.traco = null; if(!t) return;
  let p = simplifica(t.pts, 1.3).map(v => Math.round(v)), q = [];
  for(let i = 0; i < p.length; i += 2){ if(q.length && q[q.length - 2] === p[i] && q[q.length - 1] === p[i + 1]) continue; q.push(clamp(p[i], 0, LARG), clamp(p[i + 1], 0, ALT_MAX)); }
  if(q.length < 4){
    // um toque só (sem arrastar) vira um pontinho de giz de 6 de largura: dá pra fazer degrau
    if(t.pts.length >= 2 && t.len < 3){ const x = Math.round(t.pts[0]), y = Math.round(t.pts[1]); q = [clamp(x - 3, 0, LARG), y, clamp(x + 3, 0, LARG), y]; } else { atualizaTinta(); return; }
  }
  guardaDesfaz(); ED.tracos.push({ cor: t.cor, pts: q }); mudouEditor();
}
function apagaEm(w){
  const r = Math.max(9, 16 / K), r2 = r * r; let mexeu = false;
  const antes = JSON.stringify({ t: ED.tracos, c: ED.carimbos });
  for(let k = ED.tracos.length - 1; k >= 0; k--){
    const p = ED.tracos[k].pts; let toca = false;
    for(let i = 2; i < p.length && !toca; i += 2){ const ax = p[i - 2], ay = p[i - 1], dx = p[i] - ax, dy = p[i + 1] - ay, l2 = dx * dx + dy * dy || 1; let u = ((w.x - ax) * dx + (w.y - ay) * dy) / l2; u = clamp(u, 0, 1); const ex = w.x - ax - dx * u, ey = w.y - ay - dy * u; if(ex * ex + ey * ey < r2) toca = true; }
    if(toca){ ED.tracos.splice(k, 1); mexeu = true; }
  }
  const i = carimboEm(w, Math.max(16, r)); if(i !== null){ ED.carimbos.splice(i, 1); mexeu = true; }
  if(mexeu){ if(!ED.gesto || !ED.gesto.mexeu){ ED.desfaz.push(antes); if(ED.desfaz.length > 80) ED.desfaz.shift(); } if(ED.gesto){ ED.gesto.mexeu = true; ED.gesto.antes = null; } som('apaga'); poeira(w.x, w.y, 6, 50); mudouEditor(); }
}
function testaEditor(){
  if(tela !== 'editor') return;
  if(!ED.tracos.length){ aviso('Desenha a ladeira antes de testar.', 2); som('erro'); return; }
  ED.camY = camY; jogaFase(faseDoEditor(), 'teste', {});
}
function passoEditor(dt){
  // desenhando perto do pé da tela, a câmera desce sozinha
  if(ED.traco && ED.tela){
    const zona = SH - $('edFerr').offsetHeight - SH * .12;
    if(ED.tela.sy > zona){ const v = clamp((ED.tela.sy - zona) / (SH * .12), 0, 1.4) * 640; const ant = ED.camY; rolaEditor(v * dt); if(ED.camY !== ant) somaPonto({ x: (ED.tela.sx - COLX) / K, y: ED.tela.sy / K + camY }); }
  }
  ED.risca = Math.max(0, (ED.risca || 0) - dt * 4);
  if(ED.dicaT > 0){ ED.dicaT -= dt; if(ED.dicaT <= 0) $('edDica').hidden = true; }
  camY = ED.camY;
}

/* ---------- desenhar o quadro ---------- */
function desenhaCena(dt){
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.fillStyle = '#0B0A0E'; ctx.fillRect(0, 0, cv.width, cv.height);
  const sx = tremor > 0 && !reduz ? (Math.random() - .5) * 14 * tremor : 0, sy = tremor > 0 && !reduz ? (Math.random() - .5) * 10 * tremor : 0;
  desenhaFora(camY);
  if(!CENA) return;
  const t0 = Math.floor(camY / TH), t1 = Math.floor((camY + VH) / TH);
  for(let t = t0; t <= t1; t++) ctx.drawImage(ladrilho(t), Math.round((COLX + sx) * DPR), Math.round(((t * TH - camY) * K + sy) * DPR));
  ctx.setTransform(K * DPR, 0, 0, K * DPR, (COLX + sx) * DPR, (sy - camY * K) * DPR);
  ctx.save(); ctx.beginPath(); ctx.rect(0, camY - 60, LARG, VH + 120); ctx.clip();
  const F = CENA.F, S = JOGO ? JOGO.S : DEMO ? DEMO.S : null, n = S ? S.passos : Math.floor(TEMPO * 120);
  F.molas.forEach((m, i) => desenhaMola(ctx, m, JOGO && JOGO.molaT[i] > 0 ? Math.sin(JOGO.molaT[i] / .32 * Math.PI) : 0));
  F.turbos.forEach(tb => desenhaTurbo(ctx, tb, TEMPO));
  F.caes.forEach((c, i) => { const q = posCao(c, n); desenhaCao(ctx, q[0], q[1], q[2], TEMPO, JOGO && TEMPO - (JOGO.latiu[i] || -9) < .6, i * 1.7); });
  if(F.chegada) desenhaBandeira(ctx, F.chegada, TEMPO);
  desenhaPoeira(ctx);
  if(tela === 'editor'){ extrasEditor(); if(!PARADO) PARADO = novoEstado(F); desenhaCarro(ctx, PARADO.p, 1, 0, 0, corDe(nome), .9); }
  if(JOGO){
    const J = JOGO;
    if(J.G && J.gAlfa > 0.02){
      const pg = interp(J.G, J.G.fim ? 1 : alfa), gx = (pg[0] + pg[2]) / 2, gy = (pg[1] + pg[3]) / 2, sx2 = (J.S.p[0] + J.S.p[2]) / 2, sy2 = (J.S.p[1] + J.S.p[3]) / 2, longe = Math.hypot(gx - sx2, gy - sy2);
      desenhaCarro(ctx, pg, J.gVis.lado, J.gVis.giro, J.gVis.pose, corDe(J.gNome), J.gAlfa * clamp(longe / 26, .25, 1));
      if(longe > 34 || J.S.fim) etiqueta(pg, J.gNome, J.gAlfa);
    }
    if(!(J.S.fim && TITULO[J.S.fim.motivo] && ['capotou', 'torto', 'cachorro'].includes(J.S.fim.motivo))) desenhaCarro(ctx, interp(J.S, alfa), J.vis.lado, J.vis.giro, J.vis.pose, corDe(nome), 1);
  } else if(DEMO) desenhaCarro(ctx, interp(DEMO.S, DEMO.S.fim ? 1 : acc / PASSO), DEMO.vis.lado, DEMO.vis.giro, DEMO.vis.pose, DEMO.cam, 1);
  desenhaParticulas(ctx);
  ctx.restore();
}
let PARADO = null;
const IP = new Float64Array(4);
function interp(S, a){ for(let i = 0; i < 4; i++) IP[i] = S.pa[i] + (S.p[i] - S.pa[i]) * a; return IP; }
function etiqueta(p, txt, al){
  const mx = (p[0] + p[2]) / 2, my = Math.min(p[1], p[3]) - 46;
  ctx.globalAlpha = Math.min(1, al * 2); ctx.font = '700 11px ' + F_TXT; ctx.textAlign = 'center';
  const w = ctx.measureText(txt).width + 10; ctx.fillStyle = 'rgba(13,12,17,.8)'; ctx.fillRect(mx - w / 2, my - 11, w, 15);
  ctx.fillStyle = '#F3EEE2'; ctx.fillText(txt, mx, my); ctx.globalAlpha = 1; ctx.textAlign = 'left';
}
function extrasEditor(){
  const x = ctx;
  // de onde começa: a seta de giz saindo da ponta da tábua
  if(!ED.tracos.length){
    const a = .55 + .35 * Math.sin(TEMPO * 4); x.strokeStyle = `rgba(255,201,60,${a})`; x.lineWidth = 3; x.setLineDash([6, 6]); x.lineCap = 'round';
    x.beginPath(); x.moveTo(134, 158); x.quadraticCurveTo(190, 176, 220, 218); x.stroke(); x.setLineDash([]);
    x.beginPath(); x.moveTo(212, 214); x.lineTo(221, 220); x.lineTo(224, 209); x.stroke();
    x.fillStyle = `rgba(255,201,60,${a})`; x.font = '17px ' + F_GIZ; x.fillText('continua daqui', 196, 248);
  }
  // o fim do asfalto
  if(camY + VH > ALT_MAX - 20){ x.strokeStyle = 'rgba(232,64,42,.6)'; x.lineWidth = 2; x.setLineDash([10, 8]); x.beginPath(); x.moveTo(0, ALT_MAX); x.lineTo(LARG, ALT_MAX); x.stroke(); x.setLineDash([]); x.fillStyle = 'rgba(232,64,42,.8)'; x.font = '15px ' + F_GIZ; x.fillText('daqui pra baixo não dá', 120, ALT_MAX + 22); }
  if(ED.traco) gizTraco(x, ED.traco.pts, ED.traco.cor, 999);
  if(ED.cursor && ED.ferr === 'borracha' && !dedoTela){ const r = Math.max(9, 16 / K); x.strokeStyle = 'rgba(243,238,226,.6)'; x.lineWidth = 1.5; x.beginPath(); x.arc(ED.cursor.x, ED.cursor.y, r, 0, 7); x.stroke(); }
  if(ED.gesto && ED.gesto.k === 'mira'){ const c = ED.carimbos[ED.gesto.i]; if(c){ const d = DIRS[c.dir & 15]; x.strokeStyle = 'rgba(255,201,60,.8)'; x.lineWidth = 2; x.setLineDash([4, 4]); x.beginPath(); x.moveTo(c.x, c.y); x.lineTo(c.x + d[0] * 60, c.y + d[1] * 60); x.stroke(); x.setLineDash([]); } }
}

/* ---------- a tira da direita: a ladeira inteira, onde tu tá e o que tá aparecendo ---------- */
let tiraCache = null;
function alturaTira(){ if(!CENA) return VH; return tela === 'editor' ? Math.max(VH * 1.4, limiteEditor() + VH + 40) : Math.max(VH, CENA.yMax + 220); }
function desenhaTira(){
  const W = tiraCv.width, H = tiraCv.height, x = tctx;
  if(!CENA){ x.clearRect(0, 0, W, H); return; }
  const alt = alturaTira(), topo = -40, s = H / alt, sx = W / LARG;
  if(!tiraCache || tiraCache.alt !== alt || tiraCache.cena !== CENA){
    const c = document.createElement('canvas'); c.width = W; c.height = H; const y = c.getContext('2d');
    y.fillStyle = '#100F14'; y.fillRect(0, 0, W, H);
    y.fillStyle = 'rgba(255,201,60,.5)'; y.fillRect(0, 0, 1.5 * DPR, H); y.fillRect(W - 1.5 * DPR, 0, 1.5 * DPR, H);
    y.lineCap = 'round';
    for(const t of CENA.tracos){ const c2 = CORES_GIZ[t.cor] || CORES_GIZ[0]; y.strokeStyle = `rgba(${c2},.9)`; y.lineWidth = Math.max(1.2 * DPR, 1); y.beginPath(); for(let i = 0; i < t.pts.length; i += 2){ const px = t.pts[i] * sx, py = (t.pts[i + 1] - topo) * s; i ? y.lineTo(px, py) : y.moveTo(px, py); } y.stroke(); }
    if(CENA.F.chegada){ const c3 = CENA.F.chegada; y.fillStyle = '#F3EEE2'; y.fillRect(c3.x * sx - 3 * DPR, (c3.y - topo) * s - 6 * DPR, 6 * DPR, 6 * DPR); y.fillStyle = '#141218'; y.fillRect(c3.x * sx - 3 * DPR, (c3.y - topo) * s - 6 * DPR, 3 * DPR, 3 * DPR); y.fillRect(c3.x * sx, (c3.y - topo) * s - 3 * DPR, 3 * DPR, 3 * DPR); }
    tiraCache = { c, alt, cena: CENA };
  }
  x.drawImage(tiraCache.c, 0, 0);
  const y0 = (camY - topo) * s, y1 = (camY + VH - topo) * s;
  x.fillStyle = 'rgba(243,238,226,.1)'; x.fillRect(0, y0, W, y1 - y0);
  x.strokeStyle = 'rgba(243,238,226,.75)'; x.lineWidth = 1.5 * DPR; x.strokeRect(1, y0, W - 2, y1 - y0);
  const S = JOGO ? JOGO.S : DEMO ? DEMO.S : null;
  if(S){ const mx = (S.p[0] + S.p[2]) / 2, my = (S.p[1] + S.p[3]) / 2; x.fillStyle = '#FFC93C'; x.beginPath(); x.arc(clamp(mx * sx, 3 * DPR, W - 3 * DPR), clamp((my - topo) * s, 3 * DPR, H - 3 * DPR), 3.4 * DPR, 0, 7); x.fill(); }
}
function tiraPara(e){ if(tela !== 'editor') return; const r = tiraCv.getBoundingClientRect(); const f = clamp((e.clientY - r.top) / r.height, 0, 1); ED.camY = -40 + f * alturaTira() - VH / 2; rolaEditor(0); }

/* ---------- a trava da tela (pra não apagar no meio da descida) ---------- */
let trava = null;
async function pedeTrava(){ try{ if('wakeLock' in navigator && !trava){ trava = await navigator.wakeLock.request('screen'); trava.addEventListener('release', () => { trava = null; }); } }catch(e){ trava = null; } }
function soltaTrava(){ try{ if(trava) trava.release(); }catch(e){} trava = null; }

/* ---------- os comandos ---------- */
const dedosJogo = new Set();
const ehControle = el => !!(el && el.closest && el.closest('button, input, textarea, a, .cartao, .aviso, #tira'));
app.addEventListener('pointerdown', e => {
  if(tela === 'jogo'){ if(ehControle(e.target)) return; e.preventDefault(); const vazio = dedosJogo.size === 0; dedosJogo.add(e.pointerId); if(vazio) apertou(); }
}, { passive: false });
const largaDedo = e => { if(dedosJogo.delete(e.pointerId) && dedosJogo.size === 0) soltou(); };
addEventListener('pointerup', largaDedo); addEventListener('pointercancel', largaDedo);
addEventListener('blur', () => { if(dedosJogo.size){ dedosJogo.clear(); soltou(); } teclasJogo.clear(); });
cv.addEventListener('pointerdown', edDown);
cv.addEventListener('pointermove', edMove);
cv.addEventListener('pointerup', edUp); cv.addEventListener('pointercancel', edUp);
cv.addEventListener('pointerleave', () => { if(tela === 'editor' && !ED.dedos.size) ED.cursor = null; });
cv.addEventListener('contextmenu', e => e.preventDefault());
cv.addEventListener('wheel', e => { if(tela !== 'editor') return; e.preventDefault(); rolaEditor((e.deltaMode === 1 ? e.deltaY * 30 : e.deltaY) / K); }, { passive: false });
let tiraDedo = null;
tiraCv.addEventListener('pointerdown', e => { if(tela !== 'editor') return; e.preventDefault(); tiraDedo = e.pointerId; try{ tiraCv.setPointerCapture(e.pointerId); }catch(er){} tiraPara(e); });
tiraCv.addEventListener('pointermove', e => { if(e.pointerId === tiraDedo) tiraPara(e); });
tiraCv.addEventListener('pointerup', () => { tiraDedo = null; }); tiraCv.addEventListener('pointercancel', () => { tiraDedo = null; });
const teclasJogo = new Set();
const PULA = ['Space', 'ArrowUp', 'KeyW', 'KeyX', 'KeyK'];
addEventListener('keydown', e => {
  const alvoCampo = e.target && /INPUT|TEXTAREA/.test(e.target.tagName);
  if(tela === 'jogo'){
    if(!$('fim').hidden || !$('manda').hidden || !$('nome').hidden){ if(e.code === 'Escape'){ e.preventDefault(); saiDoJogo(); } return; }
    if(PULA.includes(e.code) && !alvoCampo){
      e.preventDefault(); if(e.repeat) return;
      const vazio = teclasJogo.size === 0 && dedosJogo.size === 0; teclasJogo.add(e.code); if(vazio) apertou(); return;
    }
    if((e.code === 'KeyR' || e.code === 'Enter') && $('fim').hidden && !alvoCampo){ e.preventDefault(); reinicia(); return; }
    if(e.code === 'Escape'){ e.preventDefault(); saiDoJogo(); return; }
  } else if(tela === 'editor' && !alvoCampo){
    if((e.ctrlKey || e.metaKey) && e.code === 'KeyZ'){ e.preventDefault(); desfaz(); return; }
    const n = '123456'.indexOf(e.key); if(n >= 0 && !e.ctrlKey && !e.metaKey){ escolheFerr(['lapis', 'borracha', 'mola', 'turbo', 'cachorro', 'chegada'][n]); return; }
    if(e.code === 'KeyT'){ testaEditor(); return; }
    if(e.code === 'ArrowDown' || e.code === 'PageDown'){ e.preventDefault(); rolaEditor(e.code === 'PageDown' ? VH * .8 : 60); return; }
    if(e.code === 'ArrowUp' || e.code === 'PageUp'){ e.preventDefault(); rolaEditor(e.code === 'PageUp' ? -VH * .8 : -60); return; }
    if(e.code === 'Escape'){ e.preventDefault(); mostraInicio(); }
  } else if(e.code === 'Escape' && !alvoCampo){
    if(!$('cola').hidden || !$('desafio').hidden) mostraInicio();
    else if(!$('nome').hidden) voltaNome();
    else if(!$('manda').hidden) $('mVolta').click();
  }
});
addEventListener('keyup', e => { if(teclasJogo.delete(e.code) && teclasJogo.size === 0 && dedosJogo.size === 0) soltou(); });

$('bReinicia').addEventListener('click', e => { e.stopPropagation(); reinicia(); });
$('bSai').addEventListener('click', e => { e.stopPropagation(); som('clique'); saiDoJogo(); });
document.querySelectorAll('.bt-som').forEach(b => b.addEventListener('click', e => { e.stopPropagation(); poeSom(!somOn); }));
$('pSai').addEventListener('click', e => { e.stopPropagation(); som('clique'); saiDoJogo(); });
$('pEditor').addEventListener('click', e => { e.stopPropagation(); som('clique'); abreEditor(); });
$('iFaz').addEventListener('click', () => { audio(); som('clique'); abreEditor(); });
$('iTenho').addEventListener('click', () => { audio(); som('clique'); $('cTexto').value = ''; $('cErro').hidden = true; soCartao('cola', 'cTexto'); });
$('iTroca').addEventListener('click', () => { som('clique'); pedeNome(null, 'Teu nome'); });
$('cVolta').addEventListener('click', () => { som('clique'); mostraInicio(); });
$('cAbre').addEventListener('click', () => {
  audio(); const t = $('cTexto').value;
  if(abreCodigo(t)){ som('clique'); return; }
  $('cErro').hidden = false; $('cErro').textContent = /dv1/.test(t) ? 'Esse código veio quebrado. Pede pro amigo mandar de novo.' : 'Não achei desafio nenhum aí. Cola a mensagem inteira que o amigo mandou.'; som('erro');
});
$('dDesce').addEventListener('click', () => { if(DESAFIO){ som('clique'); jogaFase(DESAFIO, 'desafio', {}); } });
$('dVolta').addEventListener('click', () => { som('clique'); mostraInicio(); });
$('nOk').addEventListener('click', confirmaNome);
$('nCampo').addEventListener('keydown', e => { if(e.key === 'Enter'){ e.preventDefault(); confirmaNome(); } });
$('nVolta').addEventListener('click', () => { som('clique'); voltaNome(); });
$('fDeNovo').addEventListener('click', () => reinicia());
$('fManda').addEventListener('click', () => {
  audio(); som('clique'); const J = JOGO; if(!J) return;
  if(J.origem === 'teste') precisaNome(mandaDoEditor); else if(J.origem === 'desafio') precisaNome(devolve); else precisaNome(duvidaPronta);
});
$('fEditor').addEventListener('click', () => { som('clique'); abreEditor(); });
$('fMenu').addEventListener('click', () => { som('clique'); const J = JOGO; if(J && J.origem === 'desafio') abreDesafio(J.fase); else mostraInicio(); });
$('mCopia').addEventListener('click', copia);
$('mShare').addEventListener('click', () => { try{ navigator.share({ text: MANDA.msg.texto }).catch(() => {}); }catch(e){} });
$('mVolta').addEventListener('click', () => { som('clique'); if(!MANDA) return mostraInicio(); if(MANDA.volta === 'editor'){ soCartao(null); mostraUI(); } else if(MANDA.volta === 'fim' && JOGO) soCartao('fim'); else mostraInicio(); });
$('eVolta').addEventListener('click', () => { som('clique'); mostraInicio(); });
$('eDesfaz').addEventListener('click', desfaz);
$('eTesta').addEventListener('click', () => { audio(); som('clique'); testaEditor(); });
$('eManda').addEventListener('click', () => {
  audio();
  if(!editorLiberado()){ som('erro'); aviso(ED.carimbos.some(c => c.tipo === 'chegada') ? 'Desce até a chegada primeiro: aí libera.' : 'Põe a CHEGADA e desce até ela: aí libera.', 2.6); return; }
  som('clique'); precisaNome(mandaDoEditor);
});
$('eLixo').addEventListener('click', () => { som('clique'); $('apagaTudo').hidden = !$('apagaTudo').hidden; });
$('eLixoNao').addEventListener('click', () => { $('apagaTudo').hidden = true; });
$('eLixoSim').addEventListener('click', () => { guardaDesfaz(); ED.tracos = []; ED.carimbos = []; $('apagaTudo').hidden = true; som('apaga'); mudouEditor(); aviso('Apagou. Se arrependeu? Desfaz.', 2.2); });
document.querySelectorAll('.ferr').forEach(b => b.addEventListener('click', () => escolheFerr(b.dataset.f)));
addEventListener('hashchange', () => { const h = location.hash.slice(1); if(h && h !== ultimoHash){ ultimoHash = h; abreCodigo(h); } });
let ultimoHash = '';
document.addEventListener('visibilitychange', () => { if(document.hidden){ if(ac) ac.suspend().catch(() => {}); } else { ultimo = performance.now(); if(ac && somOn) ac.resume().catch(() => {}); if(tela === 'jogo' || tela === 'editor') pedeTrava(); } });
new ResizeObserver(() => { medeTela(); if(tela === 'editor') rolaEditor(0); }).observe(app);

/* ---------- o laço ---------- */
let ultimo = performance.now();
function quadro(agora){
  requestAnimationFrame(quadro);
  let dt = (agora - ultimo) / 1000; ultimo = agora; if(dt > .1) dt = .1; if(dt < 0) dt = 0;
  TEMPO += dt;
  if(tela === 'jogo' && JOGO) passoJogo(dt);
  else if(tela === 'editor') passoEditor(dt);
  else if(DEMO) passoDemo(dt);
  passoParticulas(dt);
  tremor = Math.max(0, tremor - dt * 1.4);
  if(avisoT > 0){ avisoT -= dt; if(avisoT <= 0) $('aviso').hidden = true; }
  if(carimboT > 0){ carimboT -= dt; if(carimboT <= 0) $('carimbo').hidden = true; }
  desenhaCena(dt); desenhaTira();
  if(ac){
    const S = tela === 'jogo' && JOGO && !JOGO.S.fim ? JOGO.S : null;
    if(S){ const vx = (S.v[0] + S.v[2]) / 2, vy = (S.v[1] + S.v[3]) / 2; atualizaRonco(Math.sqrt(vx * vx + vy * vy), S.c0 || S.c1, 0); }
    else atualizaRonco(0, false, tela === 'editor' && ED.traco ? ED.risca || 0 : 0);
  }
}

/* ---------- começa ---------- */
medeTela(); montaCores(); poeSom(somOn, true);
if(document.fonts && document.fonts.ready) document.fonts.ready.then(() => { ladrilhos.clear(); tiraCache = null; });
{
  const h = location.hash.slice(1); ultimoHash = h;
  if(!(h && abreCodigo(h))){ mostraInicio(); if(h) aviso('Esse link veio quebrado. Pede pro amigo mandar de novo.', 3.5); }
}
requestAnimationFrame(quadro);

/* ---------- pros testes ---------- */
window.__duvido = {
  estado: () => ({ tela, nome, camY: Math.round(camY), cartao: CARTOES.find(c => !$(c).hidden) || null,
    jogo: JOGO ? { origem: JOGO.origem, titulo: JOGO.titulo, passos: JOGO.S.passos, tempo: tempoAtual(JOGO.S) / 100, fim: JOGO.S.fim, cambalhotas: JOGO.S.cambalhotas, segura: JOGO.S.segura, noChao: !!(JOGO.S.c0 || JOGO.S.c1), x: (JOGO.S.p[0] + JOGO.S.p[2]) / 2, y: (JOGO.S.p[1] + JOGO.S.p[3]) / 2, tentativas: JOGO.tentativas, ev: JOGO.ev.slice(), fantasma: JOGO.gNome || null, id: JOGO.id } : null,
    editor: { ferramenta: ED.ferr, cor: ED.cor, tracos: ED.tracos.length, pontos: ED.tracos.reduce((a, t) => a + t.pts.length / 2, 0), carimbos: ED.carimbos.map(c => c.tipo), tinta: Math.round(tintaUsada()), tintaMax: TINTA_MAX, liberado: editorLiberado(), desfaz: ED.desfaz.length },
    desafio: DESAFIO ? { autor: DESAFIO.autor, corrente: DESAFIO.corrente } : null }),
  codifica, decodifica, simula, rodaGravado, compila, idFase, piloto, desceRobo,
  prontas: PRONTAS.map(p => p.fase), nomesProntas: PRONTAS.map(p => p.nome), doDia, ladeiraDoDia, diaHoje,
  faseDoEditor: () => JSON.parse(JSON.stringify(faseDoEditor())),
  editorCom: fase => abreEditor(fase), editorPronta: i => abreEditor(PRONTAS[i].fase),
  joga: (fase, origem, extra) => jogaFase(fase, origem || 'desafio', extra || {}), jogaPronta: i => jogaFase(PRONTAS[i].fase, 'pronta', { i }),
  abreCodigo, toca: apertou, solta: soltou, agenda: lista => { if(JOGO) JOGO.agenda = lista.slice().sort((a, b) => a.n - b.n); }, reinicia, inicio: mostraInicio, editor: () => abreEditor(),
  mensagem: () => MANDA ? MANDA.msg : null, linkBase, tela: () => ({ SW, SH, K, COLX, COLW, VH, TIRAX, TIRAW }),
  mundoParaTela: (x, y) => ({ x: COLX + x * K, y: (y - camY) * K }), rola: dy => rolaEditor(dy), sons: () => SONS.slice(), audio: () => ac ? ac.state : 'sem', poeNome: n => { nome = limpaNome(n); guarda('nome', nome); }
};
