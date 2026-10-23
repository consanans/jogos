// teste do Nó: celular (toque múltiplo de verdade pelo CDP), 320 e computador (o mouse como um dedo)
// uso: node teste.cjs [cel|p320|pc|tudo]
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const path = require('path'); const dir = __dirname;
const URL = 'http://127.0.0.1:8765/pagina.html';
const qual = process.argv[2] || 'tudo';
let falhas = 0, oks = 0;

async function abre(b, w, h, toque){
  const ctx = await b.newContext({ viewport: { width: w, height: h }, isMobile: toque, hasTouch: toque, deviceScaleFactor: toque ? 2 : 1 });
  const p = await ctx.newPage(); const erros = [];
  p.on('pageerror', e => erros.push('pageerror: ' + e.message));
  p.on('console', m => { if(m.type() === 'error' && !/ERR_|Failed to load/.test(m.text())) erros.push('console: ' + m.text()); });
  await p.route('**/*', r => r.request().url().startsWith('http://127.0.0.1') ? r.continue() : r.abort());
  await p.goto(URL); await p.waitForTimeout(700);
  return { ctx, p, erros };
}
function fabrica(nome){
  const ok = (c, m) => { if(c) oks++; else falhas++; console.log((c ? 'ok: ' : 'FALHOU: ') + nome + ': ' + m); return c; };
  return ok;
}

// o robô de dedos: cada ponto tem um id do CDP e a bolinha que ele segura
class Robo {
  constructor(p, cdp){ this.p = p; this.c = cdp; this.pts = new Map(); this.seq = 1; this.vel = new Map(); }
  lista(){ return [...this.pts.values()].map(q => ({ x: q.x, y: q.y, id: q.id, radiusX: 9, radiusY: 9, force: 1 })); }
  async poe(x, y, bola){ const id = this.seq++; this.pts.set(id, { id, x, y, bola }); await this.c.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: this.lista() }); return id; }
  async move(){ if(this.pts.size) await this.c.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: this.lista() }); }
  async tira(id){ const q = this.pts.get(id); if(!q) return; this.pts.delete(id); await this.c.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [{ x: q.x, y: q.y, id: q.id }] }); }
  async tiraTudo(){ this.pts.clear(); try{ await this.c.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); }catch(e){} }
  dedoDa(bola){ return [...this.pts.values()].find(q => q.bola === bola); }
}
const E = p => p.evaluate(() => window.__no.estado());
const tela = (e, b) => ({ x: e.origem.x + b.x * e.origem.e, y: e.origem.y + b.y * e.origem.e });

// segue as bolinhas: dedo junto de cada uma que é dele; põe dedo novo nas que esperam (dos jogadores da lista)
async function segue(p, rb, ms, op = {}){
  const fim = Date.now() + ms; let maxB = 0, e;
  while(Date.now() < fim){
    e = await E(p);
    if(e.fase !== 'jogo' && !op.qualquerFase) break;
    maxB = Math.max(maxB, e.bolinhas.length);
    const agora = Date.now();
    for(const b of e.bolinhas){
      const q = rb.dedoDa(b.id), s = tela(e, b);
      // o robô adianta o dedo pelo tanto que a bolinha andou desde a última olhada (a ida e volta leva uns 20 ms)
      const ant = rb.vel.get(b.id); let px = s.x, py = s.y;
      if(ant && agora > ant.t && b.movendo){ const k = 22 / (agora - ant.t); px += (s.x - ant.x) * k; py += (s.y - ant.y) * k; }
      rb.vel.set(b.id, { x: s.x, y: s.y, t: agora });
      if(q){ if(!q.fixo){ q.x = px; q.y = py; } }
      else if((b.estado === 'espera' || b.estado === 'solto') && op.pega !== false && (!op.quem || op.quem.includes(b.dono))) await rb.poe(s.x, s.y, b.id);
    }
    for(const q of [...rb.pts.values()]) if(!q.fixo && !e.bolinhas.some(b => b.id === q.bola)) await rb.tira(q.id);
    await rb.move();
    if(op.ate && op.ate(e)) break;
    await p.waitForTimeout(14);
  }
  return { e: await E(p), maxB };
}
async function verde(p){
  // nada de verde na mesa: conta os pontos onde o verde manda
  return p.evaluate(() => {
    const c = document.getElementById('c'), x = c.getContext('2d'), d = x.getImageData(0, 0, c.width, c.height).data; let n = 0, tot = 0;
    for(let i = 0; i < d.length; i += 16){ tot++; const r = d[i], g = d[i + 1], b = d[i + 2]; if(g > 90 && g > r * 1.25 && g > b * 1.25) n++; }
    return n / tot;
  });
}

