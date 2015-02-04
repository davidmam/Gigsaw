#!/usr/bin/perl -w
=pod

=head1 seqsim.pl - Simulating Next Gen Sequence Assembly with Scissors and Glue

This script prepares a PDF of sequence reads that are formatted as a Genome jigsaw (Gigsaw). You can print out the reads then attempt to assemble the sequence. This is an ideal training tool for students as it gives them 'hands on' experience with sequence assembly.


The script is configurable, allowing different type of sequencing experiments to be visualised including paired end reads, SNP detection, and errors in the sequence.

=head2 Parameters

=over

=item B<sequence> I<text> The sequence to use as the base for the Gigsaw

=item B<reads> I<integer> The number of reads to obtain.

=item B<pe> I<integer> The size of the gap for paired end reads. 0 gives single end reads.

=item B<seqcolour> I<text> The font colour for the sequence (so you don't mix different experiments). HTML/PDF colour name or #xxyyzz value

=item B<errors> I<integer> The error rate in errors per 1000 bases. Errors are calculated by selecting a random base from the sequence and replacing another random base with it. 

=item B<outfile> I<text> Filename to write the Gigsaw to.

=item B<reference> Print the reference sequence.

=back

=head2 DEPENDENCIES

PDF::API2

All other modules are core perl.

The file Gigsaw_intro.pdf is required and can be customised to give local instructions. The first page of this file is all that is required, subsequent pages are ignored.

=head2 Use as a CGI script

The script should autodetect whether it is being called as a CGI or command line. Just make sure the dependent file Gigsaw_intro.pdf is present.

=head1 CREDITS/ACKNOWLEDGEMENTS

Gigsaw was conceived and written by Dr David Martin at the University of Dundee, Scotland.


=cut

use PDF::API2;
use CGI;
use Getopt::Long;
use strict;
use constant RES => 72/300;
use constant mm => 25.4 / 72;
use constant in => 1 / 72;
use constant pt => 1;
my $cgidir="/homes/www-kegg/httpd/htdocs/gigsaw/";
my $server_url="http://www.compbio.dundee.ac.uk";
my $webdir="/gigsaw/";
my $webserver="";
my $readlen=21;
my $rbh=10;
my $rbw=9;
my $rth=7; # font height for reads in mm.
my $seqfontcolour='black';
my $gigname="My gigsaw";
my $sequence=""; #sequence to generate reads from
my $reads=20; # number of reads to generate - 20 reads per page
my $errors=0; # error rate per 1000 bases.
my $outfile="";
my $pe=0; # gap is zero for single ends, otherwise it is a positive integer and gaps can vary with an SD of 5%.
my $rpp=20; # reads per page.
my $seqgap=2;
my $height=297; #height in mm;
my $width=210; #width in mm
my $reference=0;
my @snps=();
# snp is specified as position:XY where X and Y are the possible nucleotides in their distribution ratio. 
# SNPS are determined prior to error calculation.

#read length is 21 or 10 for each end of a paired end read.
my $is_cgi=0;
if ($ENV{REQUEST_METHOD}){
    my $q=CGI->new();
    $sequence=$q->param("sequence");
    unless ($sequence) {
	# no sequence -> return form.
	print $q->header();
	print $q->start_html(-title=>"The Gigsaw NextGen Sequence Assembly Simulator", -style=>{'src'=>'/gigsaw/styles1.css'},);
	print <<FORM;
	<h1>The Gigsaw NextGen Sequence Assembly Simulator</h1>
	    <div class="bodydiv">
	    Gigsaw is a script that produces a physical model simulation of 
Next Generation Sequencing experiments. These models are ideal for 
teaching and illustratin g the concepts and challenges of Next 
Generation Sequencing. The model is created as PDF which can then be 
printed and cut out. Some examples are on the <a href="/gigsaw/examples.html">examples page</a>. The code for Gigsaw and associated documentation is available on request.
 
</div>
	<div class="formdiv">
	<form method="POST" isindex="">
<table>
	<tbody><tr><td><span class=title>Name</span> for this Gigsaw</td><td><input name="gigname" value="$gigname" size="30" type="text"></td></tr>
	<tr><td><span class=title>Sequence</span> to build a Gigsaw from. Do not make this too long or 
you will get sparse coverage, or a large number of reads to assemble. Maximum length is 1000bp.</td><td><textarea name="sequence" rows="6" cols="70">ACTGACTGGTTGCAATACGGCATCGAGCGGCGGATTATTATATCGATCGATCGACGCGCATGCGATACAGCATGCTCGGCTAATTTCGATGCTAGCTAGCTATA</textarea></td></tr>
	<tr><td><span class=title>Number of reads</span>. All reads are length 21bp</td><td><input name="reads" value="20" size="10" type="text"></td></tr>
	<tr><td><span class=title>Error rate</span> per 1000 bases. Errors are introduced by random sample and replacement.</td><td><input name="errors" value="0" size="10" type="text"></td></tr>
	<tr><td><span class=title>SNPs</span>. Specify as Position:bases with the number of bases 
proprotional to their prevalence. EG C:T at position 20 in a 3:1 ratio 
would be 20:CCCT. Separate SNP definitions with commas and/or spaces.</td><td><input name="snps" size="20" type="text"></td></tr>
	<tr><td><span class=title>Paired end gap size</span>. Paired end reads are 10bp each end with a gap of the specified size +/- 5%</td><td><input name="pe" value="0" size="10" type="text"></td></tr>
	<tr><td><span class=title>Sequence colour</span>. Choose a colour for the reads so different experiments are not mixed </td><td><select name="seqcolour">
<option value="black" selected="selected">Black
</option><option value="#0000CC">Blue
</option><option value="red">Red
</option><option value="#CCCC00">Yellow
</option><option value="#00AA00">Green
</option><option value="#AAAAAA">Grey
</option></select></td></tr>
<tr><td><span class=title>Print reference sequence</span></td><td><input name="reference" option="checked/" type="checkbox"></td></tr>
	<tr><td></td><td><input name="submit" value="Make me a Gigsaw" type="submit"></td></tr>
	

</tbody></table></form></div>
	<div class="footerdiv">
Gigsaw was conceived and created by <a href="mailto:d.m.a.martin\@dundee.ac.uk">Dr David Martin</a> at the University of Dundee.
</div>
<script type="text/javascript">
var gaJsHost = (("https:" == document.location.protocol) ? 
"https://ssl." : "http://www.");
document.write(unescape("%3Cscript src='" + gaJsHost + 
"google‑analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
</script>
<script type="text/javascript">
try{
var pageTracker = _gat._getTracker("UA‑5356328‑1");
pageTracker._trackPageview();
} catch(err) {}
</script>

FORM

	print $q->end_html;
	exit;

    }
    $reads=$q->param("reads");
    $gigname=$q->param("gigname");
    $errors=$q->param("errors");
    my $snps=$q->param("snps");
    $seqfontcolour=$q->param("seqcolour");
    $reference=$q->param("reference");
    @snps=split /[ ,]+/,$snps;
    $pe=$q->param("pe");
    $outfile=$$."_$gigname";
    $outfile =~s/\W/_/g;
    $outfile .=".pdf";
    $webdir.=$outfile;
    $outfile=$cgidir.$outfile;
    $is_cgi=$server_url.$webdir;

    
}else{
GetOptions( "sequence=s"=>\$sequence,
	    "name=s"=>\$gigname,
	    "reads=i"=>\$reads,
	    "errors=i"=>\$errors,
	    "seqcolour=s"=>\$seqfontcolour,
	    "outfile=s"=>\$outfile,
	    "snps=s"=>\@snps,
	    "reference"=>\$reference,
	    "pe=i"=>\$pe
    );
}
@snps=split( /[, ]+/,join( ",",@snps));


$sequence=~s/[^TAGCtagc]//g;

unless ($sequence) {
    die "no valid DNA sequence specified\n";
}
unless ($outfile) {
   $outfile="$gigname";
    $outfile =~s/\W/_/g;
   $outfile .=".pdf";
}
# calculate coverage
$sequence=uc $sequence;
my $cov=$readlen*$reads/length($sequence);
my $intro=PDF::API2->open("Gigsaw_intro.pdf");
my $pdf=PDF::API2->new(-file=>$outfile);
my $page=$pdf->importpage($intro, 1);
my %font = (
    Helvetica => {
	Bold   => $pdf->corefont( 'Helvetica-Bold',    -encoding => 'latin1' ),
	Roman  => $pdf->corefont( 'Helvetica',         -encoding => 'latin1' ),
	Italic => $pdf->corefont( 'Helvetica-Oblique', -encoding => 'latin1' ),
    },
    Times => {
	Bold   => $pdf->corefont( 'Times-Bold',   -encoding => 'latin1' ),
	Roman  => $pdf->corefont( 'Times',        -encoding => 'latin1' ),
	Italic => $pdf->corefont( 'Times-Italic', -encoding => 'latin1' ),
    }
    );
my %h = $pdf->info(
        'Author'       => " David Martin ",
        'CreationDate' => "D:20101025000000+01'00'",
        'ModDate'      => "D:YYYYMMDDhhmmssOHH'mm'",
        'Creator'      => "gigsaw.pl",
        'Producer'     => "PDF::API2",
        'Title'        => "The Genome Jigsaw - $gigname",
        'Subject'      => "Next generation sequence assembly simulation",
        'Keywords'     => "Next generation sequence assembly DNA SNP"
    );
add_footer($page);
#set up background colours.

print STDERR "generating jigsaw with coverage of ".sprintf("%.1f", $cov)."\n";

my $sheetcount=0;
#write instructions.

my $seqcount=0;
my @reads=();
while ($seqcount <$reads) {

    $seqcount++;
    #my $ypos=$seqcount % $rpp; #positon on page for a sequence
    my $sslen=$readlen;
    if ($pe){
	$sslen+= $pe+(gaussian_rand()*int($pe/20));
#	print STDERR "getting read of length $sslen\n";
    }
    my $readpos=int(rand(length($sequence)-$sslen));
    my $readseq=substr($sequence,$readpos, $sslen);
    #add errors
    foreach my $s (@snps){
	my ($spos, $snuc)=split /:/, $s;
	$snuc=~s/[^ACTG]//g;
	if ($spos && $snuc){
	    if ($spos>$readpos && ($spos-$readpos) <= length($readseq)){
		my @b=split //, $snuc;
		substr($readseq,$spos-($readpos+1),1)= $b[int(rand(scalar @b))];
	    }
	}
    }

 #   print STDERR "sequence read - adding read errors\n";
    for (my $e=0; $e<$errors; $e++){
	my $ep=int(rand(1000)); #1 in 1000 chance of substitution, repeated for the n per thousand error rate.
	my $esub=[split //, $sequence]->[int(rand(length($sequence)))]; # sample base randomly from sequence
	if ($ep < length($readseq)){ #if base in range of readseq.
	    substr($readseq, $ep, 1)=$esub;
	}
    }
    if ($pe){
#	print STDERR "getting paired end read\n";
	substr($readseq,int($readlen/2),1+$sslen-$readlen)=" ";
    }
    if (rand()>0.5){
	$readseq=~tr/ACGT/TGCA/; $readseq=join ("", reverse split(//,$readseq));
    }
    push @reads, $readseq;
}

# Page to put all the run parameters on

$page=$pdf->page();
$page->mediabox(int($width/mm), int($height/mm));
add_footer($page);
my $text= $page->text;
# Title
$text->font($font{Helvetica}{Bold}, 18/pt);
$text->translate($width/(2*mm), 260/mm);
$text->fillcolor('#0000AA');
$text->text_center("Gigsaw Parameters for $gigname");

#sequence
$text->font($font{Helvetica}{Bold}, 12/pt);
$text->translate((($width/2)-5)/mm, 240/mm);
$text->fillcolor('#00AA00');
$text->text_right('Sequence Length');
$text->translate((($width/2)+5)/mm, 240/mm);
$text->fillcolor('#808080');
$text->text(length($sequence));

#coverage
$text->font($font{Helvetica}{Bold}, 12/pt);
$text->translate((($width/2)-5)/mm, 220/mm);
$text->fillcolor('#00AA00');
$text->text_right('Coverage');
$text->translate((($width/2)+5)/mm, 220/mm);
$text->fillcolor('#808080');
$text->text(sprintf("%.1f", $cov));

#Errors
$text->font($font{Helvetica}{Bold}, 12/pt);
$text->translate((($width/2)-5)/mm, 200/mm);
$text->fillcolor('#00AA00');
$text->text_right('Error rate');
$text->translate((($width/2)+5)/mm, 200/mm);
$text->fillcolor('#808080');
$text->text("$errors/1000 bases");

#SNPs
$text->font($font{Helvetica}{Bold}, 12/pt);
$text->translate((($width/2)-5)/mm, 180/mm);
$text->fillcolor('#00AA00');
$text->text_right('Polymorphisms');
$text->translate((($width/2)+5)/mm, 180/mm);
$text->fillcolor('#808080');
$text->text("Sequence contains ".(scalar @snps)." polymorphisms");

if ($pe) {
#coverage
$text->font($font{Helvetica}{Bold}, 12/pt);
$text->translate((($width/2)-5)/mm, 160/mm);
$text->fillcolor('#00AA00');
$text->text_right('Paired end library');
$text->translate((($width/2)+5)/mm, 160/mm);
$text->fillcolor('#808080');
$text->text("Gap size is $pe +/- 5%");
}

for (my $r=0; $r<$reads; $r++){

    if ($r % $rpp ==0){
#	print STDERR "Adding new sheet\n";
	$sheetcount++;
	$page=$pdf->page;
	$page->mediabox(int($width/mm), int($height/mm));
	add_footer($page);
	my $title=$page->text();
	$title->font($font{Helvetica}{Roman}, 10/pt);
	$title->translate(int($width/(2*mm)),270/mm);
	$title->fillcolor('black');
	$title->text_center(ucfirst "$gigname sheet $sheetcount reverse reads");
    }
    plotseq($reads[$r], $r, $page);
}

$sheetcount=0;
for (my $r=0; $r<$reads; $r++){
    if ($r % $rpp ==0){
#	print STDERR "Adding new sheet\n";
	$sheetcount++;
	$page=$pdf->page(1+($sheetcount * 2));
	$page->mediabox(int($width/mm), int($height/mm));
	add_footer($page);
	my $title=$page->text();
	$title->font($font{Helvetica}{Roman}, 10/pt);
	$title->translate(int($width/(2*mm)),270/mm);
	$title->fillcolor('black');
	$title->text_center(ucfirst "$gigname sheet $sheetcount forward reads");
    }
    my $readseq=$reads[$r];
    $readseq=~tr/ACGT/TGCA/;
    $readseq=join("", reverse split( //,$readseq));
    plotseq($readseq, $r, $page);
}

if ($reference){
    my $sl=int(length($sequence)/($readlen-1));
    my $cr=0;
    while ($cr<$sl){
	if ($cr % ($rpp/2) ==0){
	    $page=$pdf->page;
	    $page->mediabox(int($width/mm), int($height/mm));
	    add_footer($page);
	    my $title=$page->text();
	    $title->font($font{Helvetica}{Roman}, 10/pt);
	    $title->translate(int($width/(2*mm)),270/mm);
	    $title->fillcolor('black');
	    $title->text_center(ucfirst "$gigname sheet $sheetcount forward reference sequence");
	}
	my $seq=substr($sequence, $cr*20, 21);
	if ($cr) {
	    substr($seq, 0,1)="X";
	}
	plotref($seq, $cr, $page);
	$cr++;
    }
    if ($cr % ($rpp/2) ==0){
	$page=$pdf->page;
	$page->mediabox(int($width/mm), int($height/mm));
	add_footer($page);
	my $title=$page->text();
	$title->font($font{Helvetica}{Roman}, 10/pt);
	$title->translate(int($width/(2*mm)),270/mm);
	$title->fillcolor('black');
	$title->text_center(ucfirst "$gigname sheet $sheetcount forward reference sequence");
    }
    my $seq=substr(substr($sequence, $cr*20)."                     ",0,21);
    if ($cr) {
	substr($seq, 0,1)="X";
    }
    plotref($seq, $cr, $page);
    $cr=0;
    while ($cr<$sl){
	if ($cr % ($rpp/2) ==0){
	    $page=$pdf->page;
	    $page->mediabox(int($width/mm), int($height/mm));
	    add_footer($page);
	    my $title=$page->text();
	    $title->font($font{Helvetica}{Roman}, 10/pt);
	    $title->translate(int($width/(2*mm)),270/mm);
	    $title->fillcolor('black');
	    $title->text_center(ucfirst "$gigname sheet $sheetcount reverse reference sequence");
	}
	my $rseq=substr($sequence, $cr*20, 21);
	$rseq=~tr/ACGT/TGCA/;
	substr($rseq, 20, 1)="X";
	plotref(join("", reverse split(//, $rseq)), $cr, $page,1);
	$cr++;
    }
    if ($cr % ($rpp/2) ==0){
	$page=$pdf->page;
	$page->mediabox(int($width/mm), int($height/mm));
	add_footer($page);
	my $title=$page->text();
	$title->font($font{Helvetica}{Roman}, 10/pt);
	$title->translate(int($width/(2*mm)),270/mm);
	$title->fillcolor('black');
	$title->text_center(ucfirst "$gigname sheet $sheetcount reverse reference sequence");
    }
    my $rseq=substr(substr($sequence, $cr*20)."                     ",0,21);
    $rseq=~tr/ACGT/TGCA/;
    plotref(join("", reverse split(//, $rseq)), $cr, $page,1);  
# print sequence at 20 bases per strip plus one overlap.

}

    $pdf->save;
if ($is_cgi){
#redirect output to PDF location.

   print CGI->redirect($is_cgi);

}
$pdf->end();

sub add_footer {
    my ($page)=@_;
    my $foot=$page->text;
    $foot->font($font{Helvetica}{Roman}, 11/pt);
    $foot->translate($width/(2*mm), 15/mm);
    $foot->text_center("Gigsaw created by Dr David Martin, University of Dundee, Scotland");
}

sub plotref {
    my ($seq, $sc,$page, $rev)=@_;
 #   print STDERR "plotting read $sc $seq\n";
    my $pos=2*($sc % ($rpp/2));
    my @bases= split//, uc $seq;
    my $fg=$page->gfx;
    my $ft=$page->text;
    $ft->strokecolor('black');
    my %basecol=(G=>'#1E90FF',C=>'#FFD700',A=>'#FF6347',T=>"#00FF7F",X=>"#AAAAAA");
    my $ypos=30+$pos*($rbh+$seqgap);
    my $ypost=$ypos+$rbh+$seqgap;
    my $ymar=($width-($readlen*$rbw))/2;
    for (my $b=0;$b< scalar @bases; $b++){
	
#	print STDERR "plotting base $b of read\n"; 
	my $xpos=$ymar+($rbw*$b);
	#draw box. #draw character.
	$fg->strokecolor('black');
#	$fg->linewidth(0.5/mm);
	if (exists($basecol{$bases[$b]})){ # not a space for the end of the sequence
	    $ft->fillcolor($seqfontcolour);
	   # print STDERR "basecolour is $basecol{$bases[$b]} xpos $xpos ypos $ypos\n"; 
	    $fg->fillcolor($basecol{$bases[$b]});
	    $fg->rect($xpos/mm, $ypos/mm, $rbw/mm, $rbh/mm);
	    $fg->fill;
	    $fg->rect($xpos/mm, $ypos/mm, $rbw/mm, $rbh/mm);
	    $fg->stroke;
	    $ft->font($font{Helvetica}{Bold}, $rth/mm);
	    $ft->translate(($xpos+$rbw/2)/mm, ($ypos+($rbh-$rth)/2 + 1)/mm);
	    $ft->text_center($bases[$b]);
	    # need to calculate this properly.
	    my $basenum=1+$sc*20+$b;
	    if ($rev) {
		$basenum=1+length($sequence)-($sc*20+(scalar @bases) -$b);
	    }
	    if ($b && $basenum % 10 == 0 || $basenum== length($sequence) || $basenum==1){
		$ft->font($font{Helvetica}{Bold}, $rth/(2*mm));
		$ft->translate(($xpos+$rbw/2)/mm, ($ypost+1)/mm);
		$ft->text_center($basenum);
	    }		
	}
    }
    #finish objects.
    #$pdf->finishobjects($fg, $ft);

}

sub plotseq {
    my ($seq, $sc,$page)=@_;
 #   print STDERR "plotting read $sc $seq\n";
    my $pos=$sc % $rpp;
    my @bases= split//, uc $seq;
    my $fg=$page->gfx;
    my $ft=$page->text;
    $ft->strokecolor('black');
    my %basecol=(G=>'#1E90FF',C=>'#FFD700',A=>'#FF6347',T=>"#00FF7F");
    my $ypos=30+$pos*($rbh+$seqgap);
    my $ymar=($width-($readlen*$rbw))/2;
    for (my $b=0;$b< scalar @bases; $b++){
#	print STDERR "plotting base $b of read\n"; 
	my $xpos=$ymar+($rbw*$b);
	#draw box. #draw character.
	$fg->strokecolor('black');
#	$fg->linewidth(0.5/mm);
	if (exists($basecol{$bases[$b]})){ # not a space for paired end sequencing
	    $ft->fillcolor($seqfontcolour);
	   # print STDERR "basecolour is $basecol{$bases[$b]} xpos $xpos ypos $ypos\n"; 
	    $fg->fillcolor($basecol{$bases[$b]});
	    $fg->rect($xpos/mm, $ypos/mm, $rbw/mm, $rbh/mm);
	    $fg->fill;
	    $fg->rect($xpos/mm, $ypos/mm, $rbw/mm, $rbh/mm);
	    $fg->stroke;
	    $ft->font($font{Helvetica}{Bold}, $rth/mm);
	    $ft->translate(($xpos+$rbw/2)/mm, ($ypos+($rbh-$rth)/2 + 1)/mm);
	    $ft->text_center($bases[$b]);
	}else { # is the join in a paired end sequence.
	    #draw white rectangles
	    $ft->fillcolor('black');
	    $fg->fillcolor('white');
	    $fg->rect($xpos/mm, $ypos/mm, $rbw/mm, $rbh/mm);
	    $fg->fill;
#	    $fg->rect($xpos/mm, $ypos/mm, $rbw/mm, $rbh/mm);
	    $fg->move($xpos/mm, $ypos/mm);
	    $fg->line(($xpos+$rbw)/mm, ($ypos+$rbh)/mm);
	    $fg->stroke;
	    $fg->move(($xpos+$rbw)/mm, $ypos/mm);
	    $fg->line($xpos/mm, ($ypos+$rbh)/mm);
	    $fg->stroke;
	    #draw midline
	    #put read label on each segment
	    $ft->font($font{Helvetica}{Roman},(($rbh-4)/2)/mm);
	    $ft->transform(-translate=>[($ymar-2)/mm, ($ypos+($rbh/2))/mm], 
			   -rotate=>90
		);
	    $ft->text_center("[$sc]");
	    $ft->transform(-translate=>[(2+$width-$ymar)/mm, ($ypos+($rbh/2))/mm], 
			   -rotate=>270
		);
	    $ft->text_center("[$sc]");
	}
    }
    #finish objects.
    #$pdf->finishobjects($fg, $ft);

}



sub gaussian_rand {
    my ($u1, $u2);  # uniformly distributed random numbers
    my $w;          # variance, then a weight
    my ($g1, $g2);  # gaussian-distributed numbers

    do {
        $u1 = 2 * rand() - 1;
        $u2 = 2 * rand() - 1;
        $w = $u1*$u1 + $u2*$u2;
    } while ( $w >= 1 );

    $w = sqrt( (-2 * log($w))  / $w );
    $g2 = $u1 * $w;
    $g1 = $u2 * $w;
    # return both if wanted, else just one
    return wantarray ? ($g1, $g2) : $g1;
}
