#!/usr/bin/env perl
use strict;
use warnings;


#-------------------------CONFIG--------------------#

# file that contains league scoring information
my $scoringFile='MillarScoring.txt';

# file containing text copied from league page of all teams roster after non-keepers have been dropped 
my $keepFile='Millar_kept_2021.txt';

# file containing text copied from league page of all teams rosters from last year 
my $preDropFile='Millar_AllTeamLineup_end2020.txt';

# file containin list of players that have already been drafted.
my $draftedFile='drafted_millar.txt';

# list of years to look back at stats
my @YEARS=(2020,2019,2018,2017,2016);

# weighting for previous year stats 
my @WEIGHTS=(0.4*(162/60),0.4,0.1,0.1);

# display this many top players
my $nplayers=15;

#--------------------END CONFIG---------------------#


print "What Postion (C,1B,2B,3B,SS,OF,DH,U,all)?\n";
my $pos=<>;
chomp $pos;
$pos=uc($pos);

print "\n       D I L L G O R I T H M";
print "\n       ~~~~~~~~~~~~~~~~~~~~~";
print "\n          Millar Batters\n";


my %batScoring;
my %pitchScoring;


# read the scoring
open IN, "<$scoringFile";

while (<IN>){
   chomp;
   if ($_ =~ m/BATTING/){
      while (<IN>){
          chomp;
          last if $_=~ m/END/;
          $_ =~ s/^\s+//;
          my ($key,$val)=split('\s+',$_);
          $batScoring{$key}=$val;
          #print "scoring $key is $val points\n";
      }   
   }   
   if ($_ =~ m/PITCHING/){
      while (<IN>){
          chomp;
          last if $_=~ m/END/;
          $_ =~ s/^\s+//;
          my ($key,$val)=split('\s+',$_);
          $pitchScoring{$key}=$val;
          #print "scoring $key is $val points\n";
      }   
   }   

}
close (IN);


# read the stats and calc points


my %scores;
my %perGameScores;
my %nGames;
my %position;

foreach my $year (@YEARS){
   my $dir="$year-stats";

   # this is a loop over players below
   open IN, "<$dir/mlb-player-stats-Batters.csv";
   my $line=<IN>;
   chomp $line;
   $line =~ s/^\s+//;
   my @statNames=split(',',$line);
   my $qPlayer=$statNames[0];
   while (<IN>){
      chomp;
      $_ =~ s/^\s+//;
      my @vals=split(',',$_);
      my %stats;
      foreach my $stat (@statNames){
          my $val=shift(@vals);
          $stats{$stat}=$val;
      }
      # sum up the score from this year
      my $score=0; 
      foreach my $stat (keys %batScoring){
          $score+=$batScoring{$stat}*$stats{$stat} if defined $stats{$stat};
      }
      # average the score by games played
      # print " games played is $stats{G}\n";
      my $ngames= $stats{G};
     
      #print "$year   $stats{$qPlayer} :: $score from $ngames games\n";
      my $player= $stats{$qPlayer};
      $scores{$player}->{$year}=$score;
      $perGameScores{$player}->{$year}=$score/$ngames;
      $nGames{$player}->{$year}=$ngames;
      $position{$player}=$stats{Pos};
      #sleep(1);

   }
   close (IN);


}


# total weighted historic score
my %FINALSCORE;

foreach my $player (keys %scores){
    #print "$player\n";
    my $total=0;
    my $wtTotal=0;
    foreach my $year (@YEARS){
        my $weight = shift @WEIGHTS; push @WEIGHTS, $weight;
        if (defined ($scores{$player}->{$year})){
            $total+=$scores{$player}->{$year}*$weight;
            $wtTotal+=$weight;
        }
     }
     $FINALSCORE{$player}=int($total/$wtTotal); 
        
}

my %top20;
my @sortedPlayers = sort { $FINALSCORE{$b} <=> $FINALSCORE{$a} } keys (%FINALSCORE);
my $knt=1;
print "\n         Historic Weighted Score\n\n";
foreach my $player (@sortedPlayers){

  my $available=1;
 
  $available=0 if &isInFile($keepFile,$player);
  $available=0 if &isInFile($draftedFile,$player);
  next unless $available; 

  my $starit=0;  # stars for players people had last year
  my ($av,$morePos)=&isInFile($preDropFile,$player);
  $starit=1 if ($av);
  

  unless ( $pos =~ m/ALL/i ){
     next unless ($pos =~ m/$position{$player}/);
  }

  if ($starit){
     $morePos=uc($morePos);
     print "$knt: ** $player    | $position{$player},$morePos | $FINALSCORE{$player} **\n";
  }else{
     print "$knt:    $player    | $position{$player} | $FINALSCORE{$player}\n";
  }
 
  $top20{$player}=1;


  $knt++;
  last unless $knt < $nplayers+1;
}


