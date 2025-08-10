#!/bin/sh
# Script de préparation à la migration : /backup/maintpage_dump.sh
#       - Disable le site mantisbt
#       - Enable le site mantisbt_migration avec la page de maintenance
#       - Backup du dossier /var/www/html/mantisbt
#       - Dump de la DB bugtracker
#
# Entrée Crontab :
# 00 12 25 06 *   /backup/maintenance_page_db_dump.sh


# A remplir
MYSQL_USER=mysql_user
MYSQL_PASSWORD=mysql_password
MYSQL_DB_NAME=mysql_database

MAIL_TO=server_sysadmin@domain.com
MAIL_SMTP=smtp@domain.com:25
MAIL_FROM=server_name@domain.com


echo "    ---------------- DESACTIVATION DU SITE MANTISBT -----------------   " > /backup/maintpage_dump.log
date  >> /backup/maintpage_dump.log
echo ""
/usr/sbin/a2dissite mantisbt >> /backup/maintpage_dump.log
/usr/sbin/a2ensite mantisbt_migration >> /backup/maintpage_dump.log

echo "    ---------------- RELOAD APACHE2 POUR APPLICATION DE LA CONF -----------------   " >> /backup/maintpage_dump.log
date  >> /backup/maintpage_dump.log
echo ""
systemctl reload apache2; systemctl status apache2 >> /backup/maintpage_dump.log
echo ""
/usr/sbin/apachectl -S >> /backup/maintpage_dump.log
echo ""
echo "    ---------------- DEBUT DU PROCESS DE SYNC DE BACKUP DU DOSSIER MANTIS BT -----------------   " >> /backup/maintpage_dump.log
date  >> /backup/maintpage_dump.log
echo ""
/usr/bin/rsync -a --delete /var/www/html/mantisbt /backup;diff --brief --recursive /var/www/html/mantisbt /backup/mantisbt  >> /backup/maintpage_dump.log
echo ""
echo "    ---------------- DEBUT DU PROCESS DE BACKUP DE LA DB MANTIS BT -----------------   "  >> /backup/maintpage_dump.log
date  >> /backup/maintpage_dump.log
echo ""
/usr/bin/mysqldump -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DB_NAME= > /backup/dump_bugtracker_migration.sql 
echo ""
echo "    ---------------- FIN DU PROCESS DE BACKUP MANTIS BT -----------------   "  >> /backup/maintpage_dump.log
date >> /backup/maintpage_dump.log
echo ""
echo "    ---------------- COMPRESSION DE BACKUP MANTIS BT -----------------   " >> /backup/maintpage_dump.log
date >> /backup/maintpage_dump.log
echo ""
/usr/bin/gzip /backup/dump_bugtracker_migration.sql
ls -ltrah  >> /backup/maintpage_dump.log
echo ""
echo "    ---------------- FIN DU PROCESS DE COMPRESSION DE BACKUP MANTIS BT -----------------   "  >> /backup/maintpage_dump.log
date  >> /backup/maintpage_dump.log
echo ""
echo "    ---------------- FIN DU SCRIPT -----------------   "  >> /backup/maintpage_dump.log

/usr/bin/swaks -t server_sysadmin@domain.com -s smtp@domain.com:25 -f server_name@domain.com --body /backup/maintpage_dump.log --h-Subject "Test - Fin du script"
