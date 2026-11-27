#!/usr/bin/env perl
# check_ids.pl — проверка идентификации требований (раздел «Идентификация» в docs/00_checklist.tex).
#   ./build.sh --check            (или: perl tools/check_ids.pl из корня репозитория)
# Коды [И1]…[И14] совпадают с пунктами чек-листа. Ошибки — код выхода 1.
use strict;
use warnings;
use File::Basename qw(dirname);
use Cwd qw(abs_path);

my $root = abs_path(dirname(abs_path($0)) . '/..');
chdir "$root/docs" or die "нет каталога docs: $!";

my ($errors, $warnings) = (0, 0);
sub err  { print "ОШИБКА   $_[0]\n"; $errors++ }
sub warn_ { print "ВНИМАНИЕ $_[0]\n"; $warnings++ }

sub slurp { my $f = shift; local $/; open my $h, '<', $f or return undef; my $s = <$h>; $s =~ s/\r//g; $s }

# Разбор требований документа: id, версия, тело, порядок, раздел.
sub parse_reqs {
  my ($text) = @_;
  $text =~ s/\\begin\{verbatim\}.*?\\end\{verbatim\}//gs;   # образцы исходного кода — не объявления
  my @reqs;
  while ($text =~ /\\begin\{req\}\{([^}]*)\}\{([^}]*)\}(.*?)\\end\{req\}/gs) {
    my ($id, $ver, $body) = ($1, $2, $3);
    $id =~ s/^\s+|\s+$//g; $ver =~ s/^\s+|\s+$//g;
    push @reqs, { id => $id, ver => $ver, body => $body };
  }
  return @reqs;
}
# Поле draft=[…] отменено 20.11.2026 (ссылка на внутренний черновик): его удаление не считается
# изменением требования.
sub norm { my $s = shift; $s =~ s/%[^\n]*//g; $s =~ s/;\s*draft=\[[^\]]*\]//g; $s =~ s/\s+/ /g; $s =~ s/^ | $//g; $s }

my @docs = glob('0[1-9]_*.tex');
# Документ-владелец префикса — тот, где требований с этим префиксом больше всего
# (SYS — «Системные требования», SRD — «Требования к ПО»); его объявления разбираются первыми,
# а в остальных документах те же ID считаются цитатами.
my %cnt;
for my $f (@docs) { my $t = slurp($f); $t =~ s/\\begin\{verbatim\}.*?\\end\{verbatim\}//gs; $cnt{$f}{$1}++ while $t =~ /\\begin\{req\}\{\s*(SYS|SRD)_/g }
my %rank;
for my $p ('SYS', 'SRD') { my ($best) = sort { ($cnt{$b}{$p} // 0) <=> ($cnt{$a}{$p} // 0) } @docs; $rank{$best} = 1 if $best && $cnt{$best}{$p} }
@docs = sort { ($rank{$b} // 0) <=> ($rank{$a} // 0) or $a cmp $b } @docs;
my (%doc_reqs, %where, %all_ids);
for my $f (@docs) {
  my $t = slurp($f);
  my @r = parse_reqs($t);
  next unless @r;
  $doc_reqs{$f} = { text => $t, reqs => \@r };
  for my $q (@r) {
    my $id = $q->{id};
    # [И2] одно требование в двух документах: допустимо как цитата, но текст и версия совпадают
    if (my $o = $all_ids{$id}) {
      next if $where{$id} eq $f;
      err("[И2] $id объявлен в $where{$id} и в $f с разным текстом или версией — один ID обозначает одно требование")
        if norm($o->{body}) ne norm($q->{body}) || $o->{ver} ne $q->{ver};
      next;
    }
    $where{$id} = $f; $all_ids{$id} = $q;
  }
}

for my $f (sort keys %doc_reqs) {
  my @r = @{ $doc_reqs{$f}{reqs} };
  my $t = $doc_reqs{$f}{text};
  my (%seen, %byfn, $prev);
  for my $q (@r) {
    my $id = $q->{id};
    # [И1] формат
    err("[И1] $f: идентификатор «$id» не по схеме SYS_ФФ_НН или SRD_ФФ_НН") unless $id =~ /^(SYS|SRD)_\d\d_\d\d$/;
    # [И2] уникальность
    err("[И2] $f: идентификатор $id объявлен повторно") if $seen{$id}++;
    # [И3] версия — целое число от 1
    err("[И3] $f: у $id версия «$q->{ver}», нужно целое число от 1") unless $q->{ver} =~ /^[1-9]\d*$/;
    next unless ($where{$id} // '') eq $f;   # цитата требования из другого документа: порядок и нумерацию не проверяем
    # [И4] порядок объявления
    err("[И4] $f: $id объявлен после $prev — идентификаторы объявляются по возрастанию") if defined $prev && $id lt $prev;
    $prev = $id;
    push @{ $byfn{$1} }, $2 + 0 if $id =~ /_(\d\d)_(\d\d)$/;
  }
  # [И5] нумерация внутри функции с 01 без пропусков
  for my $fn (sort keys %byfn) {
    my %n = map { $_ => 1 } @{ $byfn{$fn} };
    my ($max) = sort { $b <=> $a } keys %n;
    my @gaps = grep { !$n{$_} } 1 .. $max;
    warn_("[И5] $f: в функции $fn пропущены номера " . join(', ', map { sprintf '%02d', $_ } @gaps)
          . " (допустимо, только если требования удалены и это записано в листе регистрации)") if @gaps;
  }
  # [И13] ссылки \reqref на существующие требования
  for my $ref ($t =~ /\\reqref\{([^}]*)\}/g) {
    err("[И13] $f: \\reqref{$ref} — такого требования нет ни в одном документе") unless $all_ids{$ref};
  }
  for my $ref ($t =~ /\b((?:SYS|SRD)_\d\d_\d\d)\b/g) {
    warn_("[И13] $f: в тексте упомянут $ref, такого требования нет") unless $all_ids{$ref};
  }
}

# Связи требований к ПО с системными требованиями
my @sys = grep { /^SYS_/ } keys %all_ids;
my @srd = grep { /^SRD_/ } keys %all_ids;
my (%covered, %fromsrc);
for my $id (sort @srd) {
  my $q = $all_ids{$id};
  my ($src) = $q->{body} =~ /\\reqsource\{(.*?)\}\s*(?:\\req|$)/s;
  $src //= '';
  if ($src =~ /derived=\[yes\]/) {
    # [И11] производные помечены и обоснованы
    err("[И11] $id: производное требование без комментария с обоснованием") unless $q->{body} =~ /\\reqnote\{/;
    next;
  }
  my ($list) = $src =~ /parent=\[([^\]]*)\]/;
  unless (defined $list) { err("[И8] $id: в источнике нет parent=[…] и нет derived=[yes]"); next }
  my @p = grep { length } map { s/\s//gr } split /,/, $list;
  my ($fn) = $id =~ /_(\d\d)_/;
  my $samefn = 0;
  for my $p (@p) {
    # [И8] родитель существует
    if (!$all_ids{$p} || $p !~ /^SYS_/) { err("[И8] $id: родитель $p не найден среди системных требований"); next }
    $covered{$p}++; $fromsrc{$p}{$id} = 1;
    $samefn = 1 if $p =~ /^SYS_${fn}_/;
  }
  # [И7] номер функции совпадает с функцией родителя
  warn_("[И7] $id: ни один родитель (@p) не относится к функции $fn") if @p && !$samefn;
}
# [И9] покрытие
if (@srd) {
  for my $s (sort @sys) { err("[И9] $s: не покрыто ни одним требованием к ПО") unless $covered{$s} }
}

# [И10] матрица трассировки совпадает с источниками; [И12] сводная таблица идентификаторов
for my $f (sort keys %doc_reqs) {
  my $t = $doc_reqs{$f}{text};
  if (my ($tab) = $t =~ /\[tab:trace\](.*?)\\end\{tabl\}/s) {
    my %mx;
    for my $line (split /\n/, $tab) {
      next unless $line =~ /&/;
      my ($a, $b) = split /&/, $line, 2;
      my ($s) = $a =~ /(SYS_\d\d_\d\d)/ or next;
      $mx{$s}{$_} = 1 for $b =~ /(SRD_\d\d_\d\d)/g;
    }
    my %keys = (%mx, %fromsrc);
    for my $s (sort keys %keys) {
      my $x = join ', ', sort keys %{ $fromsrc{$s} || {} };
      my $y = join ', ', sort keys %{ $mx{$s} || {} };
      err("[И10] $f: матрица трассировки, $s: в матрице [$y], по источникам [$x]") if $x ne $y;
    }
  }
  if (my ($tab) = $t =~ /\[tab:ids\](.*?)\\end\{tabl\}/s) {
    my (%inrange, %sysrow, $total);
    for my $line (split /\n/, $tab) {
      next unless $line =~ /^\s*(\d\d)\s*&[^&]*&\s*(SRD_\d\d_\d\d)\s*-+\s*(SRD_\d\d_\d\d)\s*&\s*(\d+)\s*&\s*(\d*)/;
      my ($fn, $from, $to, $cnt, $sysn) = ($1, $2, $3, $4, $5);
      my @ids = grep { $_ ge $from && $_ le $to } grep { /^SRD_/ } keys %all_ids;
      err("[И12] $f: сводная таблица, $from -- $to: указано $cnt, фактически " . scalar(@ids)) if @ids != $cnt;
      err("[И12] $f: сводная таблица, $from или $to не существует") unless $all_ids{$from} && $all_ids{$to};
      $inrange{$_}++ for @ids;
      $sysrow{$fn} += $sysn if length $sysn;
    }
    for my $id (sort @srd) { err("[И12] $f: $id не попал ни в одну строку сводной таблицы") unless $inrange{$id} }
    for my $fn (sort keys %sysrow) {
      my $n = grep { /^SYS_${fn}_/ } @sys;
      err("[И12] $f: сводная таблица, функция $fn: SYS указано $sysrow{$fn}, фактически $n") if $n != $sysrow{$fn};
    }
  }
}

# [И6] сверка с принятой версией из docs/accepted.txt: ID не исчезают, изменённый текст — новая версия
if (open my $acc, '<', 'accepted.txt') {
  while (my $line = <$acc>) {
    next if $line =~ /^\s*(#|$)/;
    my ($name, $commit, $ver) = split ' ', $line;
    next unless $doc_reqs{"$name.tex"};
    my $old = `git -C "$root" show "$commit:docs/$name.tex" 2>/dev/null`;
    unless ($old) { warn_("[И6] $name: не удалось взять принятую версию $commit из git"); next }
    $old =~ s/\r//g;
    my %new = map { $_->{id} => $_ } @{ $doc_reqs{"$name.tex"}{reqs} };
    for my $o (parse_reqs($old)) {
      my $n = $new{ $o->{id} };
      next if !$n && $all_ids{ $o->{id} } && $where{ $o->{id} } ne "$name.tex";   # была цитата из другого документа
      unless ($n) { warn_("[И6] $name: требование $o->{id} из принятой версии удалено — его ID нельзя использовать повторно"); next }
      if (norm($o->{body}) ne norm($n->{body}) && $n->{ver} <= $o->{ver}) {
        err("[И6] $name: текст $o->{id} изменён после принятой версии, а версия осталась #$n->{ver} — нужно #" . ($o->{ver} + 1));
      }
      if ($n->{ver} < $o->{ver}) { err("[И6] $name: версия $o->{id} уменьшилась: #$o->{ver} → #$n->{ver}") }
    }
  }
}

my $nsys = @sys; my $nsrd = @srd;
print "Проверено: $nsys SYS, $nsrd SRD. Ошибок: $errors, предупреждений: $warnings.\n";
exit($errors ? 1 : 0);
