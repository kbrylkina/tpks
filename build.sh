#!/usr/bin/env bash
# Сборка PDF из docs/*.tex. Подробнее — AGENTS.md, раздел «LaTeX и сборка».
#   ./build.sh                                  собрать все docs/0*.tex
#   ./build.sh docs/02_scm_plan.tex             собрать один документ
#   ./build.sh --changes                        экземпляры с выделенными изменениями для всех
#                                               документов из docs/accepted.txt
#   ./build.sh --changes docs/02_scm_plan.tex   то же для одного документа
#   ./build.sh --check                          проверка идентификации требований (без сборки PDF),
#                                               пункты И1–И13 чек-листа docs/00_checklist.tex
#   ENGINE=tectonic ./build.sh …                выбрать движок: latexmk, xelatex или tectonic
# Готовый PDF кладётся в pdf/ (с изменениями — в pdf/changes/), временные файлы и логи — в docs/build/.
set -u
root="$(cd "$(dirname "$0")" && pwd)"
cd "$root/docs" || exit 1
mkdir -p "$root/pdf" build

if [ "${1:-}" = "--check" ]; then exec perl "$root/tools/check_ids.pl"; fi

changes=0
if [ "${1:-}" = "--changes" ]; then changes=1; shift; fi

engine="${ENGINE:-}"
if [ -z "$engine" ]; then
  if command -v latexmk >/dev/null 2>&1 && command -v xelatex >/dev/null 2>&1 && command -v perl >/dev/null 2>&1; then
    engine=latexmk
  elif command -v xelatex >/dev/null 2>&1; then
    engine=xelatex
  elif command -v tectonic >/dev/null 2>&1; then
    engine=tectonic
  else
    cat >&2 <<'EOF'
LaTeX не найден. Поставьте одно из (подробно — AGENTS.md §9):
  macOS M1–M4:      brew install tectonic
  macOS Intel, Linux:
    curl --proto '=https' --tlsv1.2 -fsSL https://drop-sh.fullyjustified.net | sh
    mkdir -p ~/.local/bin && mv tectonic ~/.local/bin/    (и добавьте ~/.local/bin в PATH)
  Windows:          winget install MiKTeX.MiKTeX
                    initexmf --set-config-value=[MPM]AutoInstall=1
                    затем откройте Git Bash заново (другой вариант: scoop install tectonic)
Потом снова ./build.sh.
EOF
    exit 2
  fi
fi

# latexdiff-so несёт Algorithm::Diff внутри себя: обычному latexdiff нужен этот модуль perl,
# а в perl из Git Bash его нет. Поэтому сначала пробуем latexdiff-so.
latexdiff_cmd=""
if [ $changes -eq 1 ]; then
  for c in latexdiff-so latexdiff; do
    if command -v "$c" >/dev/null 2>&1 && "$c" --version >/dev/null 2>&1; then latexdiff_cmd="$c"; break; fi
  done
fi
if [ $changes -eq 1 ] && [ -z "$latexdiff_cmd" ]; then
  cat >&2 <<'EOF'
Для --changes нужен latexdiff (и perl). Поставьте:
  MiKTeX (Windows):        miktex packages install latexdiff
  TeX Live / MacTeX:       sudo tlmgr install latexdiff
  macOS с Homebrew:        brew install latexdiff
  Ubuntu/Debian:           sudo apt install latexdiff
EOF
  exit 2
fi

compile() {  # $1 — путь к .tex от docs/, $2 — имя задания (имя PDF без .pdf); вывод движка — в $out
  case "$engine" in
    tectonic) tectonic --keep-logs --outdir build "$1" >"$out" 2>&1 ;;
    xelatex)
      for _ in 1 2 3; do
        xelatex -interaction=nonstopmode -halt-on-error -file-line-error -output-directory=build "$1" >"$out" 2>&1 || return 1
        grep -q -E "Rerun|Label\(s\) may have changed" "build/$2.log" || return 0
      done ;;
    *) latexmk -xelatex -interaction=nonstopmode -halt-on-error -file-line-error -outdir=build "$1" >"$out" 2>&1 ;;
  esac
}

