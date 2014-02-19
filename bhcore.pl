#!/usr/bin/perl


# Copyright � 2014, University of Illinois/NCSA/Energy Sciences Network. All rights reserved.
#
# Developed by: CITES Networking, NCSA Cyber Security and Energy Sciences Network (ESnet)
# University of Illinois/NCSA/Energy Sciences Network (ESnet)
# www.illinois.edu,www.ncsa.illinois.edu, www.es.net
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the �Software�), to deal with the
# Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimers.
# Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimers in the documentation
# and/or other materials provided with the distribution.
# Neither the names of CITES, NCSA, University of Illinois, Energy Sciences Network (ESnet), nor the names of its contributors
# may be used to endorse or promote products derived from this Software
# without specific prior written permission.
#
# THE SOFTWARE IS PROVIDED �AS IS�, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
# IN NO EVENT SHALL THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS WITH THE SOFTWARE.




use warnings;
use strict;
use Data::Validate::IP qw(is_ipv4 is_ipv6);
#I dont think we are using NetAddr::IP
#use NetAddr::IP;
use Email::MIME;
use Email::Sender::Simple qw(sendmail);
use Net::DNS;
use File::stat;
use DBI;
use Config::Simple;


#read in config options from an external file
#config file location
my $configfile = "/services/blackhole/bin/bhr.cfg";
my $config = new Config::Simple($configfile);
my $logtosyslog = $config->param('logtosyslog');
my $logprepend = $config->param('logprepend');
my $sendstats = $config->param('sendstats');
my $statprepend = $config->param('statprepend');
my $emailfrom = $config->param('emailfrom');
my $emailto = $config->param('emailto');
my $emailsubject = $config->param('emailsubject');
my $db_host = $config->param('databasehost');
my $db_name = $config->param('databasename');
my $statusfilelocation = $config->param('statusfilelocation');
my $filenhtmlnotpriv = $config->param('filenhtmlnotpriv');
my $filecsvnotpriv = $config->param('filecsvnotpriv');
my $filecsvpriv = $config->param('filecsvpriv');

#database connection settings
#connection uses the user running the script - make sure all users have all privileges on the DB and tables.
my $db = "dbi:Pg:dbname=${db_name};host=${db_host}";
my $dbh = DBI->connect("dbi:Pg:dbname=$db_name", "", "");


my @months = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
my $date = localtime;

my $num_args = $#ARGV + 1;
if (($num_args == 0) || ($num_args > 5))
	{
	print "\nUsage: add|remove|list|query|reconcile|cronjob|digest Service_Name IPaddress \"Reason\"\(In quotes if more then one word) How_long_in_seconds\n";
	print "For Add or Remove must provide servicename, IPaddress, and reason\n";
	print "For query only provide IPaddress\n";
	exit;
	}
