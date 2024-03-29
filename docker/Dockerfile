FROM postfwd/postfwd:v2.02

LABEL maintainer="Postfwd GeoIP Spam Plugin Maintainer <ondrej.vaskoo@gmail.com>"

ENV POSTFWD_ANTISPAM_MAIN_CONFIG_PATH=/etc/postfwd/anti-spam.conf
ENV POSTFWD_ANTISPAM_SQL_STATEMENTS_CONFIG_PATH=/etc/postfwd/anti-spam-sql-st.conf

# Install build tools
# Build and Install modules
# Cleanup
RUN    apk --no-cache update \
    && apk --no-cache add make \
                          wget \
                          gcc \
                          build-base \
                          perl-utils \
                          perl-dev \
                          geoip-dev \
                          postgresql-dev \
                          mysql-dev \
                          openssl \
                          libmaxminddb-dev \
    && cpan App::cpanminus \
    && cpanm IO::Handle \
             Config::General \
             Config::Tiny \
             Config::Any::INI \
             Config::Any::General \
             Readonly \
             DBI \
             DBD::Pg \
             DBD::mysql \
             Net::Subnet \
             Sys::Mmap \
             Net::SSLeay \
             IO::Socket::SSL::Utils \
             IO::Socket::SSL \
             LWP::Protocol::https \
             GeoIP2::Database::Reader \
             Class::XSAccessor \
             MaxMind::DB::Reader::XS --force \
             Data::Validate::IP \
    && apk del make \
               wget \
               gcc \
               build-base \
               perl-utils \
               perl-dev \
    && rm -rf ~/.cpanm

# Copy entrypoint script
COPY docker/docker-entrypoint.sh /usr/local/bin/
RUN chmod 750 /usr/local/bin/docker-entrypoint.sh

# Install plugin
COPY --chown=postfw:postfw conf/anti-spam-sql-st.conf /etc/postfwd/anti-spam-sql-st.conf
COPY --chown=postfw:postfw postfwd-anti-spam.plugin /etc/postfwd/postfwd-anti-spam.plugin
RUN chmod 644 \
        /etc/postfwd/postfwd-anti-spam.plugin \
        /etc/postfwd/anti-spam-sql-st.conf

EXPOSE 10040
ENTRYPOINT ["docker-entrypoint.sh", \
            "--file", "/etc/postfwd/postfwd.cf", \
            "--user", "postfw", "--group", "postfw", \
            "--plugins", "/etc/postfwd/postfwd-anti-spam.plugin", \
            "--server_socket", "tcp:0.0.0.0:10040", \
            "--cache_socket=unix::/var/lib/postfwd/postfwd.cache", \
            "--pidfile=/var/lib/postfwd/postfwd.pid", \
            "--save_rates=/var/lib/postfwd/postfwd.rates", \
            "--stdout", "--nodaemon"]

CMD ["--cache=60", \
     "--noidlestats", \
     "--summary=600"]
