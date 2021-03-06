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

my 			$q = new CGI;	# create new CGI object
print		$q->header;		# create the HTTP header
print		$q->start_html('Singularity Blackhole System');	# start the HTML
print		$q->center($q->h2('Blackhole Simple Web Interface'));        # level 2 header
print "\n";
print "<p>Username: ".$ENV{'REMOTE_USER'}."</p>\n";
print "<form METHOD=\"POST\" ACTION=\"bhwebsimpleproc.pl\">\n";
print "<p>Function?<br>\n";




print "	<input TYPE=\"radio\" VALUE=\"query\" NAME=\"function_to_perform\"CHECKED>Query - provide IP<br>\n";
print "	<input TYPE=\"radio\" VALUE=\"add\" NAME=\"function_to_perform\">Add - provide IP & Reason<br>\n";
print "	<input TYPE=\"radio\" VALUE=\"remove\" NAME=\"function_to_perform\">Remove - provide IP & Reason<br>\n";
print "	<input TYPE=\"radio\" VALUE=\"reconcile\" NAME=\"function_to_perform\">Reconcile</P>\n";
print "<table border=\"1\" width=\"100%\">\n";
print           "<tr>\n".
                        "     <td>IP<\/td>\n".
						"     <td>Reason<\/td>\n".
						"     <td>Duration<\/td>\n".
                "<\/tr>\n";
print           "<tr>\n".
                        "     <td><INPUT NAME=\"ip\" TYPE=text><\/td>\n".
						"     <td><INPUT NAME=\"reason\" TYPE=text><\/td>\n".
						"     <td><INPUT NAME=\"duration\" TYPE=text>\n".
						"     <select name=\"durationscale\">\n".
						"     <option value=\"days\">Days</option>\n".
						"     <option value=\"hours\">Hours</option>\n".
						"     <option value=\"minutes\">Minutes</option>\n".
						"     </select>   Leave blank for indefinite<\/td>\n".
                "<\/tr>\n";
print ("</table>\n");

print "<p>\n     <input TYPE=\"submit\" VALUE=\"Submit\">\n";
print "     <input TYPE=\"reset\" VALUE=\"Clear\">\n</p>\n";

print "<input type=\"hidden\" NAME=\"user\" value=\"".$ENV{'REMOTE_USER'}."\">\n";

print $q->end_html;  # end the HTML
print "\n";