else # okay we have number of args in correct range, lets do something. Start by reading in function ARGV
	{
	my $scriptfunciton=$ARGV[0];
	
# figure out what function to perform and call the correct sub function.
#ADD function

	if ($scriptfunciton eq "add")
		{
		my $reason;
		my $servicename;
		my $howlong;
		my $blocktimedescribed;
		my $ipaddress;
		if (!defined $ARGV[3])
			{
			print ("You must specify a reason\n");
			}
		else
			{
			$reason=$ARGV[3];
			$reason =~ tr/-//d; #using dashes/hyphens in the BH log file for separators, need to remove from the reason
			$reason =~ tr/,//d; #using commas in the individual log file for separators, need to remove from the reason
			}
		if (!defined $ARGV[1])
			{
			print ("You must specify a Username or Service Name\n");
			}
		else
			{
			$servicename=$ARGV[1];
			$servicename =~ tr/-//d; #using dashes/hyphens in the BH log file for separators, need to remove from the reason
			$servicename =~ tr/,//d; #using commas in the individual log file for separators, need to remove from the reason
			}
	
		if (!defined $ARGV[4])
			{
			$howlong = 0; #indefinite
			$blocktimedescribed = "indefinite";
			}
		elsif (sub_is_integer_string($ARGV[4]) == 0)
			{
			$howlong = 0; #indefinite
			$blocktimedescribed = "indefinite";
			}
		elsif ($ARGV[4] == 0)
			{
			$howlong = 0; #indefinite
			$blocktimedescribed = "indefinite";
			}
		else
			{
			$howlong=$ARGV[4]; #list in seconds;
			$blocktimedescribed = ($howlong." Seconds");
			}
		if (!defined $ARGV[2])
			{
			print ("No IP provided\n");
			}
		else
			{
			$ipaddress=$ARGV[2];
			if (my $ipversion = sub_what_ip_version($ipaddress))
				{
				if ($ipversion == 4)
					{
					sub_bhr_add($ipaddress,$servicename,$reason,$howlong,$blocktimedescribed,4)
					}
				elsif ($ipversion == 6)
					{
					sub_bhr_add($ipaddress,$servicename,$reason,$howlong,$blocktimedescribed,6)
					}
				else
					{
					}
				}
			else
				{
				print ("IP is invalid\n");
				}
			}
		} #close add if

#remove function
		elsif ($scriptfunciton eq "remove")
		{
			my $reason;
			my $servicename;
			my $ipaddress;
			if (!defined $ARGV[3])
				{
				print ("You must specify a reason\n");
				}
			else
				{
				$reason=$ARGV[3];
				}
			if (!defined $ARGV[1])
				{
				print ("You must specify a Username or Service Name\n");
				}
			else
				{
				$servicename=$ARGV[1];
				}
			if (!defined $ARGV[2])
				{
				print ("No IP provided\n");
				}
			else
				{
				$ipaddress=$ARGV[2];
				if (my $ipversion = sub_what_ip_version($ipaddress))
					{
					if ($ipversion == 4)
						{
						sub_bhr_remove($ipaddress,$reason,$servicename,4)
						}
					elsif ($ipversion == 6)
						{
						sub_bhr_remove($ipaddress,$reason,$servicename,6)
						}
					else
						{
						}
					}
				else
					{
					print ("IP is invalid\n");
					}
				}
		} #close remove if

#LIST function
		elsif ($scriptfunciton eq "list")
		{
		sub_bhr_list();
		}	

#QUERY fucntion
		elsif ($scriptfunciton eq "query")
			{
			if (!defined $ARGV[1])
				{
				print ("No IP provided\n");
				}
			else
				{
				sub_get_ips();
				if (sub_what_ip_version($ARGV[1]))
					{
					if (sub_bhr_check_if_ip_blocked($ARGV[1]))
						{
						my ($whoblocked,$whyblocked,$whenepochblocked,$tillepochblocked) = sub_read_in_ipaddress_log ($ARGV[1]);
						print($whoblocked." - ".$whyblocked." - ".$whenepochblocked." - ".$tillepochblocked."\n");
						}
					else
						{
						print("IP not blackholed\n");
						}
					}
				else
					{
					print ("IP is invalid\n");
					}
				}
			}
		
#RECONCILE function
		elsif ($scriptfunciton eq "reconcile")
		{
		sub_bhr_reconcile();
		}	

#CRONJOB function
		elsif ($scriptfunciton eq "cronjob")
		{
		sub_bhr_cronjob();
		}

#digest function
		elsif ($scriptfunciton eq "digest")
		{
		sub_bhr_digest();
		}
#test function
		elsif ($scriptfunciton eq "test")
		{
		#sub_test();
		}

#no valid function was provided
		
		else
		{
		print ("No function performed\n");
		}

#close database	
		$dbh->disconnect();
		
	} #close the function picker
	
	


sub sub_bhr_check_if_ip_blocked
	{
	my $ipaddress = shift;
	my $sql1 =
			q{
			select count(*)
			from blocklist
			inner join blocklog
			on blocklog.block_id = blocklist.blocklist_id
			where blocklog.block_ipaddress = ?
			};
	my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
	$sth1->execute($ipaddress) or die $dbh->errstr;
	my $ipexists = $sth1->fetchrow();
	return $ipexists;
}	#end of check if IP blocked sub
	
	
	
