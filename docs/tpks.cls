% tpks.cls — шаблон документов ТПКС: всё оформление и наши команды.
% Документы этот файл не меняют. Как писать — docs/00_example.tex, как собирать — ./build.sh.
% Сам подключает docs/project.tex (проект и команда) и docs/glossary.tex (термины).
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{tpks}[2026/10/02 TPKS documents]
\LoadClass[12pt,a4paper,oneside]{article}

\ifdefined\XeTeXrevision\else\ifdefined\directlua\else
  \ClassError{tpks}{Нужен XeLaTeX: собирай командой ./build.sh}{Подробнее: AGENTS.md, раздел «LaTeX и сборка».}
\fi\fi

% --- Шрифт и язык ------------------------------------------------------------
% Times New Roman; если его нет — Liberation Serif, затем CMU Serif (есть в TeX Live и Tectonic).
\RequirePackage{fontspec}
\defaultfontfeatures{Ligatures=TeX}
\IfFontExistsTF{Times New Roman}{%
  \setmainfont{Times New Roman}\newfontfamily\cyrillicfont{Times New Roman}%
}{\IfFontExistsTF{Liberation Serif}{%
  \setmainfont{Liberation Serif}\newfontfamily\cyrillicfont{Liberation Serif}%
}{%
  \setmainfont{cmunrm.otf}[BoldFont=cmunbx.otf,ItalicFont=cmunti.otf,BoldItalicFont=cmunbi.otf]%
  \newfontfamily\cyrillicfont{cmunrm.otf}[BoldFont=cmunbx.otf,ItalicFont=cmunti.otf,BoldItalicFont=cmunbi.otf]%
}}
\IfFontExistsTF{Courier New}{%
  \setmonofont{Courier New}\newfontfamily\cyrillicfonttt{Courier New}%
}{\IfFontExistsTF{Liberation Mono}{%
  \setmonofont{Liberation Mono}\newfontfamily\cyrillicfonttt{Liberation Mono}%
}{%
  \setmonofont{cmuntt.otf}\newfontfamily\cyrillicfonttt{cmuntt.otf}%
}}
\RequirePackage{polyglossia}
\setdefaultlanguage{russian}
\setotherlanguage{english}

% --- Страница и абзацы ---------------------------------------------------------
\RequirePackage[a4paper,left=25mm,right=15mm,top=20mm,bottom=20mm]{geometry}
\linespread{1.15}
\setlength{\parindent}{1.25cm}
\setlength{\parskip}{0pt}
\RequirePackage{indentfirst}
\raggedbottom
\setcounter{secnumdepth}{3}
\setcounter{tocdepth}{3}

\RequirePackage{titlesec}
\titleformat{\section}{\large\bfseries}{\thesection}{0.6em}{}
\titleformat{\subsection}{\normalsize\bfseries}{\thesubsection}{0.6em}{}
\titleformat{\subsubsection}{\normalsize\bfseries}{\thesubsubsection}{0.6em}{}
\titlespacing*{\section}{0pt}{14pt plus 4pt minus 2pt}{6pt plus 2pt}
\titlespacing*{\subsection}{0pt}{10pt plus 3pt minus 2pt}{4pt plus 2pt}
\titlespacing*{\subsubsection}{0pt}{8pt plus 2pt minus 2pt}{3pt plus 1pt}

\RequirePackage{enumitem}
\setlist{itemsep=1pt,parsep=0pt,topsep=3pt,leftmargin=\parindent}
\setlist[itemize]{label=\textendash}

