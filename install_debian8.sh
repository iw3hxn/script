#!/bin/bash
################################################################################
# Script for Installation: Didotech ERP Solution on Debian
# autor Carlo Vettore
#-------------------------------------------------------------------------------
# This script will install openerp Server on
# clean Debian
#-------------------------------------------------------------------------------
# USAGE:
#
# install
#
# EXAMPLE:
# ./install
#
################################################################################

##fixed parameters

#openerp
OE_USER="openerp"
OE_HOME="/opt/$OE_USER"
OE_HOME_EXT="/opt/$OE_USER/server"

#set the superadmin password
OE_SUPERADMIN="superadminpassword"
OE_CONFIG="$OE_USER-server"
LO_CONFIG="office_init"

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
sudo apt-get update
sudo apt-get upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
sudo apt-get install postgresql postgresql-server-dev-9.4 -y
	
echo -e "\n---- PostgreSQL $PG_VERSION Settings  ----"
sudo sed -i s/"#listen_addresses = 'localhost'"/"listen_addresses = '*'"/g /etc/postgresql/9.4/main/postgresql.conf

echo -e "\n---- Creating the PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n---- Install tool packages ----"
sudo apt-get install wget subversion git bzr bzrtools python-pip python-dev libxml2-dev libxslt-dev lib32z1-dev libldap2-dev poppler-utils libsasl2-dev libssl-dev -y 

echo -e "\n---- Install wkhtml ----"

sudo apt-get remove wkhtmltopdf
sudo apt-get install bzip2

#cd /tmp
#sudo wget https://wkhtmltopdf.googlecode.com/files/wkhtmltopdf-0.11.0_rc1-static-amd64.tar.bz2
#sudo tar xvjf wkhtmltopdf-0.11.0_rc1-static-amd64.tar.bz2
#sudo mv wkhtmltopdf-amd64 /usr/local/sbin/wkhtmltopdf
#sudo chmod +x /usr/local/sbin/wkhtmltopdf

echo -e "\n---- Create OpenERP system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------

echo -e "\n==== Installing ODOO Server ===="
sudo git clone https://github.com/iw3hxn/server.git $OE_HOME/server
sudo git clone https://github.com/iw3hxn/addons.git $OE_HOME/addons
sudo git clone https://github.com/iw3hxn/LibrERP.git $OE_HOME/LibrERP
sudo bzr branch lp:aeroolib $OE_HOME/libaeroo

echo -e "\n---- Install python libraries ----"
sudo pip install -r $OE_HOME/server/requirements.txt
sudo pip install codicefiscale pyvies

echo -e "\n---- Create custom module directory ----"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"


echo -e "\n----  Configure Aeroo Reports ----"
aptitude install openoffice.org python-genshi python-cairo python-openoffice python-uno -y
apt-get install  python-uno

cd $OE_HOME/libaeroo/aeroolib
sudo python ./setup.py install

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Create server config file"
sudo cp $OE_HOME/server/install/openerp-server.conf /etc/$OE_CONFIG.conf
sudo chown $OE_USER:$OE_USER /etc/$OE_CONFIG.conf
sudo chmod 640 /etc/$OE_CONFIG.conf

echo -e "* Change server config file"
sudo sed -i s/"db_user = .*"/"db_user = $OE_USER"/g /etc/$OE_CONFIG.conf
sudo sed -i s/"; admin_passwd.*"/"admin_passwd = $OE_SUPERADMIN"/g /etc/$OE_CONFIG.conf
sudo su root -c "echo 'logfile = /var/log/$OE_USER/$OE_CONFIG$1.log' >> /etc/$OE_CONFIG.conf"
sudo su root -c "echo 'addons_path=$OE_HOME/LibrERP/web_client/ea_web-github/addons,$OE_HOME/LibrERP,$OE_HOME/addons' >> /etc/$OE_CONFIG.conf"

#--------------------------------------------------
# Adding deamon (initscript)
#--------------------------------------------------