# build_one <путь к .tex от docs/> <имя задания> <куда положить PDF>
build_one() {
  local src="$1" job="$2" dest="$3"
  log="build/$job.log"
  out="build/$job.stdout"
  rm -f "$log"
  compile "$src" "$job"
  local rc=$?
  if [ $rc -eq 0 ] && [ -f "build/$job.pdf" ]; then
    if ! cp -f "build/$job.pdf" "$dest"; then
      echo "   ОШИБКА: не удалось сохранить ${dest#"$root"/}" >&2
      return 1
    fi
    echo "   готово: ${dest#"$root"/}"
    grep -h -E "tpks Warning|LaTeX Warning: (Reference|There were undefined)" "$log" 2>/dev/null | sort -u | head -20
    return 0
  fi
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
  return 1
}

# Экземпляр с выделенными изменениями относительно принятой версии из docs/accepted.txt.
build_changes() {
  local name="$1" line commit version date
  line=$(grep -E "^$name[[:space:]]" accepted.txt 2>/dev/null | tail -1)
  if [ -z "$line" ]; then
    echo "   пропущен: в docs/accepted.txt нет принятой версии этого документа"
    return 0
  fi
  read -r _ commit version date _ <<<"$line"
  if [ -z "${date:-}" ]; then
    echo "   ОШИБКА: в docs/accepted.txt строка «$line» — нужно: документ коммит версия дата" >&2
    return 1
  fi
  if ! git -C "$root" show "$commit:docs/$name.tex" >"build/$name.accepted.raw" 2>"build/$name.git.err"; then
    echo "   ОШИБКА: в git нет docs/$name.tex на коммите $commit (docs/accepted.txt):" >&2
    cat "build/$name.git.err" >&2
    return 1
  fi
  # Обе версии приводим к одному порядку частей, чтобы перенос листа изменений не считался правкой.
  perl "$root/tools/changelog_first.pl" <"build/$name.accepted.raw" >"build/$name.accepted.tex" &&
  perl "$root/tools/changelog_first.pl" <"$name.tex" >"build/$name.current.tex" || return 1
  if ! "$latexdiff_cmd" --encoding=utf8 --type=UNDERLINE --math-markup=whole \
      --append-textcmd="reqsource,reqverify,reqnote" \
      --append-safecmd="reqref,clarify" \
      "build/$name.accepted.tex" "build/$name.current.tex" >"build/$name.diff.tex" 2>"build/$name.latexdiff.log"; then
    echo "   ОШИБКА latexdiff, лог: docs/build/$name.latexdiff.log" >&2
    return 1
  fi
  CHANGES_BASE="{$version}{$date}" perl -pe 'BEGIN { $b = $ENV{CHANGES_BASE} } $done = 1 if !$done && s/^\\begin\{document\}/\\changesbase$b\n\\begin{document}/' \
    "build/$name.diff.tex" >"build/$name-changes.tex"
  mkdir -p "$root/pdf/changes"
  build_one "build/$name-changes.tex" "$name-changes" "$root/pdf/changes/$name.pdf"
}

# Версии требований всех документов: по ним ссылка печатается как «SYS_01_01; #1».
perl "$root/tools/req_versions.pl" 0[1-9]_*.tex >build/req_versions.tex 2>/dev/null || : >build/req_versions.tex

if [ $# -eq 0 ]; then
  if [ $changes -eq 1 ]; then
    set -- $(grep -v -E '^[[:space:]]*(#|$)' accepted.txt 2>/dev/null | awk '{print $1 ".tex"}')
  else
    set -- 0*.tex
  fi
fi
status=0
for src in "$@"; do
  name="$(basename "$src" .tex)"
  if [ ! -f "$name.tex" ]; then echo "Нет файла docs/$name.tex" >&2; status=1; continue; fi
  if [ $changes -eq 1 ]; then
    echo "== $name.tex: изменения после принятой версии ($engine)"
    build_changes "$name" || status=1
    continue
  fi
  echo "== $name.tex ($engine)"
  pdf_name="$name.pdf"
  if [ "$name" = "05_software_requirements" ]; then
    pdf_name="05_software_requirements_final.pdf"
  fi
  build_one "$name.tex" "$name" "$root/pdf/$pdf_name" || status=1
done
exit $status
