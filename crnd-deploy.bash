#!/bin/bash

# CRND Deploy - the simple way to start new production-ready Odoo instance.
# Copyright (C) 2020  Center of Research and Development
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


# WARN: Must be ran under SUDO

# NOTE: Automaticaly installs odoo-helper-scripts if not installed yet

# Supports passing parametrs as environment variables and as arguments to script
# Environment vars and default values:
ODOO_USER=axanta
ODOO_INSTALL_DIR=/opt/axanta
ODOO_DB_HOST=localhost
ODOO_DB_USER=axanta
ODOO_DB_PASSWORD="False"
ODOO_REPO=https://github.com/odoo/odoo
ODOO_BRANCH=16.0
ODOO_VERSION=16.0
ODOO_WORKERS=5
ODOO_CONF_FILE=/opt/axanta/conf/axanta.conf
LOG_FILE=/opt/axanta/logs/axanta.log

AXANTA_REPO=https://github.com/burhanghee/ax-addons-16.git
AXANTA_BRANCH=16.0

#
# Also some configuration could be passed as command line args:
#   sudo bash crnd-deploy.bash <db_host> <db_user> <db_pass>
# 

#--------------------------------------------------
# Script params
#--------------------------------------------------
SCRIPT=$0;
SCRIPT_NAME=$(basename $SCRIPT);
SCRIPT_DIR=$(dirname $SCRIPT);
SCRIPT_PATH=$(readlink -f $SCRIPT);
NGIX_CONF_GEN="$SCRIPT_DIR/gen_nginx.py";

WORKDIR=`pwd`;

#--------------------------------------------------
# Version
#--------------------------------------------------
CRND_DEPLOY_VERSION="1.1.1"

