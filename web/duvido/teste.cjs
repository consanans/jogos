// o caminho principal do Duvido num celular de toque e num computador; frases "ok:" e "FALHOU:", fotos na pasta
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const path = require('path'), dir = __dirname;
const URL0 = 'http://127.0.0.1:8731/pagina.html';
const MODOS = {
  cel: { viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 },
  p320: { viewport: { width: 320, height: 568 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 },
  pc: { viewport: { width: 1366, height: 860 } }
};
const nome = process.argv[2] || 'cel', M = MODOS[nome], toque = !!M.hasTouch;
let falhas = 0, oks = 0;
const ok = (c, m) => { if (c) oks++; else falhas++; console.log((c ? 'ok: ' : 'FALHOU: ') + nome + ': ' + m); };
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ ...M, permissions: ['clipboard-read', 'clipboard-write'] });
  const erros = [];
  const abre = async (url) => {
    const p = await ctx.newPage();
    p.on('pageerror', e => erros.push('pageerror: ' + e.message));
    p.on('console', m => { if (m.type() === 'error' && !/Failed to load resource/.test(m.text())) erros.push('console: ' + m.text()); });
    await p.route('**/*', r => r.request().url().startsWith('http://127.0.0.1') ? r.continue() : r.abort());
    await p.goto(url); await p.waitForTimeout(700);
    return p;
  };
  let p = await abre(URL0);
  const C = (f, a) => p.evaluate(f, a), W = ms => p.waitForTimeout(ms), E = () => C(() => window.__duvido.estado());
  const foto = n => p.screenshot({ path: path.join(dir, `${nome}-${n}.png`) });
  let sessao = null, sessaoDe = null;
  const cdp = async () => { if (sessaoDe !== p) { sessao = await p.context().newCDPSession(p); sessaoDe = p; } return sessao; };
  const espera = async (cond, ms = 20000, passo = 100) => { const t0 = Date.now(); while (Date.now() - t0 < ms) { const e = await E(); if (cond(e)) return e; await W(passo); } return await E(); };
  const clica = async sel => { if (toque) await p.tap(sel); else await p.click(sel); };
  const semRolagem = async () => C(() => document.documentElement.scrollWidth <= innerWidth + 1 && document.body.scrollWidth <= innerWidth + 1);

  // 1. a entrada
  let e = await E();
  ok(e.tela === 'inicio' && e.cartao === 'inicio', 'abre na entrada');
  ok(await C(() => document.querySelectorAll('#iFases .fase').length === 6), 'seis ladeiras na lista (a do dia e as cinco)');
  ok(await semRolagem(), 'sem rolagem de lado na entrada');
  await foto('0-inicio');

  // 2. desce a primeira sem tocar: chega
  await clica('#iFases .fase:nth-child(2)');
  e = await E(); ok(e.tela === 'jogo' && e.jogo && e.jogo.titulo === 'Pra aquecer', 'toca na "Pra aquecer" e desce (' + (e.jogo && e.jogo.titulo) + ')');
  await W(2200); await foto('1-descendo');
  e = await espera(e => e.jogo && e.jogo.fim, 20000);
  ok(e.jogo.fim && e.jogo.fim.motivo === 'chegou', 'a "Pra aquecer" chega sozinha (' + JSON.stringify(e.jogo.fim) + ')');
  await W(1300);
  e = await E(); ok(e.cartao === 'fim', 'o cartão do resultado aparece');
  const cmp = await C(() => document.getElementById('fCompara').textContent + ' | ' + document.getElementById('fRec').textContent);
  ok(/casa/i.test(cmp), 'o resultado compara com a casa (' + cmp + ')');
  await foto('2-resultado');

  // 3. de novo: recomeça na hora
  const t0 = Date.now(); await clica('#fDeNovo');
  e = await espera(e => e.jogo && e.jogo.tentativas === 2 && e.jogo.passos > 0 && !e.jogo.fim, 3000, 20);
  ok(e.jogo.tentativas === 2 && Date.now() - t0 < 1000, 'De novo recomeça em menos de 1 s (' + (Date.now() - t0) + ' ms)');

  // 4. o toque pula: espera ele no chão e toca na pista
  e = await espera(e => e.jogo && e.jogo.noChao && e.jogo.passos > 40, 4000, 20);
  const nAntes = e.jogo.ev.length;
  if (toque) { const s = await cdp(); await s.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: 150, y: Math.round(M.viewport.height * .6), id: 1 }] }); await W(60); await s.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); }
  else { await p.keyboard.down('Space'); await W(60); await p.keyboard.up('Space'); }
  await W(120); e = await E();
  ok(e.jogo.ev.length >= nAntes + 2, (toque ? 'o toque' : 'o espaço') + ' vira pulo (toques gravados: ' + e.jogo.ev.length + ')');
  const sons = await C(() => window.__duvido.sons());
  ok(sons.includes('pulo') && sons.includes('vai'), 'o pulo e a largada fazem barulho (' + sons.slice(-6).join(',') + ')');
  ok(['running', 'suspended'].includes(await C(() => window.__duvido.audio())), 'o som nasceu no primeiro toque (' + await C(() => window.__duvido.audio()) + ')');

  // 5. o caramelo: sem pular, capota; um toque recomeça
  await clica('#bSai'); await W(300);
  e = await E(); ok(e.tela === 'inicio', 'o × volta pra entrada');
  await clica('#iFases .fase:nth-child(4)');
  e = await espera(e => e.jogo && e.jogo.fim, 20000);
  ok(e.jogo.fim && e.jogo.fim.motivo === 'cachorro', 'sem pular, o caramelo derruba (' + JSON.stringify(e.jogo.fim) + ')');
  await W(600); await foto('3-capotou');
  ok(await C(() => !document.getElementById('carimbo').hidden && /CAPOTOU/.test(document.getElementById('carT').textContent)), 'o carimbo CAPOTOU aparece');
  const sons2 = await C(() => window.__duvido.sons());
  ok(sons2.includes('latido') && sons2.includes('capotou'), 'o caramelo late e a capotada faz estrondo');
  const t1 = Date.now();
  if (toque) await p.touchscreen.tap(200, 500); else await p.mouse.click(400, 500);
  e = await espera(e => e.jogo && e.jogo.tentativas === 2 && !e.jogo.fim, 2000, 20);
  ok(e.jogo.tentativas === 2 && Date.now() - t1 < 1000, 'um toque depois de capotar recomeça (' + (Date.now() - t1) + ' ms)');
  if (!toque) { await W(300); await p.keyboard.press('KeyR'); await W(200); e = await E(); ok(e.jogo.tentativas === 3, 'R recomeça no computador'); await p.keyboard.press('Escape'); await W(300); e = await E(); ok(e.tela === 'inicio', 'Esc sai da descida'); }
  else { await clica('#bSai'); await W(300); }

  // 5b. a cambalhota: na Mola maluca, segura logo depois da mola e solta antes de cair
  // (o toque entra pela mesma fila do dedo, mas no passo certo: 10 passos depois da mola, segurando 0,9 s)
  await C(() => { window.__duvido.jogaPronta(3); window.__duvido.agenda([{ n: 83, k: 1 }, { n: 191, k: 0 }]); });
  await W(1500); await foto('3b-cambalhota');
  e = await espera(e => e.jogo && e.jogo.fim, 15000);
  ok(e.jogo.cambalhotas >= 1, 'segurar no ar dá cambalhota (' + e.jogo.cambalhotas + ', ' + e.jogo.fim.motivo + (e.jogo.fim.cs ? ' em ' + e.jogo.fim.cs / 100 + ' s' : '') + ')');
  await W(1300);
  if (e.jogo.fim.motivo === 'chegou') ok(await C(() => /cambalhota/.test(document.getElementById('fBonus').textContent)), 'o resultado mostra o desconto da cambalhota');
  await C(() => window.__duvido.inicio()); await W(300);

  // 6. o editor: desenha com o dedo (ou o mouse), desfaz, põe a chegada
  await clica('#iFaz'); await W(500);
  e = await E(); ok(e.tela === 'editor' && e.editor.tracos === 0, 'Fazer o meu abre o editor vazio');
  ok(await semRolagem(), 'sem rolagem de lado no editor');
  await foto('4-editor');
  const tl = await C(() => window.__duvido.tela());
  const sc = (x, y) => C(([x, y]) => window.__duvido.mundoParaTela(x, y), [x, y]);
  const risca = async (pts) => {
    const q = []; for (const [x, y] of pts) q.push(await sc(x, y));
    if (toque) { const s = await cdp(); await s.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: q[0].x, y: q[0].y, id: 7 }] }); for (let i = 1; i < q.length; i++) { for (let k = 1; k <= 6; k++) { const x = q[i - 1].x + (q[i].x - q[i - 1].x) * k / 6, y = q[i - 1].y + (q[i].y - q[i - 1].y) * k / 6; await s.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x, y, id: 7 }] }); await W(8); } } await s.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); }
    else { await p.mouse.move(q[0].x, q[0].y); await p.mouse.down(); for (let i = 1; i < q.length; i++) await p.mouse.move(q[i].x, q[i].y, { steps: 6 }); await p.mouse.up(); }
    await W(150);
  };
  await risca([[126, 152], [200, 186], [270, 214], [300, 222]]);
  e = await E(); ok(e.editor.tracos === 1 && e.editor.pontos >= 2, 'um risco vira um traço de giz (' + e.editor.pontos + ' pontos)');
  ok(e.editor.tinta > 150 && e.editor.tinta < 260, 'o giz gasta pelo comprimento (' + e.editor.tinta + ' de ' + e.editor.tintaMax + ')');
  await risca([[60, 330], [200, 360], [330, 330]]);
  e = await E(); ok(e.editor.tracos === 2, 'tirou o dedo e riscou de novo: dois traços (o buraco no meio é pulo)');
  await clica('#eDesfaz'); await W(150); e = await E(); ok(e.editor.tracos === 1, 'Desfazer tira o último traço (' + JSON.stringify(e.editor) + ')');
  await clica('.ferr[data-f="chegada"]'); await W(100);
  const pc0 = await sc(290, 200); if (toque) await p.touchscreen.tap(pc0.x, pc0.y); else await p.mouse.click(pc0.x, pc0.y);
  await W(200); e = await E(); ok(e.editor.carimbos.includes('chegada'), 'a bandeira de chegada vai pro chão');
  const ch = await C(() => window.__duvido.faseDoEditor().carimbos.find(c => c.tipo === 'chegada'));
  ok(ch && ch.y >= 210 && ch.y <= 225, 'a bandeira encaixa no giz embaixo do toque (y ' + (ch && ch.y) + ')');
  await clica('.ferr[data-f="turbo"]'); await W(80);
  const pt = await sc(200, 120), pt2 = await sc(250, 170);
  if (toque) { const s = await cdp(); await s.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: pt.x, y: pt.y, id: 3 }] }); for (let k = 1; k <= 6; k++) { await s.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: pt.x + (pt2.x - pt.x) * k / 6, y: pt.y + (pt2.y - pt.y) * k / 6, id: 3 }] }); await W(10); } await s.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); }
  else { await p.mouse.move(pt.x, pt.y); await p.mouse.down(); await p.mouse.move(pt2.x, pt2.y, { steps: 6 }); await p.mouse.up(); }
  await W(150);
  const tb = await C(() => window.__duvido.faseDoEditor().carimbos.find(c => c.tipo === 'turbo'));
  ok(tb && tb.dir === 2, 'o turbo entra e aponta pra onde arrastou (dir ' + (tb && tb.dir) + ')');
  await clica('.ferr[data-f="borracha"]'); await W(80);
  if (toque) await p.touchscreen.tap(pt.x, pt.y); else await p.mouse.click(pt.x, pt.y);
  await W(150); e = await E(); ok(!e.editor.carimbos.includes('turbo'), 'a borracha apaga o turbo');
  await clica('.ferr[data-f="lapis"]'); await W(80);
  await foto('5-editor-desenho');
  // rolar: dois dedos no celular, a rodinha no computador
  const cam0 = (await E()).camY;
  if (toque) {
    const s = await cdp();
    const y0 = Math.round(M.viewport.height * .65);
    await s.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: 100, y: y0, id: 1 }, { x: 200, y: y0, id: 2 }] });
    for (let k = 1; k <= 8; k++) { await s.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: 100, y: y0 - k * 26, id: 1 }, { x: 200, y: y0 - k * 26, id: 2 }] }); await W(16); }
    await s.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await W(120);
    e = await E(); ok(e.camY > cam0 + 80 && e.editor.tracos === 1, 'dois dedos rolam a ladeira sem riscar (camY ' + cam0 + ' → ' + e.camY + ', traços ' + e.editor.tracos + ')');
  } else {
    await p.mouse.move(tl.COLX + 200, 400); await p.mouse.wheel(0, 500); await W(150);
    e = await E(); ok(e.camY > cam0 + 100, 'a rodinha rola a ladeira (camY ' + cam0 + ' → ' + e.camY + ')');
    await p.keyboard.press('Control+KeyZ'); await W(100); e = await E(); ok(e.editor.tracos === 1, 'Ctrl+Z desfaz (volta a ter o turbo apagado de novo)');
  }
  // desenhando perto do pé da tela, a câmera desce sozinha e o traço acompanha
  {
    const camA = (await E()).camY, nA = (await E()).editor.tracos, H = M.viewport.height, x0 = tl.COLX + tl.COLW * .5;
    if (toque) { const s = await cdp(); await s.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: x0, y: H * .5, id: 9 }] }); for (let k = 1; k <= 10; k++) { await s.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: x0 + k * 2, y: H * .5 + (H * .38) * k / 10, id: 9 }] }); await W(16); } await W(900); await s.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); }
    else { await p.mouse.move(x0, H * .5); await p.mouse.down(); await p.mouse.move(x0 + 20, H * .88, { steps: 10 }); await W(900); await p.mouse.up(); }
    await W(150); e = await E();
    const ft = await C(() => { const f = window.__duvido.faseDoEditor(); const t = f.tracos[f.tracos.length - 1]; let y1 = -1; for (let i = 1; i < t.pts.length; i += 2) y1 = Math.max(y1, t.pts[i]); return y1; });
    ok(e.camY > camA + 80 && e.editor.tracos === nA + 1 && ft > camA + H / tl.K, 'desenhando no pé da tela a câmera desce e o traço vai junto (camY ' + camA + ' → ' + e.camY + ', ponta em ' + ft + ')');
    await clica('#eDesfaz'); await W(120);
  }
  // a tira da direita leva pro topo
  const tr = await C(() => { const r = document.getElementById('tira').getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + 4 }; });
  if (toque) await p.touchscreen.tap(tr.x, tr.y); else await p.mouse.click(tr.x, tr.y);
  await W(150); e = await E(); ok(e.camY <= -30, 'tocar no alto da tira volta pro topo (camY ' + e.camY + ')');
  e = await E(); ok(!e.editor.liberado && (await C(() => document.getElementById('eManda').getAttribute('aria-disabled'))) === 'true', 'Mandar fica trancado antes de descer');

  // 7. testa uma ladeira pronta no editor e manda o desafio
  await C(() => window.__duvido.editorPronta(0)); await W(300);
  await clica('#eTesta');
  e = await espera(e => e.jogo && e.jogo.fim, 20000);
  ok(e.jogo.origem === 'teste' && e.jogo.fim.motivo === 'chegou', 'Testar desce a ladeira do editor e chega');
  await W(1300);
  ok(await C(() => !document.getElementById('fManda').hidden && document.getElementById('fManda').textContent === 'Mandar o desafio'), 'chegou: libera o Mandar o desafio');
  await clica('#fManda'); await W(300);
  e = await E(); ok(e.cartao === 'nome', 'pede o nome na própria tela');
  await p.fill('#nCampo', 'Thales'); await clica('#nOk'); await W(300);
  e = await E(); ok(e.cartao === 'manda' && e.nome === 'Thales', 'guardou o nome e abriu a mensagem');
  const msg = await C(() => window.__duvido.mensagem());
  ok(/^Duvido tu descer essa ladeira de rolimã\. Eu desci em \d+,\d s\./.test(msg.texto), 'a mensagem (' + msg.texto.split('\n')[0] + ')');
  ok(/^http:\/\/127\.0\.0\.1:8731\/pagina\.html#dv1[A-Za-z0-9_-]+$/.test(msg.link), 'solto, o link é o endereço da página + # + código (' + msg.link.length + ' letras)');
  await clica('#mCopia'); await W(300);
  const okc = await C(() => document.getElementById('mOk').textContent);
  ok(/Copiado|copia/i.test(okc), 'Copiar responde (' + okc + ')');
  await foto('6-manda');
  ok(await C(() => window.__duvido.estado().editor.liberado), 'o editor fica liberado depois de descer');

  // 8. quem recebe: abre o link, vê o desafio, desce com o fantasma, devolve
  const p1 = p; p = await abre(msg.link);
  e = await E(); ok(e.tela === 'desafio' && e.cartao === 'desafio', 'o link abre direto no desafio');
  const dq = await C(() => document.getElementById('dT').textContent);
  ok(/Thales duvidou tu descer essa/.test(dq), 'o desafio diz quem duvidou (' + dq + ')');
  await foto('7-desafio');
  await C(() => window.__duvido.poeNome('Bia'));
  await clica('#dDesce'); await W(200);
  e = await E(); ok(e.jogo && e.jogo.fantasma === 'Thales', 'desce com o fantasma de quem mandou (' + (e.jogo && e.jogo.fantasma) + ')');
  await W(2500); await foto('8-fantasma');
  e = await espera(e => e.jogo && e.jogo.fim, 20000);
  await W(1300);
  const cmp2 = await C(() => document.getElementById('fCompara').textContent);
  ok(/Empatou com Thales|Ganhou de Thales|Faltou/.test(cmp2), 'compara com quem duvidou (' + cmp2 + ')');
  await clica('#fManda'); await W(300);
  const msg2 = await C(() => window.__duvido.mensagem());
  const de2 = await C(c => window.__duvido.decodifica(c), msg2.cod);
  ok(de2 && de2.corrente.length === 2 && de2.corrente[0].nome === 'Thales' && de2.corrente[1].nome === 'Bia', 'Devolver põe o teu nome na corrente (' + (de2 && de2.corrente.map(c => c.nome + ' ' + c.cs).join(', ')) + ')');
  ok(de2 && de2.fantasma && de2.fantasma.length >= 0 && de2.autor === 'Thales', 'a ladeira devolvida segue sendo do Thales, com o teu fantasma');
  await foto('9-devolve');

  // 9. colar o desafio na mão
  await p.close(); p = p1;
  await C(() => window.__duvido.inicio()); await W(300);
  await clica('#iTenho'); await W(200);
  await p.fill('#cTexto', 'olha isso: ' + msg2.texto); await clica('#cAbre'); await W(400);
  e = await E(); ok(e.tela === 'desafio' && /Bia/.test(await C(() => document.getElementById('dT').textContent)), 'colar a mensagem inteira abre o desafio');
  await C(() => window.__duvido.inicio()); await W(200); await clica('#iTenho'); await W(200);
  await p.fill('#cTexto', msg2.cod.slice(0, -4) + 'AAAA'); await clica('#cAbre'); await W(200);
  ok(await C(() => !document.getElementById('cErro').hidden && /quebrado/.test(document.getElementById('cErro').textContent)), 'código estragado avisa que veio quebrado');

  // 10. o núcleo: determinístico, código vai e volta, a do dia dá pra chegar
  const nucleo = await C(() => {
    const D = window.__duvido, o = {};
    o.det = D.prontas.every(f => JSON.stringify(D.simula(f, [{ t: 1, tipo: 'toca' }, { t: 1.4, tipo: 'solta' }])) === JSON.stringify(D.simula(f, [{ t: 1, tipo: 'toca' }, { t: 1.4, tipo: 'solta' }])));
    o.ida = D.prontas.concat([D.doDia()]).every(f => { const c = D.codifica(f), d = D.decodifica(c); return d && D.codifica(d) === c && JSON.stringify(d.tracos) === JSON.stringify(f.tracos) && JSON.stringify(d.carimbos) === JSON.stringify(f.carimbos); });
    const dia = D.doDia(); o.dia = D.simula(dia, (dia.robo || []).map((n, i) => ({ t: n / 120, tipo: i % 2 ? 'solta' : 'toca' }))).chegou;
    o.diaIgual = D.codifica(D.ladeiraDoDia(D.diaHoje())) === D.codifica(D.ladeiraDoDia(D.diaHoje()));
    const f = { autor: 'Zé', tracos: [{ cor: 2, pts: [128, 150, 380, 300] }], carimbos: [{ tipo: 'turbo', x: 200, y: 180, dir: 15 }, { tipo: 'chegada', x: 360, y: 288 }], corrente: [{ nome: 'Zé', cs: 123 }, { nome: 'Ângela', cs: 99 }], fantasma: [10, 14, 80, 81] };
    o.idaVolta = JSON.stringify(D.decodifica(D.codifica(f))) === JSON.stringify(f);
    o.safada = D.simula(D.prontas[4], []).motivo;
    return o;
  });
  ok(nucleo.det, 'simula é determinístico (mesma fase e toques, mesmo resultado)');
  ok(nucleo.ida && nucleo.idaVolta, 'codifica e decodifica vão e voltam (com acento no nome, fantasma e turbo)');
  ok(nucleo.dia && nucleo.diaIgual, 'a ladeira do dia sai igual e dá pra chegar');
  ok(nucleo.safada === 'cachorro', 'a safada sem tocar não passa (' + nucleo.safada + ')');

  // 11. link quebrado na entrada
  const p3 = await abre(URL0 + '#dv1estragado');
  const av = await p3.evaluate(() => [window.__duvido.estado().tela, document.getElementById('aviso').textContent]);
  ok(av[0] === 'inicio' && /quebrado/.test(av[1]), 'link quebrado cai na entrada com aviso');
  await p3.close();

  ok(erros.length === 0, 'nenhum erro de JS (' + (erros.join(' | ') || 'nenhum') + ')');
  console.log(nome + ': ' + oks + ' ok, ' + falhas + ' falharam');
  await b.close();
  process.exit(falhas ? 1 : 0);
})().catch(e => { console.log('FALHOU: ' + nome + ': exceção ' + e.stack); process.exit(1); });
