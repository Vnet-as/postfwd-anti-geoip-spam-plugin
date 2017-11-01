# **Table of Contents**

- [Postfwd GeoIP Botnet Block Plugin](#postfwd-geoip-botnet-block-plugin)
   - [Installation](#installation)
   - [Dependencies](#dependencies)
      - [RedHat based distributions](#dependencies-on-redhat-based-distributions)
      - [Debian based distributions](#dependencies-on-debian-based-distributions)
   - [Configuration](#configuration)
      - [Postfwd configuration](#postfwd-configuration)
      - [Database backend configuration](#database-backend-configuration)
      - [Database cleanup period](#database-cleanup-period)
   - [Logging](#logging)
   - [Useful database queries](#useful-database-queries)
   - [Development and testing](#development-and-testing)

# Postfwd GeoIP Botnet Block Plugin

This is plugin to postfix firewall [postfwd](http://postfwd.org/) also located on [github](https://github.com/postfwd/postfwd) intended to block international spam botnets. International spam botnets are logging into hacked mail addresses via sasl login from multiple IP addresses based in usually more than 30 unique countries. After successful login, the hackers send spam from huge amount of unique IP addresses which circumvents traditional rate limits per IP address.

If you are interested in theory of how botnet spam works and motivation for creating this plugin, check the blog and tutorial on [HowToForge](https://www.howtoforge.com/tutorial/blocking-of-international-spam-botnets-postfix-plugin/).

If you are interested in how your users got their mail accounts hacked, check out `bsdly` blog about slow distributed brute force attack on SSH passwords, which also applies to pop3/imap logins [Hail Mary Cloud](http://bsdly.blogspot.sk/2013/10/the-hail-mary-cloud-and-lessons-learned.html).

Plugin was tested with `postfwd2 ver. 1.35` with `MySQL` and `PostgreSQL` backend.

## Installation

For installation follow next steps
- Clone this repository.
- Install dependencies according to chapter [Dependencies](#dependencies).
- Run script `install.sh` to install plugin into `/etc/postfix/`
- To load plugin to postfwd you must add argument `--plugins <PATH TO PLUGIN>` to postfwd command (or in /etc/default/postfwd).
- Configure postfwd rules according to chapter [Postfwd configuration](#postfwd-configuration)
- Create database table with indexes using following SQL statement (database is created on plugin startup but indexes can not be).

```sql
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

### Dependencies

* Postfwd
* Database (MySQL, PostgreSQL)
* Geo::IP
* DBI
* Time::Piece
* Config::Any

#### Dependencies on RedHat based distributions

* Install *GeoIP*, *Time*, *Config* and *DBI* module with `yum install -y perl\(Geo::IP\) perl\(Time::Piece\) perl\(Config::Any\) perl\(DBI\)`.


* To install database perl modules execute `yum install perl\(DBD::mysql\)'` for `MySQL` or `yum install perl\(DBD::Pg\)` for `PostgreSQL`.


#### Dependencies on Debian based distributions

* Install *GeoIP*, *Time*, *Config* and *DBI* module with `apt-get install -y libgeo-ip-perl libtime-piece-perl libconfig-any-perl libdbi-perl`.


* To install database perl modules execute `apt-get install -y libdbd-mysql-perl` for `MySQL` or `apt-get install -y libdbd-pg-perl` for `PostgreSQL`.


## Configuration

### Postfwd configuration

Add following rules to postfwd configuration file `postfwd.cf`. You can use your own message and parameter value `client_uniq_country_login_count` which sets maximum number of unique countries to allow user to log in via sasl.

```bash
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
   action=jump(BAN_BOTNET)

id=BAN_BOTNET ; \
   sasl_username=~^(.+)$ ; \
   &&PRIVATE_RANGES ; \
   &&LOOPBACK_RANGE ; \
   client_uniq_country_login_count > 5 ; \
   action=rate(sasl_username/1/3600/554 Your mail account ($$sasl_username) was compromised. Please change your password immediately after next login.)
```

### Database backend configuration

Update configuration file with your credentials to selected database backend (tested with mysql/postgresql). Don't forget to use proper driver and port.

```INI
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
### Database cleanup period

The plugin is by default configured to remove records for users with last login date older than 24 hours. This interval can be changed in configuration file.

```INI
[app]
# Flush database records with last login older than 1 day
db_flush_interval = 86400
```

## Logging

By default logging for debuging purposes is enabled. Log file is located in `/tmp/postfwd_plugin.log`. You can disable logging by updating configuration file.

```INI
[debugging]
# Enable(1) or disable(0) logging
debug = 1
# Make log after exceeding unique country count limit
country_limit = 5
```

If you use `logrotate` to rotate anti-spam logs, use option `copytruncate` which prevents logging errors when log file is rotated. See issue #6 for more information.


## Useful database queries

##### 1. Print mail accounts, total number of logins, total number of unique ip addresses and unique states for users who were logged in from more than 3 countries (Most useful for me)

```sql
SELECT sasl_username,
   SUM(login_count),
   COUNT(*) AS ip_address_count,
   COUNT(DISTINCT state_code) AS country_login_count
FROM postfwd_logins
GROUP BY sasl_username
HAVING country_login_count > 3;
```

##### 2. Print users who are logged in from more than 1 country and write number of countries from which they were logged in

```sql
SELECT sasl_username, COUNT(DISTINCT state_code) AS country_login_count
FROM postfwd_logins
GROUP BY sasl_username
HAVING country_login_count > 1;
```

##### 3. Dump all IP addresses and login counts for users who were logged in from more than 1 country

```sql
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
```sql
SELECT SUM(login_count)
FROM postfwd_logins
WHERE sasl_username='<SASL_USERNAME>';
```

##### 5. COUNT of distinct login *state_codes* for user <SASL_USERNAME>
```sql
SELECT COUNT(DISTINCT state_code)
FROM postfwd_logins
WHERE sasl_username='<SASL_USERNAME>';
```

##### 6. COUNT of distinct IP addresses for user <SASL_USERNAME>
```sql
SELECT COUNT(DISTINCT ip_address)
FROM postfwd_logins
WHERE sasl_username='<SASL_USERNAME>';
```

##### 7. COUNT of IP addresses for each *state_code* for user <SASL_USERNAME>
```sql
SELECT sasl_username, state_code, COUNT(state_code) AS country_login_count
FROM postfwd_logins
WHERE sasl_username='<SASL_USERNAME>'
GROUP BY state_code
ORDER BY country_login_count;
```

## Development and testing

### Check for proper linting

Install [Perl Critic module](https://github.com/Perl-Critic/Perl-Critic) and then run script `perl lint.pl`.
