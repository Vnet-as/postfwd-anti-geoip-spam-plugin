# Table of Contents

- [Postfwd GeoIP Botnet Block Plugin](#postfwd-geoip-botnet-block-plugin)
  - [Plugin Compatibility Matrix](#plugin-compatibility-matrix)
  - [Running with Docker](#running-with-docker)
  - [Installation](#installation)
    - [Dependencies](#dependencies)
      - [Dependencies on RedHat based distributions](#dependencies-on-redhat-based-distributions)
      - [Dependencies on Debian based distributions](#dependencies-on-debian-based-distributions)
  - [Configuration](#configuration)
    - [Postfwd configuration](#postfwd-configuration)
    - [Database backend configuration](#database-backend-configuration)
    - [Application configuration](#application-configuration)
    - [Logging](#logging)
  - [Useful database queries](#useful-database-queries)
  - [Development and testing](#development-and-testing)
    - [Prototyping with Docker](#prototyping-with-docker)
    - [Running tests](#running-tests)

# Postfwd GeoIP Botnet Block Plugin

This is a plugin to postfix firewall [postfwd](http://postfwd.org/) (also located on [github](https://github.com/postfwd/postfwd)) intended to block international spam botnets. International spam botnets are logging into hacked mail addresses via sasl login from multiple IP addresses based in usually more than 30 unique countries. After successful login, the hackers send spam from huge amount of unique IP addresses which circumvents traditional rate limits per IP address.

If you are interested in theory about how botnet spam works and motivation for creating this plugin, look at the blog on [Medium](https://medium.com/@ondrej.vaskoo/blocking-of-international-spam-botnets-a8a98e1ab589).

If you are interested in how your users got their mail accounts hacked, check out [bsdly](https://bsdly.blogspot.com) blog about slow distributed brute force attack on SSH passwords, which also applies to pop3/imap logins [Hail Mary Cloud](http://bsdly.blogspot.com/2013/10/the-hail-mary-cloud-and-lessons-learned.html).

## Plugin Compatibility Matrix

| Plugin Version | Postfwd Version          | GeoIP Version | IP version |
| :------------- | :----------------------- | :------------ | :--------- |
| v2.0.0         | postfwd3 v2.xx           | GeoIP 1, 2    | IPv4, IPv6 |
| v1.50.0        | postfwd3 v2.xx           | GeoIP 1, 2    | IPv4       |
| v1.40          | postfwd3 v2.xx           | GeoIP 1       | IPv4       |
| v1.30          | postfwd3 v2.xx           | GeoIP 1       | IPv4       |
| v1.21          | postfwd1, postfwd2 v1.xx | GeoIP 1       | IPv4       |

- Supported database backends are **MySQL** and **PostgreSQL**.

To list changed between versions check release notes or look into the [Changelog](CHANGELOG.md).

## Running with Docker

Pre-built ready-to-use Docker image is located on DockerHub and can be simply pulled by command:

```bash
# postfwd3 tags
docker pull lirt/postfwd-anti-geoip-spam-plugin:v2.0.0
# postfwd1, postfwd2 tags
docker pull lirt/postfwd-anti-geoip-spam-plugin:v1.21
```

To run postfwd with geoip-plugin, run docker with configuration files mounted as volumes:

```bash
docker run \
    -v </absolute/path/to/anti-spam.conf>:/etc/postfwd/anti-spam.conf \
    -v </absolute/path/to/postfwd.cf>:/etc/postfwd/postfwd.cf \
    lirt/postfwd-anti-geoip-spam-plugin:v2.0.0
```

This will run `postfwd2` or `postfwd3` (based on docker tag) with default arguments, reading postfwd rules file from your mounted volume file `postfwd.cf` and using anti-spam configuration from your file `anti-spam.conf`.

## Installation

To install this plugin follow next steps:

- Clone this repository.
- Install dependencies according to chapter [Dependencies](#dependencies).
- Run script `install.sh` to install plugin into `/etc/postfix/`.
- To load plugin you must add argument `--plugins <PATH TO PLUGIN>` to postfwd command (or update it in `/etc/default/postfwd`).
- Configure postfwd rules according to chapter [Postfwd configuration](#postfwd-configuration).
- Create database table with indexes using following SQL statements (database is created on plugin startup but indexes cannot be).

```sql
CREATE TABLE IF NOT EXISTS postfwd_logins (
   sasl_username varchar(100),
   ip_address varchar(45),
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
- GeoIP database (version 1 or 2).

#### Cpanm

You can install all dependencies using cpanm with single command `cpanm --installdeps .`

#### Dependencies on RedHat based distributions

Install *GeoIP*, *Time*, *Config*, *DBI* and database modules with following command:

```bash
yum install -y 'perl(Geo::IP)' \
               'perl(Time::Piece)' \
               'perl(Config::Any)' \
               'perl(DBI)' \
               'perl(DBD::mysql)' \
               'perl(DBD::Pg)' \
               'perl(Net::Subnet)' \
               'perl(GeoIP2::Database::Reader)' \
               'perl(Net::SSLeay)' \
               'perl(IO::Socket::SSL)' \
               'perl(LWP::Protocol::https)' \
               'perl(Class::XSAccessor)' \
               'perl(MaxMind::DB::Reader::XS)' \
               'perl(Readonly)' \
               'perl(Data::Validate::IP)'
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
                   geoip-database \
                   libnet-ssleay-perl \
                   libio-socket-ssl-perl \
                   liblwp-protocol-https-perl \
                   libclass-xsaccessor-perl \
                   libmaxmind-db-reader-xs-perl \
                   libgeoip2-perl \
                   libreadonly-perl \
                   libdata-validate-ip-perl
```

## Configuration

Plugin configuration file `anti-spam.conf` is INI style configuration file, in which values must NOT be quoted!

### Postfwd configuration

Add following rules to postfwd configuration file `postfwd.cf`. You can use your own message and value of parameters:
- `client_uniq_country_login_count`: Sets maximum number of unique countries to allow user to log in using sasl.
- `client_uniq_ip_login_count`: Sets maximum number of unique IP addresses to allow user to log in using sasl.

```bash
# Anti spam botnet rule:
#   This example shows how to limit e-mail address defined by `sasl_username`
#   to be able to login from max. 5 different countries or 20 different IP
#   addresses, otherwise it will be blocked from sending messages.

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

Update configuration file `/etc/postfix/anti-spam.conf` with your credentials to selected database backend. Don't forget to use proper driver and port.

In case you use different path such as `/etc/postfix/anti-spam.conf` and `/etc/postfix/anti-spam-sql-st.conf` to main configuration file, export environment variables `POSTFWD_ANTISPAM_MAIN_CONFIG_PATH` and `POSTFWD_ANTISPAM_SQL_STATEMENTS_CONFIG_PATH` with your custom path.

```ini
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

```ini
[app]
# flush database records with last login older than 1 day
db_flush_interval = 86400
geoip_db_path = /usr/local/share/GeoIP/GeoIP.dat
# IP whitelist must be valid comma separated strings in CIDR format without whitespaces.
# it specifies IP addresses which will NOT be counted into user logins database.
ip_whitelist = 198.51.100.0/24,203.0.113.123/32
# ip_whitelist_path = /etc/postfwd/ip_whitelist.txt
```

### Logging

Plugin is by default logging into standard output. This can be changed in configuration file by setting value for `logging.logfile`.

You can disable logging completely by updating value of statement `logging.enable` to `0`.

```ini
[logging]
# enable(1) or disable(0) logging
enable = 1
# remove statement `logfile`, or set it to empty `logfile = ` to log into STDOUT
logfile = /var/log/postfwd_plugin.log
autoflush = 0
# make log after exceeding unique country count limit
country_limit = 5
# make log after exceeding unique ip count limit
ip_limit = 20
```

If you use `logrotate` to rotate anti-spam logs, use option `copytruncate` which prevents [logging errors](https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin/issues/6) when log file is rotated.

## Useful database queries

Plugin stores interesting statistical information in the database. To query those statistics you can use predefined SELECTs located in separate file [DB-Queries.md](DB-Queries.md).

## Development and testing

### Prototyping with Docker

Complete development environment with postfwd, anti-spam plugin and mysql/postgresql database configured together can be run with single command from directory `tests/`:
- MySQL: `docker-compose -f compose-dev-mysql.yml up`
- PostgreSQL: `docker-compose -f compose-dev-postgresql.yml up`
- MySQL with GeoIP2: `export POSTFWD_ANTISPAM_MAIN_CONFIG_PATH=/etc/postfwd/03-dev-anti-spam-mysql-geoip2.conf; docker-compose -f compose-dev-mysql.yml up`

Note for overriding postfwd arguments:

* Most important arguments to run `postfwd` in Docker are `--stdout` and `--nodaemon`. These arguments configure postfwd to log into standard output and stay in foreground.
* For running postfwd plugin, you also need to set argument `--plugins <path-to-plugin>` to correct location of plugin.

MaxMind test database `tests/GeoLite2-Country-Test.mmdb` was downloaded from [MaxMind-DB repository](https://github.com/maxmind/MaxMind-DB).

### Running tests

Check for proper linting with `perlcritic postfwd-anti-spam.plugin`.

Run plugin as mentioned in [Prototyping with Docker](#prototyping-with-docker) and send SMTP requests to postfwd policy server, or use testing script to check functionality:

```bash
# manually send postfwd request
export CLIENT_ADDRESS='1.2.3.4'
export SASL_USERNAME='testuser@example.com'
nc 127.0.0.1 10040 < <(envsubst < dev-request)

# run testing script
cd tests
DATABASES="mysql postgresql" RUN_COMPOSE=1 ./integration-compose-test-geoip1.sh
```
