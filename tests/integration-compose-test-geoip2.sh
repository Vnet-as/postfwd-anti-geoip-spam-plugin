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


# Valid user logging in with IPv4 and IPv6 addresses from United Kingdom and Sweden
sasl_username="valid-user@example.com"
valid_user_addresses=( 2.125.160.216
                       81.2.69.142
                       81.2.69.144
                       81.2.69.192
                       89.160.20.112
                       89.160.20.128
                       2a02:d3c0::12
                       2a02:da40::ee02
                       2a02:da40:0000:0000:0000:ff00:0042:8329
)
send_requests "$sasl_username" "valid_user_addresses"


# User logging from IPv4 and IPv6 addresses which are not in DB
sasl_username="valid-user-non-existing-ip@example.com"
valid_user_non_existing_ip_addresses=(192.168.35.1
                                      10.1.1.1
                                      172.20.20.20
                                      192.0.2.15
                                      ::1
                                      2001::4444
)
send_requests "$sasl_username" "valid_user_non_existing_ip_addresses"


# User logging from invalid IP addresses
sasl_username="valid-user-non-existing-ip@example.com"
valid_user_invalid_ips=(my-special-ip
                        10123.1.1.1
                        172.20.20.20:1234
                        500.0.2.15
                        2a02:da40::oo1k
                        ::
)
send_requests "$sasl_username" "valid_user_invalid_ips"


# Spam user logging in with IPv4 and IPv6 addresses from 7 different countries
# UK, US, BT, SE, CN, PH, GI
sasl_username="spam-user1@example.com"
spam_user1_addresses=( 2.125.160.216
                       50.114.0.12 216.160.83.56
                       67.43.156.0
                       89.160.20.112
                       111.235.160.1
                       202.196.224.0
                       217.65.48.0
                       2a02:d540::a
                       2a02:d040::15
                       2001:252::252
                       2a02:ffc0:500::100
)
send_requests "$sasl_username" "spam_user1_addresses"


# Spam user logging in with 30 different IPv4 and IPv6 addresses from SE
sasl_username="spam-user2@example.com"
spam_user2_addresses=( 89.160.20.128 89.160.20.129 89.160.20.130
                       89.160.20.131 89.160.20.132 89.160.20.133
                       89.160.20.134 89.160.20.135 89.160.20.136
                       89.160.20.137 89.160.20.138 89.160.20.139
                       89.160.20.140 89.160.20.141 89.160.20.142
                       89.160.20.143 89.160.20.144 89.160.20.145
                       89.160.20.146 89.160.20.147 89.160.20.148
                       89.160.20.149 89.160.20.150 89.160.20.151
                       89.160.20.152 2a02:ffc0::30 2a02:ffc0::31
                       2a02:ffc0::32 2a02:ffc0::33 2a02:ffc0::34
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
                -e "ERROR.*: Retry [123]/3 - could not connect to server: Connection refused" \
   | grep -E -v -e "\[postfwd3/policy\]\[[[:digit:]]+\]\[LOG crit\]: FATAL: The IP address you provided.*is not a valid IPv4 or IPv6 address" \
                -e "\[postfwd3/policy\]\[[[:digit:]]+\]\[LOG crit\]: FATAL: The IP address you provided.*is not a public IP address" \
                -e "\[postfwd3/policy\]\[[[:digit:]]+\]\[LOG crit\]: FATAL: No record found for IP address"; then
  echo -e 'ERROR: Errors found in log.\nTEST FAILED!'
  errors+=("1")
fi
if ! docker-compose -f "${script_path}/compose-dev-mysql.yml" logs postfwd-geoip-antispam \
     | grep "User spam-user1@example.com was logged from more than 5 countries([67])"; then
  echo -e 'ERROR: User did not exceed country login limit (5) but should!'
  errors+=("2")
fi
if ! docker-compose -f "${script_path}/compose-dev-mysql.yml" logs postfwd-geoip-antispam \
    | grep -E "User spam-user2@example.com was logged from more than 20 IP addresses\((30|29)\)"; then
  echo -e 'ERROR: User did not exceed IP address limit (20) but should!'
  errors+=("3")
fi

if [ "${#errors[@]}" -gt 0 ]; then
  echo "Tests ended up with errors[${errors[*]}]."
  exit 1
fi

