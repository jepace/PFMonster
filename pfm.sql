drop table if exists pfm;
drop table if exists pfm_test;
drop table if exists pfm_policy;

begin;

create table pfm (
    id serial not null primary key,
	login varchar(120) not null unique,
    timeleft integer not null default 0,
    today integer not null default 0,
    isrunning boolean not null default false,
	last_login timestamp default null,
	email varchar(250) not null default '',
	full_name varchar(250) not null default '',
	password varchar(250) not null default '',
	created timestamp default null);

insert into pfm (login, timeleft, today, email, full_name,created) 
    values ('jepace', 60*60, 2*60*60, 'james@pacehouse.com', 'James E. Pace', CURRENT_TIMESTAMP);
insert into pfm (login, timeleft, today, email, full_name, created) 
    values ('ethan', 60*60, 2*60*60, 'ethan@pacehouse.com', 'Ethan Pace', CURRENT_TIMESTAMP);
insert into pfm (login, timeleft, today, email, full_name, created) 
    values ('sloane', 60*60, 2*60*60, 'sloane@pacehouse.com', 'Sloane Pace', CURRENT_TIMESTAMP);

create table pfm_test (
    id serial not null primary key,
	login varchar(120) not null unique,
    timeleft integer not null default 0,
    today integer not null default 0,
    isrunning boolean not null default false,
	last_login timestamp default null,
	email varchar(250) not null default '',
	full_name varchar(250) not null default '',
	password varchar(250) not null default '',
	created timestamp default null);

insert into pfm_test (login, timeleft, today, email, full_name,created) 
    values ('jepace', 5*60*60, 2*60*60, 'james@pacehouse.com', 'James E. Test', CURRENT_TIMESTAMP);
insert into pfm_test (login, timeleft, today, email, full_name, created) 
    values ('ethan', 5*60*60, 2*60*60, 'ethan@pacehouse.com', 'Ethan Test', CURRENT_TIMESTAMP);
insert into pfm_test (login, timeleft, today, email, full_name, created) 
    values ('sloane', 5*60*60, 2*60*60, 'sloane@pacehouse.com', 'Sloane Test', CURRENT_TIMESTAMP);

create table pfm_policy (
    id serial not null primary key,
    login varchar(120) not null unique,
    max_time_day integer not null default 0,
    curr_time_day integer not null default 0,
    max_contig_time integer not null default 0,
    day_0_start integer default null,
    day_0_end integer default null,
    day_1_start integer default null,
    day_1_end integer default null,
    day_2_start integer default null,
    day_2_end integer default null,
    day_3_start integer default null,
    day_3_end integer default null,
    day_4_start integer default null,
    day_4_end integer default null,
    day_5_start integer default null,
    day_5_end integer default null,
    day_6_start integer default null,
    day_6_end integer default null
);

insert into pfm_policy (login, max_time_day, max_contig_time)
    values ('jepace', 16*60*60, 16*60*60);
insert into pfm_policy (login, max_time_day, max_contig_time)
    values ('ethan', 6*60*60, 3*60*60);
insert into pfm_policy (login, max_time_day, max_contig_time)
    values ('sloane', 6*60*60, 3*60*60);

commit;