#--------------------------------------------------
# Defaults
#--------------------------------------------------
DEFAULT_ODOO_BRANCH=16.0
DEFAULT_ODOO_VERSION=16.0
#--------------------------------------------------
# Parse environment variables
#--------------------------------------------------
ODOO_REPO=${ODOO_REPO:-https://github.com/odoo/odoo};
ODOO_BRANCH=${ODOO_BRANCH:-$DEFAULT_ODOO_BRANCH};
ODOO_VERSION=${ODOO_VERSION:-$DEFAULT_ODOO_VERSION};
ODOO_USER=${ODOO_USER:-axanta};
ODOO_WORKERS=${ODOO_WORKERS:-2};
PROJECT_ROOT_DIR=${ODOO_INSTALL_DIR:-/opt/axanta};
DB_HOST=${ODOO_DB_HOST:-localhost};
DB_USER=${ODOO_DB_USER:-axanta};
DB_PASSWORD=${ODOO_DB_PASSWORD:-axanta};
INSTALL_MODE=${INSTALL_MODE:-archive};
ODOO_BUILD_PYTHON_VERSION=3.10.12


#--------------------------------------------------
# Define color variables
#--------------------------------------------------
NC='\e[0m';
REDC='\e[31m';
GREENC='\e[32m';
YELLOWC='\e[33m';
BLUEC='\e[34m';
LBLUEC='\e[94m';


if [[ $UID != 0 ]]; then
    echo -e "${REDC}ERROR${NC}";
    echo -e "${YELLOWC}Please run this script as root or with sudo:${NC}"
    echo -e "${BLUEC}sudo $0 $* ${NC}"
    exit 1
fi


#--------------------------------------------------
# FN: Print usage
#--------------------------------------------------
function print_usage {

    echo "
Usage:

    crnd-deploy.bash [options]    - install odoo

Options:

    --odoo-repo <repo>         - git repository to clone odoo from.
                                 default: $ODOO_REPO
    --odoo-branch <branch>     - odoo branch to clone.
                                 default: $ODOO_BRANCH
    --odoo-version <version>   - odoo version to clone.
                                 default: $ODOO_VERSION
    --odoo-user <user>         - name of system user to run odoo with.
                                 default: $ODOO_USER
    --build-python <ver>       - build custom python for specified version
                                 'auto' could be specified to automatically guess correct version.
    --build-python-if-needed   - Automatically detect if it is necessary to build custom python.
    --build-python-optimize    - Apply '--enable-optimizations' for python build.
                                 This could take a while.
    --build-python-sqlite3     - Apply  --enable-loadable-sqlite-extensions
                                 when building python.
    --node-version <ver>       - Version of node.js to be installed. By default lts.
    --db-host <host>           - database host to be used by odoo.
                                 default: $DB_HOST
    --db-user <user>           - database user to connect to db with
                                 default: $DB_USER
    --db-password <password>   - database password to connect to db with
                                 default: $DB_PASSWORD
    --install-dir <path>       - directory to install odoo in
                                 default: $PROJECT_ROOT_DIR
    --install-mode <mode>      - installation mode. could be: 'git', 'archive'
                                 default: $INSTALL_MODE
    --local-postgres           - install local instance of postgresql server
    --proxy-mode               - Set this option if you plan to run odoo
                                 behind proxy (nginx, etc)
    --workers <workers>        - number of workers to run.
                                 Default: $ODOO_WORKERS
    --local-nginx              - install local nginx and configure it for this
                                 odoo instance
    --odoo-helper-dev          - If set then use dev version of odoo-helper
    --install-ua-locales       - If set then install also uk_UA and ru_RU
                                 system locales.
    -v|--version               - print version and exit
    -h|--help|help             - show this help message

Suggestion:

    Take a look at [Yodoo Cockpit](https://crnd.pro/yodoo-cockpit) project,
    and discover the easiest way to manage your odoo installation.

    Just short notes about [Yodoo Cockpit](https://crnd.pro/yodoo-cockpit):
        - start new production-ready odoo instance in 1-2 minutes.
        - add custom addons to your odoo instances in 5-10 minutes.
        - out-of-the-box email configuration: just press button and
          add some records to your DNS, and get a working email
        - make your odoo instance available to external world in 30 seconds:
          just add single record in your DNS

    If you have any questions, then contact us at
    [info@crnd.pro](mailto:info@crnd.pro),
    so we could schedule online-demonstration.

---
Version: ${CRND_DEPLOY_VERSION}
";
}

#--------------------------------------------------
# Parse command line
#--------------------------------------------------
while [[ $# -gt 0 ]]
do
    key="$1";
    case $key in
        --odoo-repo)
            ODOO_REPO=$2;
            shift;
        ;;
        --odoo-branch)
            ODOO_BRANCH=$2;
            shift;
        ;;
        --odoo-version)
            ODOO_VERSION=$2;
            shift;

            if [ "$ODOO_VERSION" != "$DEFAULT_ODOO_VERSION" ] && [ "$ODOO_BRANCH" == "$DEFAULT_ODOO_BRANCH" ]; then
                ODOO_BRANCH=$ODOO_VERSION;
            fi
        ;;
        --odoo-user)
            ODOO_USER=$2;
            shift;
        ;;
        --build-python)
            ODOO_BUILD_PYTHON_VERSION=$2;
            shift;
        ;;
        --build-python-if-needed)
            ODOO_BUILD_PYTHON_VERSION=auto;
        ;;
        --build-python-optimize)
            ODOO_BUILD_PYTHON_OPTIMIZE=1;
        ;;
        --build-python-sqlite3)
            ODOO_BUILD_PYTHON_SQLITE3=1;
        ;;
        --node-version)
            ODOO_INSTALL_NODE_VERSION=$2;
            shift;
        ;;
        --db-host)
            DB_HOST=$2;
            shift;
        ;;
        --db-user)
            DB_USER=$2;
            shift;
        ;;
        --db-password)
            DB_PASSWORD=$2;
            shift;
        ;;
        --install-dir)
            PROJECT_ROOT_DIR=$2;
            shift;
        ;;
        --install-mode)
            if [ "$2" != "git" ] && [ "$2" != "archive" ]; then
                echo "ERROR: Wrong install mode specified: $2"
                exit 1;
            fi
            INSTALL_MODE=$2;
            shift;
        ;;
        --workers)
            ODOO_WORKERS=$2;
            shift;
        ;;
        --proxy-mode)
            PROXY_MODE=1;
        ;;
        --local-postgres)
            # Generate random password for database
            DB_HOST="localhost";
            DB_PASSWORD="$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 32)";
            INSTALL_LOCAL_POSTGRES=1;
        ;;
        --local-nginx)
            INSTALL_LOCAL_NGINX=1;
            PROXY_MODE=1;
        ;;
        --odoo-helper-dev)
            USE_DEV_VERSION_OF_ODOO_HElPER=1;
        ;;
        --install-ua-locales)
            CRND_DEPLOY_INSTALL_UA_LOCALES=1;
        ;;
        -v|--version)
            echo "$CRND_DEPLOY_VERSION";
            exit 0;
        ;;
        -h|--help|help)
            print_usage;
            exit 0;
        ;;
        *)
            echo "Unknown option global option /command $key";
            echo "Use --help option to get info about available options.";
            exit 1;
        ;;
    esac;
    shift;
