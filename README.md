# **Table of Contents**

(*generated with [DocToc](http://doctoc.herokuapp.com/)*)
- [Postfwd GeoIP Botnet Block Plugin](#)
   - [Installation](#)
   - [Dependencies](#)
         - [RedHat based distributions](#)
         - [Debian based distributions](#)
   - [Configuration](#)
            - [Database backend configuration](#)
            - [Database cleanup period](#)
            - [Logging](#)
   - [Useful database queries](#)
   - [Automatic Tests (In progress)](#)
   - [TODO list](#)

# Postfwd GeoIP Botnet Block Plugin

This is plugin to postfix firewall `postfwd` intended to block international spam botnets. International spam botnets are logging into hacked mail addresses via sasl login from multiple IP addresses based in usually more than 30 unique countries. After successful login, the hackers send spam from many unique IP addresses which circumvents traditional rate limits per IP address.

## Installation

For installation follow next steps and also instructions in section [dependencies](#dependencies)
- Copy plugin to your mail server. 
- Install dependencies according to chapter `Dependencies`. 
- To load plugin to postfwd you must add argument `--plugins <PATH TO PLUGIN>` to postfwd command. 
- Add following rules to postfwd configuration file `postfwd.cf`. You can use your own message and parameter value `client_uniq_country_login_count` which sets maximum number of unique countries to allow user to log in via sasl. 

```
# Anti spam botnet rule
# This example shows how to limit e-mail address defined by `sasl_username` to be able to login from max. 5 different countries, otherwise they will be blocked to send messages.
id=COUNTRY_LOGIN_COUNT ; \
   sasl_username=~^(.+)$ ; \
   incr_client_country_login_count != 0 ; \
   action=dunno

id=BAN_BOTNET ; \
   sasl_username=~^(.+)$ ; \
   client_uniq_country_login_count > 5 ; \
   action=rate(sasl_username/1/3600/554 Your mail account $$sasl_username was compromised. Please change your password immediately after next login.)
```

Create database table with indexes (Optional, because if database is not created it is always created on plugin startup)

```
CREATE TABLE IF NOT EXISTS postfwd_logins (
   sasl_username varchar(100),
   ip_address varchar(16),
   state_code varchar(4),
   login_count int,
   last_login timestamp
);
CREATE INDEX postfwd_sasl_client_state_index ON postfwd_logins (sasl_username, ip_address, state_code);
CREATE INDEX postfwd_sasl_username ON postfwd_logins (sasl_username);
```

## Dependencies

* Geo::IP
* DBI
* Time::Piece


#### RedHat based distributions 

Install *GeoIP* and *Time* module with `yum install -y perl\(Geo::IP\) perl\(Time::Piece\)`
If you use Mysql backend, install DBD mysql module `yum install 'perl(DBD::mysql)'`
If you use PostgreSQL backend, DBD mysql module `yum install 'perl(DBD::Pg)'`
For other backends, please refer to DBD modules on CPAN.

#### Debian based distributions 

Install *GeoIP* and *Time* module with `apt-get install -y libgeo-ip-perl libtime-piece-perl`
If you use Mysql backend, install DBD mysql module `apt-get install -y libdbd-mysql-perl`
If you use PostgreSQL backend, DBD mysql module `apt-get install -y libdbd-pg-perl`
For other backends, please refer to DBD modules on CPAN.


## Configuration

##### Database backend configuration

First configure database backend with your credentials (eg. mysql). Use proper driver and port if you are using different backend.

```
# my $driver = "Pg"; 
my $driver = "mysql"; 
my $database = "test";
my $host = "127.0.0.1";
my $port = "3306";
# my $port = "5432";
my $dsn = "DBI:$driver:database=$database;host=$host;port=$port";
my $userid = "testuser";
my $password = "password";
```
##### Database cleanup period

The database is by default set to remove records for users with last login date older than 24 hours, but can be changed within code to arbitrary time period (DAY, WEEK, MONTH...) by changing variable `$flush_interval`.

##### Logging

By default logging for debuging purposes is enabled. Log file is located in `/tmp/postfwd_plugin.log`.
You can disable logging by changing `use constant DEBUG => 1;` to `use constant DEBUG => 0;`

## Useful database queries 

1. Print mail accounts, total number of logins, total number of unique ip addresses and unique states for users who were logged in from more than 3 countries (Most useful for me)
```
SELECT sasl_username, 
   SUM(login_count), 
   COUNT(*) AS ip_address_count, 
   COUNT(DISTINCT state_code) AS country_login_count 
FROM postfwd_logins 
GROUP BY sasl_username 
HAVING country_login_count > 3;
```

1. Print users who are logged in from more than 1 country and write number of countries from which they were logged in
```
SELECT sasl_username, COUNT(DISTINCT state_code) AS country_login_count 
FROM postfwd_logins 
GROUP BY sasl_username 
HAVING country_login_count > 1;
```

2. Dump all IP addresses and login counts for users who were logged in from more than 1 country
```
SELECT * FROM postfwd_logins 
JOIN (
   SELECT sasl_username 
   FROM postfwd_logins 
   GROUP BY sasl_username 
   HAVING COUNT(DISTINCT state_code) > 1
   ) AS users_logged_from_multiple_states 
      ON postfwd_logins.sasl_username = users_logged_from_multiple_states.sasl_username 
ORDER BY postfwd_logins.sasl_username;
```

3. SUM of logins for user <SASL_USERNAME>
```
SELECT SUM(login_count) 
FROM postfwd_logins 
WHERE sasl_username='<SASL_USERNAME>';
```

4. COUNT of distinct login *state_codes* for user <SASL_USERNAME>
```
SELECT COUNT(DISTINCT state_code) 
FROM postfwd_logins 
WHERE sasl_username='<SASL_USERNAME>';
```

5. COUNT of distinct IP addresses for user <SASL_USERNAME>
```
SELECT COUNT(DISTINCT ip_address) 
FROM postfwd_logins 
WHERE sasl_username='<SASL_USERNAME>';
```

6. COUNT of IP addresses for each *state_code* for user <SASL_USERNAME>
```
SELECT sasl_username, state_code, COUNT(state_code) AS country_login_count 
FROM postfwd_logins 
WHERE sasl_username='<SASL_USERNAME>' 
GROUP BY state_code 
ORDER BY country_login_count;
```

## Automatic Tests (In progress)

Create database and user (MySQL)

```
CREATE DATABASE test;
CREATE USER 'testuser'@'localhost' IDENTIFIED BY 'password';
GRANT ALL ON test.* TO 'testuser'@'localhost';
```

Create database and user (PostgreSQL)

```
CREATE DATABASE test;
CREATE USER testuser WITH PASSWORD 'password';
GRANT ALL PRIVILEGES ON DATABASE test to testuser;
```

Execute test case with default credentials

```
tests/01-basic-random-ip-test.pl
```

## TODO list

1. Test with IPv6 addresses
2. Encrypt DB Password or store to file (DBIx)
3. Logging with Log4Perl
4. Dump database in intervals to supply logs for analysis.
5. Automatic testing

