// O teste da versão web exportada (build/web), num navegador de verdade (Chromium com WebGL por software):
// abre num celular (390x844, toque) e num computador (1366x860, mouse), confere que não dá erro no console,
// arrasta uma tábua da caixa pro cômodo, gira, monta uma gambiarra que funciona, aperta VAI!, vê a laranja
// andar e o cartão do fim aparecer. Tira fotos de cada tela em screenshots/.
//   node tests/web_teste.cjs [http://localhost:8060/?teste=1]
let pw; try { pw = require('playwright'); } catch (e) { pw = require('/opt/node22/lib/node_modules/playwright'); }
const { chromium } = pw;
const path = require('path');
const URL = process.argv[2] || 'http://localhost:8060/?teste=1';   // o ?teste liga a ponte com a página
const FOTOS = path.join(__dirname, '..', 'screenshots');

// a gambiarra da cozinha que funciona (a da versão web, acertada pra física da Godot): o gato liga o rádio
const COZINHA = [['colchao', 226, 701, 0.33, 1], ['gato', 580, 513, 0, -1]];
const LAJE = [['caramelo', 110, 108, 0, 1], ['tabua', 234, 330, 0.37, 1], ['garrafa', 278, 301, -0.07, 1], ['gangorra', 428, 471, 0, 1], ['bacia', 417, 320, 3.15, 1]];
const GARAGEM = [['tabua', 363, 320, -0.32, 1], ['limpador', 258, 383, 1.64, 1], ['balde', 162, 478, -0.07, 1], ['balde', 342, 492, 0.01, 1], ['lata', 589, 846, 0, 1]];

let falhas = 0;
const confere = (cond, txt) => { console.log((cond ? '  ok: ' : '  FALHOU: ') + txt); if (!cond) falhas++; };

async function estado(p) { return await p.evaluate(() => window.__gambi_estado || null); }
async function espera(p, fn, ms, passo = 100) {
  const ate = Date.now() + ms;
  while (Date.now() < ate) { const e = await estado(p); if (e && fn(e)) return e; await p.waitForTimeout(passo); }
  return await estado(p);
}
async function cmd(p, c) { await p.evaluate(c => { (window.__gambi_cmd = window.__gambi_cmd || []).push(c); }, c); await p.waitForTimeout(120); }
// os retângulos vêm em pixels do canvas; a página trabalha em pixels CSS
async function dpr(p) { return await p.evaluate(() => { const c = document.querySelector('#canvas'); return c.width / c.getBoundingClientRect().width; }); }
const centro = (r, k) => ({ x: (r[0] + r[2] / 2) / k, y: (r[1] + r[3] / 2) / k });
const doMundo = (e, x, y, k) => ({ x: (e.mundo[0] + x * e.mundo[2]) / k, y: (e.mundo[1] + y * e.mundo[2]) / k });

async function toque(p, cdp, x, y) {
  if (cdp) {
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
    await p.waitForTimeout(60);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  } else await p.mouse.click(x, y);
  await p.waitForTimeout(250);
}
async function arrasta(p, cdp, a, b, passos = 14) {
  if (cdp) {
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: a.x, y: a.y }] });
    for (let i = 1; i <= passos; i++) { await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: a.x + (b.x - a.x) * i / passos, y: a.y + (b.y - a.y) * i / passos }] }); await p.waitForTimeout(30); }
  } else {
    await p.mouse.move(a.x, a.y); await p.mouse.down();
    for (let i = 1; i <= passos; i++) { await p.mouse.move(a.x + (b.x - a.x) * i / passos, a.y + (b.y - a.y) * i / passos); await p.waitForTimeout(30); }
  }
}
async function solta(p, cdp) {
  if (cdp) await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  else await p.mouse.up();
  await p.waitForTimeout(250);
}

