#!/bin/bash

cp postfwd-anti-spam.plugin /etc/postfix/
cp anti-spam-sql-st.conf /etc/postfix/

if [[ ! -e /etc/postfix/anti-spam.conf ]]; then
  # If main configuration file exists do not overwrite it
  cp anti-spam.conf /etc/postfix/
fi

chown postfw:postfix /etc/postfix/anti-spam-sql-st.conf
chown postfw:postfix /etc/postfix/anti-spam.conf
chown postfw:postfix /etc/postfix/postfwd-anti-spam.plugin
chmod 640 anti-spam-sql-st.conf
chmod 640 anti-spam.conf
chmod 640 postfwd-anti-spam.plugin

echo "Do not forget to follow next steps after installation:"
echo "1. Configure postfwd to run with argument --plugins <PATH TO PLUGIN> (eg. in /etc/default/postfwd)"
echo "2. Don't forget to update configuration file /etc/postfix/anti-spam.conf if you are installing plugin for the first time"
echo "3. During first installation update postfwd.cf file with configuration on github"
echo "4. During first installation install also perl dependencies according to documentation on github"
echo "5. During first installation setup database table and indexes (not necessary if you do not need indexes.. tables will be created automatically)"
