#!/usr/bin/env bash

cat << _EOF_
request=smtpd_access_policy
protocol_state=RCPT
protocol_name=ESMTP
helo_name=some.domain.tld
queue_id=8045F2AB23
sender=foo@bar.tld
recipient=bar@foo.tld
recipient_count=0
client_address=${1}
reverse_client_name=another.domain.tld
instance=123.456.7
sasl_method=plain
sasl_username=testuser@domain.com

sasl_sender=
size=12345
ccert_subject=solaris9.porcupine.org
ccert_issuer=Wietse+20Venema
ccert_fingerprint=C2:9D:F4:87:71:73:73:D9:18:E7:C2:F3:C1:DA:6E:04
encryption_protocol=TLSv1/SSLv3
encryption_cipher=DHE-RSA-AES256-SHA
encryption_keysize=256
etrn_domain=
stress=
ccert_pubkey_fingerprint=68:B3:29:DA:98:93:E3:40:99:C7:D8:AD:5C:B9:C9:40
client_port=1234
policy_context=submission
server_address=10.3.2.1
server_port=54321
_EOF_
