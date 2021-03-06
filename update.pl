#!/usr/bin/perl

use strict;
use warnings;
use LWP::Simple qw(mirror);
use RDF::NS;
use File::Temp;

# get current version distribution
my $dist = do { local( @ARGV, $/ ) = 'dist.ini'; <> };
my $cur_version = $1 if $dist =~ /^\s*version\s*=\s*([^\s]+)/m;
$cur_version or die 'current version not found in dist.ini';

# get current prefixes
my $cur = RDF::NS->LOAD( "share/prefix.cc", warn => 1 );
die "share/prefix.cc is empty" unless %$cur;

# get new current datestamp
my @t = gmtime;
my $new_version = sprintf '%4d%02d%02d', $t[5]+1900, $t[4]+1, $t[3];
die "$new_version is not new" if $new_version eq $cur_version;

# download new prefixes
my $tmp = File::Temp->new->filename;
my $url = "http://prefix.cc/popular/all.file.txt";
mirror($url,$tmp) or die "Failed to load $url";
my $new = RDF::NS->LOAD( $tmp, warn => 1 );

my $diff = $new->UPDATE( "share/prefix.cc", $new_version );

foreach my $change (qw(create delete update)) {
    my $prefixes = $diff->{$change} or next;
    foreach my $prefix (@$prefixes) {
        if ($change eq 'create') {
            printf "+ $prefix %s\n", $new->URI($prefix);
        } elsif ($change eq 'delete') {
            printf "- $prefix %s\n", $cur->URI($prefix);
        } else {
            printf "- $prefix %s\n", $cur->URI($prefix);
            printf "+ $prefix %s\n", $new->URI($prefix);
        }
    }
}

my (@log) = "$new_version (" . $new->COUNT . " prefixes)"; 

push @log, "  added: " . join(",",@{$diff->{create}}) if @{$diff->{create}};
push @log, "  removed: " . join(",",@{$diff->{delete}}) if @{$diff->{delete}};
push @log, "  changed: " . join(",",@{$diff->{update}}) if @{$diff->{update}};

foreach my $file (qw(dist.ini lib/RDF/NS.pm lib/RDF/NS/Trine.pm lib/RDF/NS/URIS.pm README)) {
    print "$cur_version => $new_version in $file\n";
    local ($^I,@ARGV)=('.bak',$file);
    while(<>) {
        s/$cur_version/$new_version/ig;
        print;
    }
}
do {
    print "prepend modifications to Changes\n"; 
    local ($^I,@ARGV)=('.bak','Changes');
    my $line=0;
    while (<>) {
        if (!$line++) {
            print join '', map { "$_\n" } @log;
        }
        print; 
    } 
};

print <<HELP;
To store and release the changes, call:
 
  git add Changes README dist.ini lib/RDF/NS.pm lib/RDF/NS/Trine.pm share/prefix.cc
  git commit -m "update to $new_version"
  git tag $new_version
  dzil release

HELP

1;
