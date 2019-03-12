# Supported tags and respective `Dockerfile` links

* [`latest` (Dockerfile)](https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin/blob/master/docker/Dockerfile)
* [`v1.2` (Dockerfile)](https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin/blob/v1.2/Dockerfile)

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
```

Second one is postfwd rules configuration. Here is sample configuration:

```bash
# Anti spam botnet rule:
# This example shows how to limit e-mail address defined by `sasl_username`
# to be able to login from max. 5 different countries, otherwise it will
# be blocked from sending messages.

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
   action=jump(BAN_BOTNET);

id=BAN_BOTNET ; \
   sasl_username=~^(.+)$ ; \
   &&PRIVATE_RANGES ; \
   &&LOOPBACK_RANGE ; \
   client_uniq_country_login_count > 5 ; \
   action=rate(sasl_username/1/3600/554 Your mail account ($$sasl_username) was compromised. Please change your password immediately after next login.);
```
