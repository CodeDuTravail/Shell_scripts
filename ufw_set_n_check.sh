#!/bin/bash
#
# /home/pi/scripts/ufw_set_n_check_ex.sh
# Purpose: check open ports and set ufw allow ports
#
# UFW PORTS CONF CHECK -----------------
# 0/5 * * * *  /home/pi/scripts/ufw_set_n_check_ex.sh
#
# -------------------------------------------------------------------------------

DATE=`date +%Y_%m_%d`

DEST_MAIL="you_email@mail.com"

UFW_CONF_PATH="/home/pi/conf_backup/ports_conf"
UFW_CONF_FILE="$UFW_CONF_PATH/ufw_ports.conf"
UFW_CONF_CHECK="$UFW_CONF_PATH/ufw_ports.check"
UFW_CONF_DIFF="$UFW_CONF_PATH/ufw_ports.log"
UFW_LAST_LOG="$UFW_CONF_PATH/ufw_ports_last.log"

PORTS=$(netstat -ano | grep -i -e listen | grep -e tcp | cut -d ":" -f 2  | cut -d " " -f 1 | tr -s '\n' | sort -u)

if [ ! -f $UFW_CONF_FILE ]; then
	echo "          ------------------------------------- "
    echo "#  $UFW_CONF_FILE # File not found"
	echo "          ------------------------------------- "
	
	if [ ! -d $UFW_CONF_PATH ]; then
		echo "#  $UFW_CONF_PATH # Folder not found, creating folder $UFW_CONF_PATH..."
		echo "          ------------------------------------- "
		mkdir $UFW_CONF_PATH
		ls -ltra $UFW_CONF_PATH
		echo "          ------------------------------------- "
	fi
	
	echo "#  $UFW_CONF_PATH # Folder exist, creating file $UFW_CONF_FILE..."
	echo "          ------------------------------------- "
	
	echo "UFW PORTS" > $UFW_CONF_FILE
	echo "${PORTS[@]}" | tr ' ' '\n' >> $UFW_CONF_FILE
	cat $UFW_CONF_FILE
	echo "          ------------------------------------- "
	echo "#  Adding Ports to UFW..."
	echo "          ------------------------------------- "
	for PORT in $PORTS;do echo " **  Add UFW rule : allow $PORT  **" && ufw allow $PORT && echo "";done
	echo "          ------------------------------------- "
	ufw status numbered
	
	echo "          ------------------------------------- "
	echo "#  Adding UFW PORTS CONF CHECK Crontask..."
	echo "          ------------------------------------- "
	echo "# UFW PORTS CONF CHECK -------------------------------------------------------------------------" >> /var/spool/cron/crontabs/root
	echo "*/5 * * * * /home/pi/scripts/ufw_set_n_check.sh" >> /var/spool/cron/crontabs/root
	
fi

if [ -e $UFW_CONF_DIFF ]; then
    mv $UFW_CONF_DIFF $UFW_LAST_LOG
fi   

echo "OPEN PORTS CHECK" > $UFW_CONF_CHECK
echo "${PORTS[@]}" | tr ' ' '\n' >> $UFW_CONF_CHECK

echo "          ------------------------------------- "
echo " #  Diff between files : "
echo "         $UFW_CONF_FILE"
echo "         $UFW_CONF_CHECK"
echo "          ------------------------------------- " 

diff -y --width=40 $UFW_CONF_FILE $UFW_CONF_CHECK > $UFW_CONF_DIFF

if [[ -z $(diff -y --width=40 $UFW_LAST_LOG $UFW_CONF_DIFF | grep -e "<" -e ">") ]]; then
	echo " **  SAME OUTPUT : Not sending another mail.  **"
else
	echo " **  OUTPUT CHANGE : Might need to send a mail alert.  **"
	
	if [[ -z $(cat $UFW_CONF_DIFF | grep -e "<" -e ">") ]]; then
		echo " **  OK : No new open ports.  **"
	else
		echo " **  WARNING : New open ports. **"
		echo "          ------------------------------------- "
		cat $UFW_CONF_DIFF
		# LET FLY THE PEACOCK.
		(printf "Subject: $(uname -n) - WARNING : New open ports.\n\nSup John, here is the report.\n\n          ------------------------------------- \n\n";cat $UFW_CONF_DIFF)  | msmtp -a default DEST_MAIL
	fi
	echo "          ------------------------------------- "

fi
