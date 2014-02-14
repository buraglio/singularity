#!/usr/bin/perl


# Copyright © 2014, University of Illinois/NCSA/Energy Sciences Network. All rights reserved.
#
# Developed by: CITES Networking, NCSA Cyber Security and Energy Sciences Network (ESnet)
# University of Illinois/NCSA/Energy Sciences Network (ESnet)
# www.illinois.edu,www.ncsa.illinois.edu, www.es.net
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the “Software”), to deal with the
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
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
# IN NO EVENT SHALL THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS WITH THE SOFTWARE.




use warnings;
use strict;
use Data::Validate::IP qw(is_ipv4);
use NetAddr::IP;
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


#database connection settings
#connection uses the user running the script - make sure all users have all privileges on the DB and tables.
my $db = "dbi:Pg:dbname=${db_name};host=${db_host}";
my $dbh = DBI->connect("dbi:Pg:dbname=$db_name", "", "");


my @months = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
my $date = localtime;

my $num_args = $#ARGV + 1;
if (($num_args == 0) || ($num_args > 5))
	{
	print "\nUsage: add|remove|list|reconcile|cronjob|digest Service_Name IPaddress \"Reason\"\(In quotes if more then one word) How_long_in_seconds\n";
	print "For Add or Remove must provide servicename, IPaddress, and reason\n";
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
			$reason =~ tr/-//d; #using dashes/hypens in the BH log file for separators, need to remove from the reason
			$reason =~ tr/,//d; #using commas in the individual log file for separators, need to remove from the reason
			}
		if (!defined $ARGV[1])
			{
			print ("You must specify a Username or Service Name\n");
			}
		else
			{
			$servicename=$ARGV[1];
			$servicename =~ tr/-//d; #using dashes/hypens in the BH log file for seperators, need to remove from the reason
			$servicename =~ tr/,//d; #using commas in the individual log file for seperators, need to remove from the reason
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
			if (is_ipv4($ipaddress))
				{
				sub_bhr_add($ipaddress,$servicename,$reason,$howlong,$blocktimedescribed)
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
				if (is_ipv4($ipaddress))
					{
					sub_bhr_remove($ipaddress,$reason,$servicename)
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
		system("sudo /usr/bin/vtysh -c \"conf t\" -c \"ip route $ipaddress 255.255.255.255 null0\"");
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
		system("sudo /usr/bin/vtysh -c \"conf t\" -c \"no ip route $ipaddress 255.255.255.255 null0\"");
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
	my $whoblocked;
	my $whyblocked;
	my $whenepochblocked;
	my $tillepochblocked;
	my $whenblockedsec;
	my $whenblockedmin;
	my $whenblockedhour;
	my $whenblockedday;
	my $whenblockedmonth;
	my $whenblockedyear;
	my $form1counter;
	my $blackholedip;
	my ($officialbhdips_ref,$forrealbhdips_ref) = sub_get_ips ();
	my @officialbhdips = @$officialbhdips_ref;
	my @forrealbhdips = @$forrealbhdips_ref;
	#my @officialbhdips2 = @officialbhdips;
	
	foreach (@officialbhdips)
		{
		$form1counter ++;
		if ($_ ne "")
			{
			$blackholedip = $_;
			($whoblocked,$whyblocked,$whenepochblocked,$tillepochblocked) = sub_read_in_ipaddress_log ($blackholedip);
			($whenblockedsec, $whenblockedmin, $whenblockedhour, $whenblockedday,$whenblockedmonth,$whenblockedyear) = (localtime($whenepochblocked))[0,1,2,3,4,5];
			print ($blackholedip."-".$whoblocked."-".$whyblocked);
			if ($tillepochblocked == 0)
				{
				print ("-0\n");
				}
			else
				{
				print ("-".$tillepochblocked."\n");
				}
				
			}
		} #end for each loop
	return ;
	
	
	} #close sub list

sub sub_bhr_reconcile
	{
	my ($officialbhdips_ref,$forrealbhdips_ref) = sub_get_ips ();
	my @officialbhdips = @$officialbhdips_ref;
	my @forrealbhdips = @$forrealbhdips_ref;
	#if one is missing from real - remove from listed
	my $blackholedip = "";
	my $realblackholedip = "";
	my $isinreal = "";
	my $isinlist = "";
	my $listedblackholedip = "";
	
	foreach (@officialbhdips)
		{
		if ($_ ne "")
			{
			$blackholedip = $_;
			$isinreal = 0;
			foreach (@forrealbhdips)
				{
				if ($_ ne "")
					{
					$realblackholedip = $_;
					chomp($realblackholedip);
					if ($blackholedip eq $realblackholedip)
						{
						$isinreal = 1;
						}
					}
				}
			if ($isinreal == 0)
				{
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
				#remove entry from blockedlist
				my $sql2 =
				q{
				DELETE from blocklist where blocklist_id = ?
				};
				my $sth2 = $dbh->prepare($sql2) or die $dbh->errstr;
				$sth2->execute($blockid) or die $dbh->errstr;	
		#end of database operations	for removing from blocklist
				}
			}
		}
	#if one is missing from listed - add to listed
	foreach (@forrealbhdips)
		{
		if ($_ ne "")
			{
			$blackholedip = $_;
			$isinlist = 0;
			foreach (@officialbhdips)
				{
				if ($_ ne "")
					{
					$listedblackholedip = $_;
					chomp($listedblackholedip);
					if ($blackholedip eq $listedblackholedip)
						{
						$isinlist = 1;
						}
					}
				}
			if ($isinlist == 0)
				{
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
			}
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
		sub_bhr_remove($unblockip,"Block Time Expired","cronjob");
	};
	#end of database operations	
	
	my ($officialbhdips_ref,$forrealbhdips_ref) = sub_get_ips ();
	my @officialbhdips = @$officialbhdips_ref;
	my $filehtml="bhlisttemp.html";
	my $filecsv="bhlisttemp.csv";
	my $cmdString = "/services/blackhole/www/html/"; 
	chdir($cmdString)|| die "Error: could not '$cmdString'"; 
	#open new files on top of other ones - not append
	#using temp files to create new ones and then do cp on top of old one when done
	open(FILEHTML, ">$filehtml") or die "Cannot open $filehtml: $!";
	open(FILECSV, ">$filecsv") or die "Cannot open $filecsv: $!";

	my $htmltable = "<table border=\"1\" width=\"100%\">\n";
	print FILECSV "ip,who,why,when,expire\n";
	my $bhrdcount = 0;
	my $blackholedip;
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

	
	
	foreach (@officialbhdips)
		{
		if ($_ ne "")
			{
			$bhrdcount++;
			$blackholedip = $_;
			($whoblocked,$whyblocked,$whenepochblocked,$tillepochblocked) = sub_read_in_ipaddress_log ($blackholedip);
			($tillblockedsec, $tillblockedmin, $tillblockedhour, $tillblockedday,$tillblockedmonth,$tillblockedyear) = (localtime($tillepochblocked))[0,1,2,3,4,5];
			($whenblockedsec, $whenblockedmin, $whenblockedhour, $whenblockedday,$whenblockedmonth,$whenblockedyear) = (localtime($whenepochblocked))[0,1,2,3,4,5];
			$htmltable .=  "<tr>\n".
			"     <td>".$blackholedip."</td>\n";
			if($tillepochblocked == 0)
				{
				$htmltable .=  "     <td>Block time: ".$months[$whenblockedmonth]." ".$whenblockedday.", ".($whenblockedyear+1900)." ".$whenblockedhour.":".$whenblockedmin.":".$whenblockedsec."</td>\n
					<td>Blocked indefinitely</td>\n
					</tr>\n";
				print FILECSV $blackholedip.",".$whoblocked.",".$whyblocked.",".$whenepochblocked.",0\n";
				}
			else
				{
				$htmltable .=  "     <td>Block time: ".$months[$whenblockedmonth]." ".$whenblockedday.", ".($whenblockedyear+1900)." ".$whenblockedhour.":".$whenblockedmin.":".$whenblockedsec."</td>\n
					<td>Block expires: ".$months[$tillblockedmonth]." ".$tillblockedday.", ".($tillblockedyear+1900)." ".$tillblockedhour.":".$tillblockedmin.":".$tillblockedsec."</td>\n
					</tr>\n";
				print FILECSV $blackholedip.",".$whoblocked.",".$whyblocked.",".$whenepochblocked.",".$tillepochblocked."\n";
				}

			}	#close if
		} #end for each loop

		$htmltable .=  "</table>\n";
		print FILEHTML "<HTML>\n";
		print FILEHTML "<p>Number of blocked IPs: ",$bhrdcount,"<br>\n";
		print FILEHTML "This file is also available as a csv - bhlist.csv<br>\n";
		print FILEHTML "Created ".(localtime)."</p>\n";
		print FILEHTML $htmltable;
		print FILEHTML "</html>\n";
		close(FILEHTML);
		close(FILECSV);
		#replace the live files with the new temp ones
		$cmdString="rm bhlist.html; cp bhlisttemp.html bhlist.html"; 
		system($cmdString)==0 or die "Error: could not '$cmdString'";
		$cmdString="rm bhlist.csv; cp bhlisttemp.csv bhlist.csv"; 
		system($cmdString)==0 or die "Error: could not '$cmdString'";
	}#close sub cronjob

	
sub sub_bhr_digest
	# send the email notification digest
	{
	#build the list of blocked IDs that need to be notified
	#database operations
		my $sql1 = 
			q{
			select block_id
			from blocklog
			where not block_notified
			};
		my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
		$sth1->execute() or die $dbh->errstr;
		#my $blockednotify = "";
		my @blockednotifyarray;
		my $blocknotifyid;
		while ($blocknotifyid = $sth1->fetchrow())
			{
			push (@blockednotifyarray,$blocknotifyid)
			};
	#build list of unblocked IDs that need to be notified
		my $sql2 = 
			q{
			select unblock_id
			from unblocklog
			where not unblock_notified
			};
		my $sth2 = $dbh->prepare($sql2) or die $dbh->errstr;
		$sth2->execute() or die $dbh->errstr;
		my @unblockednotifyarray;
		my $unblocknotifyid;
		while ($unblocknotifyid = $sth2->fetchrow())
			{
			push (@unblockednotifyarray,$unblocknotifyid)
			};

	#end of database operations	
	

	my $queueline = "";
	my $queuehaddata = 0;
	#build email body
	#print activity counts
	my $emailbody = "Activity since last digest:\nBlocked: ".scalar (@blockednotifyarray)."\nUnblocked: ".scalar (@unblockednotifyarray)."\n";	
	
	#add blocked notifications to email body
	foreach (@blockednotifyarray)
		{
		#print $_;
		$queuehaddata = 1;
		#database operations to go get block detail
		my $sql1 = 
		q{
		select blocklog.block_when,blocklog.block_who,blocklog.block_ipaddress,blocklog.block_reverse,blocklog.block_why,blocklist.blocklist_until
		from blocklist
		inner join blocklog
		on blocklog.block_id = blocklist.blocklist_id
		where blocklog.block_id = ?
		};
		my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
		$sth1->execute($_) or die $dbh->errstr;
		my @blockedipinfo = $sth1->fetchrow_array();
		my $notifyidline = ("BLOCK - ".$blockedipinfo[0]." - ".$blockedipinfo[1]." - ".$blockedipinfo[2]." - ".$blockedipinfo[3]." - ".$blockedipinfo[4]." - ".$blockedipinfo[5]);
		$emailbody = $emailbody."\n".$notifyidline;		
		#alter the log entry to true for notified
		my $sql2 = 
			q{
			update blocklog
			set block_notified = true
			where block_id = ?
			};
		my $sth2 = $dbh->prepare($sql2) or die $dbh->errstr;
		$sth2->execute($_) or die $dbh->errstr;
		} #close while loop		
	#add unblocked notifications to email body
	foreach (@unblockednotifyarray)
		{
		$queuehaddata = 1;
		#database operations to go get block detail
		my $sql1 = 
			q{
			select unblocklog.unblock_when,unblocklog.unblock_who,unblocklog.unblock_why,blocklog.block_ipaddress,blocklog.block_reverse,blocklog.block_who,blocklog.block_why
			from unblocklog
			inner join blocklog on blocklog.block_id = unblocklog.unblock_id
			where unblocklog.unblock_id = ?
			};
			my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
		$sth1->execute($_) or die $dbh->errstr;
		my @unblockedipinfo = $sth1->fetchrow_array();
		my $notifyidline = ("UNBLOCK - ".$unblockedipinfo[0]." - ".$unblockedipinfo[1]." - ".$unblockedipinfo[2]." - ".$unblockedipinfo[3]." - ".$unblockedipinfo[4]." - Originally Blocked by: ".$unblockedipinfo[5]." for ".$unblockedipinfo[6]);
		$emailbody = $emailbody."\n".$notifyidline;		
		#alter the log entry to true for notified
		my $sql2 = 
			q{
			update unblocklog
			set unblock_notified = true
			where unblock_id = ?
			};
		my $sth2 = $dbh->prepare($sql2) or die $dbh->errstr;
		$sth2->execute($_) or die $dbh->errstr;
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
		#build the list of unique blockers
 		my $sql3 =
			q{
			select distinct block_who
			from blocklog
			inner join blocklist
			on blocklog.block_id = blocklist.blocklist_id
			};
		my $sth3 = $dbh->prepare($sql3) or die $dbh->errstr;
		$sth3->execute() or die $dbh->errstr;
		my $whoblockname;
		my $whocount;
		while ($whoblockname = $sth3->fetchrow())
			{
			#database operations to count blocks for each who
			my $sql4 = 
				q{
					select count(*)
					from blocklog
					inner join blocklist
					on blocklog.block_id = blocklist.blocklist_id
					where blocklog.block_who = ?
				};
			my $sth4 = $dbh->prepare($sql4) or die $dbh->errstr;
			$sth4->execute($whoblockname) or die $dbh->errstr;
			$whocount = $sth4->fetchrow();
			system("logger ".$logprepend."_STATS who=$whoblockname total_blocked=$whocount");
			} close #stat log line create while
		} #end if end stats
			
	} #close sub_bhr_digest

sub sub_get_ips
	{
	my @subgetipsofficialbhdips =();
	my @subgetipsforrealbhdips =();
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
	@subgetipsforrealbhdips=readpipe("/usr/bin/sudo /usr/bin/vtysh -c \"sh ip route static\" | grep \"/32\" | grep Null | awk {\'print \$2\'} |sed -e s/\\\\/32//g | grep -iv 38.32.0.0 | grep -iv 192.0.2.1 | grep -iv 192.0.2.2");
	chomp(@subgetipsforrealbhdips);
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
	#database read in information
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

sub sub_check_if_ip_good
	{
	my $ipaddress = shift;
	#check to see if the IP is good	
	if (is_ipv4($ipaddress))
		{
		return 1;
		}
	else
		{
		return 0;
		}
	} #close sub ip good


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