sub sub_bhr_add
	{
	my $ipaddress = shift;
	my $servicename = shift;
	my $reason = shift;
	my $howlong = shift;
	my $blocktimedescribed = shift;
	my $ipversion = shift;
	my $endtime = "";		
	if (sub_bhr_check_if_ip_blocked($ipaddress) == 0)
		{
		if (($howlong == 0) || ($howlong eq ""))
			{
			$endtime = 0;
			}
		elsif (sub_is_integer_string($howlong) == 0)
			{
			$endtime = 0;
			}
		else
			{
			$endtime = (time()+$howlong);
			}
		my $hostname = sub_reverse_lookup($ipaddress);
		#database operations for adding to logs
		#create the blocklog entry and return the block_id for use in creating blocklist entry
		my $sql1 = 
			q{
			INSERT INTO blocklog (block_when,block_ipaddress,block_reverse,block_who,block_why) VALUES (to_timestamp(?),?,?,?,?) RETURNING block_id
			};
		my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
		$sth1->execute(time(),$ipaddress,$hostname,$servicename,$reason) or die $dbh->errstr;
		my $ipid = $sth1->fetchrow();
		my $sql2 =
			q{
			INSERT INTO blocklist (blocklist_id,blocklist_until) VALUES (?,to_timestamp(?))
			};
		my $sth2 = $dbh->prepare($sql2) or die $dbh->errstr;
		$sth2->execute($ipid,$endtime) or die $dbh->errstr;	
		#end of database operations	
		# create null route, config is now saved using the cronjob function
		if ($ipversion == 4)
			{
			system("sudo /usr/bin/vtysh -c \"conf t\" -c \"ip route $ipaddress 255.255.255.255 null0\"");
			}
		elsif ($ipversion == 6)
			{
			print ("Place holder for IPv6 route command\n");
			}
		else
			{
			}
			
		if ($logtosyslog)
			{
			system("logger ".$logprepend."_BLOCK IP=$ipaddress HOSTNAME=$hostname WHO=$servicename WHY=$reason UNTIL=$endtime");
			}
		}
	else
		{
		print("<p>Nothing to do IP already blackholed</p>\n");
		}
	} #close sub add

sub sub_bhr_remove	
	{
	my $ipaddress = shift;
	my $reason = shift;
	my $servicename = shift;
	my $ipversion = shift;
	if (sub_bhr_check_if_ip_blocked($ipaddress) == 1)
		{

		#database operations for unblock
		#first find blocklog.block_id associated with the IP
		my $sql1 = 
			q{
			select blocklog.block_id
			from blocklist
			inner join blocklog
			on blocklog.block_id = blocklist.blocklist_id
			where blocklog.block_ipaddress = ?
			};
		my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
		$sth1->execute($ipaddress) or die $dbh->errstr;
		my $blockid = $sth1->fetchrow();
		#insert a log line for removing - references the original block_id
		my $sql2 = 
			q{
			INSERT INTO unblocklog (unblock_id,unblock_when,unblock_who,unblock_why) VALUES (?,to_timestamp(?),?,?)
			};
		my $sth2 = $dbh->prepare($sql2) or die $dbh->errstr;
		$sth2->execute($blockid,time(),$servicename,$reason) or die $dbh->errstr;
		#remove entry from blockedlist
		my $sql3 =
			q{
			DELETE from blocklist where blocklist_id = ?
			};
		my $sth3 = $dbh->prepare($sql3) or die $dbh->errstr;
		$sth3->execute($blockid) or die $dbh->errstr;	
		#end of database operations	for unblock
		# delete null route, config is now saved using the cronjob function
		if ($ipversion == 4)
			{
			system("sudo /usr/bin/vtysh -c \"conf t\" -c \"no ip route $ipaddress 255.255.255.255 null0\"");
			}
		elsif ($ipversion == 6)
			{
			print ("Place holder for IPv6 route command\n");
			}
		else
			{
			}
		
		if ($logtosyslog)
			{
			system("logger ".$logprepend."_UNBLOCK IP=$ipaddress WHO=$servicename WHY=$reason");
			}
		}
	else
		{
		print("<p>Nothing to do IP not blackholed<p>\n");
		}
	} #close sub remove

