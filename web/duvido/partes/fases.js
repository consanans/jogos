
/* ---------- as ladeiras feitas por nós e a ladeira do dia ---------- */
// seno sem o seno do navegador (série de Taylor): a ladeira do dia tem que sair igual em todo aparelho
function sen(x){
  const DP = 6.283185307179586, P = 3.141592653589793, M = 1.5707963267948966;
  x = x - DP * Math.floor(x / DP + 0.5);
  if(x > M) x = P - x; else if(x < -M) x = -P - x;
  const x2 = x * x;
  return x * (1 - x2 / 6 * (1 - x2 / 20 * (1 - x2 / 42 * (1 - x2 / 72 * (1 - x2 / 110)))));
}
const cos_ = x => sen(x + 1.5707963267948966);
const GRAU = 0.017453292519943295;
function sorteio(semente){ let a = semente | 0; return () => { a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
function arco(cx, cy, r, a0, a1, pg){ const n = Math.max(2, Math.ceil(Math.abs(a1 - a0) / (pg || 9))), o = []; for(let i = 0; i <= n; i++){ const a = (a0 + (a1 - a0) * i / n) * GRAU; o.push(Math.round(cx + cos_(a) * r), Math.round(cy + sen(a) * r)); } return o; }
function junta(...ps){ const o = []; for(const p of ps) for(let i = 0; i < p.length; i += 2){ if(o.length && o[o.length - 2] === p[i] && o[o.length - 1] === p[i + 1]) continue; o.push(p[i], p[i + 1]); } return o; }
// inclinação → graus, sem o atan do navegador
function grausDe(s){ const z = s / (1 + Math.sqrt(1 + s * s)), z2 = z * z; return 2 * z * (1 - z2 * (1 / 3 - z2 * (1 / 5 - z2 * (1 / 7 - z2 / 9)))) / GRAU; }
// a direção do turbo mais perto de um ângulo (graus, 0 = direita, 90 = pra baixo)
const dirDe = g => ((Math.round(g / 22.5) % 16) + 16) % 16;

// A serra: andares em zigue-zague. Cada andar desce pra um lado e acaba numa beirada; o de baixo pega o carrinho
// numa curva grande colada no barranco (ele sobe, perde força e volta) e desce pro outro lado.
// No caminho: lombada, buraco, turbo, cachorro, mola. A beirada pode ser um chutador (voa mais).
function serra(spec){
  const tracos = [], carimbos = [], MURO = 412, BEIRA = spec.beira || 270;
  let x = 128, y = 150, d = 1;
  for(let k = 0; k < spec.andares.length; k++){
    const A = spec.andares[k], P0 = spec.andares[k + 1], cor = A.cor || 0, desce = A.desce;
    // queda grande pro próximo andar pede beirada mais longe do barranco (senão ele bate alto na curva)
    const beira = A.beira || (P0 && (P0.queda || 66) > 110 ? 230 : BEIRA), fimX = d > 0 ? beira : LARG - beira;
    let partes = [];
    if(k > 0){
      const R = A.raio || 96, lado = -d, wx = lado > 0 ? MURO : LARG - MURO, cx = wx - lado * R, cy = y - R;
      partes.push([wx, Math.max(0, cy - (A.parede || 70))], lado > 0 ? arco(cx, cy, R, 0, 90) : arco(cx, cy, R, 180, 90));
    } else partes.push([x, y]);
    const x0 = x, y0 = y; let off = 0;
    const fx = xx => y0 + Math.abs(xx - x0) * desce + off;
    const xAt = em => Math.round(x0 + (fimX - x0) * em);
    const itens = (A.itens || []).slice().sort((a, b) => a.em - b.em);
    for(const it of itens){
      const xi = xAt(it.em);
      if(it.k === 'lombada'){
        const w = it.w || 60, h = it.h || 14, n = 8, xa = xi - d * w / 2;
        partes.push([Math.round(xa), Math.round(fx(xa))]);
        for(let i = 1; i <= n; i++){ const xx = xa + d * w * i / n; partes.push([Math.round(xx), Math.round(fx(xx) - h * sen(3.141592653589793 * i / n))]); }
      } else if(it.k === 'buraco'){
        const w = it.w || 50, xa = xi - d * w / 2, xb = xi + d * w / 2;
        partes.push([Math.round(xa), Math.round(fx(xa))]);
        tracos.push({ cor, pts: junta(...partes) });
        off += it.cai || 8;
        partes = [[Math.round(xb), Math.round(fx(xb))]];
      } else if(it.k === 'meiofio' || it.k === 'muro'){
        // um degrau no meio do chão: o meio-fio pede pulo, o muro pede mola
        const h = it.h || (it.k === 'muro' ? 90 : 18), w = it.w || 8, ya = Math.round(fx(xi));
        partes.push([xi, ya], [xi, ya - h], [xi + d * w, ya - h], [xi + d * w, Math.round(fx(xi + d * w))]);
      } else if(it.k === 'turbo'){
        const g = grausDe(desce);
        carimbos.push({ tipo: 'turbo', x: xi, y: Math.round(fx(xi)) - 16, dir: dirDe(d > 0 ? g : 180 - g) });
      } else if(it.k === 'cachorro') carimbos.push({ tipo: 'cachorro', x: xi, y: Math.round(fx(xi)) });
      else if(it.k === 'mola') carimbos.push({ tipo: 'mola', x: xi, y: Math.round(fx(xi)) - 3 });
    }
    let yLip;
    if(k === spec.andares.length - 1){
      // o último andar acaba num reto com a bandeira e um murinho
      const yF = Math.round(fx(fimX)), reto = spec.reto || 70, xr = fimX + d * reto;
      partes.push([fimX, yF], [xr, yF + 2], [xr + d * 12, yF - 12]);
      carimbos.push({ tipo: 'chegada', x: Math.round(fimX + d * reto * 0.5), y: yF + 1 });
    } else if(A.chuta){
      // o chutador: o fim do andar sobe numa curvinha e joga o carrinho pro alto
      const xa = fimX - d * 46, ya = Math.round(fx(xa));
      partes.push([Math.round(xa), ya], [Math.round(fimX - d * 22), ya + 3], [Math.round(fimX - d * 8), ya - 2], [fimX, ya - A.chuta]);
      yLip = ya - A.chuta;
    } else {
      // a beirada: o fim do andar deita um pouco, pra o carrinho sair reto
      const xa = fimX - d * 34, ya = Math.round(fx(xa));
      partes.push([Math.round(xa), ya], [fimX, ya + 4]);
      yLip = ya + 4;
    }
    tracos.push({ cor, pts: junta(...partes) });
    const P = spec.andares[k + 1];
    if(P){
      const R = P.raio || 96, cx = (d > 0 ? MURO : LARG - MURO) - d * R;
      // o chão do próximo fica abaixo da beirada o bastante pra caber a cabeça quando ele voltar por baixo
      y = Math.round(yLip + (P.queda || 66) - Math.abs(cx - fimX) * P.desce);
      x = cx;
    }
    d = -d;
  }
  return { autor: spec.autor || '', tracos, carimbos, corrente: [], fantasma: null };
}

// o piloto robô: pula os cachorros que vêm pela frente (é com ele que a ladeira do dia é conferida, e é ele que desce na tela de entrada)
function piloto(F, S, cfg){
  const antes = (cfg && cfg.antes) || 0.36;
  if(S.segura){ return S.segT >= 3 ? 0 : -1; }
  // só pula de chão reto (na curva o pulo sai torto) e com velocidade
  if(S.coyote < COYOTE || S.ny > -0.8) return -1;
  const p = S.p, v = S.v, mx = (p[0] + p[2]) / 2, my = (p[1] + p[3]) / 2, vx = (v[0] + v[2]) / 2;
  if(Math.abs(vx) < 30) return -1;
  // degrau em pé na frente (meio-fio): pula um tiquinho antes
  const fr = S.frente === 1 ? 2 : 0, ux = (p[2] - p[0]) / LB * (S.frente === 1 ? 1 : -1), uy = (p[3] - p[1]) / LB * (S.frente === 1 ? 1 : -1);
  const dObs = degrauNaFrente(F, p[fr], p[fr + 1], ux, uy, Math.abs(vx) * 0.32 + 14);
  if(dObs !== null && dObs > Math.abs(vx) * 0.12){
    // só se o chão continua até o degrau (na beirada, o que aparece na frente é a curva do andar de baixo)
    const qx = p[fr] + ux * dObs * 0.6, qy = p[fr + 1] + uy * dObs * 0.6, ch = chaoEmbaixo(F, qx, qy, 24);
    if(ch !== null) return 1;
  }
  for(let i = 0; i < F.caes.length; i++){
    const c = posCao(F.caes[i], S.passos), dx = c[0] - mx, dy = c[1] - my;
    // só o cachorro do chão em que ele tá: a altura que o chão teria lá, seguindo a tábua
    const ux = p[2] - p[0], uy = p[3] - p[1];
    if(dx * vx <= 0 || Math.abs(ux) < 1 || Math.abs(dy - uy / ux * dx) > 24) continue;
    const t = (Math.abs(dx) - 26) / Math.abs(vx);
    if(t > 0 && t < antes) return 1;
  }
  return -1;
}
// a distância até um segmento quase em pé cruzando a linha da tábua, na frente da roda da frente
function degrauNaFrente(F, ox, oy, ux, uy, L){
  const n = consulta(F, ox + ux * L / 2, oy + uy * L / 2, L / 2 + 12), s = F.segs; let melhor = null;
  for(let j = 0; j < n; j++){
    const k = F.lista[j], o = k * 4, ax = s[o], ay = s[o + 1], bx = s[o + 2] - ax, by = s[o + 3] - ay;
    if(Math.abs(bx) > Math.abs(by) * 0.5) continue;
    // só degrau que nasce do chão em que ele tá (a ponta de baixo na altura do chão)
    const ha = (ax - ox) * uy - (ay - oy) * ux, hb = (s[o + 2] - ox) * uy - (s[o + 3] - oy) * ux, hb0 = Math.min(-ha, -hb);
    if(hb0 < -17 || hb0 > -3) continue;
    const den = ux * by - uy * bx; if(Math.abs(den) < 1e-9) continue;
    const t = ((ax - ox) * by - (ay - oy) * bx) / den, u = ((ax - ox) * uy - (ay - oy) * ux) / den;
    if(t > 0 && t < L && u >= 0 && u <= 1 && (melhor === null || t < melhor)) melhor = t;
  }
  return melhor;
}
// desce com o robô e devolve os toques que ele deu (em passos) e o resultado
function desceRobo(F, cfg){
  const S = novoEstado(F), ev = [];
  while(!S.fim){
    const a = piloto(F, S, cfg);
    if(a === 1){ toca(S); ev.push(S.passos); } else if(a === 0){ solta(S); ev.push(S.passos); }
    S.ev.length = 0; passo(F, S);
  }
  return { r: resumo(S), ev };
}

// a ladeira do dia: a data vira a semente; a serra sai sorteada e o robô confere que dá pra chegar.
// Não deu, sorteia de novo com outra semente (sempre na mesma ordem: sai igual pra todo mundo).
function geraDia(semente){
  const r = sorteio(semente), na = 6 + Math.floor(r() * 3), andares = [];
  for(let k = 0; k < na; k++){
    const A = { desce: Math.round((0.24 + r() * 0.12) * 100) / 100, raio: 84 + Math.floor(r() * 16), queda: 84 + Math.floor(r() * 22), itens: [], cor: r() < 0.25 ? 1 + Math.floor(r() * 3) : 0 };
    const sorte = r();
    // o cachorro fica na parte larga do andar (longe do andar de cima), e o andar desce mais pra caber o pulo
    if(k > 0 && sorte < 0.3){ A.itens.push({ k: 'cachorro', em: 0.74 + r() * 0.14 }); A.queda = 96 + Math.floor(r() * 16); }
    else if(sorte < 0.55) A.itens.push({ k: 'lombada', em: 0.35 + r() * 0.35, h: 8 + Math.floor(r() * 10), w: 50 + Math.floor(r() * 30) });
    else if(sorte < 0.75) A.itens.push({ k: 'buraco', em: 0.55 + r() * 0.3, w: 26 + Math.floor(r() * 22) });
    // turbo só em andar manso (no ladeirão ele joga o carrinho longe demais)
    if(k > 0 && A.desce < 0.3 && r() < 0.35) A.itens.push({ k: 'turbo', em: 0.12 + r() * 0.1 });
    if(k < na - 1 && r() < 0.25) A.chuta = 5 + Math.floor(r() * 5);
    andares.push(A);
  }
  return serra({ autor: 'Ladeira do dia', andares, reto: 60 + Math.floor(r() * 30) });
}
function diaHoje(agora){
  const d = new Date((agora === undefined ? Date.now() : agora) - 3 * 3600 * 1000);
  return { a: d.getUTCFullYear(), m: d.getUTCMonth() + 1, d: d.getUTCDate() };
}
function ladeiraDoDia(dia){
  dia = dia || diaHoje();
  const base = dia.a * 10000 + dia.m * 100 + dia.d;
  for(let t = 0; t < 40; t++){
    const f = geraDia(base * 31 + t * 7919), F = compila(f), r = desceRobo(F);
    if(r.r.chegou && r.r.cs >= 500 && r.r.cs <= 2000){ f.dia = dia; f.par = r.r.cs; f.robo = r.ev; return f; }
  }
  const f = serra({ autor: 'Ladeira do dia', andares: [{ desce: .35 }, { desce: .3 }, { desce: .3 }, { desce: .25 }] });
  f.dia = dia; return f;
}

// as cinco da casa, da fácil à safada (todas conferidas pelo robô: dá pra chegar)
const PRONTAS = [
  { nome: 'Pra aquecer', sub: 'Desce sozinha. Só não atrapalha.', spec: { andares: [{ desce: .34 }, { desce: .3, queda: 96, itens: [{ k: 'lombada', em: .6, h: 10 }] }, { desce: .32, cor: 1, queda: 100 }, { desce: .3, queda: 104 }, { desce: .3, queda: 96, itens: [{ k: 'lombada', em: .5, h: 9 }] }, { desce: .28, queda: 100, cor: 3 }, { desce: .24, queda: 96 }] } },
  { nome: 'Lombada', sub: 'Lombada, buraco e meio-fio. No meio-fio, pula.', spec: { andares: [{ desce: .34, itens: [{ k: 'lombada', em: .45, h: 14 }, { k: 'lombada', em: .75, h: 12 }] }, { desce: .3, queda: 100, itens: [{ k: 'buraco', em: .7, w: 40 }] }, { desce: .32, queda: 104, cor: 1, itens: [{ k: 'meiofio', em: .86, h: 16 }] }, { desce: .3, queda: 96, itens: [{ k: 'lombada', em: .4, h: 14 }, { k: 'lombada', em: .7, h: 14 }] }, { desce: .32, queda: 104, itens: [{ k: 'buraco', em: .75, w: 46 }] }, { desce: .3, queda: 100, cor: 2, itens: [{ k: 'meiofio', em: .84, h: 16 }] }, { desce: .24, queda: 96, itens: [{ k: 'lombada', em: .5, h: 16 }] }] } },
  { nome: 'Cachorro do vizinho', sub: 'Quatro caramelos de guarda. Pula os quatro.', spec: { andares: [{ desce: .34 }, { desce: .3, queda: 112, itens: [{ k: 'cachorro', em: .84 }] }, { desce: .28, queda: 110, cor: 2, itens: [{ k: 'lombada', em: .35, h: 10 }, { k: 'cachorro', em: .72 }] }, { desce: .32, queda: 96 }, { desce: .28, queda: 112, itens: [{ k: 'cachorro', em: .72 }] }, { desce: .3, queda: 100, cor: 1, itens: [{ k: 'lombada', em: .45, h: 10 }] }, { desce: .24, queda: 112, itens: [{ k: 'cachorro', em: .62 }] }] } },
  { nome: 'Mola maluca', sub: 'A mola te manda pro céu. Volta inteiro.', spec: { andares: [{ desce: .2, itens: [{ k: 'mola', em: .35 }, { k: 'muro', em: .53, h: 70 }] }, { desce: .26, parede: 292, raio: 106, queda: 97, cor: 3, itens: [{ k: 'turbo', em: .14 }, { k: 'buraco', em: .52, w: 76, cai: 4 }] }, { desce: .3, queda: 100 }, { desce: .3, queda: 104, itens: [{ k: 'lombada', em: .4, h: 12 }] }, { desce: .26, queda: 96, itens: [{ k: 'turbo', em: .16 }, { k: 'buraco', em: .62, w: 60, cai: 4 }] }, { desce: .3, queda: 104, cor: 1 }, { desce: .24, queda: 100, itens: [{ k: 'lombada', em: .5, h: 12 }] }] } },
  { nome: 'A safada', sub: 'Tudo junto, e o caramelo te esperando. Duvido.', spec: { andares: [{ desce: .12, itens: [{ k: 'mola', em: .19 }, { k: 'muro', em: .56, h: 88 }] }, { desce: .24, parede: 237, raio: 116, queda: 83, cor: 2, itens: [{ k: 'turbo', em: .16 }, { k: 'buraco', em: .52, w: 81, cai: 4 }] }, { desce: .25, queda: 114, itens: [{ k: 'lombada', em: .43, h: 12 }, { k: 'cachorro', em: .8 }] }, { desce: .26, queda: 114, chuta: 6, cor: 3, itens: [{ k: 'meiofio', em: .89, h: 16 }] }, { desce: .3, queda: 96, itens: [{ k: 'buraco', em: .7, w: 50 }] }, { desce: .26, queda: 110, chuta: 7, itens: [{ k: 'cachorro', em: .78 }] }, { desce: .3, queda: 104, cor: 1, itens: [{ k: 'lombada', em: .4, h: 14 }, { k: 'meiofio', em: .86, h: 16 }] }, { desce: .24, queda: 116, itens: [{ k: 'cachorro', em: .7 }] }] } }
];
PRONTAS.forEach((p, i) => { p.fase = serra(Object.assign({ autor: 'Duvido' }, p.spec)); p.i = i; });
