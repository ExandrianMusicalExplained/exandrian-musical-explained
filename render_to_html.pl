#!/usr/bin/env perl
use strict;
use warnings;
use Encode::Simple qw(encode decode);
use Markdent::Simple::Fragment;
use Mojo::DOM;
use Mojo::File 'path';
use Mojo::Template;
use Scalar::Util 'weaken';

my $home = path(__FILE__)->to_abs->dirname;
my $source_dir = $home->child('source');
die "No sources found in $source_dir\n" unless -d $source_dir->child('songs') and my @sources = $source_dir->child('songs')->list->sort->each;
my $template_dir = $home->child('templates');
my $public_dir = $home->child('docs');
$public_dir->child('songs')->make_path;

my $mds = Markdent::Simple::Fragment->new;

my @songs;
my $prev_song;
foreach my $source (@sources) {
  my $html = $mds->markdown_to_html(markdown => decode('UTF-8', $source->slurp));
  chomp(my $name = Mojo::DOM->new($html)->at('h2')->all_text =~ s/^\s*\d+\s*-\s*//r);
  my $slug = $source->basename =~ s/[^.]*\K.*//r;
  my %song = (name => $name, slug => $slug, content => $html);
  weaken($song{previous} = $prev_song);
  weaken($songs[-1]{next} = \%song) if @songs;
  push @songs, $prev_song = \%song;
}

my $mt = Mojo::Template->new(vars => 1, auto_escape => 1);
my $layout = $template_dir->child('layouts', 'main.html.ep');

foreach my $song (@songs) {
  my $content = $mt->render_file($template_dir->child('song.html.ep'), {content => $song->{content}, previous => $song->{previous}, next => $song->{next}});
  my $output = $mt->render_file($layout, {title => $song->{name}, content => $content, in_subdir => 1});
  $public_dir->child('songs', "$song->{slug}.html")->spurt(encode 'UTF-8', $output);
}

my $content = $mt->render_file($template_dir->child('songs.html.ep'), {songs => \@songs});
my $output = $mt->render_file($layout, {title => 'Vox Machina', content => $content, in_subdir => 0});
$public_dir->child('songs.html')->spurt(encode 'UTF-8', $output);

my $html = $mds->markdown_to_html(markdown => decode('UTF-8', $source_dir->child('index.md')->slurp));
$content = $mt->render_file($template_dir->child('index.html.ep'), {content => $html, songs => \@songs});
$output = $mt->render_file($layout, {title => 'Vox Machina', content => $content, in_subdir => 0});
$public_dir->child('index.html')->spurt(encode 'UTF-8', $output);

print "Rendered songs from $source_dir to $public_dir\n";