sub sub_bhr_list
	{
	my ($blocklistwithinfo_ref) = sub_block_list_with_info();
	my @blocklistwithinfo= @$blocklistwithinfo_ref;
	my $rowref;
	while ($rowref = shift(@blocklistwithinfo))
		{
		print ($rowref->{ip}."-".$rowref->{who}."-".$rowref->{why}."-".$rowref->{until}."\n");
		} #end for each loop
	}
	 #close sub list test
	 
	 
sub sub_bhr_reconcile
	{
	
	my ($officialbhdips_ref,$forrealbhdips_ref) = sub_get_ips ();
	my @officialbhdips = @$officialbhdips_ref;
	my @forrealbhdips = @$forrealbhdips_ref;
	#build hashes
	my %forrealbhdips;
	my %officialbhdips;
	map($officialbhdips{$_}=1,@officialbhdips);
	map($forrealbhdips{$_}=1,@forrealbhdips);
	
	#figure out the differences
	my @missingfromreal = grep(!defined($forrealbhdips{$_}),@officialbhdips);
	my @missingfromofficial = grep(!defined($officialbhdips{$_}),@forrealbhdips);
	my $blackholedip;

	#delete missing from the real BH system
	foreach (@missingfromreal)
		{
		$blackholedip = $_;
		print("<p>Deleting ".$blackholedip." from the list</p>\n");
		#database operations for removing from blocklist
		#figure out the id for the active block
		my $sql1 = 
			q{
			select blocklog.block_id
			from blocklist
			inner join blocklog
			on blocklog.block_id = blocklist.blocklist_id
			where blocklog.block_ipaddress = ?
			};
		my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
		$sth1->execute($blackholedip) or die $dbh->errstr;
		my $blockid = $sth1->fetchrow();
		#remove entry from blockedlist i
		my $sql2 =
			q{
			DELETE from blocklist where blocklist_id = ?
			};
		my $sth2 = $dbh->prepare($sql2) or die $dbh->errstr;
		$sth2->execute($blockid) or die $dbh->errstr;	
		#end of database operations	for removing from blocklist
		}

	#add to official if listed in real but not official
	foreach (@missingfromofficial)
		{
		$blackholedip = $_;
		print("<p>Adding ".$blackholedip." to the list</p>\n");
		my $hostname = sub_reverse_lookup($blackholedip);
		#database operations for adding to logs
		my $sql1 = 
			q{
			INSERT INTO blocklog (block_when,block_ipaddress,block_reverse,block_who,block_why) VALUES (to_timestamp(?),?,?,?,?) RETURNING block_id
			};
		my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
		$sth1->execute(time(),$blackholedip,$hostname,'BHRscript','reconciled') or die $dbh->errstr;
		my $ipid = $sth1->fetchrow();
		my $sql2 =
			q{
			INSERT INTO blocklist (blocklist_id,blocklist_until) VALUES (?,to_timestamp(?))
			};
		my $sth2 = $dbh->prepare($sql2) or die $dbh->errstr;
		$sth2->execute($ipid,0) or die $dbh->errstr;	
		#end of database operations	for adding to logs
		}
	
	}#close sub reconcile


