#!/usr/bin/env -S bash
#

if [ -f /var/run/reboot-required ]
then
    echo "[*** Hello $USER, you must reboot your machine ***]" | mail -s "Reboot required for $(uname -n) !" server_sysadmin@domain.com
fi