# calculate projected score based on linear regression
my %PROJSCORE;
my %PROJVALS;
my $mxYear;
foreach my $player (keys %scores){
    #print "$player\n";
    my @S=();
    my @N=();
    $mxYear=0;
    foreach my $year (@YEARS){
        next unless (defined  $perGameScores{$player}->{$year});
        push @S, $perGameScores{$player}->{$year};
        my $ng=$nGames{$player}->{$year};
        $ng=$nGames{$player}->{$year}*162/60  if ($year == 2020);
        push @N, $ng;
        $mxYear=$year if ($year > $mxYear);
    }  
    $mxYear++;

    my ($m,$b)=&linearRegress(\@YEARS,\@S);
    my $projScr=$b+$m*$mxYear;
    #  print "$player m=$m b=$b [s: @S ] [y: @YEARS] = $projScr\n";

    my ($m2,$b2)=&linearRegress(\@YEARS,\@N);
    my $projGms=$b2+$m2*$mxYear;
    #  print "$player m=$m b=$b [s: @N ] [y: @YEARS] = $projGms\n";
    my $npoints=$#N+1;

    $projGms=162 if $projGms > 162;

    $PROJSCORE{$player}=int($projGms*$projScr);
    my $str='';
    $str="!-TOP-$nplayers-!" if (defined $top20{$player});
    $PROJVALS{$player}=sprintf('nYrs=%d, projGames=%0.2f, scoreSlope=%0.2f %s',$npoints,$projGms,$m,$str);


}

@sortedPlayers = sort { $PROJSCORE{$b} <=> $PROJSCORE{$a} } keys (%PROJSCORE);
$knt=1;
print "\n         Projected Score\n\n";
foreach my $player (@sortedPlayers){

  my $available=1;
 
  $available=0 if &isInFile($keepFile,$player);
  $available=0 if &isInFile($draftedFile,$player);
  next unless $available; 

  my $starit=0;  # stars for players people had last year
  my ($av,$morePos)=&isInFile($preDropFile,$player);
  $starit=1 if ($av);
  

  unless ( $pos =~ m/ALL/i ){
     next unless ($pos =~ m/$position{$player}/);
  }

  if ($starit){
     $morePos=uc($morePos);
     print "$knt: ** $player    | $position{$player},$morePos | $PROJSCORE{$player} | $PROJVALS{$player} **\n";
  }else{
     print "$knt:    $player    | $position{$player} | $PROJSCORE{$player} | $PROJVALS{$player}\n";
  }

  $knt++;
  last unless $knt < $nplayers+1;
}





my $exit=<>;





# e.g. $isIn=&inFile($file,$player)
sub isInFile{
   my $file=shift;
   my $player=shift;
   $player=lc($player);
 #print "$player in $file\n";
   open IN, "<$file";
   while  (<IN>){
      if (lc($_) =~ m/$player\s+(.+)\s+\|/){
         # print "--------$1\n";
          return (1,$1);
      }
     # return $1 if lc($_) =~ m/$player\s+(+.+)\s+|/;
   } 
   return 0;
}  
 

# e.g. ($slope,$intercept)=&linearRegress(\@X,\@Y);
sub linearRegress{
    my $xrf=shift;
    my $yrf=shift;
    my @X=@{$xrf};
    my @Y=@{$yrf};
  
    my $meanX=0;
    my $n=0;
    foreach my $x (@X){
        $meanX+=$x;
        $n++;
    }
    $meanX=$meanX/$n;
    
    my $meanY=0;
    $n=0;
    foreach my $y (@Y){
        $meanY+=$y;
        $n++;
    }
    $meanY=$meanY/$n;

    my $numerator=0;
    my $denom=0;
    foreach my $k (0..$n-1){
       $numerator+=($X[$k]-$meanX)*($Y[$k]-$meanY);
       $denom+=($X[$k]-$meanX)**2;
    }
    my $slope=$numerator/$denom;
    my $intercept=$meanY-$slope*$meanX;
    return($slope,$intercept);
}    

