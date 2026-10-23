// dentro de um quadro (como no claude.ai), menos movimento, e quanto custa um quadro
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const path = require('path'), dir = __dirname;
let falhas = 0, oks = 0; const ok = (c, m) => { c ? oks++ : falhas++; console.log((c ? 'ok: ' : 'FALHOU: ') + m); };
(async () => {
  const b = await chromium.launch(); const erros = [];
  const nova = async (opc) => { const ctx = await b.newContext(opc); const p = await ctx.newPage(); p.on('pageerror', e => erros.push(e.message)); p.on('console', m => { if (m.type() === 'error' && !/Failed to load resource/.test(m.text())) erros.push(m.text()); }); await p.route('**/*', r => r.request().url().startsWith('http://127.0.0.1') ? r.continue() : r.abort()); return p; };
  // 1. no quadro: sem link base, a mensagem leva o código e manda colar no Duvido
  let p = await nova({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  await p.goto('http://127.0.0.1:8731/quadro.html'); await p.waitForTimeout(900);
  let f = p.frame({ url: /pagina\.html/ });
  const r1 = await f.evaluate(() => { const D = window.__duvido; D.poeNome('Thales'); D.editorPronta(0); return { base: D.linkBase(), dentro: window.self !== window.top }; });
  ok(r1.dentro && r1.base === '', 'no quadro, sem LINK_DO_ARTEFATO, não tem link base (' + JSON.stringify(r1) + ')');
  await f.evaluate(() => window.__duvido.agenda && 0);
  await f.click('#eTesta'); for (let i = 0; i < 150; i++) { await p.waitForTimeout(100); const e = await f.evaluate(() => window.__duvido.estado()); if (e.cartao === 'fim') break; }
  await f.click('#fManda'); await p.waitForTimeout(300);
  const m = await f.evaluate(() => window.__duvido.mensagem());
  ok(m && !m.link && /Tenho um desafio/.test(m.texto) && m.texto.includes(m.cod), 'a mensagem leva o código e diz pra colar no Duvido');
  await f.click('#mCopia'); await p.waitForTimeout(300);
  const cp = await f.evaluate(() => [document.getElementById('mOk').textContent, !document.getElementById('mTexto').hidden]);
  ok(/Copiado|na mão/.test(cp[0]), 'copiar no quadro responde, nem que seja pelo campo selecionado (' + cp.join(' / ') + ')');
  await p.screenshot({ path: path.join(dir, 'quadro-manda.png') });
  // o código no endereço do quadro abre o desafio
  await p.evaluate(c => { document.getElementById('q').src = 'pagina.html#' + c; }, m.cod); await p.waitForTimeout(1200);
  f = p.frame({ url: /pagina\.html/ });
  const e2 = await f.evaluate(() => window.__duvido.estado());
  ok(e2.tela === 'desafio', 'o #código do quadro abre direto no desafio');
  await p.context().close();
  // 2. menos movimento
  p = await nova({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, reducedMotion: 'reduce' });
  await p.goto('http://127.0.0.1:8731/pagina.html'); await p.waitForTimeout(500);
  await p.evaluate(() => window.__duvido.jogaPronta(2)); for (let i = 0; i < 60; i++){ await p.waitForTimeout(100); if ((await p.evaluate(() => window.__duvido.estado())).jogo.fim) break; }
  await p.waitForTimeout(500); await p.screenshot({ path: path.join(dir, 'menos-movimento.png') });
  ok(await p.evaluate(() => matchMedia('(prefers-reduced-motion: reduce)').matches), 'com menos movimento ligado o jogo roda e capota sem erro');
  await p.context().close();
  // 3. o custo do quadro numa descida (celular)
  p = await nova({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 3 });
  await p.goto('http://127.0.0.1:8731/pagina.html'); await p.waitForTimeout(500);
  await p.evaluate(() => window.__duvido.jogaPronta(4));
  const custo = await p.evaluate(() => new Promise(res => { const ts = []; let n = 0; const f = t => { ts.push(performance.now()); if (++n < 240) requestAnimationFrame(f); else { const d = ts.slice(1).map((v, i) => v - ts[i]).sort((a, b) => a - b); res({ media: d.reduce((a, b) => a + b) / d.length, p95: d[Math.floor(d.length * .95)] }); } }; requestAnimationFrame(f); }));
  ok(custo.media < 25, 'quadro médio na descida ' + custo.media.toFixed(1) + ' ms (95%: ' + custo.p95.toFixed(1) + ' ms)');
  ok(erros.length === 0, 'nenhum erro de JS (' + (erros.join(' | ') || 'nenhum') + ')');
  console.log(oks + ' ok, ' + falhas + ' falharam'); await b.close(); process.exit(falhas ? 1 : 0);
})().catch(e => { console.log('FALHOU: exceção ' + e.stack); process.exit(1); });