async function celular(b, nome, w, h){
  const ok = fabrica(nome);
  const { ctx, p, erros } = await abre(b, w, h, true);
  const cdp = await ctx.newCDPSession(p), rb = new Robo(p, cdp);
  let e = await E(p);
  ok(e.fase !== 'capa' && e.demo, 'a capa abre com a demonstração rodando atrás (' + e.fase + ')');
  ok(await p.evaluate(() => !document.getElementById('capa').hidden), 'a capa aparece');
  const larg = await p.evaluate(() => document.documentElement.scrollWidth);
  ok(larg <= w, 'sem rolagem de lado (' + larg + ' <= ' + w + ')');
  await p.evaluate(() => window.__no.limite(10));
  ok(await p.evaluate(() => !document.querySelector('#seg button[data-n="4"]').disabled), 'com 10 dedos, dá pra escolher 4 pessoas');
  await p.evaluate(() => window.__no.limite(5));
  await p.tap('#seg button[data-n="4"]'); await p.waitForTimeout(150);
  const av = await p.evaluate(() => !document.getElementById('aviso').hidden && document.getElementById('aviso').textContent);
  ok(/5 dedos/.test(av || ''), 'com 4 num celular de 5 dedos, avisa que fica apertado (' + av + ')');
  await p.evaluate(() => window.__no.limite(10));
  await p.tap('#seg button[data-n="2"]'); await p.waitForTimeout(150);
  ok(await p.evaluate(() => document.querySelectorAll('#turma li').length === 2), 'com 2, a turma tem 2 nomes');
  await p.fill('#turma li:nth-child(1) input', 'Mari'); await p.fill('#turma li:nth-child(2) input', 'Jão');
  await p.screenshot({ path: path.join(dir, nome + '-0-capa.png') });
  await p.tap('#bVai'); await p.waitForTimeout(400);
  e = await E(p);
  ok(e.fase === 'segura' && !e.demo && e.bolinhas.length === 2 && e.jogadores[0].nome === 'Mari', 'Dar o nó: duas bolinhas de partida, com os nomes (' + e.fase + ', ' + e.bolinhas.length + ')');
  ok(e.jogadores[0].lado === 'baixo' && e.jogadores[1].lado === 'cima', 'Rosa embaixo, Amarelo em cima');
  await p.screenshot({ path: path.join(dir, nome + '-1-segura.png') });
  // os dois dedos, um de cada vez
  const [b0, b1] = e.bolinhas;
  await rb.poe(tela(e, b0).x, tela(e, b0).y, b0.id); await p.waitForTimeout(500);
  e = await E(p); ok(e.fase === 'segura', 'um dedo só não começa');
  await rb.poe(tela(e, b1).x, tela(e, b1).y, b1.id); await p.waitForTimeout(1300);
  e = await E(p); ok(e.fase === 'conta', 'os dois segurando 1 s: conta 3, 2, 1 (' + e.fase + ')');
  await p.screenshot({ path: path.join(dir, nome + '-2-conta.png') });
  // levantar no meio da contagem volta pra segurar
  const d1 = rb.dedoDa(b1.id); await rb.tira(d1.id); await p.waitForTimeout(150);
  e = await E(p); ok(e.fase === 'segura' && e.jogadores.every(j => !j.fora), 'levantou na contagem: volta pra segurar, ninguém sai');
  await rb.poe(tela(e, b1).x, tela(e, b1).y, b1.id);
  await p.evaluate(() => { window.__no.automatico(false); window.__no.velocidade(2); });
  for(let i = 0; i < 40 && (await E(p)).fase !== 'jogo'; i++) await p.waitForTimeout(100);
  e = await E(p); ok(e.fase === 'jogo', 'NÓ! começou (' + e.fase + ')');
  // dedo novo pra Mari
  ok(await p.evaluate(() => window.__no.forcaEvento('novo', 0)), 'força DEDO NOVO pra Rosa');
  e = await E(p);
  const nova = e.bolinhas.find(b => b.estado === 'espera');
  ok(nova && nova.dono === 0 && nova.prazo > 2.5, 'a bolinha nova espera dedo, com uns 3 s (' + (nova && nova.prazo) + ')');
  ok(nova && nova.y < e.H / 2, 'a bolinha nova da Rosa (embaixo) nasce na metade de cima (' + (nova && Math.round(nova.y)) + ')');
  ok(e.jogadores[0].banner === 'DEDO NOVO!', 'o aviso DEDO NOVO! aparece pra ela');
  await p.screenshot({ path: path.join(dir, nome + '-3-dedo-novo.png') });
  await rb.poe(tela(e, nova).x, tela(e, nova).y, nova.id); await p.waitForTimeout(200);
  e = await E(p); ok(e.bolinhas.find(b => b.id === nova.id).estado === 'preso', 'o dedo novo pegou a bolinha');
  // anda: o robô arrasta junto
  ok(await p.evaluate(() => window.__no.forcaEvento('anda', 1)), 'força ANDA pro Amarelo');
  let r = await segue(p, rb, 4000, { ate: x => !x.bolinhas.some(b => b.movendo) });
  ok(r.e.fase === 'jogo' && r.e.jogadores.every(j => !j.fora), 'arrastando junto, ninguém sai do ANDA');
  ok(r.e.eventos.some(x => x.tipo === 'anda'), 'o ANDA ficou no histórico');
  // troca entre os dois
  // a troca pode não ter caminho livre nesse arranjo: aí a Rosa anda e tenta de novo
  let trocou = false;
  for(let k = 0; k < 4 && !trocou; k++){ trocou = await p.evaluate(() => window.__no.forcaEvento('troca', [0, 1])); if(!trocou){ await p.evaluate(() => window.__no.forcaEvento('anda', 0)); await segue(p, rb, 3000, { ate: x => !x.bolinhas.some(b => b.movendo) }); } }
  ok(trocou, 'força TROCA entre Rosa e Amarelo');
  await p.waitForTimeout(250); await p.screenshot({ path: path.join(dir, nome + '-4-troca-previa.png') });
  r = await segue(p, rb, 400);
  await p.screenshot({ path: path.join(dir, nome + '-5-troca.png') });
  r = await segue(p, rb, 5000, { ate: x => !x.bolinhas.some(b => b.movendo) });
  ok(r.e.fase === 'jogo' && r.e.jogadores.every(j => !j.fora), 'na TROCA os dois dedos rodam junto e ninguém sai');
  // solta: a bolinha some e o dedo levanta sem castigo
  const antes = r.e.bolinhas.filter(b => b.dono === 0).length;
  ok(await p.evaluate(() => window.__no.forcaEvento('solta', 0)), 'força SOLTA UM pra Rosa');
  r = await segue(p, rb, 900);
  ok(r.e.bolinhas.filter(b => b.dono === 0).length === antes - 1 && r.e.jogadores.every(j => !j.fora), 'a bolinha some, o dedo sai e ninguém é eliminado');
  // tirar e voltar em menos de meio segundo não elimina
  const bA = r.e.bolinhas.find(b => b.dono === 1), dA = bA && rb.dedoDa(bA.id);
  if(!bA || !dA){ console.log('ESTADO ESTRANHO', JSON.stringify(r.e), JSON.stringify([...rb.pts.values()])); throw new Error('sem bolinha ou dedo do Amarelo'); }
  await rb.tira(dA.id); await p.waitForTimeout(120);
  e = await E(p); ok(e.bolinhas.find(b => b.id === bA.id).estado === 'solto', 'levantou: a bolinha fica esperando a volta');
  await rb.poe(tela(e, bA).x, tela(e, bA).y, bA.id); await p.waitForTimeout(500);
  e = await E(p); ok(e.jogadores.every(j => !j.fora) && e.bolinhas.find(b => b.id === bA.id).estado === 'preso', 'voltou em menos de meio segundo: segue no jogo');
  // automático por uns segundos: o robô pega tudo
  await p.evaluate(() => window.__no.automatico(true));
  r = await segue(p, rb, 6000);
  ok(r.e.fase === 'jogo' && r.e.jogadores.every(j => !j.fora), 'uns segundos de eventos automáticos com o robô segurando tudo (' + r.e.eventos.slice(-6).map(x => x.tipo).join(',') + ')');
  await p.screenshot({ path: path.join(dir, nome + '-6-meio.png') });
  ok(await verde(p) < .001, 'nada de verde na mesa');
  // agora o Amarelo solta de vez
  await p.evaluate(() => window.__no.automatico(false));
  const doAm = r.e.bolinhas.filter(b => b.dono === 1).map(b => rb.dedoDa(b.id)).filter(Boolean);
  for(const q of doAm) await rb.tira(q.id);
  r = await segue(p, rb, 1500, { quem: [0], qualquerFase: true, ate: x => x.fase !== 'jogo' });
  e = await E(p);
  ok(e.jogadores[1].fora && e.jogadores[1].motivo === 'soltou', 'tirou e não voltou: Amarelo soltou (' + e.jogadores[1].motivo + ')');
  ok(e.fase === 'fim' && e.vencedor === 0, 'sobrou a Rosa: ganhou (' + e.fase + ', ' + e.vencedor + ')');
  await p.waitForTimeout(400); await p.screenshot({ path: path.join(dir, nome + '-7-ganhou.png') });
  for(let i = 0; i < 40 && !(await E(p)).fimNaTela; i++) await p.waitForTimeout(100);
  const fimTxt = await p.evaluate(() => document.getElementById('fimT').textContent + ' | ' + document.getElementById('fimDur').textContent + ' | ' + document.getElementById('fimDedos').textContent + ' | ' + document.getElementById('fimNos').textContent + ' | ' + document.getElementById('fimOrdem').textContent);
  ok(/MARI GANHOU/.test(fimTxt), 'o fim diz quem ganhou, quanto durou, dedos e nós (' + fimTxt + ')');
  await rb.tiraTudo();
  await p.screenshot({ path: path.join(dir, nome + '-8-fim.png') });
  const cab = await p.evaluate(() => { const r = document.getElementById('fim').getBoundingClientRect(); return [r.left >= 0, r.right <= innerWidth, r.top >= 0, r.bottom <= innerHeight + 1]; });
  ok(cab.every(Boolean), 'o cartão do fim cabe na tela (' + cab + ')');
  // de novo, mesma turma, um toque
  await p.tap('#bDeNovo'); await p.waitForTimeout(300);
  e = await E(p); ok(e.fase === 'segura' && e.jogadores.length === 2 && e.jogadores[0].nome === 'Mari', 'De novo: mesma turma, direto pra segurar');

  // quatro pessoas num celular de 5 dedos: nunca passa de 5 bolinhas
  await p.evaluate(() => { window.__no.limite(5); window.__no.comeca(4); window.__no.velocidade(2); window.__no.automatico(true); });
  e = await E(p);
  ok(e.bolinhas.length === 4 && e.jogadores.map(j => j.lado).join() === 'baixo,cima,esq,dir', '4 pessoas: embaixo, em cima, esquerda e direita');
  for(const bb of e.bolinhas) await rb.poe(tela(e, bb).x, tela(e, bb).y, bb.id);
  for(let i = 0; i < 40 && (await E(p)).fase !== 'jogo'; i++) await p.waitForTimeout(100);
  r = await segue(p, rb, 12000);
  ok(r.maxB <= 5, 'com limite de 5 dedos, nunca passou de 5 bolinhas (máx ' + r.maxB + ')');
  ok(r.e.jogadores.every(j => !j.fora), 'o robô segurou os quatro (' + r.e.eventos.map(x => x.tipo).filter(t => t !== 'pegou').join(',') + ') ' + JSON.stringify(r.e.sairam));
  const tiposQ = new Set(r.e.eventos.map(x => x.tipo));
  ok(['novo', 'anda', 'troca', 'solta'].filter(t => tiposQ.has(t)).length >= 2, 'rolou mais de um tipo de evento: ' + [...tiposQ].join(','));
  ok(r.e.maxNos >= 1, 'com quatro, as cordas se cruzaram: ' + r.e.maxNos + ' nó(s) no máximo');
  await p.screenshot({ path: path.join(dir, nome + '-9-quatro.png') });
  // o sorteio: no começo puxa dedo novo; com a mesa cheia, puxa soltar (pra girar os dedos)
  const sorteio = await p.evaluate(() => {
    const conta = (cheia) => { const c = {}; for(let k = 0; k < 300; k++){ window.__no.limite(cheia ? 4 : 10); window.__no.comeca(4); fase = 'jogo'; tj = cheia ? 40 : 2; auto = false;
      if(cheia) for(const j of J.slice(0, 1)){ const q = achaLugar(j); if(q) novaBola(j, q.x, q.y, 'preso'); }
      B.forEach(b => { b.estado = 'preso'; b.toque = 'x' + b.id; T.set('x' + b.id, { id: 'x' + b.id, x: b.x, y: b.y, bola: b.id }); });
      const n0 = eventos.length; sorteiaEvento(); const ev = eventos.slice(n0).map(e => e.tipo)[0] || 'nada'; c[ev] = (c[ev] || 0) + 1; } return c; };
    const r = { comeco: conta(false), cheia: conta(true) }; window.__no.limite(5); T.clear(); return r; });
  ok(sorteio.comeco.novo > 150 && sorteio.comeco.anda > 20 && sorteio.comeco.troca > 20, 'no começo o sorteio puxa DEDO NOVO, com ANDA e TROCA no meio ' + JSON.stringify(sorteio.comeco));
  ok(!sorteio.cheia.novo && sorteio.cheia.solta > 60, 'com a mesa no limite de dedos, não tem DEDO NOVO e o SOLTA UM aparece ' + JSON.stringify(sorteio.cheia));
  await p.evaluate(() => { window.__no.comeca(4); window.__no.automatico(true); });
  rb.pts.clear(); await rb.tiraTudo();
  e = await E(p); for(const bb of e.bolinhas) await rb.poe(tela(e, bb).x, tela(e, bb).y, bb.id);
  for(let i = 0; i < 40 && (await E(p)).fase !== 'jogo'; i++) await p.waitForTimeout(100);
  // dedo novo que ninguém pega: sai
  await p.evaluate(() => window.__no.automatico(false));
  r = await segue(p, rb, 3000, { ate: x => !x.bolinhas.some(b => b.movendo) });
  let quem = -1;
  for(const i of [2, 3, 0, 1]){ if(await p.evaluate(i => window.__no.forcaEvento('novo', i), i)){ quem = i; break; } if(await p.evaluate(i => window.__no.forcaEvento('solta', i), i)) await segue(p, rb, 300); if(await p.evaluate(i => window.__no.forcaEvento('novo', i), i)){ quem = i; break; } }
  ok(quem >= 0, 'força um dedo novo pro jogador ' + quem);
  r = await segue(p, rb, 4000, { quem: [0, 1, 2, 3].filter(i => i !== quem), ate: x => x.jogadores[quem].fora });
  ok(r.e.jogadores[quem].fora && r.e.jogadores[quem].motivo === 'nao_pegou', 'não pôs o dedo a tempo: saiu (' + r.e.jogadores[quem].motivo + ')');
  // dedo que foge da bolinha: sai
  const vivo = r.e.jogadores.find(j => !j.fora && j.i !== quem), bv = r.e.bolinhas.find(b => b.dono === vivo.i), dv = rb.dedoDa(bv.id);
  dv.x += 130; dv.fixo = true; await rb.move();
  r = await segue(p, rb, 1500, { pega: false, ate: x => x.jogadores[vivo.i].fora });
  ok(r.e.jogadores[vivo.i].fora && r.e.jogadores[vivo.i].motivo === 'escapou', 'dedo fora da bolinha por mais de 0,3 s: saiu (' + r.e.jogadores[vivo.i].motivo + ')');
  await rb.tiraTudo();

  // solo: aguenta e solta
  await p.evaluate(() => { window.__no.comeca(1); window.__no.velocidade(2); window.__no.automatico(true); });
  e = await E(p); await rb.poe(tela(e, e.bolinhas[0]).x, tela(e, e.bolinhas[0]).y, e.bolinhas[0].id);
  for(let i = 0; i < 40 && (await E(p)).fase !== 'jogo'; i++) await p.waitForTimeout(100);
  r = await segue(p, rb, 7000);
  ok(r.e.fase === 'jogo' && r.e.tempo > 8, 'no Solo, o robô aguenta ' + r.e.tempo.toFixed(1) + ' s de jogo (' + r.e.eventos.map(x => x.tipo).filter(t => t !== 'pegou').join(',') + ')');
  await p.screenshot({ path: path.join(dir, nome + '-10-solo.png') });
  await rb.tiraTudo();
  for(let i = 0; i < 40 && !(await E(p)).fimNaTela; i++) await p.waitForTimeout(100);
  const st = await p.evaluate(() => [document.getElementById('fimT').textContent, document.getElementById('fimRec').textContent, localStorage.getItem('no-rec-solo')]);
  ok(/AGUENTOU/.test(st[0]) && /recorde/i.test(st[1]) && +st[2] > 0, 'o fim do Solo mostra o tempo e guarda o recorde (' + st.join(' | ') + ')');
  await p.screenshot({ path: path.join(dir, nome + '-11-solo-fim.png') });
  await p.tap('#bTurma'); await p.waitForTimeout(300);
  ok(await p.evaluate(() => !document.getElementById('capa').hidden && window.__no.estado().demo), 'Mudar a turma volta pra capa');
  ok(!erros.length, 'sem erro de JS (' + (erros.join(' | ') || 'nenhum') + ')');
  await ctx.close();
}

