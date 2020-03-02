# Supported tags and respective `Dockerfile` links

* [`latest` (Dockerfile)](https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin/blob/master/docker/Dockerfile)
* [`v1.40` (Dockerfile)](https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin/blob/v1.40/docker/Dockerfile)
* [`v1.30` (Dockerfile)](https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin/blob/v1.30/docker/Dockerfile)
* [`v1.21` (Dockerfile)](https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin/blob/v1.21/docker/Dockerfile)

# Postfwd GeoIP Anti-Spam Plugin

This is official DockerHub repository for [GeoIP Anti-Spam plugin](https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin) for [postfwd](https://postfwd.org/) - postfix firewall.

Plugin was developed for fighting against international spam botnets and works by counting number of countries from which was user logged into account via `sasl` authentication and blocking them when this number of countries exceeds specified allowed number.

For full documentation visit our [GitHub repository](https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin).

## Running

Pull image with `docker pull lirt/postfwd-anti-geoip-spam-plugin:latest`.

Prepare your configuration files and run this docker image with following command:


```bash
docker run -d \
    -v </absolute/path/to/anti-spam.conf>:/etc/postfwd/anti-spam.conf \
    -v </absolute/path/to/postfwd.cf>:/etc/postfwd/postfwd.cf \
    lirt/postfwd-anti-geoip-spam-plugin
```


**Plugin needs MySQL or PostgreSQL database to work**!

If you don't have database by your hand, but **want to try the plugin**, you can try it with `docker-compose` template located in [official GitHub repository](https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin/tree/master/tests) in directory `./tests`.

Run it with `docker-compose -f dev-compose.yml up` - this will bootstrap ready-to-work environment, where you can try the plugin.

Then you can run from local shell `nc 127.0.0.1 10040 < <(./dev-request.sh <IP_ADDRESS>)`, to send artificial request into postfwd and watch logs what is happening.

## Configuration

As you can see, 2 configuration files must be mounted as volumes for postfwd and plugin to work.

First one `anti-spam.conf` is plugin configuration. As mentioned above, plugin needs database the work and the most important settings, that needs to be altered are database connection parameters (driver, database, host, port, userid, password).

Here is sample configuration file:


```conf
[database]
# driver = Pg
driver = mysql
database = postfwd-antispam-test
host = localhost
# port = 5432
port = 3306
userid = testuser
password = testpasswordpostfwdantispam

[logging]
# logfile =
autoflush = 1

[debugging]
# Enable(1) or disable(0) logging
debug = 1
# Make log after exceeding unique country count limit
country_limit = 5
# Make log after exceeding unique ip count limit
ip_limit = 20

[app]
# Flush database records with last login older than 1 day
db_flush_interval = 86400
geoip_db_path = /usr/local/share/GeoIP/GeoIP.dat
# IP whitelist must be valid comma separated strings in CIDR format without whitespaces.
# It specifies IP addresses which will NOT be counted into user logins database.
# ip_whitelist = 198.51.100.0/24,203.0.113.123/32
# ip_whitelist_path = /etc/postfwd/ip_whitelist.txt
```

Second one is postfwd rules configuration. Here is sample configuration:

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