done;
#--------------------------------------------------


set -e;   # fail on errors

#--------------------------------------------------
# Update Server and Install Dependencies
#--------------------------------------------------
echo -e "\n${BLUEC}Update Server...${NC}\n";
apt-get update -qq;
apt-get upgrade -qq -y;
echo -e "\n${BLUEC}Installing basic dependencies...${NC}\n";
apt-get install -qqq -y \
    sudo wget locales;

#--------------------------------------------------
# Generate locales
#--------------------------------------------------
echo -e "\n${BLUEC}Update locales...${NC}\n";
sed -i -r "s@# en_US.UTF-8(.*)@en_US.UTF-8\1@" /etc/locale.gen;
sed -i -r "s@# en_GB.UTF-8(.*)@en_GB.UTF-8\1@" /etc/locale.gen;
locale-gen en_US.UTF-8;
locale-gen en_GB.UTF-8;

if [ -n "$CRND_DEPLOY_INSTALL_UA_LOCALES" ]; then
    sed -i -r "s@# ru_UA.UTF-8(.*)@ru_UA.UTF-8\1@" /etc/locale.gen;
    sed -i -r "s@# uk_UA.UTF-8(.*)@uk_UA.UTF-8\1@" /etc/locale.gen;
    locale-gen ru_UA.UTF-8;
    locale-gen uk_UA.UTF-8;
fi

update-locale LANG="en_US.UTF-8";
update-locale LANGUAGE="en_US:en";

#--------------------------------------------------
# Install wkhtmltopdf 
#--------------------------------------------------
echo -e "\n${BLUEC}Installing wkhtmltopdf...${NC}\n";
apt update
apt install -y software-properties-common
add-apt-repository -y universe
apt update
apt install -y wkhtmltopdf fontconfig fonts-dejavu-core fonts-liberation

echo -e "\n${GREENC}Installed wkhtmltopdf...${NC}\n";
wkhtmltopdf --version
which wkhtmltopdf

#--------------------------------------------------
# Ensure odoo-helper installed
#--------------------------------------------------
if ! command -v odoo-helper >/dev/null 2>&1; then
    echo -e "${BLUEC}Odoo-helper not installed! installing...${NC}";
    if ! wget -q -T 2 -O /tmp/odoo-helper-install.bash \
            https://raw.githubusercontent.com/katyukha/odoo-helper-scripts/master/install-system.bash; then
        echo "${REDC}ERROR${NC}: Cannot download odoo-helper-scripts installer from github. Check your network connection.";
        exit 1;
    fi

    # install latest version of odoo-helper scripts
    if [ -z "$USE_DEV_VERSION_OF_ODOO_HElPER" ]; then
        ALWAYS_ANSWER_YES=1 bash /tmp/odoo-helper-install.bash master;
    else
        ALWAYS_ANSWER_YES=1 bash /tmp/odoo-helper-install.bash dev;
    fi

    # Print odoo-helper version
    odoo-helper --version;
fi

# Install odoo pre-requirements
odoo-helper install pre-requirements -y;
odoo-helper install sys-deps -y --branch "$ODOO_BRANCH" "$ODOO_VERSION";

if [ ! -z $INSTALL_LOCAL_POSTGRES ]; then
    odoo-helper install postgres;

    if ! odoo-helper exec postgres_test_connection; then
        echo -e "${YELLOWC}WARNING${NC}: it seams postgres not started, so start it before creating postgres user.";

        # It seams we ran inside docker container, so start postgres server before user creation
        /etc/init.d/postgresql start;
        odoo-helper postgres user-create $DB_USER $DB_PASSWORD;
        /etc/init.d/postgresql stop;
    else
        odoo-helper postgres user-create $DB_USER $DB_PASSWORD;
    fi
fi

#--------------------------------------------------
# Install Odoo
#--------------------------------------------------
echo -e "\n${BLUEC}Installing odoo...${NC}\n";
# import odoo-helper common module, which contains some useful functions
source $(odoo-helper system lib-path common);


