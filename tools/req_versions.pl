#!/usr/bin/env perl
# req_versions.pl — собирает версии требований из документов для ссылок вида «SYS_01_01; #1».
#   perl tools/req_versions.pl docs/0*.tex > docs/build/req_versions.tex
# ./build.sh запускает его сам перед сборкой; шаблон читает результат (\tpksreqversion).
use strict;
use warnings;

for my $file (@ARGV) {
  open my $fh, '<', $file or die "$file: $!";
  while (my $line = <$fh>) {
    while ($line =~ /\\begin\{req\}\{\s*((?:SYS|SRD)_\d\d_\d\d)\s*\}\{\s*(\d+)\s*\}/g) {
      print "\\tpksreqversion{$1}{$2}\n";
    }
  }
  close $fh;
}