% --- Таблицы и рисунки -----------------------------------------------------------
\RequirePackage{graphicx}
\graphicspath{{img/}}
\RequirePackage{array}
\RequirePackage{xltabular}
\renewcommand{\arraystretch}{1.2}
\newcolumntype{L}{>{\raggedright\arraybackslash}X}
\newcolumntype{P}[1]{>{\raggedright\arraybackslash}p{#1}}
\RequirePackage{caption}
\captionsetup{labelsep=endash}
\captionsetup[table]{name=Таблица,justification=raggedright,singlelinecheck=false,position=top,skip=4pt}
\captionsetup[figure]{name=Рисунок,justification=centering,skip=6pt}

\RequirePackage{xcolor}
\RequirePackage[unicode,hidelinks,bookmarksnumbered]{hyperref}

% Подчёркивание в тексте печатается как есть: SYS_04_02 можно писать без \_.
\AtBeginDocument{\catcode`\_=12\relax}

\ExplSyntaxOn
\msg_new:nnn { tpks } { no-meta } { Не~задано~\iow_char:N\\#1~—~допишите~его~перед~\iow_char:N\\begin{document}. }
\msg_new:nnn { tpks } { bad-id } { ID~«#1»~не~по~схеме~SYS_NN_NN~или~SRD_NN_NN~(README.md~§4.6). }
\msg_new:nnn { tpks } { dup-id } { ID~«#1»~уже~есть~в~этом~документе:~у~каждого~требования~свой~ID. }
\msg_new:nnn { tpks } { no-term } { Термина~«#1»~нет~в~docs/glossary.tex:~добавьте~\iow_char:N\\term{#1}{…}. }
\msg_new:nnn { tpks } { dup-term } { Термин~«#1»~определён~в~docs/glossary.tex~дважды. }
\cs_generate_variant:Nn \msg_error:nnn { nnV }
\cs_generate_variant:Nn \msg_warning:nnn { nnV }

% --- Данные документа и проекта ----------------------------------------------------
\tl_new:N \g__tpks_title_tl
\tl_new:N \g__tpks_version_tl
\tl_new:N \g__tpks_date_tl
\tl_new:N \g__tpks_authors_tl
\tl_new:N \g__tpks_project_tl
\tl_new:N \g__tpks_course_tl
\tl_new:N \g__tpks_teacher_tl
\tl_new:N \g__tpks_university_tl
\seq_new:N \g__tpks_team_short_seq
\seq_new:N \g__tpks_team_rows_seq

\NewDocumentCommand \doctitle   { m } { \tl_gset:Nn \g__tpks_title_tl {#1} }
\NewDocumentCommand \docversion { m } { \tl_gset:Nn \g__tpks_version_tl {#1} }
\NewDocumentCommand \docdate    { m } { \tl_gset:Nn \g__tpks_date_tl {#1} }
\NewDocumentCommand \docauthors { m } { \tl_gset:Nn \g__tpks_authors_tl {#1} }
\NewDocumentCommand \project    { m } { \tl_gset:Nn \g__tpks_project_tl {#1} }
\NewDocumentCommand \course     { m } { \tl_gset:Nn \g__tpks_course_tl {#1} }
\NewDocumentCommand \teacher    { m } { \tl_gset:Nn \g__tpks_teacher_tl {#1} }
\NewDocumentCommand \university { m } { \tl_gset:Nn \g__tpks_university_tl {#1} }

% \teammember{Фамилия И. О.}{Фамилия Имя Отчество}{группа}{роль или пусто}
\NewDocumentCommand \teammember { m m m m }
  {
    \tl_if_blank:nTF {#4}
      { \seq_gput_right:Nn \g__tpks_team_short_seq {#1} }
      { \seq_gput_right:Nn \g__tpks_team_short_seq { #1~(#4) } }
    \seq_gput_right:Nn \g__tpks_team_rows_seq { #2 & #3 & #4 \\ \hline }
  }

\cs_new_protected:Npn \__tpks_check_meta:Nn #1#2
  { \tl_if_blank:VT #1 { \msg_error:nnn { tpks } { no-meta } {#2} } }

% Шапка первой страницы и содержание
\NewDocumentCommand \makeheader { }
  {
    \__tpks_check_meta:Nn \g__tpks_title_tl { doctitle }
    \__tpks_check_meta:Nn \g__tpks_version_tl { docversion }
    \__tpks_check_meta:Nn \g__tpks_date_tl { docdate }
    \tl_if_blank:VT \g__tpks_authors_tl
      { \tl_gset:Nx \g__tpks_authors_tl { \seq_use:Nn \g__tpks_team_short_seq { ,~ } } }
    \exp_args:Nx \hypersetup { pdftitle = { \exp_not:V \g__tpks_title_tl } }
    \begingroup
    \setlength{\parindent}{0pt}
    {\Large\bfseries \g__tpks_title_tl \par}
    \smallskip
    Проект:~\g__tpks_project_tl \par
    Версия~\g__tpks_version_tl {}~от~\g__tpks_date_tl \par
    Авторы:~\g__tpks_authors_tl \par
    {\small \g__tpks_course_tl {}~·~преподаватель~\g__tpks_teacher_tl {}~·~\g__tpks_university_tl \par}
    \smallskip \hrule \bigskip
    \endgroup
    \tableofcontents
    \clearpage
  }

% Таблица состава команды из project.tex
\NewDocumentCommand \printteam { }
  {
    \begin{xltabular}{\textwidth}{|L|l|L|}
      \hline \textbf{ФИО} & \textbf{Группа} & \textbf{Роль} \\ \hline \endhead
      \seq_use:Nn \g__tpks_team_rows_seq { }
    \end{xltabular}
  }

% --- Требования ----------------------------------------------------------------------
% \begin{req}{SYS_04_02}{1} Текст \reqsource{…} \reqverify{…} \reqnote{…} \end{req}
\str_new:N \l__tpks_id_str
\seq_new:N \g__tpks_ids_seq
\regex_const:Nn \c__tpks_id_regex { \A (SYS|SRD)_\d\d_\d\d \Z }
\prg_generate_conditional_variant:Nnn \regex_match:Nn { NV } { F }
\prg_generate_conditional_variant:Nnn \seq_if_in:Nn { NV } { TF }
\cs_new_protected:Npn \tpks@reqdefined #1 { \cs_gset:cpn { tpks@req@ \tl_to_str:n {#1} } { } }

\NewDocumentEnvironment { req } { m m }
  {
    \str_set:Nx \l__tpks_id_str { \tl_trim_spaces:n {#1} }
    \regex_match:NVF \c__tpks_id_regex \l__tpks_id_str
      { \msg_error:nnV { tpks } { bad-id } \l__tpks_id_str }
    \seq_if_in:NVTF \g__tpks_ids_seq \l__tpks_id_str
      { \msg_error:nnV { tpks } { dup-id } \l__tpks_id_str }
      { \seq_gput_right:NV \g__tpks_ids_seq \l__tpks_id_str }
    \iow_now:Nx \@auxout { \token_to_str:N \tpks@reqdefined { \l__tpks_id_str } }
    \par \addvspace { 6pt plus 2pt } \noindent
    \use:x { \exp_not:N \hypertarget { req: \l__tpks_id_str } }
      { \textbf { \l__tpks_id_str ;~\#\tl_trim_spaces:n {#2} } }
    \par \nopagebreak \noindent \ignorespaces
  }
  { \par \addvspace { 6pt plus 2pt } }

\NewDocumentCommand \reqsource { m } { \par \noindent \textit{Источник:}~#1 }
\NewDocumentCommand \reqverify { m } { \par \noindent \textit{Способ~проверки:}~#1 }
\NewDocumentCommand \reqnote   { m } { \par \noindent \textit{Комментарий:}~#1 }

% \reqref{SYS_04_02}: ссылка, если требование есть в этом документе, иначе просто ID
\NewDocumentCommand \reqref { m }
  {
    \str_set:Nx \l__tpks_id_str { \tl_trim_spaces:n {#1} }
    \cs_if_exist:cTF { tpks@req@ \l__tpks_id_str }
      { \use:x { \exp_not:N \hyperlink { req: \l__tpks_id_str } { \l__tpks_id_str } } }
      { \l__tpks_id_str }
  }

% --- Глоссарий -------------------------------------------------------------------------
% В glossary.tex: \term{ЕК}{определение}. В документе: \printterms{ЕК, СП} или \printallterms.
\prop_new:N \g__tpks_terms_prop
\seq_new:N \g__tpks_terms_seq
\tl_new:N \l__tpks_def_tl
\NewDocumentCommand \term { m m }
  {
    \prop_if_in:NnT \g__tpks_terms_prop {#1} { \msg_warning:nnn { tpks } { dup-term } {#1} }
    \prop_gput:Nnn \g__tpks_terms_prop {#1} {#2}
    \seq_gput_right:Nn \g__tpks_terms_seq {#1}
  }
\cs_new_protected:Npn \__tpks_print_term:n #1
  {
    \par \noindent \hangindent = \parindent
    \prop_get:NnNTF \g__tpks_terms_prop {#1} \l__tpks_def_tl
      { \textbf{#1}~\textemdash{}~\l__tpks_def_tl }
      { \textbf{#1}~\clarify{нет~в~glossary.tex} \msg_warning:nnn { tpks } { no-term } {#1} }
    \par
  }
\NewDocumentCommand \printterms { m }
  { \par \addvspace{3pt} \clist_map_function:nN {#1} \__tpks_print_term:n \par \addvspace{3pt} }
\NewDocumentCommand \printallterms { }
  { \par \addvspace{3pt} \seq_map_function:NN \g__tpks_terms_seq \__tpks_print_term:n \par \addvspace{3pt} }

% --- Пометки и таблицы -------------------------------------------------------------------
% \clarify{вопрос} → красное [уточнить: вопрос]; \clarify{} → [уточнить]
\NewDocumentCommand \clarify { m }
  { \textcolor{red}{[уточнить \tl_if_blank:nF {#1} { :~#1 } ]} }

% \begin{tabl}{|l|L|}{Подпись}[tab:метка]{заголовок & столбцов} строки \end{tabl}
% Таблица на всю ширину; на следующей странице заголовок столбцов повторяется.
\NewDocumentEnvironment { tabl } { m m o m }
  {
    \xltabular{\textwidth}{#1}
    \caption{#2} \IfValueT {#3} { \label{#3} } \\* \hline #4 \\* \hline \endfirsthead
    \hline #4 \\* \hline \endhead
  }
  { \endxltabular }
\ExplSyntaxOff

% \begin{changelog} \change{версия}{дата}{что изменено}{кто}{основание} \end{changelog}
\newenvironment{changelog}{%
  \section*{Лист регистрации изменений}%
  \addcontentsline{toc}{section}{Лист регистрации изменений}%
  \xltabular{\textwidth}{|c|c|L|P{3.3cm}|P{2.8cm}|}%
  \hline \textbf{Версия} & \textbf{Дата} & \textbf{Что изменено} & \textbf{Кто} & \textbf{Основание} \\ \hline
  \endhead
}{\endxltabular}
\newcommand{\change}[5]{#1 & #2 & #3 & #4 & #5 \\ \hline}

% Данные проекта и команды; читаются после \ExplSyntaxOff, чтобы пробелы не терялись.
\InputIfFileExists{project.tex}{}{\ClassWarning{tpks}{Нет файла docs/project.tex}}

% Глоссарий читается в начале документа, после включения «_ как есть».
\AtBeginDocument{\InputIfFileExists{glossary.tex}{}{\ClassWarning{tpks}{Нет файла docs/glossary.tex}}}
\endinput
