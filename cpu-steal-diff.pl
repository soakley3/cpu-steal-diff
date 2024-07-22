#!/usr/local/bin/perl

# steps
# record collectl on your VM
# gunzip the archive
# below place the archive name and CPU steal jiffies delta you'd like reported
# run the file with `perl cpu-steal-diff.pl`
# NOTE that timestamps are 4 hours behind.... sorry.

# EXAMPLE OUTPUT:
# [root@rhel8vm c]# perl cpu-steal-diff.pl  | column -t 
# Delta:  20240627  13:07:48  1                                 
# cpu     1592      2556      594   459255  100  0  137  29  0  0
# cpu0    753       711       293   113793  33   0  7    20  0  0   <<<
# cpu1    838       1844      300   112825  66   0  130  9   0  0
# cpu2    0         0         0     116318  0    0  0    0   0  0
# cpu3    0         0         0     116318  0    0  0    0   0  0
# 
# * Notes
# * From /proc/sched, reported values are USER_HZ jiffies, 
# * i.e., converted by the kernel from milliseconds and reported as hundredths of seconds
# * cumulative delta           
# * |     date   timestamp
# * |       |  of delta>thresh
# * |       |          |      # of jiffies of steal (delta) increase reported this timestamp   
# * |       |          |      |                          # of jiffies of steal cumulative total per vCPU
# Delta:  20240627  13:08:19  1                          |                 <<< the delta increase was 1 cumulatively                         
# cpu     1629      2556      618   471569  100  0  138  30  0  0            
# cpu0    754       711       294   116870  33   0  7    21  0  0          <<< because cpu 0 increased by 1 jiffy compared to previous timestamp
# cpu1    874       1844      324   115862  66   0  131  9   0  0
# cpu2    0         0         0     119418  0    0  0    0   0  0
# cpu3    0         0         0     119418  0    0  0    0   0  0
# Delta:  20240627  13:08:23  1                                 
# cpu     1632      2556      622   472958  100  0  138  31  0  0
# cpu0    754       711       294   117216  33   0  7    22  0  0
# cpu1    878       1844      328   116205  66   0  131  9   0  0
# cpu2    0         0         0     119768  0    0  0    0   0  0
# cpu3    0         0         0     119768  0    0  0    0   0  0
# Delta:  20240627  13:10:06  1                                
# cpu     1755      2556      696   513883  101  0  139  32  0  0
# cpu0    754       711       294   127446  34   0  7    22  0  0
# cpu1    1000      1844      402   126300  66   0  132  9   0  0
# cpu2    0         0         0     130068  0    0  0    0   0  0
# cpu3    0         0         0     130068  0    0  0    0   0  0
# 
# 


$file = "hostname-20240710-000000.raw";                                 # VM's collectl archive. Edit file path after downloading collect archive and gunzip'ing
$reportable_delta = 1;  # minimum threshold to report delta             # report delta between prior interval and next above this number. Its going to be high because its jiffies.
                                                                        # in specialized environments using isolcpus this should be lower.


# no touching below here
$ouser = -1;
$dstl = -1;
$last_pcpu = "";

open my $info, $file or die "Could not open $file: $!";
while( my $line = <$info>)  {
	#    print "reading new line\n";
	#    print "-$line\n";

	# handle date time stamp conversion.
	# This converts the line ">>         1719522977.001  <<<"
	# to "20240627 17:16:17", placing it in $datetime

	if ($line=~/^>>>/) {

	  # On the next timestamp, check the prior timestamp's cummulative CPU steal delta
          if ($dstl > $reportable_delta ){
            print "Delta: $datetime $dstl\n";
	    print "$last_pcpu\n";
          }

	  @opts = split /(\.| )/, $line;
	  $seconds = $opts[2];
	  ($ss, $mm, $hh, $mday, $mon, $year)=localtime($seconds);

	  $datetime=sprintf("%02d:%02d:%02d", $hh, $mm, $ss);
	  $datetime=sprintf("%04d%02d%02d %s", $year+1900, $mon+1, $mday, $datetime);
	  $last_pcpu = "";
	} 

	# handle delta in cumulative CPU time
	if ($line=~/^cpu /) { 
	  @columns = split / /, $line;

	  # check the delta
	  if ($ouser != -1) {
	    $duser = $columns[2]  - $ouser;  # delta increase user 
	    $dnice = $columns[3]  - $onice;  # delta increase nice 
	    $dsys  = $columns[4]  - $osys ;  # delta increase system
	    $didle = $columns[5]  - $oidle;  # delta increase idle 
	    $dwait = $columns[6]  - $owait;  # delta increase iowait
	    $dirq  = $columns[7]  - $oirq ;  # delta increase irq
	    $dsirq = $columns[8]  - $osirq;  # delta increase softirq
	    $dstl  = $columns[9]  - $ostl  ;  # delta increase steal
	    $dgst  = $columns[10] - $ogst ;  # delta increase guest
	    $dgstn = $columns[11] - $ogstn;  # delta increase guestnice
	  } else {
	    $duser = 0;  # set start delta increase user 
	    $dnice = 0;  # set start delta increase nice 
	    $dsys  = 0;  # set start delta increase system
	    $didle = 0;  # set start delta increase idle 
	    $dwait = 0;  # set start delta increase iowait
	    $dirq  = 0;  # set start delta increase irq
	    $dsirq = 0;  # set start delta increase softirq
	    $dstl  = 0;  # set start delta increase steal
	    $dgst  = 0;  # set start delta increase guest
	    $dgstn = 0;  # set start delta increase guestnice
	  }
	  $ouser = $columns[2];  # user 
	  $onice = $columns[3];  # nice 
	  $osys  = $columns[4];  # system
	  $oidle = $columns[5];  # idle 
	  $owait = $columns[6];  # iowait
	  $oirq  = $columns[7];  # irq
	  $osirq = $columns[8];  # softirq
	  $ostl  = $columns[9];  # steal
	  $ogst  = $columns[10];  # guest
	  $ogstn = $columns[11]; # guestnice
	}

	# just capture all the pcpu data so we can print
	# it if the cumulative delta reports any steal
	# 
        if ($line=~/^cpu[0-9]*/) {
		$last_pcpu = join '', $last_pcpu, $line;
        }


}


print "exit\n";




