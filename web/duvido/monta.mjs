// junta as partes no arquivo do artefato (duvido.html) e na página de teste (pagina.html, com o esqueleto do publicador)
import fs from 'fs'; import path from 'path';
const dir = path.dirname(new URL(import.meta.url).pathname), le = f => fs.readFileSync(path.join(dir, 'partes', f), 'utf8');
const js = ['nucleo.js', 'codigo.js', 'fases.js', 'desenho.js', 'jogo.js'].map(le).join('\n');
const html = le('topo.html').trimEnd() + "\n\n<script>\n'use strict';\n// o link deste jogo depois de publicado: quem abre o desafio dentro do Claude cai direto nele (vazio: a mensagem leva só o código)\nconst LINK_DO_ARTEFATO = '';\n" + js.trim() + '\n</script>\n';
fs.writeFileSync(path.join(dir, 'duvido.html'), html);
const pag = '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><style>:root{padding-block:env(safe-area-inset-top,0px) env(safe-area-inset-bottom,0px)}body{margin:0}[hidden]{display:none!important}</style></head><body>' + html + '</body></html>\n';
fs.writeFileSync(path.join(dir, 'pagina.html'), pag);
console.log('duvido.html', html.length, 'bytes');
