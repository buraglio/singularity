Install postgresql (INSTALL.txt) and configure as such:

postgres
user root
database blackhole owned by root

Apache process needs to access to all tables and the seq

sudo su - postgres
psql -d template1
ALTER USER postgres WITH PASSWORD 'some password';

root@singularity singularity]# sudo -u postgres psql blackhole
psql (8.4.18)
Type "help" for help.

blackhole=# \dt
           List of relations
 Schema |    Name    | Type  |  Owner   
--------+------------+-------+----------
 public | blocklist  | table | postgres
 public | blocklog   | table | postgres
 public | unblocklog | table | postgres
(3 rows)


create table blocklog(block_id bigserial primary key unique, block_when timestamp not null, block_ipaddress inet not null, block_reverse VARCHAR(256),block_who VARCHAR(32) not null,block_why VARCHAR(256) not null,block_notified boolean DEFAULT false);

create table unblocklog(unblock_id bigint unique primary key references blocklog(block_id), unblock_when timestamp not null, unblock_who VARCHAR(32) not null,unblock_why VARCHAR(256) not null,unblock_notified boolean DEFAULT false);


create table blocklist (blocklist_id bigint unique primary key references blocklog(block_id), blocklist_until timestamp not null);


