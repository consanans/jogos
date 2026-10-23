// O Duvido exportado pro navegador (build/web), num celular de toque e num computador.
// Frases "ok:" e "FALHOU:", fotos em screenshots/. Uso: node tests/web.cjs [cel|pc] [porta]
// (precisa do servidor: python3 -m http.server PORTA --directory build/web)
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const path = require('path');
const raiz = path.join(__dirname, '..');
const modo = process.argv[2] || 'cel', porta = process.argv[3] || '8765';
const URL0 = `http://127.0.0.1:${porta}/index.html`;
const MODOS = {
  cel: { viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 },
  p320: { viewport: { width: 320, height: 568 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 },
  pc: { viewport: { width: 1366, height: 860 } },
};
const M = MODOS[modo], toque = !!M.hasTouch;
// O nome com acento. No celular o Godot usa o teclado virtual (um campo escondido). No computador, o teste
// manda as teclas como um teclado ABNT2 de verdade manda (a tecla morta do acento e depois o "e"):
// o "type" do Playwright mandaria o "é" como texto colado, sem tecla nenhuma.
const nomeTeste = 'Zé';
let falhas = 0, oks = 0;
const ok = (c, m) => { if (c) oks++; else falhas++; console.log((c ? 'ok: ' : 'FALHOU: ') + modo + ': ' + m); };

(async () => {
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
  const ctx = await b.newContext({ ...M });
  // nada sai pra internet (nem a aba do WhatsApp): só o servidor local
  await ctx.route('**/*', r => r.request().url().startsWith('http://127.0.0.1') ? r.continue() : r.abort());
  const p = await ctx.newPage();
  const erros = [], avisos = [];
  p.on('pageerror', e => erros.push('pageerror: ' + e.message));
  p.on('console', m => { const t = m.text(); if (m.type() === 'error') erros.push('console: ' + t); else if (m.type() === 'warning') avisos.push(t); });
  const W = ms => p.waitForTimeout(ms);
  const E = () => p.evaluate(() => window.__duvidoEstado || null);
  const espera = async (cond, ms = 30000, passo = 150) => { const t0 = Date.now(); while (Date.now() - t0 < ms) { const e = await E(); if (e && cond(e)) return e; await W(passo); } return await E(); };
  const foto = n => p.screenshot({ path: path.join(raiz, 'screenshots', `web-${modo}-${n}.png`) });
  // as coordenadas da tela do Godot (unidades) viram px da página
  const css = async (e, r) => { const vw = M.viewport.width; const k = vw / e.tam[0]; return { x: (r[0] + r[2] / 2) * k, y: (r[1] + r[3] / 2) * k }; };
  let sessao = null;
  const cdp = async () => { if (!sessao) sessao = await ctx.newCDPSession(p); return sessao; };
  const tocaEm = async (x, y) => { if (toque) await p.touchscreen.tap(x, y); else await p.mouse.click(x, y); };
  // rola o cartão (arrastando o dedo, ou a rodinha) até o botão aparecer inteiro na tela
  const garante = async (nome) => {
    for (let i = 0; i < 6; i++) {
      const e = await E(); const r = e && e.alvos[nome]; if (!r || !e.cartao) return;
      const k = M.viewport.width / e.tam[0], cy = (r[1] + r[3] / 2) * k, H = M.viewport.height;
      if (cy > H * 0.08 && cy < H * 0.88) return;
      const dy = Math.max(-H * 0.4, Math.min(H * 0.4, cy - H * 0.5));
      if (toque) {
        const s = await cdp(), x = M.viewport.width * 0.5, y0 = H * 0.5;
        await s.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y: y0, id: 5 }] });
        for (let q = 1; q <= 8; q++) { await s.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x, y: y0 - dy * q / 8, id: 5 }] }); await W(20); }
        await s.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      } else { await p.mouse.move(M.viewport.width * 0.5, H * 0.5); await p.mouse.wheel(0, dy); }
      await W(500);
    }
  };
  const tocaAlvo = async (nome) => {
    await garante(nome);
    const e = await E(); const r = e && e.alvos[nome];
    if (!r) { ok(false, 'o botão ' + nome + ' aparece na tela'); return false; }
    const c = await css(e, r); await tocaEm(c.x, c.y); return true;
  };

  const t0 = Date.now();
  await p.goto(URL0);
  let e = await espera(e => e.tela === 'inicio' && e.alvos && e.alvos.fase_0, 90000, 300);
  ok(e && e.tela === 'inicio' && e.cartao === 'inicio', 'liga e abre na entrada (' + ((Date.now() - t0) / 1000).toFixed(1) + ' s)');
  await W(800); await foto('0-inicio');
  ok(e && ['fase_dia', 'fase_0', 'fase_1', 'fase_2', 'fase_3', 'fase_4'].every(k => e.alvos[k]), 'as seis ladeiras na lista (a do dia e as cinco)');

  // 1. toca na "Pra aquecer" e desce
  await tocaAlvo('fase_0');
  e = await espera(e => e.tela === 'jogo', 8000);
  ok(e.tela === 'jogo' && e.jogo && e.jogo.titulo === 'Pra aquecer', 'um toque na "Pra aquecer" começa a descida (' + (e.jogo && e.jogo.titulo) + ')');
  const x0 = e.jogo.x, y0 = e.jogo.y;
  await W(2200); e = await E();
  ok(e.jogo.passos > 60 && (Math.abs(e.jogo.x - x0) > 20 || Math.abs(e.jogo.y - y0) > 20), 'o carrinho anda (passos ' + e.jogo.passos + ', de ' + x0.toFixed(0) + ',' + y0.toFixed(0) + ' pra ' + e.jogo.x.toFixed(0) + ',' + e.jogo.y.toFixed(0) + ')');
  await foto('1-descendo');
  // o toque (ou o espaço) pula
  e = await espera(e => e.jogo && e.jogo.noChao && e.jogo.passos > 40, 4000, 50);
  const nAntes = e.jogo.ev.length;
  if (toque) await p.touchscreen.tap(150, Math.round(M.viewport.height * 0.6));
  else { await p.keyboard.down('Space'); await W(60); await p.keyboard.up('Space'); }
  await W(400); e = await E();
  ok(e.jogo.ev.length >= nAntes + 2, (toque ? 'o toque' : 'o espaço') + ' vira pulo (toques gravados: ' + e.jogo.ev.length + ')');
  ok(e.sons.includes('pulo') && e.sons.includes('vai'), 'o pulo e a largada tocam som (' + e.sons.slice(-5).join(',') + ')');
  // sai e entra de novo, sem tocar: chega sozinha
  await tocaAlvo('sai');
  e = await espera(e => e.tela === 'inicio' && e.alvos.fase_0, 5000);
  ok(e.tela === 'inicio', 'o × volta pra entrada');
  await tocaAlvo('fase_0');
  e = await espera(e => e.jogo && e.jogo.fim, 40000, 300);
  ok(e.jogo && e.jogo.fim === 'chegou', 'a "Pra aquecer" chega sozinha (' + (e.jogo && e.jogo.fim) + ', ' + (e.jogo && e.jogo.tempo) + ' s)');
  e = await espera(e => e.cartao === 'fim', 5000);
  ok(e.cartao === 'fim', 'o cartão do resultado aparece');
  await W(400); await foto('2-resultado');

  // 2. o caramelo: sem pular, capota; o carimbo CAPOTOU; um toque recomeça
  await W(600); await tocaAlvo('fMenu');
  e = await espera(e => e.tela === 'inicio' && e.alvos.fase_2, 5000);
  await tocaAlvo('fase_2');
  e = await espera(e => e.jogo && e.jogo.fim, 40000, 200);
  ok(e.jogo && e.jogo.fim === 'cachorro', 'sem pular, o caramelo derruba (' + (e.jogo && e.jogo.fim) + ')');
  await W(700); e = await E();
  ok(/CAPOTOU/.test(e.carimbo), 'o carimbo CAPOTOU aparece (' + e.carimbo + ')');
  ok(e.sons.includes('capotou') && e.sons.includes('latido'), 'o caramelo late e a capotada faz estrondo');
  await foto('3-capotou');
  const t1 = Date.now();
  await tocaEm(M.viewport.width * 0.45, M.viewport.height * 0.5);
  e = await espera(e => e.jogo && e.jogo.tentativas === 2 && !e.jogo.fim, 3000, 50);
  ok(e.jogo.tentativas === 2, 'um toque depois de capotar recomeça (' + (Date.now() - t1) + ' ms)');
  await tocaAlvo('sai'); await espera(e => e.tela === 'inicio', 5000);

  // 3. o editor: abre, risca com o dedo (ou o mouse), põe a chegada
  await tocaAlvo('iFaz');
  e = await espera(e => e.tela === 'editor', 5000);
  ok(e.tela === 'editor', 'Fazer o meu abre o editor (' + e.editor.tracos + ' traços do rascunho)');
  await W(600); await foto('4-editor');
  const n0 = e.editor.tracos;
  // do mundo (a ladeira) pra página: o mesmo risco do teste da versão web
  const k = M.viewport.width / e.tam[0], mu = e.mundo;
  const tela = (x, y) => [(mu.colx + x * mu.k) * k, (y - mu.cam) * mu.k * k];
  const pts = [[126, 152], [200, 186], [270, 214], [300, 222]].map(([x, y]) => tela(x, y));
  if (toque) {
    const s = await cdp();
    await s.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: pts[0][0], y: pts[0][1], id: 7 }] });
    for (let i = 1; i < pts.length; i++) for (let q = 1; q <= 6; q++) { const x = pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * q / 6, y = pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * q / 6; await s.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x, y, id: 7 }] }); await W(16); }
    await s.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  } else {
    await p.mouse.move(pts[0][0], pts[0][1]); await p.mouse.down();
    for (let i = 1; i < pts.length; i++) await p.mouse.move(pts[i][0], pts[i][1], { steps: 6 });
    await p.mouse.up();
  }
  await W(500); e = await E();
  ok(e.editor.tracos === n0 + 1, 'um risco vira um traço de giz (' + n0 + ' → ' + e.editor.tracos + ')');
  await tocaAlvo('ferr_chegada'); await W(200);
  const pc0 = tela(290, 200); await tocaEm(pc0[0], pc0[1]);
  await W(400); e = await E();
  ok(e.editor.carimbos.includes('chegada'), 'a bandeira de chegada vai pro chão (' + e.editor.carimbos.join(',') + ')');
  await W(300); await foto('5-editor-desenho');
  await tocaAlvo('eDesfaz'); await W(300); e = await E();
  ok(!e.editor.carimbos.includes('chegada'), 'Desfazer tira a bandeira');
  await tocaAlvo('eVolta'); e = await espera(e => e.tela === 'inicio', 5000);
  ok(e.tela === 'inicio', 'a seta do editor volta pro começo');

  // 4. a cambalhota: na Mola maluca, segura logo depois da mola e solta antes de cair (o mesmo agendamento do teste web)
  await p.evaluate(() => { window.__duvidoCmd = ['joga:3', 'agenda:83/1,191/0']; });
  e = await espera(e => e.jogo && e.jogo.titulo === 'Mola maluca' && e.jogo.passos > 150, 15000, 50);
  await foto('3b-cambalhota');
  e = await espera(e => e.jogo && e.jogo.fim, 40000, 200);
  ok(e.jogo.cambalhotas >= 1, 'segurar no ar dá cambalhota (' + e.jogo.cambalhotas + ', ' + e.jogo.fim + ', ' + e.jogo.tempo + ' s)');
  {
    // os toques gravados no Godot, descendo no JavaScript da web: o mesmo fim, no centésimo
    const Jw = require('./js.cjs')(), rw = Jw.rodaGravado(Jw.compila(Jw.PRONTAS[3].fase), e.jogo.ev);
    ok(rw.motivo === e.jogo.fim && Math.round(e.jogo.tempo * 100) === rw.cs && rw.cambalhotas === e.jogo.cambalhotas, 'a mesma descida (toques ' + JSON.stringify(e.jogo.ev) + ') no JS da web: ' + rw.motivo + ' em ' + rw.cs + ' cs, ' + rw.cambalhotas + ' cambalhota');
  }
  // (o cartão do resultado pode já estar por cima do ×: volta pro começo pelo comando)
  await p.evaluate(() => { window.__duvidoCmd = ['inicio']; }); await espera(e => e.tela === 'inicio' && e.alvos.fase_0, 8000);
  await W(600);

  // 5. duvidar alguém: o nome (uma vez só), a mensagem com o link, copiar, o WhatsApp
  await tocaAlvo('fase_0');
  e = await espera(e => e.cartao === 'fim', 40000, 300);
  await W(900);
  await tocaAlvo('fManda');
  e = await espera(e => e.cartao === 'nome' && e.alvos.nCampo, 5000);
  ok(e.cartao === 'nome', 'antes de mandar, pede o nome (' + e.cartao + ')');
  await W(600); e = await E();
  { const c = await css(e, e.alvos.nCampo); await tocaEm(c.x, c.y); await W(400); if (toque) await p.keyboard.type(nomeTeste);
    else {
      const s = await cdp();
      await p.keyboard.press('Shift+KeyZ');
      await s.send('Input.dispatchKeyEvent', { type: 'rawKeyDown', key: 'Dead', code: 'BracketLeft', windowsVirtualKeyCode: 219 });
      await s.send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Dead', code: 'BracketLeft', windowsVirtualKeyCode: 219 });
      await s.send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'é', code: 'KeyE', text: 'é', unmodifiedText: 'é', windowsVirtualKeyCode: 69 });
      await s.send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'é', code: 'KeyE', windowsVirtualKeyCode: 69 });
    }
    await W(400); }
  await tocaAlvo('nOk');
  e = await espera(e => e.cartao === 'manda', 5000);
  await W(600); e = await E();
  if (e.cartao !== 'manda') { await p.evaluate(() => { window.__duvidoCmd = ['nome:Zé', 'manda']; }); e = await espera(e => e.cartao === 'manda', 5000); ok(false, 'o nome digitado no campo do Godot (teclado do navegador)'); }
  else ok(e.nome === nomeTeste, 'o nome digitado vai pro jogo (' + e.nome + ')');
  ok(e.manda && /^Duvido tu descer essa ladeira de rolimã\. Eu desci em \d+,\d s\.\nhttps:\/\/mougus\.com\.br\/jogos\/duvido#dv1[A-Za-z0-9_-]+$/.test(e.manda.texto), 'a mensagem tem o texto da web e o link mougus.com.br/jogos/duvido#código');
  await W(500); await foto('6-manda');
  await ctx.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: 'http://127.0.0.1:' + porta });
  await tocaAlvo('mCopia');
  e = await espera(e => e.okCopia, 4000);
  ok(/Copiado/.test(e.okCopia), 'copiar responde (' + e.okCopia + ')');
  const copiado = await p.evaluate(() => navigator.clipboard.readText().catch(err => 'erro: ' + err));
  ok(copiado === e.manda.texto, 'a mensagem foi pra área de transferência (' + copiado.slice(0, 40) + '...)');
  const pop = new Promise(res => { const f = r => { if (/wa\.me|whatsapp/.test(r.url())) { ctx.off('request', f); res(r.url()); } }; ctx.on('request', f); setTimeout(() => res(null), 6000); });
  await tocaAlvo('mZap');
  const zap = await pop;
  ok(zap && zap.startsWith('https://wa.me/?text=') && decodeURIComponent(zap.slice(20)) === e.manda.texto, 'Mandar no WhatsApp abre o wa.me com a mensagem (' + (zap || 'nada').slice(0, 50) + ')');
  // o código do Godot abre na versão web: o mesmo desenho, a corrente e o fantasma que desce no mesmo tempo
  const J = require('./js.cjs')();
  const cod = e.manda.cod, f = J.decodifica(cod);
  ok(!!f, 'o código feito no Godot abre no núcleo da versão web');
  if (f) {
    const igual = JSON.stringify(f.tracos) === JSON.stringify(J.PRONTAS[0].fase.tracos.map(t => ({ cor: t.cor, pts: t.pts }))) && JSON.stringify(f.carimbos) === JSON.stringify(J.PRONTAS[0].fase.carimbos);
    ok(igual && f.autor === 'Duvido' && f.corrente.length === 1 && f.corrente[0].nome === nomeTeste, 'na web: a mesma ladeira, o autor e a corrente (' + JSON.stringify(f.corrente) + ')');
    const r = J.rodaGravado(J.compila(f), f.fantasma);
    ok(r.chegou && r.cs === f.corrente[0].cs, 'na web, o fantasma do Godot desce no mesmo tempo, no centésimo (' + r.cs + ' = ' + f.corrente[0].cs + ')');
    ok(J.codifica(f) === cod, 'e a web escreve o mesmo código de volta, letra por letra');
  }

  // 6. o desafio que chega pelo link (#código): a corrente, a miniatura, e o fantasma de quem mandou
  const codWeb = J.codifica({ autor: 'Thales', tracos: J.PRONTAS[2].fase.tracos, carimbos: J.PRONTAS[2].fase.carimbos, corrente: [{ nome: 'Thales', cs: 947 }, { nome: 'Bia', cs: 1040 }], fantasma: J.desceRobo(J.compila(J.PRONTAS[2].fase), { antes: 0.36 }).ev });
  await p.goto(URL0 + '#' + codWeb);
  e = await espera(e => e.tela === 'desafio' && e.alvos && e.alvos.dDesce, 60000, 300);
  ok(e.tela === 'desafio' && e.desafio && e.desafio.autor === 'Thales' && e.desafio.corrente.length === 2, 'o link com #código (feito na web) abre o desafio com a corrente');
  await W(800); await foto('7-desafio');
  await tocaAlvo('dDesce');
  e = await espera(e => e.jogo && e.jogo.passos > 200, 15000, 100);
  ok(e.jogo && e.jogo.origem === 'desafio' && e.jogo.fantasma === 'Bia', 'Descer começa com o fantasma de quem mandou por último (' + (e.jogo && e.jogo.fantasma) + ')');
  await foto('8-fantasma');
  // 7. "Tenho um desafio": o cartão de colar
  await tocaAlvo('sai'); e = await espera(e => e.tela === 'desafio', 5000);
  await W(500); await p.evaluate(() => { window.__duvidoCmd = ['inicio']; }); e = await espera(e => e.tela === 'inicio' && e.alvos.iTenho, 5000);
  await W(500); await tocaAlvo('iTenho');
  e = await espera(e => e.cartao === 'cola', 5000);
  ok(e.cartao === 'cola', '"Tenho um desafio" abre o cartão de colar');
  await W(600); await foto('9-cola');

  ok(erros.length === 0, 'nenhum erro no console (' + (erros.slice(0, 5).join(' | ') || 'nenhum') + ')');
  const fps = (await E()).fps;
  console.log('fps no fim (swiftshader, sem placa de vídeo): ' + fps);
  console.log(oks + ' ok, ' + falhas + ' falharam');
  await b.close(); process.exit(falhas ? 1 : 0);
})().catch(e => { console.log('FALHOU: exceção ' + e.stack); process.exit(1); });
