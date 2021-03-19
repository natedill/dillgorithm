#!/usr/bin/env perl
use strict;
use warnings;

print "\n          Millar Pitchers\n\n";

#my $scoringFile='MillarScoring.txt';
my $scoringFile='MillarScoring.txt';
my $keepFile='Millar_kept.txt';
my $preDropFile='Millar_AllTeamLineup_end2019.txt';
my $draftedFile='drafted_millar.txt';


my @YEARS=(2019,2018,2017);
my @WEIGHTS=(0.98,0.01,0.01);

#end config





my %batScoreing;
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
          $batScoreing{$key}=$val;
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

foreach my $year (@YEARS){
   my $dir="$year-stats";

   # this is a loop over players below
   open IN, "<$dir/mlb-player-stats-P.csv";
   <IN>; #skip firstline of commas
   my $line=<IN>;
   chomp $line;
   $line =~ s/^\s+//;
   my @statNames=split(',',$line);
   while (<IN>){
      chomp;
      $_ =~ s/^\s+//;
      my @vals=split(',',$_);
      my %stats;
      foreach my $stat (@statNames){
          my $val=shift(@vals);
          $stats{$stat}=$val;
      }
      my $score=0; 
      foreach my $stat (keys %pitchScoring){
          $score+=$pitchScoring{$stat}*$stats{$stat} if defined $stats{$stat};
      }
 #     print "$year   $stats{Player} :: $score\n";
      my $player= $stats{Player};
      $scores{$player}->{$year}=$score;
   }
   close (IN);


}

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
     $FINALSCORE{$player}=$total/$wtTotal; 
        
}

my @sortedPlayers = sort { $FINALSCORE{$b} <=> $FINALSCORE{$a} } keys (%FINALSCORE);
my $knt=1;
foreach my $player (@sortedPlayers){

  my $available=1;
  
  $available=0 if &isInFile($keepFile,$player);
  $available=0 if &isInFile($draftedFile,$player);
  next unless $available; 

  #my $starit=0;  # stars for players people had last year
  #$starit=1 if &isInFile($preDropFile,$player);
 
  my $starit=0;  # stars for players people had last year
  my ($av,$morePos)=&isInFile($preDropFile,$player);
  $starit=1 if ($av);

  if ($starit){
     print "$knt: ** $player $morePos | $FINALSCORE{$player} **\n";
  }else{
     print "$knt: $player $FINALSCORE{$player}\n";
  }

  $knt++;
  last unless $knt < 21;
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
 



# e.g. $isIn=&inFile($file,$player)
#sub isInFile{
#   my $file=shift;
#   my $player=shift;
#   $player=lc($player);
 #print "$player in $file\n";
#   open IN, "<$file";
#   while  (<IN>){
#      return 1 if lc($_) =~ m/$player/;
#   } 
#   return 0;
#}  