async function computador(b){
  const nome = 'pc', ok = fabrica(nome);
  const { ctx, p, erros } = await abre(b, 1366, 860, false);
  let e = await E(p);
  ok(await p.evaluate(() => document.getElementById('capa').classList.contains('pc') && !document.getElementById('bMouse').hidden && document.getElementById('bVai').hidden), 'no computador a capa explica e oferece testar no mouse');
  ok(/celular, deitado na mesa/.test(await p.textContent('#capaTxt')), 'a frase diz que se joga no celular, deitado na mesa');
  await p.waitForTimeout(7000);
  e = await E(p);
  ok(e.demo && e.fase === 'jogo' && e.eventos.some(x => x.tipo !== 'no' && x.tipo !== 'pegou'), 'a demonstração joga sozinha (' + e.eventos.map(x => x.tipo).join(',') + ')');
  await p.screenshot({ path: path.join(dir, 'pc-0-capa-demo.png') });
  await p.click('#bMouse'); await p.waitForTimeout(300);
  e = await E(p);
  ok(e.fase === 'segura' && e.solo && e.mouseSolo && e.W === 1366, 'Testar no mouse: o Solo na tela toda');
  const b0 = e.bolinhas[0]; let s = tela(e, b0);
  await p.mouse.move(s.x, s.y); await p.mouse.down();
  await p.evaluate(() => window.__no.velocidade(2));
  for(let i = 0; i < 40 && (await E(p)).fase !== 'jogo'; i++) await p.waitForTimeout(100);
  e = await E(p); ok(e.fase === 'jogo', 'segurou o botão: começou');
  // segue a bolinha com o mouse
  const fim = Date.now() + 9000; let tipos = new Set();
  while(Date.now() < fim){ e = await E(p); if(e.fase !== 'jogo') break; e.eventos.forEach(x => tipos.add(x.tipo)); s = tela(e, e.bolinhas[0]); await p.mouse.move(s.x, s.y); await p.waitForTimeout(12); }
  ok(e.fase === 'jogo' && e.bolinhas.length === 1, 'o mouse seguiu a bolinha: ' + e.tempo.toFixed(1) + ' s, uma bolinha só (' + [...tipos].join(',') + ')');
  ok(!tipos.has('novo') && !tipos.has('troca'), 'com um dedo só, não tem DEDO NOVO nem TROCA');
  await p.screenshot({ path: path.join(dir, 'pc-1-mouse.png') });
  await p.mouse.up();
  for(let i = 0; i < 40 && !(await E(p)).fimNaTela; i++) await p.waitForTimeout(100);
  e = await E(p);
  ok(e.fimNaTela && /AGUENTOU/.test(await p.textContent('#fimT')), 'soltou o botão: fim do Solo (' + await p.textContent('#fimT') + ')');
  ok(await p.evaluate(() => +localStorage.getItem('no-rec-mouse') > 0), 'o recorde do mouse fica guardado');
  await p.screenshot({ path: path.join(dir, 'pc-2-fim.png') });
  await p.click('#bTurma'); await p.waitForTimeout(300);
  ok(await p.evaluate(() => !document.getElementById('capa').hidden), 'Voltar leva pra capa');
  // teclado: os botões têm foco visível
  await p.keyboard.press('Tab'); await p.keyboard.press('Tab');
  const foco = await p.evaluate(() => { const a = document.activeElement; return a && a.tagName + '#' + a.id + ' ' + getComputedStyle(a).outlineStyle; });
  ok(/BUTTON/.test(foco) && !/none/.test(foco), 'Tab chega nos botões com contorno visível (' + foco + ')');
  ok(!erros.length, 'sem erro de JS (' + (erros.join(' | ') || 'nenhum') + ')');
  await ctx.close();
}