# import odoo-helper libs
ohelper_require 'install';
ohelper_require 'config';

# Do not ask confirmation when installing dependencies
ALWAYS_ANSWER_YES=1;

# Configure default odoo-helper variables
config_set_defaults;  # imported from common module

# define addons path to be placed in config files
AXANTA_ADDONS_PATH=$ODOO_INSTALL_DIR/ax-addons-16
AXANTA_ADDONS_DIR=$AXANTA_ADDONS_PATH,$AXANTA_ADDONS_PATH/oca_addons,$AXANTA_ADDONS_PATH/3rd_party_addons,$AXANTA_ADDONS_PATH/oca_reporting_addons,$AXANTA_ADDONS_PATH/tier_validation,$AXANTA_ADDONS_PATH/client_addons,$AXANTA_ADDONS_PATH/oca_operating_unit;

ADDONS_PATH="$ODOO_PATH/openerp/addons,$ODOO_PATH/odoo/addons,$ODOO_PATH/addons,$ADDONS_DIR,$AXANTA_ADDONS_DIR";
INIT_SCRIPT="/etc/init.d/axanta";
ODOO_PID_FILE="/var/run/axanta.pid";  # default odoo pid file location

install_create_project_dir_tree;   # imported from 'install' module

if [ ! -d $ODOO_PATH ]; then
    if [ "$INSTALL_MODE" == "git" ]; then
        install_clone_odoo;   # imported from 'install' module
    elif [ "$INSTALL_MODE" == "archive" ]; then
        install_download_odoo;
    else
        echo -e "${REDC}ERROR:${NC} wrong install mode specified: '$INSTALL_MODE'!";
    fi
fi

# install odoo itself
install_odoo_install;  # imported from 'install' module

# generate odoo config file
declare -A ODOO_CONF_OPTIONS;
ODOO_CONF_OPTIONS[addons_path]="$ADDONS_PATH";
ODOO_CONF_OPTIONS[admin_passwd]="$(random_string 32)";
ODOO_CONF_OPTIONS[data_dir]="$DATA_DIR";
ODOO_CONF_OPTIONS[logfile]="$LOG_FILE";
ODOO_CONF_OPTIONS[db_host]="$DB_HOST";
ODOO_CONF_OPTIONS[db_port]="False";
ODOO_CONF_OPTIONS[dbfilter]="False";
ODOO_CONF_OPTIONS[db_user]="$DB_USER";
ODOO_CONF_OPTIONS[db_password]="$DB_PASSWORD";
ODOO_CONF_OPTIONS[workers]=$ODOO_WORKERS;
ODOO_CONF_OPTIONS[max_cron_threads]=1;
ODOO_CONF_OPTIONS[limit_memory_hard]=24159191040000;
ODOO_CONF_OPTIONS[limit_memory_soft]=20132659200000;
ODOO_CONF_OPTIONS[limit_time_real]=3000000;
ODOO_CONF_OPTIONS[limit_time_cpu]=3000000;
ODOO_CONF_OPTIONS[limit_request]=999999;
ODOO_CONF_OPTIONS[db_maxconn]=5;
ODOO_CONF_OPTIONS[server_wide_modules]=web,base_ext,letsencrypt;
ODOO_CONF_OPTIONS[modules_auto_install_disabled]=partner_autocomplete;

# pid file will be managed by init script, not odoo itself
ODOO_CONF_OPTIONS[pidfile]="None";

if [ ! -z $PROXY_MODE ]; then
    ODOO_CONF_OPTIONS[proxy_mode]="True";
fi

install_generate_odoo_conf $ODOO_CONF_FILE;   # imported from 'install' module

# Write odoo-helper project config
echo "#---ODOO-INSTANCE-CONFIG---" >> /etc/$CONF_FILE_NAME;
echo "`config_print`" >> /etc/$CONF_FILE_NAME;

# this will make odoo helper scripts to run odoo with specified user
# (via sudo call)
echo "SERVER_RUN_USER=$ODOO_USER;" >> /etc/$CONF_FILE_NAME;

#--------------------------------------------------
# Fix odoo 9/10 addons path compatability
#--------------------------------------------------
if [ ! -d $ODOO_PATH/openerp/addons ]; then
    sudo mkdir -p $ODOO_PATH/openerp/addons;
fi
if [ ! -d $ODOO_PATH/odoo/addons ]; then
    sudo mkdir -p $ODOO_PATH/odoo/addons;
