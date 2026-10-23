#!/bin/sh
# junta o esqueleto do publicador com o fragmento, pra testar como vai ficar
d=$(dirname "$0")
{ printf '%s' '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><style>:root{padding-block:env(safe-area-inset-top,0px) env(safe-area-inset-bottom,0px)}body{margin:0}[hidden]{display:none!important}</style></head><body>'
  cat "$d/no.html"
  printf '%s' '</body></html>'; } > "$d/pagina.html"
