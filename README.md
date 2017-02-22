# **Table of Contents**

- [Postfwd GeoIP Botnet Block Plugin](#postfwd-geoip-botnet-block-plugin)
   - [Installation](#installation)
   - [Dependencies](#dependencies)
      - [RedHat based distributions](#redhat-based-distributions)
      - [Debian based distributions](#debian-based-distributions)
   - [Configuration](#configuration)
      - [Database backend configuration](#database-backend-configuration)
      - [Database cleanup period](#database-cleanup-period)
      - [Logging](#logging)
   - [Useful database queries](#useful-database-queries)
   - [Automatic Tests (In progress)](#-automatic-tests-in-progress)
   - [TODO list](#todo-list)

# Postfwd GeoIP Botnet Block Plugin

This is plugin to postfix firewall `postfwd` (http://postfwd.org/) intended to block international spam botnets. International spam botnets are logging into hacked mail addresses via sasl login from multiple IP addresses based in usually more than 30 unique countries. After successful login, the hackers send spam from huge amount of unique IP addresses which circumvents traditional rate limits per IP address.

If you are interested in theory of how botnet spam works and motivation for creating this plugin, check the blog and tutorial on [HowToForge](https://www.howtoforge.com/tutorial/blocking-of-international-spam-botnets-postfix-plugin/).

If you are interested in how your users got their mail accounts hacked, check out `bsdly` blog about slow distributed brute force attack on SSH passwords, which also applies to pop3/imap logins [Hail Mary Cloud](http://bsdly.blogspot.sk/2013/10/the-hail-mary-cloud-and-lessons-learned.html).

Plugin was tested with `postfwd2 ver. 1.35` with `MySQL` and `PostgreSQL` backend. 

## Installation

For installation follow next steps
- Clone this repository.
- Copy configuration file `anti-spam.conf` to `/etc/postfix/anti-spam.conf` and update configuration according to section [Configuration](#Configuration).
- Copy SQL statements file `anti-spam-sql-st.conf` to `/etc/postfix/anti-spam-sql-st.conf`.
- Ensure that configuration files are readable by user which runs `postfwd` (usually user `postfw`) and that plugin file is also readable by him.
- Install dependencies according to chapter [Dependencies](#dependencies).
- To load plugin to postfwd you must add argument `--plugins <PATH TO PLUGIN>` to postfwd command (eg. in /etc/default/postfwd). 
- Add following rules to postfwd configuration file `postfwd.cf`. You can use your own message and parameter value `client_uniq_country_login_count` which sets maximum number of unique countries to allow user to log in via sasl. 

```
# Anti spam botnet rule
# This example shows how to limit e-mail address defined by `sasl_username` to be able to login from max. 5 different countries, otherwise they will be blocked to send messages.

&&PRIVATE_RANGES { \
   client_address=!!(10.0.0.0/8) ; \
   client_address=!!(172.16.0.0/12) ; \
   client_address=!!(192.168.0.0/16) ; \
};
&&LOOPBACK_RANGE { \
   client_address=!!(127.0.0.0/8) ; \
};

id=COUNTRY_LOGIN_COUNT ; \
   sasl_username=~^(.+)$ ; \
   &&PRIVATE_RANGES ; \
   &&LOOPBACK_RANGE ; \
   incr_client_country_login_count != 0 ; \
   action=dunno

id=BAN_BOTNET ; \
   sasl_username=~^(.+)$ ; \
   &&PRIVATE_RANGES ; \
   &&LOOPBACK_RANGE ; \
   client_uniq_country_login_count > 5 ; \
   action=rate(sasl_username/1/3600/554 Your mail account ($$sasl_username) was compromised. Please change your password immediately after next login.)
```

- Create database table with indexes (database is created on plugin startup but indexes are not).

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
* Config::Any


#### RedHat based distributions 

* Install *GeoIP*, *Time* and *Config* module with `yum install -y perl\(Geo::IP\) perl\(Time::Piece\) perl\(Config::Any\)`.


* If you use Mysql backend, install DBD mysql module `yum install 'perl(DBD::mysql)'`.


* If you use PostgreSQL backend, DBD mysql module `yum install 'perl(DBD::Pg)'`.


* For other backends, please refer to DBD modules on CPAN.

#### Debian based distributions 

* Install *GeoIP*, *Time* and *Config* module with `apt-get install -y libgeo-ip-perl libtime-piece-perl libconfig-any-perl`.


* If you use Mysql backend, install DBD mysql module `apt-get install -y libdbd-mysql-perl`.


* If you use PostgreSQL backend, DBD mysql module `apt-get install -y libdbd-pg-perl`.


* For other backends, please refer to DBD modules on CPAN.


## Configuration

Copy configuration file `anti-spam.conf` to `/etc/postfix/anti-spam.conf` and also file `anti-spam-sql-st.conf` to `/etc/postfix/anti-spam-sql-st.conf`.

#### Database backend configuration

Update configuration file with your credentials to selected database backend (tested with mysql/postgresql). Don't forget to use proper driver and port.

```
[database]
# driver = Pg
driver = mysql
database = test
host = localhost
# port = 5432
port = 3306
userid = testuser
password = password
```
#### Database cleanup period

The plugin is by default configured to remove records for users with last login date older than 24 hours. This interval can be changed in configuration file.

```
[app]
# Flush database records with last login older than 1 day
db_flush_interval = 86400  
```

#### Logging

By default logging for debuging purposes is enabled. Log file is located in `/tmp/postfwd_plugin.log`. You can disable logging by updating configuration file.

```
[debugging]
# Enable(1) or disable(0) logging
debug = 1
# Make log after exceeding unique country count limit
country_limit = 5

```

## Useful database queries 

##### 1. Print mail accounts, total number of logins, total number of unique ip addresses and unique states for users who were logged in from more than 3 countries (Most useful for me)

```
SELECT sasl_username, 
   SUM(login_count), 
   COUNT(*) AS ip_address_count, 
   COUNT(DISTINCT state_code) AS country_login_count 
FROM postfwd_logins 
GROUP BY sasl_username 
HAVING country_login_count > 3;
```

##### 2. Print users who are logged in from more than 1 country and write number of countries from which they were logged in 

```
SELECT sasl_username, COUNT(DISTINCT state_code) AS country_login_count 
FROM postfwd_logins 
GROUP BY sasl_username 
HAVING country_login_count > 1;
```

##### 3. Dump all IP addresses and login counts for users who were logged in from more than 1 country

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

##### 4. SUM of logins for user <SASL_USERNAME>
```
SELECT SUM(login_count) 
FROM postfwd_logins 
WHERE sasl_username='<SASL_USERNAME>';
```

##### 5. COUNT of distinct login *state_codes* for user <SASL_USERNAME>
```
SELECT COUNT(DISTINCT state_code) 
FROM postfwd_logins 
WHERE sasl_username='<SASL_USERNAME>';
```

##### 6. COUNT of distinct IP addresses for user <SASL_USERNAME>
```
SELECT COUNT(DISTINCT ip_address) 
FROM postfwd_logins 
WHERE sasl_username='<SASL_USERNAME>';
```

##### 7. COUNT of IP addresses for each *state_code* for user <SASL_USERNAME>
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
tests/02-test-while-disconnect.pl
```

## TODO list

1. Test with IPv6 addresses
2. Automatic testing
3. Put logging into separate module file
4. Add auto installation script
5. Test with sqlite database