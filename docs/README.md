# Table of Contents

- [Postfwd GeoIP Botnet Block Plugin](#postfwd-geoip-botnet-block-plugin)
   - [Running with Docker](#running-with-docker)
   - [Development and Prototyping with Docker](#development-and-prototyping-with-docker)
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

This is a plugin to postfix firewall [postfwd](http://postfwd.org/) (also located on [github](https://github.com/postfwd/postfwd)) intended to block international spam botnets. International spam botnets are logging into hacked mail addresses via sasl login from multiple IP addresses based in usually more than 30 unique countries. After successful login, the hackers send spam from huge amount of unique IP addresses which circumvents traditional rate limits per IP address.

If you are interested in theory about how botnet spam works and motivation for creating this plugin, look at the blog on [Medium](https://medium.com/@ondrej.vaskoo/blocking-of-international-spam-botnets-a8a98e1ab589).

If you are interested in how your users got their mail accounts hacked, check out [bsdly](https://bsdly.blogspot.com) blog about slow distributed brute force attack on SSH passwords, which also applies to pop3/imap logins [Hail Mary Cloud](http://bsdly.blogspot.com/2013/10/the-hail-mary-cloud-and-lessons-learned.html).

## Plugin Compatility Matrix

- Release `v1.21` works with `postfwd1` and `postfwd2` versions `1.XX` (eg. `1.39`) and higher minor versions.
- Releases `v1.30` and higher are compatible only with `postfwd3` versions `2.XX`.
- `master` branch is compatible only with `postfwd3` versions `2.XX`.
- Supported database backends are **MySQL** and **PostgreSQL**.

## Running with Docker

Prebuilt ready-to-use Docker image is located on DockerHub and can be simply pulled by command:

```bash
# Postfwd3 tags
docker pull lirt/postfwd-anti-geoip-spam-plugin:latest
docker pull lirt/postfwd-anti-geoip-spam-plugin:v1.40
# Postfwd1, Postfwd2 tags
docker pull lirt/postfwd-anti-geoip-spam-plugin:v1.21
```

To run postfwd with geoip-plugin, run docker with configuration files mounted as volumes:

```bash
docker run \
    -v </absolute/path/to/anti-spam.conf>:/etc/postfwd/anti-spam.conf \
    -v </absolute/path/to/postfwd.cf>:/etc/postfwd/postfwd.cf \
    lirt/postfwd-anti-geoip-spam-plugin:latest
```

This will run `postfwd2` or `postfwd3` (based on docker tag) with default arguments, reading postfwd rules file from your mounted volume file `postfwd.cf` and using anti-spam configuration from your file `anti-spam.conf`.

## Development and Prototyping with Docker

Complete development environment with postfwd, anti-spam plugin and mysql/postgresql database correctly configured together can be run with command `docker-compose -f dev-compose-mysql.yml up` or `docker-compose -f dev-compose-postgresql.yml up` from directory `./tests/`.

Note for overriding postfwd arguments:

* Most important arguments to run `postfwd` in Docker are `--stdout` and `--nodaemon`. These arguments configure postfwd to log into standard output and stay in foreground.
* For running postfwd plugin, you also need to set argument `--plugins <path-to-plugin>` to correct location of plugin.

## Installation

To install this plugin follow next steps:

- Clone this repository.
- Install dependencies according to chapter [Dependencies](#dependencies).
- Run script `install.sh` to install plugin into _/etc/postfix/_.
- To load plugin to postfwd you must add argument `--plugins <PATH TO PLUGIN>` to postfwd command (or update it in _/etc/default/postfwd_).
- Configure postfwd rules according to chapter [Postfwd configuration](#postfwd-configuration).
- Create database table with indexes using following SQL statements (database is created on plugin startup but indexes can not be).

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

- `Postfwd2` or `Postfwd3`.
- Database (`MySQL` or `PostgreSQL`).
- Perl modules - `Geo::IP`, `DBI`, `Time::Piece`, `Config::Any`, `Net::Subnet`, `DBD::mysql` or `DBD::Pg`.
- GeoIP database located in `/usr/local/share/GeoIP/GeoIP.dat`.

#### Dependencies on RedHat based distributions

Install *GeoIP*, *Time*, *Config*, *DBI* and database modules with following command:

```bash
yum install -y 'perl(Geo::IP)' \
               'perl(Time::Piece)' \
               'perl(Config::Any)' \
               'perl(DBI)' \
               'perl(DBD::mysql)' \
               'perl(DBD::Pg)' \
               'perl(Net::Subnet)'
```

#### Dependencies on Debian based distributions

Install *GeoIP*, *Time*, *Config*, *DBI* and database modules with following command:

```bash
apt-get install -y libgeo-ip-perl \
                   libtime-piece-perl \
                   libconfig-any-perl \
                   libdbi-perl \
                   libdbd-mysql-perl \
                   libdbd-pg-perl \
                   libnet-subnet-perl \
                   geoip-database
```

## Configuration

Plugin configuration file `anti-spam.conf` is INI style configuration file, in which values must NOT be quoted!

### Postfwd configuration

Add following rules to postfwd configuration file `postfwd.cf`. You can use your own message and value of parameter `client_uniq_country_login_count`, which sets maximum number of unique countries to allow user to log in via sasl.

```bash
# Anti spam botnet rule:
# This example shows how to limit e-mail address defined by `sasl_username`
# to be able to login from max. 5 different countries or 20 different IP
# addresses, otherwise it will be blocked from sending messages.

id=COUNTRY_LOGIN_COUNT ;
   sasl_username=~^(.+)$ ;
   incr_client_country_login_count != 0 ;
   action=dunno ;

id=BAN_BOTNET_COUNTRY ;
   sasl_username=~^(.+)$ ;
   client_uniq_country_login_count > 5 ;
   action=rate(sasl_username/1/3600/554 Your mail account ($$sasl_username) was compromised. Please change your password immediately after next login.) ;

id=BAN_BOTNET_IP ;
   sasl_username=~^(.+)$ ;
   client_uniq_ip_login_count > 20 ;
   action=rate(sasl_username/1/3600/554 Your mail account ($$sasl_username) was compromised. Please change your password immediately after next login.) ;
```

### Database backend configuration

Update configuration file `/etc/postfix/anti-spam.conf` with your credentials to selected database backend (tested with MySQL/PostgreSQL). Don't forget to use proper driver and port.

In case you use different path as `/etc/postfix/anti-spam.conf` and `/etc/postfix/anti-spam-sql-st.conf` to main configuration file, export environment variables `POSTFWD_ANTISPAM_MAIN_CONFIG_PATH` and `POSTFWD_ANTISPAM_SQL_STATEMENTS_CONFIG_PATH` with your custom path.

```conf
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

### Application configuration

The plugin is by default configured to remove records for users with last login date older than 24 hours. This interval can be changed in configuration `app.db_flush_interval`.

Plugin looks by default for GeoIP database file in path `/usr/local/share/GeoIP/GeoIP.dat`. You can override this path in configuration `app.geoip_db_path`.

You can whitelist set of IP addresses or subnets in CIDR format by using configuration setting `app.ip_whitelist`. Whitelisting means, that if client logs into email account from IP address, which IS in whitelist, it will NOT increment login count for this pair of `sasl_username|client_address`.

```conf
[app]
# Flush database records with last login older than 1 day
db_flush_interval = 86400
geoip_db_path = /usr/local/share/GeoIP/GeoIP.dat
# IP whitelist must be valid comma separated strings in CIDR format without whitespaces.
# It specifies IP addresses which will NOT be counted into user logins database.
ip_whitelist = 198.51.100.0/24,203.0.113.123/32
# ip_whitelist_path = /etc/postfwd/ip_whitelist.txt
```

## Logging

Plugin is by default logging into standard output. This can be changed in configuration file by setting value for statement `logfile` in `[logging]` section.

You can disable logging completely by updating value of statement `debug` to `0` in section `[debugging]`.

Example configuration of file `anti-spam.conf`:

```conf
[logging]
# Remove statement `logfile`, or set it to empty `logfile = ` to log into STDOUT
logfile = /var/log/postfwd_plugin.log
autoflush = 0

[debugging]
# Enable(1) or disable(0) logging
debug = 1
# Make log after exceeding unique country count limit
country_limit = 5
# Make log after exceeding unique ip count limit
ip_limit = 20
```

If you use `logrotate` to rotate anti-spam logs, use option `copytruncate` which prevents [logging errors](https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin/issues/6) when log file is rotated.


## Useful database queries

Located in separate `README` file [DB-Queries.md](DB-Queries.md).

## Development and testing

Check for proper linting with `perlcritic postfwd-anti-spam.plugin`.

Change into directory `./test` and execute `docker-compose -f dev-compose-mysql.yml up` or `docker-compose -f dev-compose-postgresql.yml up` to get postfwd and mysql/postgresql database up.

Send SMTP requests to postfwd policy server, or use testing script to check functionality:
```bash
# Manually send postfwd request
export CLIENT_ADDRESS='1.2.3.4'
export SASL_USERNAME='testuser@example.com'
nc 127.0.0.1 10040 < <(envsubst < dev-request)

# Run testing script
cd tests
DATABASES="mysql postgresql" RUN_COMPOSE=1 ./integration-compose-test.sh
```