echo -e "* Create init file"
echo '#!/bin/sh' >> ~/$OE_CONFIG
echo '### BEGIN INIT INFO' >> ~/$OE_CONFIG
echo '# Provides: $OE_CONFIG' >> ~/$OE_CONFIG
echo '# Required-Start: $remote_fs $syslog' >> ~/$OE_CONFIG
echo '# Required-Stop: $remote_fs $syslog' >> ~/$OE_CONFIG
echo '# Should-Start: $network' >> ~/$OE_CONFIG
echo '# Should-Stop: $network' >> ~/$OE_CONFIG
echo '# Default-Start: 2 3 4 5' >> ~/$OE_CONFIG
echo '# Default-Stop: 0 1 6' >> ~/$OE_CONFIG
echo '# Short-Description: Enterprise Business Applications' >> ~/$OE_CONFIG
echo '# Description: ODOO Business Applications' >> ~/$OE_CONFIG
echo '### END INIT INFO' >> ~/$OE_CONFIG
echo 'PATH=/bin:/sbin:/usr/bin' >> ~/$OE_CONFIG
echo "DAEMON=$OE_HOME/server/openerp-server" >> ~/$OE_CONFIG
echo "NAME=$OE_CONFIG" >> ~/$OE_CONFIG
echo "DESC=$OE_CONFIG" >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo '# Specify the user name (Default: openerp).' >> ~/$OE_CONFIG
echo "USER=$OE_USER" >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo '# Specify an alternate config file (Default: /etc/openerp-server.conf).' >> ~/$OE_CONFIG
echo "CONFIGFILE=\"/etc/$OE_CONFIG.conf\"" >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo '# pidfile' >> ~/$OE_CONFIG
echo 'PIDFILE=/var/run/$NAME.pid' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo '# Additional options that are passed to the Daemon.' >> ~/$OE_CONFIG
echo 'DAEMON_OPTS="-c $CONFIGFILE"' >> ~/$OE_CONFIG
echo '[ -x $DAEMON ] || exit 0' >> ~/$OE_CONFIG
echo '[ -f $CONFIGFILE ] || exit 0' >> ~/$OE_CONFIG
echo 'checkpid() {' >> ~/$OE_CONFIG
echo '[ -f $PIDFILE ] || return 1' >> ~/$OE_CONFIG
echo 'pid=`cat $PIDFILE`' >> ~/$OE_CONFIG
echo '[ -d /proc/$pid ] && return 0' >> ~/$OE_CONFIG
echo 'return 1' >> ~/$OE_CONFIG
echo '}' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo 'case "${1}" in' >> ~/$OE_CONFIG
echo 'start)' >> ~/$OE_CONFIG
echo 'echo -n "Starting ${DESC}: "' >> ~/$OE_CONFIG
echo 'start-stop-daemon --start --quiet --pidfile ${PIDFILE} \' >> ~/$OE_CONFIG
echo '--chuid ${USER} --background --make-pidfile \' >> ~/$OE_CONFIG
echo '--exec ${DAEMON} -- ${DAEMON_OPTS}' >> ~/$OE_CONFIG
echo 'echo "${NAME}."' >> ~/$OE_CONFIG
echo ';;' >> ~/$OE_CONFIG
echo 'stop)' >> ~/$OE_CONFIG
echo 'echo -n "Stopping ${DESC}: "' >> ~/$OE_CONFIG
echo 'start-stop-daemon --stop --quiet --pidfile ${PIDFILE} \' >> ~/$OE_CONFIG
echo '--oknodo' >> ~/$OE_CONFIG
echo 'echo "${NAME}."' >> ~/$OE_CONFIG
echo ';;' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo 'restart|force-reload)' >> ~/$OE_CONFIG
echo 'echo -n "Restarting ${DESC}: "' >> ~/$OE_CONFIG
echo 'start-stop-daemon --stop --quiet --pidfile ${PIDFILE} \' >> ~/$OE_CONFIG
echo '--oknodo' >> ~/$OE_CONFIG
echo 'sleep 1' >> ~/$OE_CONFIG
echo 'start-stop-daemon --start --quiet --pidfile ${PIDFILE} \' >> ~/$OE_CONFIG
echo '--chuid ${USER} --background --make-pidfile \' >> ~/$OE_CONFIG
echo '--exec ${DAEMON} -- ${DAEMON_OPTS}' >> ~/$OE_CONFIG
echo 'echo "${NAME}."' >> ~/$OE_CONFIG
echo ';;' >> ~/$OE_CONFIG
echo '*)' >> ~/$OE_CONFIG
echo 'N=/etc/init.d/${NAME}' >> ~/$OE_CONFIG
echo 'echo "Usage: ${NAME} {start|stop|restart|force-reload}" >&2' >> ~/$OE_CONFIG
echo 'exit 1' >> ~/$OE_CONFIG
echo ';;' >> ~/$OE_CONFIG
echo '' >> ~/$OE_CONFIG
echo 'esac' >> ~/$OE_CONFIG
echo 'exit 0' >> ~/$OE_CONFIG

