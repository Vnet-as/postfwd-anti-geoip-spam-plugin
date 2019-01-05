# Changelog

This changelog notes changes between versions of Postfwd GeoIP Anti-Spam plugin.

## Version 1.1 [5. Jan 2019]

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

## Version 1.0 [12. Nov 2018]

This is first official version and release.

### Added

- Postfwd plugin.
- Sample configuration files.
- Installation script.
- README.md.

### Changed

### Removed
