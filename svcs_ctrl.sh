#!/bin/bash
#
# /root/scripts_prod/svcs_ctrl.sh
# Works with ServiceControl_Check.ps1 
#
# Cron job for command :
# service-control --status
#
# cat /etc/cron.d/svcs_ctrl.cron
# */15 * * * *  root    /root/scripts_prod/svcs_ctrl.sh
#
#



export VMWARE_PYTHON_PATH=/usr/lib/vmware/site-packages
export VMWARE_LOG_DIR=/var/log
export VMWARE_DATA_DIR=/storage
export VMWARE_CFG_DIR=/etc/vmware

echo "     ------------------- DEBUT DE SCRIPT ----------------------" > /var/log/svcs_ctrl.log;echo "" >> /var/log/svcs_ctrl.log; /usr/bin/service-control --status | grep -A 5 'Stopped' >> /var/log/svcs_ctrl.log;echo "     ------------------- FIN DE SCRIPT ----------------------" >> /var/log/svcs_ctrl.log;echo "" >> /var/log/svcs_ctrl.log