echo -e "* Security Init File"
sudo mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
sudo chmod 755 /etc/init.d/$OE_CONFIG
sudo chown root: /etc/init.d/$OE_CONFIG

echo -e "* Start OpenERP on Startup"
sudo update-rc.d $OE_CONFIG defaults

sudo service $OE_CONFIG start
echo "Done! The OpenERP server can be started with: service $OE_CONFIG start"


echo -e "* Create LibreOffice init file"


echo '#!/bin/bash ' >> ~/$LO_CONFIG
echo '# openoffice.org headless server script ' >> ~/$LO_CONFIG
echo '# ' >> ~/$LO_CONFIG
echo '# Author: Vic Vijayakumar ' >> ~/$LO_CONFIG
echo '# Modified by Federico Ch. Tomasczik ' >> ~/$LO_CONFIG
echo '# Vastly Modified by Gervais de Montbrun -> February 2014 ' >> ~/$LO_CONFIG
echo '## Tested with LibreOffice 3.5 on Ubuntu 12.04.3 LTS ' >> ~/$LO_CONFIG
echo '## Ubuntu has dropped openoffice.org-headless package ' >> ~/$LO_CONFIG
echo '## CentOS by default does not allow apache user to have a shell ' >> ~/$LO_CONFIG
echo '## If you want this to work on CentOS, then: ' >> ~/$LO_CONFIG
echo '###  sed -i "s|apache:x:48:48:Apache:/var/www:/sbin/nologin|apache:x:48:48:Apache:/var/www:/bin/sh|" /etc/passwd ' >> ~/$LO_CONFIG
echo '###  sed -i "s|www-data|apache|g" /etc/init.d/openoffice ' >> ~/$LO_CONFIG
echo '# ' >> ~/$LO_CONFIG
echo '# it\''s a service! ' >> ~/$LO_CONFIG
echo '### BEGIN INIT INFO ' >> ~/$LO_CONFIG
echo '# chkconfig: 2345 80 30 ' >> ~/$LO_CONFIG
echo '# processname: openoffice ' >> ~/$LO_CONFIG
echo '# Provides: openoffice headless ' >> ~/$LO_CONFIG
echo '# Required-Start: $all ' >> ~/$LO_CONFIG
echo '# Required-Stop: $all ' >> ~/$LO_CONFIG
echo '# Default-Start: 2 3 4 5 ' >> ~/$LO_CONFIG
echo '# Default-Stop: 0 1 6 ' >> ~/$LO_CONFIG
echo '# Short-Description: Start openoffice-headless at boot. ' >> ~/$LO_CONFIG
echo '# Description: headless openoffice server script ' >> ~/$LO_CONFIG
echo '### END INIT INFO ' >> ~/$LO_CONFIG
echo ' ' >> ~/$LO_CONFIG
echo 'OOo_HOME=/usr/bin ' >> ~/$LO_CONFIG
echo 'SOFFICE_PATH=$OOo_HOME/soffice ' >> ~/$LO_CONFIG
echo 'PID_SEARCH="pgrep -nf $SOFFICE_PATH" ' >> ~/$LO_CONFIG
echo ' ' >> ~/$LO_CONFIG
echo 'set -e ' >> ~/$LO_CONFIG
echo ' ' >> ~/$LO_CONFIG
echo 'case "$1" in ' >> ~/$LO_CONFIG
echo '  start) ' >> ~/$LO_CONFIG
echo '    if [ `$PID_SEARCH` ]; then ' >> ~/$LO_CONFIG
echo '     echo "OpenOffice headless server has already started." ' >> ~/$LO_CONFIG
echo '    else ' >> ~/$LO_CONFIG
echo '      echo "Starting OpenOffice headless server" ' >> ~/$LO_CONFIG
echo '      /bin/su - openerp -c "$SOFFICE_PATH --headless --nologo --nofirststartwizard --accept=\"socket,host=127.0.0.1,port=8100;urp\"" & > /dev/null 2>&1 ' >> ~/$LO_CONFIG
echo '    fi ' >> ~/$LO_CONFIG
echo '  ;; ' >> ~/$LO_CONFIG
echo ' ' >> ~/$LO_CONFIG
echo '  stop) ' >> ~/$LO_CONFIG
echo '    if [ `$PID_SEARCH` ]; then ' >> ~/$LO_CONFIG
echo '      echo "Stopping OpenOffice headless server." ' >> ~/$LO_CONFIG
echo '      killall -9 soffice.bin ' >> ~/$LO_CONFIG
echo '      sleep 5 ' >> ~/$LO_CONFIG
echo '    else ' >> ~/$LO_CONFIG
echo '      echo "Openoffice headless server is not running." ' >> ~/$LO_CONFIG
echo '    fi ' >> ~/$LO_CONFIG
echo '  ;; ' >> ~/$LO_CONFIG
echo ' ' >> ~/$LO_CONFIG
echo '  status) ' >> ~/$LO_CONFIG
echo '    if [ `$PID_SEARCH` ]; then ' >> ~/$LO_CONFIG
echo '      echo "OpenOffice headless is running" ' >> ~/$LO_CONFIG
echo '      exit 0 ' >> ~/$LO_CONFIG
echo '    else ' >> ~/$LO_CONFIG
echo '      echo "OpenOffice headless is not currently running, you can start it with $0 start" ' >> ~/$LO_CONFIG
echo '      exit 1 ' >> ~/$LO_CONFIG
echo '    fi ' >> ~/$LO_CONFIG
echo '  ;; ' >> ~/$LO_CONFIG
echo ' ' >> ~/$LO_CONFIG
echo 'restart) $0 stop ; $0 start ;; ' >> ~/$LO_CONFIG
echo 'status) status ;; ' >> ~/$LO_CONFIG
echo ' ' >> ~/$LO_CONFIG
echo '*) ' >> ~/$LO_CONFIG
echo '  echo "Usage: $0 {start|stop|restart|status}" ' >> ~/$LO_CONFIG
echo '  exit 1 ' >> ~/$LO_CONFIG
echo 'esac ' >> ~/$LO_CONFIG
echo 'exit 0 ' >> ~/$LO_CONFIG

echo -e "* Security Init File"
sudo mv ~/$LO_CONFIG /etc/init.d/$LO_CONFIG
sudo chmod 755 /etc/init.d/$LO_CONFIG
sudo chown root: /etc/init.d/$LO_CONFIG

echo -e "* Start LibrOffice on Startup"
sudo update-rc.d $LO_CONFIG defaults

sudo service $LO_CONFIG start

echo -e "openerp ALL=(ALL) NOPASSWD: /etc/init.d/office_init" >> /etc/sudoers