async function extras(b){
  const nome = 'extra', ok = fabrica(nome);
  // a voz: uma voz pt-BR de mentira que anota o que falaria
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  await ctx.addInitScript(() => {
    window.__falas = [];
    window.SpeechSynthesisUtterance = class { constructor(t){ this.text = t; } };
    const ss = window.speechSynthesis;
    ss.getVoices = () => [{ lang: 'pt-BR', name: 'Teste' }];
    ss.speak = u => { if(u.text.trim()) window.__falas.push(u.text); };
    ss.cancel = () => {};
  });
  const p = await ctx.newPage(); const erros = [];
  p.on('pageerror', e => erros.push(e.message)); p.on('console', m => { if(m.type() === 'error' && !/ERR_|Failed to load/.test(m.text())) erros.push(m.text()); });
  await p.route('**/*', r => r.request().url().startsWith('http://127.0.0.1') ? r.continue() : r.abort());
  await p.goto(URL + '#solo-83'); await p.waitForTimeout(500);
  const des = await p.evaluate(() => !document.getElementById('desafio').hidden && document.getElementById('desafio').textContent);
  ok(/1:23/.test(des || ''), 'o link com #solo-83 mostra o desafio (' + des + ')');
  ok(await p.evaluate(() => document.querySelector('#seg button[data-n="1"]').getAttribute('aria-pressed') === 'true'), 'e já deixa o Solo escolhido');
  ok(await p.evaluate(() => !document.getElementById('bVoz').hidden), 'com voz pt-BR, aparece o botão de Voz');
  await p.evaluate(() => window.__no.limite(10));
  const cdp = await ctx.newCDPSession(p), rb = new Robo(p, cdp);
  await p.evaluate(() => { window.__no.comeca(4, { nomes: ['Mari', '', 'Lu', ''] }); window.__no.automatico(false); window.__no.velocidade(2); });
  let e = await E(p); for(const bb of e.bolinhas) await rb.poe(tela(e, bb).x, tela(e, bb).y, bb.id);
  for(let i = 0; i < 40 && (await E(p)).fase !== 'jogo'; i++) await p.waitForTimeout(100);
  await p.evaluate(() => window.__no.forcaEvento('novo', 0));
  await segue(p, rb, 600);
  let trocou = false;
  for(let k = 0; k < 4 && !trocou; k++){ trocou = await p.evaluate(() => window.__no.forcaEvento('troca')); if(!trocou){ await p.evaluate(() => window.__no.forcaEvento('anda', 1)); await segue(p, rb, 2500, { ate: x => !x.bolinhas.some(b => b.movendo) }); } }
  await segue(p, rb, 2500, { ate: x => !x.bolinhas.some(b => b.movendo) });
  let falas = await p.evaluate(() => window.__falas.slice());
  ok(falas.includes('Nó!') && falas.includes('Mari, dedo novo!') && falas.some(f => /^(Mari|Amarelo|Lu|Laranja) e (Mari|Amarelo|Lu|Laranja), troca!$/.test(f)), 'a voz anuncia, com os nomes: ' + falas.join(' / '));
  // o som: cada efeito e a batida rodam sem erro
  const som = await p.evaluate(async () => { const r = []; audio(); for(const k of Object.keys(SFX)){ try{ SFX[k](J[0]); r.push(k); }catch(err){ r.push(k + ':' + err.message); } } mus.on = true; mus.prox = ac.currentTime; tj = 80; agendaMusica(); return { r, passos: mus.passo, pulsos: pulsos.length }; });
  ok(som.r.every(x => !x.includes(':')) && som.passos > 0, 'os ' + som.r.length + ' sons e a batida tocam sem erro (' + som.r.filter(x => x.includes(':')).join(', ') + ')');
  // a página some (trocou de app): ninguém sai; volta pedindo os dedos de novo
  await segue(p, rb, 1500);
  await p.evaluate(() => { Object.defineProperty(document, 'hidden', { value: true, configurable: true }); document.dispatchEvent(new Event('visibilitychange')); });
  await rb.tiraTudo(); await p.waitForTimeout(300);
  await p.evaluate(() => { Object.defineProperty(document, 'hidden', { value: false, configurable: true }); document.dispatchEvent(new Event('visibilitychange')); });
  await p.waitForTimeout(200);
  e = await E(p);
  ok(e.fase === 'segura' && e.jogadores.every(j => !j.fora) && e.bolinhas.every(b => b.estado === 'espera'), 'voltou pro app: pausa, ninguém sai, todo mundo põe o dedo de novo (' + e.fase + ' ' + JSON.stringify(e.sairam) + ')');
  const t0 = e.tempo, nb = e.bolinhas.length;
  for(const bb of e.bolinhas) await rb.poe(tela(e, bb).x, tela(e, bb).y, bb.id);
  for(let i = 0; i < 40 && (await E(p)).fase !== 'jogo'; i++) await p.waitForTimeout(100);
  e = await E(p); ok(e.fase === 'jogo' && e.tempo >= t0 && e.bolinhas.length === nb, 'com todos segurando, conta e continua de onde parou (' + t0.toFixed(1) + ' → ' + e.tempo.toFixed(1) + ' s)');
  await rb.tiraTudo();
  ok(!erros.length, 'sem erro de JS (' + (erros.join(' | ') || 'nenhum') + ')');
  await ctx.close();
  // girou a tela no meio: pausa, os dedos escorregam até as bolinhas e segue
  const c5 = await b.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  const p5 = await c5.newPage(); const er5 = [];
  p5.on('pageerror', e => er5.push(e.message));
  await p5.route('**/*', r => r.request().url().startsWith('http://127.0.0.1') ? r.continue() : r.abort());
  await p5.goto(URL); await p5.waitForTimeout(300);
  const rb5 = new Robo(p5, await c5.newCDPSession(p5));
  await p5.evaluate(() => { window.__no.limite(10); window.__no.comeca(3); window.__no.velocidade(2); window.__no.automatico(true); });
  e = await E(p5); for(const bb of e.bolinhas) await rb5.poe(tela(e, bb).x, tela(e, bb).y, bb.id);
  for(let i = 0; i < 40 && (await E(p5)).fase !== 'jogo'; i++) await p5.waitForTimeout(100);
  await segue(p5, rb5, 3000);
  // a barra do navegador: muda um tiquinho a altura e nada acontece
  await p5.setViewportSize({ width: 390, height: 800 }); await p5.waitForTimeout(250);
  e = await E(p5); ok(e.fase === 'jogo' && e.jogadores.every(j => !j.fora), 'a altura mudou um pouco: o jogo segue (' + e.fase + ')');
  await segue(p5, rb5, 800);
  await p5.setViewportSize({ width: 800, height: 390 }); await p5.waitForTimeout(250);
  e = await E(p5);
  ok(e.fase === 'segura' && e.jogadores.every(j => !j.fora), 'girou a tela: pausa e ninguém sai (' + e.fase + ' ' + JSON.stringify(e.sairam) + ')');
  // os dedos escorregam (sem levantar) até onde as bolinhas foram parar
  for(let k = 0; k < 30 && (await E(p5)).fase !== 'jogo'; k++){ e = await E(p5); for(const bb of e.bolinhas){ const q = rb5.dedoDa(bb.id); if(q){ const s = tela(e, bb); q.x = s.x; q.y = s.y; } } await rb5.move(); await p5.waitForTimeout(100); }
  e = await E(p5); ok(e.fase === 'jogo' && e.jogadores.every(j => !j.fora), 'os dedos escorregaram até as bolinhas e o nó continuou deitado (' + e.fase + ')');
  await p5.screenshot({ path: path.join(dir, 'extra-deitado.png') });
  await rb5.tiraTudo();
  ok(!er5.length, 'girando, sem erro de JS (' + (er5.join(' | ') || 'nenhum') + ')');
  await c5.close();
  // menos movimento: joga sem erro e sem tremer
  const c2 = await b.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, reducedMotion: 'reduce' });
  const p2 = await c2.newPage(); const er2 = [];
  p2.on('pageerror', e => er2.push(e.message));
  await p2.route('**/*', r => r.request().url().startsWith('http://127.0.0.1') ? r.continue() : r.abort());
  await p2.goto(URL); await p2.waitForTimeout(300);
  const rb2 = new Robo(p2, await c2.newCDPSession(p2));
  await p2.evaluate(() => { window.__no.limite(10); window.__no.comeca(2); window.__no.velocidade(2); });
  e = await E(p2); for(const bb of e.bolinhas) await rb2.poe(tela(e, bb).x, tela(e, bb).y, bb.id);
  for(let i = 0; i < 40 && (await E(p2)).fase !== 'jogo'; i++) await p2.waitForTimeout(100);
  await segue(p2, rb2, 3000);
  const lento = await p2.evaluate(() => ({ reduz, tremor }));
  await rb2.tiraTudo(); await p2.waitForTimeout(900);
  const lento2 = await p2.evaluate(() => ({ tremor, parts: parts.length }));
  ok(lento.reduz && lento2.tremor < .01 && !er2.length, 'com menos movimento: sem tremor quando alguém sai, sem erro (' + JSON.stringify([lento, lento2]) + ')');
  await c2.close();
  // dentro do quadro do claude.ai a página não sabe o próprio link: o botão de passar o link some (até o link ser preenchido)
  const c3 = await b.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  const p3 = await c3.newPage();
  await p3.route('**/*', r => r.request().url().startsWith('http://127.0.0.1') ? r.continue() : r.abort());
  await p3.goto('http://127.0.0.1:8765/quadro.html'); await p3.waitForTimeout(800);
  const fr = p3.frames().find(f => /pagina\.html/.test(f.url()));
  ok(fr && await fr.evaluate(() => document.getElementById('bLink').hidden), 'dentro do quadro, sem o link preenchido, o "Passar o link" não aparece');
  await c3.close();
  // solto na janela: passar o link copia ou mostra o campo pra copiar na mão
  const c4 = await b.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  const p4 = await c4.newPage();
  await p4.route('**/*', r => r.request().url().startsWith('http://127.0.0.1') ? r.continue() : r.abort());
  await p4.goto(URL); await p4.waitForTimeout(400);
  await p4.evaluate(() => { try{ delete Navigator.prototype.share; }catch(e){} });
  await p4.tap('#bLink'); await p4.waitForTimeout(400);
  const lk = await p4.evaluate(() => ({ txt: document.getElementById('bLink').textContent, campo: !document.getElementById('linkCampo').hidden && document.getElementById('linkTxt').value }));
  ok(lk.txt === 'Link copiado' || /pagina\.html$/.test(lk.campo || ''), 'Passar o link: copia ou mostra o link pra copiar (' + JSON.stringify(lk) + ')');
  await c4.close();
}

(async () => {
  const b = await chromium.launch();
  if(qual === 'cel' || qual === 'tudo') await celular(b, 'cel', 390, 844);
  if(qual === 'p320' || qual === 'tudo') await celular(b, 'p320', 320, 568);
  if(qual === 'pc' || qual === 'tudo') await computador(b);
  if(qual === 'extra' || qual === 'tudo') await extras(b);
  await b.close();
  console.log('\n' + oks + ' ok, ' + falhas + ' falhas');
})();
