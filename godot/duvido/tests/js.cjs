// Carrega o núcleo da versão web (as partes em JS) num vm e devolve as funções (pros testes de ida e volta).
const fs = require('fs'), vm = require('vm'), path = require('path');
module.exports = function (partes) {
  partes = partes || path.join(__dirname, '../../../web/duvido/partes');
  const src = ['nucleo.js', 'codigo.js', 'fases.js'].map(f => fs.readFileSync(path.join(partes, f), 'utf8')).join('\n');
  const expo = ['compila', 'novoEstado', 'simula', 'rodaGravado', 'codifica', 'decodifica', 'idFase', 'desceRobo', 'ladeiraDoDia', 'PRONTAS'];
  const ctx = vm.createContext({ Math, Date, Float64Array, Int16Array, Int32Array, Array, Object, JSON, String, Error, Infinity });
  vm.runInContext(src + '\n' + expo.map(n => `globalThis.${n} = ${n};`).join('\n'), ctx);
  return ctx;
};
