Put some better install instructions in here. 

This software should be as flexible as possible and able to run on any platform that supports Quagga, a web server that can do CGI, postgresql and perl.

CentOS:

Beginning with my standard Base CentOS 6.5 install:


sudo rpm --import http://apt.sw.be/RPM-GPG-KEY.dag.txt
yum install -y wget
wget http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.3-1.el6.rf.x86_64.rpm 
rpm -i rpmforge-release-0.5.3-1.el6.rf.x86_64.rpm 
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
rpm -ivh epel-release-6-8.noarch.rpm

yum update
yum install -y screen etckeeper locate rkhunter logwatch
yum upgrade

vi /etc/selinux/config

SELINUX=disabled

reboot

For the requirements for singularity to run:

yum install -y httpd postgresql-server postgresql quagga net-snmp perl-Data-Validate-IP perl-NetAddr-IP perl-Email-MIME perl-Net-DNS perl-DBI perl-DBD-Pg perl-CGI 

service postgresql initdb
service postgresql start
service https start

chkconfig postgresql on
chkconfig httpd on

########### You should really use ssl but in case you don't want to, here are the standard http rules:

iptables -A INPUT -i eth0 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
ip6tables -A INPUT -i eth0 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT

########### Allow ssl for v4 and v6

iptables -A INPUT -i eth0 -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
ip6tables -A INPUT -i eth0 -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT

service iptables save
service ip6tables save

service zebra start
chkconfig zebra on

Debian:

Add directions for Debian

FreeBSD: 

Add directions for FreeBSD
