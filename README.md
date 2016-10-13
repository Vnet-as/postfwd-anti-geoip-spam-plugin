# Postfwd GeoIP Botnet Block Plugin

## Plugin

This is plugin to postfix firewall `postfwd` intended to block international spam botnets which are logging to hacked mail addresses via sasl from multiple IP addresses based in usually more than 30 unique countries and sends spam.

## Installation

Copy plugin to your mail server. To load plugin to postfwd you must add argument `--plugins <PATH TO PLUGIN>` to postfwd command. 

Install dependencies according to chapter `Dependencies`. 

Add following rule to postfwd configuration file `postfwd.cf`. You can use your own message and parameter client_uniq_country_login_count which sets maximum number of unique countries to allow user to log in via sasl. 

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

Create database table with indexes

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

Plugin is dependent on Perl Geo::IP module, DBI module and needs database which is supported by DBI. 

On RH based distributions install GeoIP module with `yum install -y perl\(Geo::IP\)`

On Debian based distributions install GeoIP module with `apt-get install -y libgeo-ip-perl`

### Database cleanup period

The database is by default set to remove records for users with last login date older than 24 hours, but can be changed within code to arbitrary time period (DAY, WEEK, MONTH...) by changing variable $flush_interval.

### Useful database queries 

Print users who are logged in from more than 1 country and write number of countries from which they were logged in: 
```
SELECT sasl_username, COUNT(DISTINCT state_code) AS country_login_count FROM postfwd_logins GROUP BY sasl_username HAVING country_login_count > 1;
```

Dump all IP addresses and login counts for users who were logged in from more than 1 country
```
SELECT * FROM postfwd_logins JOIN (SELECT sasl_username FROM postfwd_logins GROUP BY sasl_username HAVING COUNT(DISTINCT state_code) > 1) AS users_logged_from_multiple_states ON postfwd_logins.sasl_username = users_logged_from_multiple_states.sasl_username ORDER BY postfwd_logins.sasl_username;
```

SUM of logins for user <SASL_USERNAME>
```
SELECT SUM(login_count) FROM postfwd_logins WHERE sasl_username='<SASL_USERNAME>';
```

COUNT of distinct login state_codes for user <SASL_USERNAME>
```
SELECT COUNT(DISTINCT state_code) FROM postfwd_logins WHERE sasl_username='<SASL_USERNAME>';
```

COUNT of distinct IP addresses for user <SASL_USERNAME>
```
SELECT COUNT(DISTINCT ip_address) FROM postfwd_logins WHERE sasl_username='<SASL_USERNAME>';
```

COUNT of IP addresses for each state_code for user <SASL_USERNAME>
```
SELECT sasl_username, state_code, COUNT(state_code) AS country_login_count FROM postfwd_logins WHERE sasl_username='<SASL_USERNAME>' GROUP BY state_code ORDER BY country_login_count;
```


