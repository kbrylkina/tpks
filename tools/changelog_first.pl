#!/usr/bin/env perl
# changelog_first.pl — переносит лист регистрации изменений сразу после \makeheader.
#   perl tools/changelog_first.pl < old.tex > new.tex
# Нужен ./build.sh --changes: старая принятая версия документа могла держать лист
# в конце, а сравнивать надо с новым порядком, иначе весь лист выглядит изменённым.
# Если \makeheader нет (старый самодельный заголовок), лист ставится после \begin{document}.
use strict;
use warnings;

local $/;
my $s = <STDIN>;
my $nl = ($s =~ /\r\n/) ? "\r\n" : "\n";
$s =~ s/\r\n/\n/g;

$s =~ s/\\makeheader\*/\\makeheader/g;

if ($s =~ s/(?:^%[^\n]*Лист регистрации[^\n]*\n)?(\\begin\{changelog\}.*?\\end\{changelog\}[^\n]*\n)//ms) {
  my $cl = $1;
  if ($s =~ /^\\makeheader\b[^\n]*\n/m) {
    $s =~ s/^(\\makeheader\b[^\n]*\n)/$1$cl/m;
  } else {
    $s =~ s/^(\\begin\{document\}[^\n]*\n)/$1$cl/m;
  }
}
$s =~ s/\n{3,}(\\end\{document\})/\n\n$1/;

$s =~ s/\n/$nl/g if $nl eq "\r\n";
print $s;
