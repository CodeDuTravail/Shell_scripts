#!/bin/bash
#
# cert_expiration.sh
# Purpose: Alert sysadmin/developer about the TLS/SSL cert expiry date in advance
#
#
# -------------------------------------------------------------------------------

CERT="/CERT_PATH/CERT_NAME.crt"

# 7 days in seconds 
DAYS="604800" 
 
# Email settings 
_sub="On $HOSTNAME $CERT will expire within $DAYS (7 days)."
_from="server_sysadmin@domain.com"
_to="mailing_list@domain.com"
_openssl="/usr/bin/openssl"

$_openssl x509 -enddate -noout -in "$CERT"  -checkend "$DAYS" | grep -q 'Certificate will expire'
 
# Send email and push message to my mobile
if [ $? -eq 0 ]
then
	echo "${_sub}"
        mail -s "$_sub" -r "$_from" "$_to" <<< "Warning: The TLS/SSL certificate ($CERT) will expire soon on $HOSTNAME [$(date)]"
fi