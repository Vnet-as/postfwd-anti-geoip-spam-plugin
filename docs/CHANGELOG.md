# Changelog

This changelog notes changes between versions of Postfwd GeoIP Anti-Spam plugin.

## Version 2.0.0 [3. October 2021]

Add IPv6 support for GeoIP2 databases.

This is a feature that was [requested and meant to be included for a long time](https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin/issues/12), but the revision of code was always postponed.

This release is tagged as `2.0.0` because IPv6 support in this plugin requires some breaking changes. The database must be dropped and recreated (or left to be created by plugin) because IPv6 addresses are longer than IPv4 addresses and the `ip_address` column had size of `varchar(16)`. With this change the column will be expanded to 45 characters.

Note: Dropping the database is nothing major in this project as it only serves as cache. Altering the database schema or doing migrations would complicate code.

There is one new dependency - `Data::Validate::IP` - that will make the IP address validation easier and more consistent than using regexes. It will test for valid IPv4 or IPv6 address, but also test if IP address is public. Since GeoIP databases can work only with public addresses, the GeoIP would throw error on other than public address anyway. This will reduce load on GeoIP.

If you forget to drop database, you will see error such as this in log:

```bash
[postfwd3/policy][10][LOG warning]: warning: DBD::mysql::st execute failed: Data too long for column 'ip_address' at row 1 at /etc/postfwd/postfwd-anti-spam.plugin line 411.?
postfwd::anti-spam-plugin ERROR[10]: Data too long for column 'ip_address' at row 1
```

### Breaking changes

- Resize column `ip_address` in database schema from 16 to 45 characters.
- Add new dependency `Data::Validate::IP`.

### Features / Enhancements

- IPv6 support
- Better IP address validation

### Bugfixes

None


## Version 1.50.0 [27. March 2021]

GeoIP2 Feature.

### Breaking changes

- New dependencies for GeoIP2 module were added, please see changes in `cpanfile`.

### Features / Enhancements

- Added GeoIP2 support. Now you can use Maxmind GeoIP2 databases. Path to GeoIP file can be changed in config `app.geoip_db_path`.
- Removed entrypoint check for configuration file. The config file path can be overriden using environment variable `POSTFWD_ANTISPAM_MAIN_CONFIG_PATH`.
- Added integration tests for GeoIP2 (test structure changed overall).


## Version 1.40 [2. March 2020]

This stable release contains IP whitelisting feature (Reported as bug and requested by @csazku in https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin/issues/50).

This release has one new CPAN dependency - `Net::Subnet`.

You can specify line `ip_whitelist = 198.51.100.0/24,203.0.113.123/32` in main
configuration file in order to skip incrementing of login count for users
who are logging into email from specified IP addresses.
This list must be comma separated without whitespaces and IP address must always
end with CIDR mask (for plain IPs `/32` must be used).

Alternative version is to read IP whitelist from file, which can be specified in
main configuration file like `ip_whitelist_path = /etc/postfwd/ip_whitelist.txt`
and whitelisting file must have following format (comments start with `#` and
one IP CIDR must be entered per line):

```bash
###
# IP ranges must be in CIDR format with prefix specified
# for all IP addresses with `/<NUM>` notation
###
# Private ranges
10.0.0.0/8
# Whitelisted test IP addresses
198.51.100.0/24
203.0.113.123/32
```

## Version 1.30 - Postfwd3 support, Integration Testing [23. Mar 2019]

This release uses new postfwd docker tag 2.00, which uses new `postfwd3` script.

Postfwd3 changed plugin interface and therefore this release is not compatible with
`postfwd1` and `postfwd2`. If you want to use older postfwd versions, use tag `v1.21`.

Postfwd3 uses Alpine Linux for docker, so the dockerfile had to be rewritten.

To better work with GeoIP database, there is new configuration option `geoip_db_path`,
which defaults to `/usr/local/share/GeoIP/GeoIP.dat`.

There is small change to logging, number of countries and unique IPs is logged on each
request loop.

A lot of rework was done in tests directory. There is docker-compose with postgresql.
Also shell script, which automatically runs docker-compose for both supported databases
and does integration test with sample requests and verification through logs.

Plugin item now exports `request{client_uniq_ip_login_count}`
and `request{client_uniq_country_login_count}` instead of `result*`.

## Version 1.2 [11. March 2019]

This stable release has changes mainly in linting, readability and testability, but also
contains several bugfixes.

Docker base image was updated from 1.37 to 1.39.

### Added

- Perl::Critic RC file `.perlcriticrc` for static code and linting purposes.
- Install `geoip-database` into Docker image and added note in README.
- Option to enable autoflush to STDOUT and log.
- 10 second timeout and 3 retries to connect to database.
- Testing script `tests/dev-request.sh` and instructions in README.

### Changed

- Updated postwfd Docker version to 1.39.
- Perl Linting according to Perl Critic (https://github.com/Vnet-as/postfwd-anti-geoip-spam-plugin/pull/26)
- Fixed Docker Compose volumes from type `volume` to `bind`.
- Fix for double calling `postfwd2` in Dockerfile.

### Removed

- Script `lint.pl` was removed and replaced by more general/portable file
`.perlcriticrc`.

## Version 1.1 [5. January 2019]

This stable version introduces docker image based on official postfwd docker image
and other minor changes. All work done by @Lirt (ondrej.vaskoo@gmail.com),
docker review done by @kirecek (erikjankovic@gmail.com).

This together with docker-compose template to bootstrap local development
environment will significantly help in testing and validation.

There are other minor improvements, such as ability to change path to main configuration
file, which was previously statically defined in `/etc/postfix/anti-spam.conf`.

DockerHub repository was created at URL https://cloud.docker.com/repository/docker/lirt/postfwd-anti-geoip-spam-plugin

Other notable changes are introducement of changelog and tags(releases).

Differences between version 1.0 and 1.1:

### Added

- Environment variables `POSTFWD_ANTISPAM_MAIN_CONFIG_PATH` and
`POSTFWD_ANTISPAM_SQL_STATEMENTS_CONFIG_PATH`, which can be used to
override default path to postfwd configuration file and configuration file
with SQL statements.
- Logging can now be redirected to STDOUT using empty logfile statement in configuration
or by removing logfile statement. This solution is backwards compatible.
- Dockerfile and entrypoint script built on official postfwd image, which
installs plugin, prepares configuration and default running arguments.
- `tests` directory with docker-compose template and default configurations to easily
bootstrap local development environment.

### Changed

- Script now uses `env perl` instead of path to static perl in shebang.
- Logged lines now contain name of program - postfwd::anti-spam-plugin - run in format
`<DATE> <PROGRAM> <LOG_LEVEL> <MESSAGE>`. This will help to distinguish between original
postfwd logs and this postfwd plugin logs.
- Plugin now tries to connect to database 3 times with 10 second timeout. If it fails
3 times, it quits.
- More and improved logging messages about database connection state.

### Removed

## Version 1.0 [12. November 2018]

This is first official version and release.

### Added

- Postfwd plugin.
- Sample configuration files.
- Installation script.
- README.md.

### Changed

### Removed