sub sub_bhr_cronjob
	{
	# this sub will finds blocklists rows with times that are less then now and not 0(indefinite block)
	# added feature: now creates an HTML file with the list of blocked IPs
	# this file can be shared with users that do not have access to the main BHR scripts.
	#JFE - 2013Dec04 - now exports a CSV file with blocked IPs and info - for auto import use
	
	#do a wr mem on the quagga system - does not happen during the routing changes now.
	system("sudo /usr/bin/vtysh -c \"wr me\"");


	#database operations for removing expired blocks
	#select statement returns IPs that have expired but not epoch 0 for block time
	my $unblockip = "";
	my $sql1 = 
		q{
		select blocklog.block_ipaddress
		from blocklist
		inner join blocklog
		on blocklog.block_id = blocklist.blocklist_id
		where (now() > blocklist.blocklist_until)
		AND (extract(epoch from blocklist.blocklist_until) != 0)
		};
	my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
	$sth1->execute() or die $dbh->errstr;
	while ($unblockip = $sth1->fetchrow())
	{
		my $ipversion = sub_what_ip_version($unblockip);
		sub_bhr_remove($unblockip,"Block Time Expired","cronjob",$ipversion);
	};
	
	#create list files
	my $filehtml="bhlisttemp.html";
	my $filecsv="bhlisttemp.csv";
	my $fileprivcsv="bhlistprivtemp.csv";
	my $cmdString = $statusfilelocation; 
	chdir($cmdString)|| die "Error: could not '$statusfilelocation'"; 
	#open new files on top of other ones - not append
	#using temp files to create new ones and then do cp on top of old one when done
	#creates a privileged (more info) CSV
	open(FILEHTML, ">$filehtml") or die "Cannot open $filehtml: $!";
	open(FILECSV, ">$filecsv") or die "Cannot open $filecsv: $!";
	open(FILEPRIVCSV, ">$fileprivcsv") or die "Cannot open $fileprivcsv: $!";
	
	my $htmltable = "<table border=\"1\" width=\"100%\">\n";
	print FILECSV "ip,when,expire\n";
	print FILEPRIVCSV "ip,who,why,when,expire\n";
	my $bhrdcount = 0;
	my $whoblocked;
	my $whenepochblocked;
	my $tillepochblocked;
	my $whyblocked;
	my $whenblockedsec;
	my $whenblockedmin;
	my $whenblockedhour;
	my $whenblockedday;
	my $whenblockedmonth;
	my $whenblockedyear;
	my $tillblockedsec;
	my $tillblockedmin;
	my $tillblockedhour;
	my $tillblockedday;
	my $tillblockedmonth;
	my $tillblockedyear;
	
	my ($blocklistwithinfo_ref) = sub_block_list_with_info();
	my @blocklistwithinfo= @$blocklistwithinfo_ref;
	my $rowref;
	while ($rowref = shift(@blocklistwithinfo))
		{
		$bhrdcount++;
		($tillblockedsec, $tillblockedmin, $tillblockedhour, $tillblockedday,$tillblockedmonth,$tillblockedyear) = (localtime($rowref->{until}))[0,1,2,3,4,5];
		($whenblockedsec, $whenblockedmin, $whenblockedhour, $whenblockedday,$whenblockedmonth,$whenblockedyear) = (localtime($rowref->{when}))[0,1,2,3,4,5];
		$htmltable .=  "<tr>\n".
			"     <td>".$rowref->{ip}."</td>\n";
			if($rowref->{until} == 0)
				{
				$htmltable .=  "     <td>Block time: ".$months[$whenblockedmonth]." ".$whenblockedday.", ".($whenblockedyear+1900)." ".$whenblockedhour.":".$whenblockedmin.":".$whenblockedsec."</td>\n
					<td>Blocked indefinitely</td>\n
					</tr>\n";

				}
			else
				{
				$htmltable .=  "     <td>Block time: ".$months[$whenblockedmonth]." ".$whenblockedday.", ".($whenblockedyear+1900)." ".$whenblockedhour.":".$whenblockedmin.":".$whenblockedsec."</td>\n
					<td>Block expires: ".$months[$tillblockedmonth]." ".$tillblockedday.", ".($tillblockedyear+1900)." ".$tillblockedhour.":".$tillblockedmin.":".$tillblockedsec."</td>\n
					</tr>\n";
				}
			print FILEPRIVCSV $rowref->{ip}.",".$rowref->{who}.",".$rowref->{why}.",".$rowref->{when}.",".$rowref->{until}."\n";
			print FILECSV $rowref->{ip}.",".$rowref->{when}.",".$rowref->{until}."\n";
		
		} #close while loop

		$htmltable .=  "</table>\n";
		print FILEHTML "<HTML>\n";
		print FILEHTML "<p>Number of blocked IPs: ",$bhrdcount,"<br>\n";
		print FILEHTML "This file is also available as a csv - bhlist.csv<br>\n";
		print FILEHTML "Created ".(localtime)."</p>\n";
		print FILEHTML $htmltable;
		print FILEHTML "</html>\n";
		close(FILEHTML);
		close(FILECSV);
		close(FILEPRIVCSV);
		#replace the live files with the new temp ones
		$cmdString="rm $filenhtmlnotpriv; cp bhlisttemp.html $filenhtmlnotpriv"; 
		system($cmdString)==0 or die "Error: could not '$cmdString'";
		$cmdString="rm $filecsvnotpriv; cp bhlisttemp.csv $filecsvnotpriv"; 
		system($cmdString)==0 or die "Error: could not '$cmdString'";
		$cmdString="rm $filecsvpriv; cp bhlistprivtemp.csv $filecsvpriv"; 
		system($cmdString)==0 or die "Error: could not '$cmdString'";
	}#close sub cronjob

	
