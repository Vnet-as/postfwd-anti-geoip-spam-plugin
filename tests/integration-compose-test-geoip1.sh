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

sleep_duration=10

for DB in ${DATABASES}; do
  # Build and run compose
  if [ "${RUN_COMPOSE}" = "1" ]; then
    docker-compose -f "${script_path}/compose-dev-${DB}.yml" up -d --build > /dev/null
    echo "Sleeping ${sleep_duration} seconds until compose initializes"
    sleep ${sleep_duration}
    echo "Sleep done"
  fi

  # Valid user logging in with IP addresses from Slovakia and Czech Republic
  sasl_username="valid-user@example.com"
  valid_user_addresses=(5.178.48.14
                        31.3.32.47
                        46.229.224.95
                        46.229.230.120
                        37.48.42.15
                        37.48.42.229
                        46.13.5.5
  )
  send_requests "$sasl_username" "valid_user_addresses"


  # Spam user logging in with IP addresses from 7 different countries
  # SVK, CZ, IT, NOR, CAN, KAZ, FRA
  sasl_username="spam-user1@example.com"
  spam_user1_addresses=( 46.229.224.61
                         46.13.7.27
                         31.44.115.66
                         79.141.110.169
                         24.37.219.201
                         79.142.52.15
                         46.238.128.94 46.238.128.94
  )
  send_requests "$sasl_username" "spam_user1_addresses"


  # Spam user logging in with 25 different IP addresses from SVK
  sasl_username="spam-user2@example.com"
  spam_user2_addresses=( 213.215.64.10 213.181.128.10 213.160.160.10
                         213.151.225.10 213.151.224.10 217.75.64.10
                         217.75.80.10 217.118.96.10 193.87.0.10
                         188.123.96.10 176.116.96.10 145.255.144.10
                         94.229.32.0 93.184.64.10 91.191.64.0
                         89.173.0.10 87.244.192.10 85.237.224.10
                         84.245.64.10 84.16.32.10 81.162.80.10
                         80.242.32.10 80.86.240.10 62.176.160.10
                         62.152.224.0
  )
  send_requests "$sasl_username" "spam_user2_addresses"


  # Verify logs
  #   1. Check for errors
  #   2. Check if spam-user exceeded country limit
  #   3. Check if spam-user exceeded IP address limit
  declare -a errors
  if docker-compose -f "${script_path}/compose-dev-${DB}.yml" logs postfwd-geoip-antispam \
     | grep -i "error\|fatal" \
     | grep -E -v -e "ERROR.*: Retry [123]/3 - Can't connect to MySQL server on" \
                  -e "ERROR.*: Retry [123]/3 - could not connect to server: Connection refused"; then
    echo -e 'ERROR: Errors found in log.\nTEST FAILED!'
    errors+=("1")
  fi
  if ! docker-compose -f "${script_path}/compose-dev-${DB}.yml" logs postfwd-geoip-antispam \
       | grep "User spam-user1@example.com was logged from more than 5 countries([67])"; then
    echo -e 'ERROR: User did not exceed country login limit (5) but should!'
    errors+=("2")
  fi
  if ! docker-compose -f "${script_path}/compose-dev-${DB}.yml" logs postfwd-geoip-antispam \
       | grep "User spam-user2@example.com was logged from more than 20 IP addresses(2[45])"; then
    echo -e 'ERROR: User did not exceed IP address limit (20) but should!'
    errors+=("3")
  fi

  # Cleanup
  if [ "${RUN_COMPOSE}" = "1" ]; then
    docker-compose -f "${script_path}/compose-dev-${DB}.yml" down > /dev/null
  fi
done

if [ "${#errors[@]}" -gt 0 ]; then
  echo "Tests ended up with errors[${errors[*]}]."
  exit 1
fi