fi

#--------------------------------------------------
# Create Odoo User
#--------------------------------------------------
if ! getent passwd $ODOO_USER  > /dev/null; then
    echo -e "\n${BLUEC}Creating Instance user: $ODOO_USER ${NC}\n";
    sudo adduser --system --no-create-home --home $PROJECT_ROOT_DIR \
        --quiet --group $ODOO_USER;
else
    echo -e "\n${YELLOWC}Axanta user already exists, using it.${NC}\n";
fi

#--------------------------------------------------
# Create Init Script
#--------------------------------------------------
echo -e "\n${BLUEC}Creating init script${NC}\n";
sudo cp $ODOO_PATH/debian/init $INIT_SCRIPT
sudo chmod a+x $INIT_SCRIPT
sed -i -r "s@DAEMON=(.*)@DAEMON=$(get_server_script)@" $INIT_SCRIPT;
sed -i -r "s@CONFIG=(.*)@CONFIG=$ODOO_CONF_FILE@" $INIT_SCRIPT;
sed -i -r "s@LOGFILE=(.*)@LOGFILE=$LOG_FILE@" $INIT_SCRIPT;
sed -i -r "s@USER=(.*)@USER=$ODOO_USER@" $INIT_SCRIPT;
sed -i -r "s@PIDFILE=(.*)@PIDFILE=$ODOO_PID_FILE@" $INIT_SCRIPT;
sed -i -r "s@PATH=(.*)@PATH=\1:$VENV_DIR/bin@" $INIT_SCRIPT;
sudo update-rc.d axanta defaults

# Configuration file
sudo chown root:$ODOO_USER $ODOO_CONF_FILE;
sudo chmod 0640 $ODOO_CONF_FILE;

# Log
sudo chown $ODOO_USER:$ODOO_USER $LOG_DIR;
sudo chmod 0750 $LOG_DIR

# Data dir
sudo chown $ODOO_USER:$ODOO_USER $DATA_DIR;

# Odoo root dir
sudo chown $ODOO_USER:$ODOO_USER $PROJECT_ROOT_DIR;

#--------------------------------------------------
# Configure logrotate
#--------------------------------------------------
echo -e "\n${BLUEC}Configuring logrotate${NC}\n";
sudo cat > /etc/logrotate.d/axanta << EOF
$LOG_DIR/*.log {
    copytruncate
    missingok
    notifempty
}
EOF

echo -e "\n${GREENC}Odoo installed!${NC}\n";

#--------------------------------------------------
# Install Axanta
#--------------------------------------------------
echo -e "\n${BLUEC}Installing Axanta...${NC}\n";
if [ ! -d $AXANTA_ADDONS_PATH ]; then
    git clone --depth 1 --branch $AXANTA_BRANCH $AXANTA_REPO $AXANTA_ADDONS_PATH
else
    echo -e "\n${YELLOWC}Axanta already exists. Updating the repo...${NC}\n";
    cd $AXANTA_ADDONS_PATH
    git checkout $AXANTA_BRANCH
    git pull origin $AXANTA_BRANCH
    cd $WORKDIR
    echo -e "\n${GREENC}Axanta Repo Updated!${NC}\n";
fi

$ODOO_INSTALL_DIR/venv/bin/pip3 install -r $AXANTA_ADDONS_PATH/requirements.txt
echo -e "\n${GREENC}Axanta installed!${NC}\n";

if [ ! -z $INSTALL_LOCAL_NGINX ]; then
    echo -e "${BLUEC}Installing and configuring local nginx..,${NC}";
    NGINX_CONF_PATH="/etc/nginx/sites-available/$(hostname).conf";
    sudo apt-get install -qqq -y --no-install-recommends nginx;
    odoo-helper python "$NGIX_CONF_GEN" \
        --instance-name="$(hostname -s)" \
        --frontend-server-name="$(hostname)" > $NGINX_CONF_PATH;
    echo -e "${GREENC}Nginx seems to be installed and default config is generated. ";
    echo -e "Look at $NGINX_CONF_PATH for nginx config.${NC}";
fi

echo -e "\n${BLUEC}Starting Server...${NC}\n";
odoo-helper start
$INIT_SCRIPT status
echo -e "\n${GREENC}Server Started!${NC}\n";


echo -e "\n${BLUEC}Run: \n\t\t tail -f $LOG_FILE \nto view logs${NC}\n";