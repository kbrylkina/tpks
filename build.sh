#!/usr/bin/env bash
# Сборка PDF из docs/*.tex. Подробнее — AGENTS.md, раздел «LaTeX и сборка».
#   ./build.sh                         собрать все docs/0*.tex
#   ./build.sh docs/02_scm_plan.tex    собрать один документ
#   ENGINE=tectonic ./build.sh …       выбрать движок: latexmk (TeX Live, MacTeX, MiKTeX) или tectonic
# Готовый PDF кладётся в pdf/, временные файлы и логи — в docs/build/.
set -u
root="$(cd "$(dirname "$0")" && pwd)"
cd "$root/docs" || exit 1
mkdir -p "$root/pdf" build

engine="${ENGINE:-}"
if [ -z "$engine" ]; then
  if command -v latexmk >/dev/null 2>&1 && command -v xelatex >/dev/null 2>&1; then
    engine=latexmk
  elif command -v tectonic >/dev/null 2>&1; then
    engine=tectonic
  else
    cat >&2 <<'EOF'
LaTeX не найден. Проще всего поставить Tectonic: одна программа, недостающие пакеты скачивает сама.
  macOS:   brew install tectonic
  Windows: winget install --id TectonicProject.Tectonic -e
  Linux:   curl --proto '=https' --tlsv1.2 -fsSL https://drop-sh.fullyjustified.net | sh
           (кладёт ./tectonic в текущую папку — перенесите его в ~/.local/bin)
Потом снова ./build.sh. Другие способы — AGENTS.md, раздел «LaTeX и сборка».
EOF
    exit 2
  fi
fi

[ $# -eq 0 ] && set -- 0*.tex
status=0
for src in "$@"; do
  name="$(basename "$src" .tex)"
  if [ ! -f "$name.tex" ]; then echo "Нет файла docs/$name.tex" >&2; status=1; continue; fi
  echo "== $name.tex ($engine)"
  log="build/$name.log"
  out="build/$name.stdout"
  rm -f "$log"
  if [ "$engine" = tectonic ]; then
    tectonic --keep-logs --outdir build "$name.tex" >"$out" 2>&1
  else
    latexmk -xelatex -interaction=nonstopmode -halt-on-error -file-line-error \
      -outdir=build "$name.tex" >"$out" 2>&1
  fi
  rc=$?
  if [ $rc -eq 0 ] && [ -f "build/$name.pdf" ]; then
    cp -f "build/$name.pdf" "$root/pdf/$name.pdf"
    echo "   готово: pdf/$name.pdf"
    grep -h -E "tpks Warning|LaTeX Warning: (Reference|There were undefined)" "$log" 2>/dev/null | sort -u | head -20
  else
    status=1
    echo "   ОШИБКА сборки. Строки из лога:" >&2
    grep -h -A3 -E "^! |\.tex:[0-9]+: |^error:" "$log" "$out" 2>/dev/null | head -40 >&2
    missing=$(grep -h -o -E "File \`[^']+\.(sty|cls)' not found" "$log" "$out" 2>/dev/null | head -1 | sed -E "s/File \`([^']+)' not found/\1/")
    if [ -n "$missing" ]; then
      echo "   Не хватает пакета $missing. Варианты:" >&2
      echo "     TeX Live / MacTeX / BasicTeX: sudo tlmgr install ${missing%.*}" >&2
      echo "       (если имя другое: tlmgr search --global --file /$missing)" >&2
      echo "     MiKTeX: miktex packages install ${missing%.*}" >&2
      echo "     без sudo: поставьте Tectonic и соберите ENGINE=tectonic ./build.sh" >&2
    fi
    echo "   Полный лог: docs/$log" >&2
  fi
done
exit $status
