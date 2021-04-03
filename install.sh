#!/bin/bash

set -x
set -o pipefail
set -u

cp postfwd-anti-spam.plugin /etc/postfix/
cp conf/anti-spam-sql-st.conf /etc/postfix/

if [[ ! -e /etc/postfix/anti-spam.conf ]]; then
    # If main configuration file exists do not overwrite it
    cp conf/anti-spam.conf /etc/postfix/
else
    echo "Not copying default configuration. Anti spam configuration already exists."
fi

if ! id postfw; then
    echo "User 'postfw' does not exist, creating user postfw."
    useradd postfw
fi

if ! getent group postfix; then
    echo "Group postfix does not exist, creating group postfix."
    groupadd postfix
fi

chown postfw:postfix /etc/postfix/anti-spam-sql-st.conf
chown postfw:postfix /etc/postfix/anti-spam.conf
chown postfw:postfix /etc/postfix/postfwd-anti-spam.plugin
chmod 640 /etc/postfix/anti-spam-sql-st.conf
chmod 640 /etc/postfix/anti-spam.conf
chmod 640 /etc/postfix/postfwd-anti-spam.plugin

echo "Do not forget to follow next steps after installation:"
echo "1. Configure postfwd to run with argument --plugins <PATH TO PLUGIN> (eg. in /etc/default/postfwd)"
echo "2. Don't forget to update configuration file /etc/postfix/anti-spam.conf if you are installing plugin for the first time"
echo "3. During first installation update postfwd.cf file with configuration on github"
echo "4. During first installation install perl dependencies according to documentation on github"
echo "5. During first installation setup database table and indexes (not necessary if you do not need indexes.. tables will be created automatically)"
