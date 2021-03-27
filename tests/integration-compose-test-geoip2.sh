#!/usr/bin/env bash

script_path=$(dirname "${0}")

function send_requests {
  local sasl_username=${1}
  local -n client_addresses=${2}
  for client_address in "${client_addresses[@]}"; do
    export SASL_USERNAME=${sasl_username}
    export CLIENT_ADDRESS=${client_address}
    nc 127.0.0.1 10040 -v -w 10 < <(envsubst < "${script_path}/dev-request") > /dev/null
  done
}


# Valid user logging in with IP addresses from United Kingdom and Sweden
sasl_username="valid-user@example.com"
valid_user_addresses=( 2.125.160.216
                       81.2.69.142
                       81.2.69.144
                       81.2.69.192
                       89.160.20.112
                       89.160.20.128
)
send_requests "$sasl_username" "valid_user_addresses"


# Spam user logging in with IP addresses from 7 different countries
# UK, US, BT, SE, CN, PH, GI
sasl_username="spam-user1@example.com"
spam_user1_addresses=( 2.125.160.216
                       50.114.0.12 216.160.83.56
                       67.43.156.0
                       89.160.20.112
                       111.235.160.1
                       202.196.224.0
                       217.65.48.0
)
send_requests "$sasl_username" "spam_user1_addresses"


# Spam user logging in with 25 different IP addresses from SE
sasl_username="spam-user2@example.com"
spam_user2_addresses=( 89.160.20.128 89.160.20.129 89.160.20.130
                       89.160.20.131 89.160.20.132 89.160.20.133
                       89.160.20.134 89.160.20.135 89.160.20.136
                       89.160.20.137 89.160.20.138 89.160.20.139
                       89.160.20.140 89.160.20.141 89.160.20.142
                       89.160.20.143 89.160.20.144 89.160.20.145
                       89.160.20.146 89.160.20.147 89.160.20.148
                       89.160.20.149 89.160.20.150 89.160.20.151
                       89.160.20.152
)
send_requests "$sasl_username" "spam_user2_addresses"


# Verify logs
#   1. Check for errors
#   2. Check if spam-user exceeded country limit
#   3. Check if spam-user exceeded IP address limit
declare -a errors
if docker-compose -f "${script_path}/compose-dev-mysql.yml" logs postfwd-geoip-antispam \
   | grep -i "error\|fatal" \
   | grep -E -v -e "ERROR.*: Retry [123]/3 - Can't connect to MySQL server on" \
                -e "ERROR.*: Retry [123]/3 - could not connect to server: Connection refused"; then
  echo -e 'ERROR: Errors found in log.\nTEST FAILED!'
  errors+=("1")
fi
if ! docker-compose -f "${script_path}/compose-dev-mysql.yml" logs postfwd-geoip-antispam \
     | grep "User spam-user1@example.com was logged from more than 5 countries([67])"; then
  echo -e 'ERROR: User did not exceed country login limit (5) but should!'
  errors+=("2")
fi
if ! docker-compose -f "${script_path}/compose-dev-mysql.yml" logs postfwd-geoip-antispam \
     | grep "User spam-user2@example.com was logged from more than 20 IP addresses(2[45])"; then
  echo -e 'ERROR: User did not exceed IP address limit (20) but should!'
  errors+=("3")
fi

if [ "${#errors[@]}" -gt 0 ]; then
  echo "Tests ended up with errors[${errors[*]}]."
  exit 1
fi

