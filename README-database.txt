postgres
user root
database blackhole owned by root

Need to allow apache procress to access to all tables and the seq



create table blocklog(block_id bigserial primary key unique, block_when timestamp not null, block_ipaddress inet not null, block_reverse VARCHAR(256),block_who VARCHAR(32) not null,block_why VARCHAR(256) not null,block_notified boolean DEFAULT false);

create table unblocklog(unblock_id bigint unique primary key references blocklog(block_id), unblock_when timestamp not null, unblock_who VARCHAR(32) not null,unblock_why VARCHAR(256) not null,unblock_notified boolean DEFAULT false);


create table blocklist (blocklist_id bigint unique primary key references blocklog(block_id), blocklist_until timestamp not null);