sub sub_bhr_digest
	# send the email notification digest
	{
	#build the list of blocked IDs and info that need to be notified
	#database operations
		my $sql1 = 
			q{
			select blocklog.block_ipaddress AS ip,
			blocklog.block_who AS who,
			blocklog.block_why AS why,
			blocklog.block_when AS whenblock,
			blocklist.blocklist_until AS until,
			blocklist.blocklist_id AS blockid,
			blocklog.block_reverse AS reverse
			from blocklist
			inner join blocklog
			on blocklog.block_id = blocklist.blocklist_id
			where not block_notified
			order by whenblock
			};
		my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
		$sth1->execute() or die $dbh->errstr;
		my $blockactivitycount = $sth1->rows();
		my @blockednotifyarray;
		my $blockednotifyarrayrow;
		while ( $blockednotifyarrayrow = $sth1->fetchrow_hashref())
			{
			push (@blockednotifyarray,$blockednotifyarrayrow)
			};
	#build list of unblocked IDs and info that need to be notified
		my $sql2 = 
			q{
			select blocklog.block_ipaddress AS ip,
			unblocklog.unblock_who AS whounblock,
			unblocklog.unblock_why AS whyunblock,
			unblock_when AS whenunblock,
			blocklog.block_reverse as reverse,
			blocklog.block_who AS whoblock,
			blocklog.block_why AS whyblock,
			unblocklog.unblock_id AS unblockid
			from unblocklog
			inner join blocklog on blocklog.block_id = unblocklog.unblock_id
			where not unblock_notified
			order by whenunblock
			};
		my $sth2 = $dbh->prepare($sql2) or die $dbh->errstr;
		$sth2->execute() or die $dbh->errstr;
		my $unblockactivitycount = $sth2->rows();
		my @unblockednotifyarray;
		my $unblockednotifyarrayrow;
		while ($unblockednotifyarrayrow = $sth2->fetchrow_hashref())
			{
			push (@unblockednotifyarray,$unblockednotifyarrayrow)
			};

	#end of database operations	
	

	my $queueline = "";
	my $queuehaddata = 0;
	my $blocknotifyidline = "";
	#build email body
	#print activity counts
	my $emailbody = "Activity since last digest:\nBlocked: ".$blockactivitycount."\nUnblocked: ".$unblockactivitycount."\n";	
	
	#add blocked notifications to email body
	my $blockrowref;
	while ($blockrowref = shift(@blockednotifyarray))
		{
		#indicate we have put into to queue
		$queuehaddata = 1;
		
		$blocknotifyidline = ("BLOCK - ".$blockrowref->{whenblock}." - ".$blockrowref->{who}." - ".$blockrowref->{ip}." - ".$blockrowref->{reverse}." - ".$blockrowref->{why}." - ".$blockrowref->{until});
		$emailbody = $emailbody."\n".$blocknotifyidline;		
		#alter the log entry to true for notified
		my $sql3 = 
			q{
			update blocklog
			set block_notified = true
			where block_id = ?
			};
		my $sth3 = $dbh->prepare($sql3) or die $dbh->errstr;
		$sth3->execute($blockrowref->{blockid}) or die $dbh->errstr;
		} #close while loop		
	#add unblocked notifications to email body
	my $unblockrowref;
	while ($unblockrowref = shift(@unblockednotifyarray))
		{
		#indicate we have put into to queue
		$queuehaddata = 1;

		my $notifyidline = ("UNBLOCK - ".$unblockrowref->{whenunblock}." - ".$unblockrowref->{whounblock}." - ".$unblockrowref->{whyunblock}." - ".$unblockrowref->{ip}." - ".$unblockrowref->{reverse}." - Originally Blocked by: ".$unblockrowref->{whoblock}." for ".$unblockrowref->{whyblock});
		$emailbody = $emailbody."\n".$notifyidline;		
		#alter the log entry to true for notified
		my $sql4 = 
			q{
			update unblocklog
			set unblock_notified = true
			where unblock_id = ?
			};
		my $sth4 = $dbh->prepare($sql4) or die $dbh->errstr;
		$sth4->execute($unblockrowref->{unblockid}) or die $dbh->errstr;
		} #close while loop	
	
	
	#if we created a non-empty queue email it
	if ($queuehaddata)
		{
		my $message = Email::MIME->create
			(
				header_str =>
				[
					From    => $emailfrom,
					To      => $emailto,
					Subject => $emailsubject,
				],
				attributes =>
				{
					encoding => 'quoted-printable',
					charset  => 'ISO-8859-1',
				},
				body_str => $emailbody,
			);
		sendmail($message);
		}
	#if send stats is enabled create and log stats
	if ($sendstats)
		{
		#build table of unique blockers and counts
 		my $sql5 =
			q{
			select block_who,count(block_who)
			from blocklog inner join blocklist
			on blocklog.block_id = blocklist.blocklist_id
			group by block_who;
			};
		my $sth5 = $dbh->prepare($sql5) or die $dbh->errstr;
		$sth5->execute() or die $dbh->errstr;
		my $whoblockname;
		my $whocount;
		while (($whoblockname,$whocount) = $sth5->fetchrow())
			{
			system("logger ".$logprepend."_STATS WHO=$whoblockname TOTAL_BLOCKED=$whocount");
			} close #stat log line create while
		} #end if end stats
			
	} #close sub_bhr_digest

