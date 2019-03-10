FROM postfwd/postfwd:v1.37

LABEL maintainer="Postfwd GeoIp Spam Plugin Maintainer <ondrej.vaskoo@gmail.com>"

ENV PATH="/opt/postfwd/sbin/:${PATH}"
ENV POSTFWD_ANTISPAM_MAIN_CONFIG_PATH=/etc/postfwd/anti-spam.conf
ENV POSTFWD_ANTISPAM_SQL_STATEMENTS_CONFIG_PATH=/etc/postfwd/anti-spam-sql-st.conf

# Install dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libconfig-any-perl \
        libconfig-tiny-perl \
        libconfig-ini-perl \
        libconfig-general-perl \
        libdbi-perl \
        libdbd-mysql-perl \
        libdbd-pg-perl \
        libgeo-ip-perl \
        libtime-piece-perl \
        geoip-database \
    && rm -rf /var/lib/apt/lists/*

# Copy binaries into PATH
RUN cp /opt/postfwd/sbin/postfwd1 /opt/postfwd/sbin/postfwd2 /usr/sbin/

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod 750 /usr/local/bin/docker-entrypoint.sh

# Install plugin
COPY --chown=postfw:postfw anti-spam-sql-st.conf /etc/postfwd/anti-spam-sql-st.conf
COPY --chown=postfw:postfw postfwd-anti-spam.plugin /etc/postfwd/postfwd-anti-spam.plugin
RUN chmod 644 \
        /etc/postfwd/postfwd-anti-spam.plugin \
        /etc/postfwd/anti-spam-sql-st.conf

ENTRYPOINT ["docker-entrypoint.sh", \
            "--file", "/etc/postfwd/postfwd.cf", \
            "--user", "postfw", "--group", "postfw", \
            "--plugins", "/etc/postfwd/postfwd-anti-spam.plugin", \
            "--server_socket", "tcp:0.0.0.0:10040", \
            "--cache_socket=unix::/var/lib/postfwd/postfwd.cache", \
            "--pidfile=/var/lib/postfwd/postfwd.pid", \
            "--save_rates=/var/lib/postfwd/postfwd.rates", \
            "--stdout", "--nodaemon"]

EXPOSE 10040
CMD ["--cache=60", \
     "--noidlestats", \
     "--summary=600"]
