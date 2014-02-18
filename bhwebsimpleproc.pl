#!/usr/bin/perl

# Copyright (c) 2014, James Eyrich, Nick Buraglio
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#  list of conditions and the following disclaimer.  
# 2. Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are those
# of the authors and should not be interpreted as representing official policies,
# either expressed or implied, of the FreeBSD Project.


use strict;
use warnings;
use CGI;

#bhcore.pl file location
my $binlocation = "/services/blackhole/bin/";


my $q = new CGI;			# create new CGI object
print		$q->header;		 # create the HTTP header
print		$q->start_html('Singularity Blackhole System');	# start the HTML
print		$q->center($q->h2('Blackhole Web Simple Process Page'));        # level 2 header
print "\n";
print "<form METHOD=\"POST\" ACTION=\"bhwebsimple.pl\">\n";

#receive values from display page
my $scriptfunciton = $q->param('function_to_perform');

	
	# figure out what function to perform and call the correct sub function.
	if ($scriptfunciton eq "add")
		{
		my $add_ip = $q->param('ip');
		my $add_user = $q->param('user');
		my $add_reason = $q->param('reason');
		my $add_duration = $q->param('duration');
		my $durationscale = $q->param('durationscale');
		chomp $durationscale;
		my $durationscalefactor;
		my $howlong = "";
		my $blocktimedescribed = "";
		my $everythingisok = 1;
		if ($add_reason eq "")
			{
			print ("<p>You must specify a reason</p>\n");
			$everythingisok = 0;
			}
		else
			{
			$add_reason =~ tr/-//d; #using dashes/hyphens in the BH log file for separators, need to remove from the reason
			$add_reason =~ tr/,//d; #using commas in the individual log file for separators, need to remove from the reason
			}
		if ($add_user eq "")
			{
			print ("<p>You must specify a user or service</p>\n");
			$everythingisok = 0;
			}
		else
			{
			$add_user =~ tr/-//d; #using dashes/hyphens in the BH log file for separators, need to remove from the reason
			$add_user =~ tr/,//d; #using commas in the individual log file for separators, need to remove from the reason
			}	
		if ($add_duration eq "")
			{
			$howlong = 0; #indefinite
			$blocktimedescribed = "indefinite";
			}
		elsif ($add_duration == 0)
			{
			$howlong = 0; #indefinite
			#$blocktimedescribed = "indefinite";
			}
		elsif (sub_is_integer_string($add_duration) == 0)
			{
			$howlong = 0;
			$blocktimedescribed = "indefinite";
			}
		else
			{
			if ($durationscale eq "minutes")
				{
				$durationscalefactor = 60;
				}
			elsif ($durationscale eq "hours")
				{
				$durationscalefactor = 3600;
				}
			elsif ($durationscale eq "days")
				{
				$durationscalefactor = 86400;
				}
			$howlong=($add_duration * $durationscalefactor); #list in seconds;
			$blocktimedescribed = ($add_duration." ".$durationscale);
			}
		if ($everythingisok)
			{
			print "<p>Blocking ".$add_ip." for user ".$add_user." for reason ". $add_reason." for ".$blocktimedescribed."</p>\n";
			my $bhrcommand = $binlocation."bhcore.pl add ".$add_user." ".$add_ip." \"".$add_reason."\" ".$howlong;
			print "Calling Core BH script<br>\n";
			print "Executing: ".$bhrcommand."<br>\n";
			open(BHCORE,"$bhrcommand |");
				while (<BHCORE>)
				{
				chomp;
				print "$_<br>\n";
				}
			}
		}
	
	elsif ($scriptfunciton eq "remove")
		{
		#print $numberofips." IPs in table<br>\n";
		my $remove_user = $q->param('user');
		#my $checkboxname;
		my $ipaddress;
		my $reason;
		#my $reasonname;
		my $everythingisok = 1;
		if ($remove_user eq "")
			{
			print ("<p>You must specify a user or service</p>\n");
			$everythingisok = 0;
			}
		else
			{
			$remove_user =~ tr/-//d; #using dashes/hyphens in the BH log file for separators, need to remove from the reason
			$remove_user =~ tr/,//d; #using commas in the individual log file for separators, need to remove from the reason
			}
		if ($everythingisok)
			{
			$ipaddress = $q->param('ip');
			$reason = $q->param('reason');
			if (defined $ipaddress)
				{
				if ($reason eq "")
					{
					print "<p>You must provide a reason to unblock ".$ipaddress."</p>\n";
					}
				else
					{
					print "<p>unblocking ".$ipaddress." for: ".$reason." for you user: ".$remove_user."</p>\n";
					my $bhrcommand = $binlocation."bhcore.pl remove ".$remove_user." ".$ipaddress." \"".$reason."\"";
					print "Calling Core BH script<br>\n";
					print "Executing: ".$bhrcommand."<br>\n";
					open(BHCORE,"$bhrcommand |");
					while (<BHCORE>)
						{
						chomp;
						print "$_<br>\n";
						}
					}
				}
			
			}	
		}

	elsif ($scriptfunciton eq "query")
		{
		my $ipaddress = $q->param('ip');
		print "<p>Querying ".$ipaddress."</p>\n";
					my $bhrcommand = $binlocation."bhcore.pl query ".$ipaddress;
					print "Calling Core BH script<br>\n";
					print "Executing: ".$bhrcommand."<br>\n";
					open(BHCORE,"$bhrcommand |");
					while (<BHCORE>)
						{
						chomp;
						print "$_<br>\n";
						}
		}
	
	elsif ($scriptfunciton eq "reconcile")
		{
		#sub_bhr_reconcile();
		my $bhrcommand = $binlocation."bhcore.pl reconcile";
		print "Calling Core BH script<br>\n";
		print "Executing: ".$bhrcommand."<br>\n";
		print "This may take some time<br>BH Core output-None is okay for reconcile :<br>\n";
		open(BHCORE,"$bhrcommand |");
			while (<BHCORE>)
			{
			chomp;
			print "$_<br>\n";
			}
		}		
	else
		{
		print "<p>No function performed</p>\n";
		}

		
print "<p>\n     <input TYPE=\"submit\" VALUE=\"Continue\"></p>\n";
print $q->end_html;  # end the HTML
print "\n";

#end of program

	
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
	}