sub sub_get_ips
	{
	#returns array references to the IP lists
	#this sub also always checks to see if the router and database are in sync
	my @subgetipsofficialbhdips =();
	#figure out what IPs are in the DB that we say are BHd
	#database list blocked ips
	my $sql1 = 
		q{
		select blocklog.block_ipaddress
		from blocklist
		inner join blocklog
		on blocklog.block_id = blocklist.blocklist_id
		};
	my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
	$sth1->execute() or die $dbh->errstr;
	my $rowip = "";
	while ($rowip = $sth1->fetchrow())
		{
		push (@subgetipsofficialbhdips,$rowip)
		};
	@subgetipsofficialbhdips = sort(@subgetipsofficialbhdips);
	# find what IPs are actually being BHd locally		
	#IPv4 null routes first
	my @subgetipsforrealbhdipsv4=readpipe("/usr/bin/sudo /usr/bin/vtysh -c \"sh ip route static\" | grep \"/32\" | grep Null | awk {\'print \$2\'} |sed -e s/\\\\/32//g | grep -iv 38.32.0.0 | grep -iv 192.0.2.1 | grep -iv 192.0.2.2");
	chomp(@subgetipsforrealbhdipsv4);
	#ipv6 null routes  next
	#need to get this information for quagga
	#@subgetipsforrealbhdipsv6=readpipe("/usr/bin/sudo /usr/bin/vtysh -c \"sh ip route static\" | grep \"/128\" | grep Null | awk {\'print \$2\'} |sed -e s/\\\\/32//g | grep -iv 38.32.0.0 | grep -iv 192.0.2.1 | grep -iv 192.0.2.2")
	#empty set for now
	my @subgetipsforrealbhdipsv6= ();
	#concatenate the 2 lists
	my @subgetipsforrealbhdips = (@subgetipsforrealbhdipsv4,@subgetipsforrealbhdipsv6);
	@subgetipsforrealbhdips = sort(@subgetipsforrealbhdips);
	
	#compare the official list of IPs and what the BHR reports is blocked
	if (@subgetipsforrealbhdips ~~ @subgetipsofficialbhdips)
		{
		#do nothing - the lists match
		}
	else
		{
		print "     WARNING! WARNING! WARNING! WARNING!\n";
		print "     The List of BHd IPs and IPs actually BHd by the router do not match.\n";
		print "     Use the reconcile argument to fix this\n";		
		print "     Reconcile will remove listed but not really blocked and add listings for blocked but not in the list\n";			
		}
	#return references to the arrays of IPs
	return (\@subgetipsofficialbhdips,\@subgetipsforrealbhdips);
	} #close get IPs

	