async function uma(b, nome, vp, toqueSim) {
  console.log('# ' + nome + ' ' + vp.width + 'x' + vp.height + (toqueSim ? ' (toque)' : ' (mouse)'));
  const ctx = await b.newContext({ viewport: vp, isMobile: toqueSim, hasTouch: toqueSim, deviceScaleFactor: 2 });
  const p = await ctx.newPage();
  const erros = [];
  p.on('pageerror', e => erros.push('pageerror: ' + e.message));
  p.on('console', m => { if (m.type() === 'error') erros.push(m.text()); });
  const cdp = toqueSim ? await ctx.newCDPSession(p) : null;
  await p.goto(URL);
  let e = await espera(p, e => e.modo === 'edita', 60000);
  confere(!!e, 'o jogo abriu (window.__gambi_estado apareceu)');
  if (!e) { await ctx.close(); return; }
  const t_ini = Date.now();
  const es = await espera(p, e => e.som_pronto, 20000);
  confere(es.som_pronto, 'os instrumentos foram sintetizados (' + ((Date.now() - t_ini) / 1000).toFixed(1) + ' s depois de abrir)');
  await cmd(p, { f: 'esquece' });
  await p.waitForTimeout(1500);
  e = await estado(p);
  const k = await dpr(p);
  confere(e.intro, 'o cartão da introdução tá na tela');
  await p.screenshot({ path: path.join(FOTOS, nome + '-1-intro.png') });
  await toque(p, cdp, centro(e.ret.bora, k).x, centro(e.ret.bora, k).y);
  e = await espera(p, e => !e.intro, 3000);
  confere(!e.intro, 'Bora fecha a introdução');
  // arrasta a tábua da caixa pro cômodo
  const t0 = e.estoque.tabua;
  const de = centro(e.itens.tabua, k), ate = doMundo(e, 290, 430, k);
  if (toqueSim) ate.y += 52; // no toque a peça aparece um pouco acima do dedo
  await arrasta(p, cdp, de, ate);
  await p.screenshot({ path: path.join(FOTOS, nome + '-2-arrasta.png') });
  await solta(p, cdp);
  e = await espera(p, e => e.pecas === 1, 3000);
  confere(e.pecas === 1 && e.estoque.tabua === t0 - 1, 'arrastou a tábua da caixa pro cômodo (na caixa: ' + t0 + ' → ' + e.estoque.tabua + ')');
  confere(e.sel === 'tabua' && e.ferr, 'a tábua ficou escolhida, com girar e devolver');
  // gira duas vezes pela ferramenta
  await toque(p, cdp, centro(e.ret.gira_dir, k).x, centro(e.ret.gira_dir, k).y);
  e = await estado(p);
  await toque(p, cdp, centro(e.ret.gira_dir, k).x, centro(e.ret.gira_dir, k).y);
  await p.screenshot({ path: path.join(FOTOS, nome + '-3-girou.png') });
  // devolve pra caixa e monta a gambiarra que funciona
  e = await estado(p);
  await toque(p, cdp, centro(e.ret.tira, k).x, centro(e.ret.tira, k).y);
  e = await espera(p, e => e.pecas === 0, 2000);
  confere(e.pecas === 0 && e.estoque.tabua === t0, 'devolveu a tábua pra caixa');
  for (const l of COZINHA) await cmd(p, { f: 'poe', a: l });
  e = await espera(p, e => e.pecas === COZINHA.length, 3000);
  confere(e.pecas === COZINHA.length, 'montou a gambiarra da cozinha (' + e.pecas + ' peças)');
  await p.screenshot({ path: path.join(FOTOS, nome + '-4-montado.png') });
  const ini = e.laranja;
  await toque(p, cdp, centro(e.ret.vai, k).x, centro(e.ret.vai, k).y);
  e = await espera(p, e => e.modo === 'roda', 3000);
  confere(e.modo === 'roda' || e.modo === 'festa', 'VAI! começou a rodar');
  await p.waitForTimeout(2200);
  e = await estado(p);
  confere(Math.hypot(e.laranja[0] - ini[0], e.laranja[1] - ini[1]) > 20, 'a laranja andou (' + ini + ' → ' + e.laranja + ')');
  await p.screenshot({ path: path.join(FOTOS, nome + '-5-rodando.png') });
  e = await espera(p, e => e.fim, 45000, 250);
  confere(e.fim, 'o cartão do fim apareceu');
  confere(e.ganhou && e.carimbo === 'FUNCIONOU!', 'FUNCIONOU! (quem ligou: ' + e.quem + ', ' + e.pts + ' pontos)');
  confere(e.loop, 'o beat da gambiarra tá tocando em volta (' + e.batidas + ' batidas gravadas; ' + e.fps + ' quadros/s no Chromium com WebGL por software)');
  await p.waitForTimeout(1200);
  await p.screenshot({ path: path.join(FOTOS, nome + '-6-fim.png') });
  // a laje e a garagem: montadas por comando, só pra ver a tela e o fim
  for (const [i, lay, rot] of [[1, LAJE, 'laje'], [2, GARAGEM, 'garagem']]) {
    await cmd(p, { f: 'fase', i });
    e = await espera(p, e => e.fase === i && e.modo === 'edita', 4000);
    await p.waitForTimeout(500);
    await p.screenshot({ path: path.join(FOTOS, nome + '-' + rot + '-1-intro.png') });
    e = await estado(p);
    await toque(p, cdp, centro(e.ret.bora, k).x, centro(e.ret.bora, k).y);
    for (const l of lay) await cmd(p, { f: 'poe', a: l });
    e = await espera(p, e => e.pecas === lay.length, 3000);
    await p.screenshot({ path: path.join(FOTOS, nome + '-' + rot + '-2-montada.png') });
    await toque(p, cdp, centro(e.ret.vai, k).x, centro(e.ret.vai, k).y);
    await p.waitForTimeout(3000);
    await p.screenshot({ path: path.join(FOTOS, nome + '-' + rot + '-3-rodando.png') });
    e = await espera(p, e => e.fim, 45000, 250);
    confere(e.fim && e.ganhou, rot + ': FUNCIONOU! (quem ligou: ' + e.quem + ')');
    await p.waitForTimeout(1200);
    await p.screenshot({ path: path.join(FOTOS, nome + '-' + rot + '-4-fim.png') });
    e = await estado(p);
    await toque(p, cdp, centro(e.ret.de_novo, k).x, centro(e.ret.de_novo, k).y);
  }
  // o menu das fases
  e = await estado(p);
  await toque(p, cdp, centro(e.ret.marca, k).x, centro(e.ret.marca, k).y);
  e = await espera(p, e => e.fases, 2000);
  confere(e.fases, 'tocar no nome abre o menu das fases');
  await p.screenshot({ path: path.join(FOTOS, nome + '-7-fases.png') });
  confere(erros.length === 0, 'nenhum erro no console' + (erros.length ? ': ' + erros.slice(0, 5).join(' | ') : ''));
  const larg = await p.evaluate(() => [document.documentElement.scrollWidth, innerWidth]);
  confere(larg[0] <= larg[1], 'nada passa da largura da tela');
  await ctx.close();
}

(async () => {
  require('fs').mkdirSync(FOTOS, { recursive: true });
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
  await uma(b, 'cel', { width: 390, height: 844 }, true);
  await uma(b, 'pc', { width: 1366, height: 860 }, false);
  await b.close();
  console.log('\nRESULTADO: ' + (falhas ? falhas + ' falhas' : 'tudo ok'));
  process.exit(falhas ? 1 : 0);
})();
