#!/usr/bin/perl -w
use lib qw!/sw/lib/perl/arch!;
use CGI;
use GD;
my $q=new CGI;

my @colours = qw/red green blue yellow magenta cyan /;
if ($ENV{REQUEST_METHOD} eq 'POST'){
    $imagefile=$q->param('image');

    next unless $imagefile;
    $lines=$q->param('lines');
    next unless $lines;
    $points=$q->param('points');
    $colselect=$q->param('colour');
    $gridon=$q->param('gridon');
    $gridsize=$q->param('gridsize');

    my $image=GD::Image->new($imagefile);
    $tmp=$image->colorAllocate(255,0,0);
    if ($tmp==-1){
	$image->colorDeallocate($image->colorClosest(255,0,0));
	$image->colorDeallocate($image->colorClosest(0,255,0));
	$image->colorDeallocate($image->colorClosest(0,0,255));
	$image->colorDeallocate($image->colorClosest(255,255,0));
	$image->colorDeallocate($image->colorClosest(255,0,255));
	$image->colorDeallocate($image->colorClosest(0,255,255));
	$tmp=$image->colorAllocate(255,0,0);
    }	   
    @cols=($tmp,
	   $image->colorAllocate(0,255,0),
	   $image->colorAllocate(0,0,255),
	   $image->colorAllocate(255,255,0),
	   $image->colorAllocate(255,0,255),
	   $image->colorAllocate(0,255,255)
	   );
    
    my ($xsize, $ysize)=$image->getBounds();

    print STDERR "Bounds $xsize,$ysize\n";
    my $xtot=0;    
    my $ytot=0;    
    my $degtot=0;
    for (my $l=0; $l<$lines; $l++) {
	my $xp1=0;
	my $yp1=0;
	my $xp2=0;
	my $yp2=0;
	my $xp= getrand($xsize);
	my $yp= getrand($ysize);
	
	$ytot += $yp;
	$xtot += $xp;
	if ($points eq 'lines'){

	    my $angle=3.14159*getrand(180)/180;
	    #my $angle=3.14159*45/180;
	    my $deg=$angle*180/3.14159;
	    $degtot +=$deg;
	    #draw lines.
	    #calculate hypothetical end points along x axis.
	    
	    my $dx=$xp;
	    if (sin($angle)==0) {
		$xp1=$xp2=$xp;
		$yp1=0;
		$yp2=$ysize;
	    } else {
		my $grad=cos($angle)/sin($angle);
		my $dy= $grad*$dx;
		my $con= $yp-$dy;
		
	#	print STDERR "$angle $deg dx $dx dy $dy grad $grad con $con\n";
		
		$xp1=getx(0,$grad,$con);
		
	#	print STDERR "X1 at Y1=0 $xp1\n";
		if ($xp1 >0 && $xp1 <$xsize) {
		    $yp1=0;
		}elsif ($xp1 >$xsize) {
		    $yp1=gety($xsize, $grad, $con);
	#	    print STDERR "Y1 at X1=$xsize $yp1\n";
		    $xp1 =$xsize;
		} else { 
		    $yp1=gety(0, $grad,$con);
	#	    print STDERR "Y1 at X1=0 $yp1\n";
		    $xp1=0;
		}
		$xp2=getx($ysize,$grad,$con);
	#	print STDERR "X2 at Y2=0 $xp2\n";
		if ($xp2 >0 && $xp2 <$xsize) {
		    $yp2=$ysize;
		}elsif ($xp2 >$xsize) {
		    $yp2=gety($xsize, $grad, $con);
	#	    print STDERR "Y2 at X2=$xsize $yp2\n";
		    $xp2=$xsize;
		} else {
		    $yp2=gety(0, $grad,$con);
	#	    print STDERR "Y2 at X2=0 $yp2\n";
		    $xp2=0;
		}
		
	    }
	    
	    if ($colselect>=0 && $colselect<6){
		$colour=$cols[int($colselect)];
	    }else{
		$colour=$cols[int(rand(600))%6];
	    }
	    print STDERR "colour selected is $colour \n";
	    $image->line($xp1,$yp1,$xp2,$yp2,$colour);
	#    print STDERR "YP:$yp XP:$xp A:$angle D:$deg YP1:$yp1 XP1:$xp1 YP2:$yp2 XP2:$xp2\n";
	#} else {
	}	
	$yp1= $yp-10;
	$yp1=$yp1<0?0:$yp1;
	$yp2= $yp+10;
	$yp2=$yp2>$ysize?$ysize:$yp2;
	$xp1= $xp-10;
	$xp1=$xp1<0?0:$xp1;
	$xp2= $xp+10;
	$xp2=$xp2>$xsize?$xsize:$xp2;
	if ($colselect>=0 && $colselect<6){
	    $colour=$cols[(int($colselect)+1)%6];
	}else{
	    $colour=$cols[int(rand(600))%6];
	}
	    print STDERR "point colour selected is $colour \n";
	$image->line($xp1,$yp,$xp2,$yp,$colour);
	$image->line($xp,$yp1,$xp,$yp2,$colour);
	
    }
    if ($gridon){
	if ($gridsize < $xsize && $gridsize < $ysize){
	    $gridstart=int(rand($gridsize));
	    $colour=0;
	    for (my $x=$gridstart; $x<$xsize; $x+=$gridsize){
		if ($colselect>=0 && $colselect<6){
		    $colour=$cols[(int($colselect)+2)%6];
		}else{
		    $colour=$cols[int(rand(600))%6];
		}
		$image->line($x,0,$x,$ysize,$colour);
	    }
	    $gridstart=int(rand($gridsize));
	    for (my $y=$gridstart; $y<$ysize; $y+=$gridsize){
		if ($colselect>=0 && $colselect<6){
		    $colour=$cols[(int($colselect)+2)%6];
		}else{
		    $colour=$cols[int(rand(600))%6];
		}
		$image->line(0,$y,$xsize,$y,$colour);
	    }
	}
    }
    $xtot /=$lines;
    $ytot /=$lines;
    $degtot /=$lines;
    $xtot=int($xtot);
    $ytot=int($ytot);
    $degtot=int($degtot);

    print STDERR "Random $xtot, $ytot, $degtot\n";
    

    print $q->header("image/png");
    print $image->png();
    
} else {

    print $q->header();
    print $q->start_html();
    print $q->start_multipart_form(-method=>"POST");
    print $q->filefield(-name=>'image');
    print "<br>Number of random <select name=\"points\">\n<option value=\"lines\">lines\n<option value=\"points\">points\n</select><input type=text size=\"6\" name=\"lines\"><br/>\n";
    print "Colour <select name=\"colour\"><option value=0>red\n<option value=1>green\n<option value=2>blue\n<option value=3>yellow\n<option value=4>magenta\n<option value=5>cyan\n<option value=-1>random\n</select><br>\n";
    print "Show grid <input type=checkbox name=gridon checked> size (pixels) <input type=text value=0 name=gridsize><br>\n";
    print $q->submit();
    print $q->endform;
    print $q->end_html;
#do form.
}

sub getx {
    my ($y,$m,$c) = @_;
    my $x=($y-$c)/$m;
    return $x;
}

sub gety {
    my ($x,$m,$c) = @_;
    my $y=($x*$m) + $c;
    return $y;
}


sub getrand {
    my $val=shift;
    my $rv = int(rand($val));

    if (int(rand(99))%2){
	$rv=$val-$rv;
    }
    return $rv;
}