sub sub_read_in_ipaddress_log
	{
	#database read in information for a specific IP
	my $sql1 =
		q{
		select blocklog.block_who,blocklog.block_why,EXTRACT (EPOCH from blocklog.block_when),EXTRACT (EPOCH from blocklist.blocklist_until)
		from blocklist
		inner join blocklog
		on blocklog.block_id = blocklist.blocklist_id
		where blocklog.block_ipaddress = ?
		};
	my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
	$sth1->execute($_[0]) or die $dbh->errstr;
	my @blockedipinfo = $sth1->fetchrow_array();
	return ($blockedipinfo[0],$blockedipinfo[1],$blockedipinfo[2],$blockedipinfo[3]);
	} #close sub read in IP address log

sub sub_what_ip_version
	{
	my $ipaddress = shift;
	#check to see what version of IP, return 0 if the IP is invalid
	if (is_ipv4($ipaddress))
		{
		return 4;
		}
	elsif (is_ipv6($ipaddress))
		{
		return 6;
		}
	else
		{
		return 0;
		}
	} #close sub what ip version

sub sub_block_list_with_info
	{
	#database list blocked ips and info
	my $sql1 = 
		q{
		select blocklog.block_ipaddress AS ip,blocklog.block_who AS who,blocklog.block_why AS why,EXTRACT (EPOCH from blocklog.block_when) AS when,EXTRACT (EPOCH from blocklist.blocklist_until) AS until
		from blocklist
		inner join blocklog
		on blocklog.block_id = blocklist.blocklist_id
		order by ip
		};
	my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
	$sth1->execute() or die $dbh->errstr;
	my @blocklistwithinfo;
	my $blocklistwithinfo;
	while ($blocklistwithinfo = $sth1->fetchrow_hashref())
		{
		push (@blocklistwithinfo,$blocklistwithinfo);
		}
	#return references to the array
	return \@blocklistwithinfo;
	}

sub sub_is_integer_string
	{
	my $testthis = shift;
	# a valid integer is any amount of white space, followed
	# by an optional sign, followed by at least one digit,
	# followed by any amount of white space
	if(($testthis =~ /^\s*[\+\-]?\d+\s*$/) and ($testthis > 0))
		{
		return 1;
		}
	else
		{
		return 0;
		}
	} #close sub integer

sub sub_reverse_lookup
	{
	my $ipaddress = shift;
	my $hostname = "";
	if ($ipaddress ne "")
		{
		my $res = Net::DNS::Resolver->new;
		# create the reverse lookup DNS name (note that the octets in the IP address need to be reversed).
		my $target_IP = join('.', reverse split(/\./, $ipaddress)).".in-addr.arpa";
		my $query = $res->query("$target_IP", "PTR");
		if ($query) 
			{
			foreach my $rr ($query->answer)
				{
				next unless $rr->type eq "PTR";
				$hostname = (substr($rr->rdatastr,0,-1));
				}
			}
		else
			{
			$hostname = "no reverse found";
			}
		}
	else
		{
		$hostname = "no reverse found";
		}
	return $hostname
	} #end sub_reverse_lookup sub

