#!/bin/bash

# TODO
# Fix cloning sites with subdomains, xxx.bellcom.dk. Seems to fail now
# SSH keys? Sudo?
# Lots of cleanup :)

declare -A SETTINGS
SETTINGS["quiet"]="n"
SETTINGS["use-remote-host"]="y"
SETTINGS["remote-host"]='devel.bellcom.dk'
SETTINGS["overwrite-existing"]="n"
SETTINGS["new-domain-name-suffix"]="devel.dk"
SETTINGS["site-type"]="drupal"
SETTINGS["site-version"]="7"
SETTINGS["tmp-dir"]="/var/tmp"
SETTINGS["vhost-url"]="http://tools.bellcom.dk/vhost.txt"
SETTINGS["remote-host-ip"]=$(dig +short ${SETTINGS["remote-host"]})
SETTINGS["create-tarball"]="n"
SETTINGS["from-tarball"]="n"
SETTINGS["script-name"]=$0
SETTINGS["existing-vhost-name"]=""
SETTINGS["new-vhost-name"]=""
SETTINGS["database-admin-username"]="root"

function info {
  if [[ ${SETTINGS["quiet"]} == "n" ]]; then
    echo $@
  fi
}

function warning {
  echo -e "\e[01;33m${@}\e[00m"
}

function error {
  echo -e "\e[00;31m${@}\e[00m"
}

function success {
  if [[ ${SETTINGS["quiet"]} == "n" ]]; then
    echo -e "\e[00;32m${@}\e[00m"
  fi
}



function usage {
cat <<EOF
$0 [ACTION] [OPTION]
Global options:
-h          this help
-q          be quiet

Action specific options:
   create-tarball
            --vhost Which virtual host to create tarball from (in /etc/apache2/sites-enabled/)
   
   from-tarball
            --location Location to tarball
            --remote If tarball is on remote server 

   clone-drupal
            --vhost Which virtual host to create tarball from (in /etc/apache2/sites-enabled/)
            --remote Destination server (else default will be used)

   drush-archive-restore
            --location Location of archive
            --destination
            --db-url
   
   fix-permissions: Changes permissions on dir to owner www-data and group g+rwX
            --location Which folder to fix permissions on 

   create-database: Create new empty database
            --user Username for access
            --password Password for access
            --name Database name

   create-vhost: Creates a new virtual host
            --user Username for htaccess
            --password Password for htaccess
            --vhost Virtual host name
EOF
}

if [[ -z $1 ]]; then
  error "You must provide one of the supportet actions"
  usage
  exit 1
fi

MAIN_ACTION="help"

#
# Setup getopt pr action
#
# MAIN_ACTION is used at the end of the script to start the correct function
#
case $1 in
  "create-tarball")
    MAIN_ACTION=$1
    ARGS=$(getopt -l "vhost:" -- "$@");
    ;;
  "from-tarball")
    MAIN_ACTION=$1
    ARGS=$(getopt -l "location:,remote:" -- "$@");
    ;;
  "clone-drupal")
    MAIN_ACTION=$1
    ARGS=$(getopt -l "vhost:,remote:" -- "$@");
    ;;
  "create-dirs")
    MAIN_ACTION=$1
    ARGS=$(getopt -l "location:" -- "$@");
    SETTINGS["use-remote-host"]="n"
    ;;
  "fix-permissions")
    MAIN_ACTION=$1
    ARGS=$(getopt -l "location:" -- "$@");
    SETTINGS["use-remote-host"]="n"
    ;;
  "drush-archive-restore")
    MAIN_ACTION=$1
    ARGS=$(getopt -l "location:,destination:,db-url:" -- "$@");
    SETTINGS["use-remote-host"]="n"
    ;;
  "create-database")
    MAIN_ACTION=$1
    ARGS=$(getopt -l "user:,password:,name:" -- "$@");
    SETTINGS["use-remote-host"]="n"
    ;;
  "create-vhost")
    MAIN_ACTION=$1
    ARGS=$(getopt -l "user:,password:,vhost:" -- "$@");
    SETTINGS["use-remote-host"]="n"
    ;;
  "help")
    usage;
    exit 0
    ;;
  *)
    error "Unimplimented action: $1"; 
    exit 1
    ;;
  \?)
    error "Unimplimented action: $1"; 
    exit 1
    ;;
esac

eval set -- "$ARGS"

# 
# Read options pr action
#
while true; do
  case "$1" in
    --vhost)
      shift;
      if [ -n "$1" ]; then
        SETTINGS["existing-vhost-name"]=$1
        shift;
      fi
      ;;
    --remote)
      shift;
      if [ -n "$1" ]; then
        SETTINGS["remote-host"]=$1; 
        SETTINGS["use-remote-host"]="y"
        shift;
      fi
      ;;
    --location)
      shift;
      if [ -n "$1" ]; then
        SETTINGS["location"]=$1
        shift;
      fi
      ;;
    --destination)
      shift;
      if [ -n "$1" ]; then
        SETTINGS["destination"]=$1
        shift;
      fi
      ;;
    --db-url)
      shift;
      if [ -n "$1" ]; then
        SETTINGS["db-url"]=$1
        shift;
      fi
      ;;
    --user)
      shift;
      if [ -n "$1" ]; then
        SETTINGS["user"]=$1
        shift;
      fi
      ;;
    --password)
      shift;
      if [ -n "$1" ]; then
        SETTINGS["password"]=$1
        shift;
      fi
      ;;
    --name)
      shift;
      if [ -n "$1" ]; then
        SETTINGS["name"]=$1
        shift;
      fi
      ;;
    --)
      shift;
      break;
      ;;
  esac
done

#
# Check options
#
case $MAIN_ACTION in
  create-tarball)
    if [[ -z ${SETTINGS["existing-vhost-name"]} ]]; then
      error "Missing virtual host"
      usage
      exit
    fi
    ;;
  from-tarball)
    if [[ -n ${SETTINGS["remote-host"]} ]]; then
      TAR_BALL_HOST=${SETTINGS["remote-host"]}
    fi
    ;;
  clone-drupal)
    if [[ -z ${SETTINGS["existing-vhost-name"]} ]]; then
      error "Missing virtual host"
      usage
      exit
    fi
    if [[ -z ${SETTINGS["remote-host"]} ]]; then
      error "Missing remote host"
      usage
      exit
    fi
    ;;
esac

if [[ ! -z ${SETTINGS["new-domain-name-suffix"]} ]]; then
  SETTINGS["new-vhost-name"]="${SETTINGS["existing-vhost-name"]}.${SETTINGS["new-domain-name-suffix"]}"
else
  SETTINGS["new-vhost-name"]="${SETTINGS["existing-vhost-name"]}"
fi

function createVHost {
  local VHOSTPATH="/etc/apache2/sites-available"
  local HTPASSWDFILE="/var/www/.htpasswd"

  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    info "Creating virtual host ${1}"
    local HTPASSWD="$(pwgen -N1 -s 6)"
    # TODO. better username?
    local HTUSER=$1

    local RESULT=''
    RESULT=$(runRemoteCommand "create-vhost" "--user ${HTUSER} --password ${HTPASSWD} --vhost $1")

    info "htaccess login: $HTUSER"
    info "htaccess password: $HTPASSWD"
  elif [[ ${SETTINGS["create-tarball"]} == "y" ]]; then
    warning "createVHost: FIXME: copy vhost?"
  else
    wget -q --output-document=$VHOSTPATH/$1 ${SETTINGS["vhost-url"]}
    perl -pi -e "s/\[domain\]/${1}/g" $VHOSTPATH/$1
    sed -i -e '/ServerAlias/d' $VHOSTPATH/$1
    sed -i -e 's/#Include\ \/etc\/apache2\/limit-bellcom.conf/Include\ \/etc\/apache2\/limit-bellcom.conf/g' $VHOSTPATH/$1
    a2ensite $1
    /etc/init.d/apache2 reload
    # TODO. Check if htaccess file exists and use -c if it doesnt
    htpasswd -b /var/www/.htpasswd ${SETTINGS["user"]} ${SETTINGS["password"]}
  fi
}

function createDirectories {
  # If location option is set, use that path instead of building one based on hostname + subdirs
  # Is used when calling remotely
  if [[ -n ${SETTINGS["location"]} ]]; then
    local DIRS=${SETTINGS["location"]}
  else
    # TODO:
    #local DIRS="/var/www/${1}/{public_html,tmp,logs,sessions}"
    local DIRS="/var/www/${1}"
  fi

  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    info "Creating directories ${DIRS} on remote host"
    local RESULT=''
    RESULT=$(runRemoteCommand "create-dirs" $DIRS)
  else
    info "Creating directories ($HOST)"

    # FIXME: when run remotely it is a bit dangurous
    # TODO: Do we need eval to expand variable?
    if [[ $UID -ne 0 ]]; then
      #eval "sudo mkdir -p ${DIRS}"
      sudo mkdir -p ${DIRS}
    else
      #eval "mkdir -p ${DIRS}"
      mkdir -p ${DIRS}
    fi
  fi
}

function detectSiteTypeAndVersion {
  info "Detecting site type and version for ${1}"
  # TODO: make this usefull for other than drupal
  if [[ -e "${1}/public_html/ezpublish.cron" ]]; then
    SETTINGS["site-type"]='ez-publish'
    SETTINGS["site-version"]='unknown'
  elif [[ -d "${1}/public_html/modules/blockcart" ]]; then
    SETTINGS["site-type"]='prestashop'
    SETTINGS["site-version"]='unknown'
  elif [[ -f "${1}/public_html/misc/drupal.js" ]]; then
    SETTINGS["site-type"]='drupal'
    SETTINGS["site-version"]='7'
  fi
  info "-> Type   : ${SETTINGS["site-type"]}"
  info "-> Version: ${SETTINGS["site-version"]}"
}

function checkForExistingSite {
  local VHOST_PATH=$1 

  info "Checking for existing site"
  local EXISTS="n"
  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    local RESULT='';
    RESULT=$(runRemoteCommand "check-existing-site" "${VHOST_PATH}")
    if [[ $RESULT == 'y' ]]; then
      EXISTS="y"
    fi
  else
    if [[ -d ${VHOST_PATH} ]]; then
      EXISTS="y"
    fi
  fi

  if [[ $EXISTS == "y" ]]; then
    if [[ ${SETTINGS["overwrite-existing"]} == "n" ]]; then
      warning "Site '${VHOST_PATH}' exists"
      local OVERWRITE=n
      echo -n "Do you want to overwrite? (y/N): "
      read OVERWRITE
      if [[ $OVERWRITE == 'y' ]]; then
        warning "Overwriting existing site (User conirmed)"
      else
        info "Not overwriting, exiting"
        exit
      fi
    else
      warning "Overwriting existing site"
    fi
  fi
}

function checkVhost {
  local VHOST=$1
  info "Checking virtual host '${VHOST}'"
  if [[ ! -e "/etc/apache2/sites-enabled/${VHOST}" ]]; then
    error "Virtual host '/etc/apache2/sites-enabled/${VHOST}' not found"
    exit;
  fi
}

function createDatabase {
  local USER=$1
  local PASSWORD=$2
  local DBNAME=$3

  if [[ ! -f ~/.my.cnf ]]; then
    error "Missing ~/.my.cnf file, it must exist and contain MySQL password"
    exit 1
  fi

  mysql -u root -e "CREATE DATABASE ${DBNAME}"
  mysql -u root -e "GRANT ALL ON ${DBNAME}.* TO ${USER}@localhost IDENTIFIED BY \"${PASSWORD}\""
  mysql -u root -e "FLUSH PRIVILEGES"
}

function runRemoteCommand {
  local COMMAND='exit'
  local RESULT=''
  case $1 in
      'check-existing-site'  )
        COMMAND="if [[ -d ${2} ]]; then echo y; else echo n; fi"
        ;;
      'create-dirs'  )
        # FIXME: hardcoded path for testing
        COMMAND="sudo ~hf/create-test-site.sh create-dirs --location ${2}"
        ;;
      'fix-permissions'  )
        # FIXME: hardcoded path for testing
        COMMAND="sudo ~hf/create-test-site.sh fix-permissions --location ${2}"
        ;;
      'drush-archive-restore'  )
        # FIXME: hardcoded path for testing
        COMMAND="sudo ~hf/create-test-site.sh drush-archive-restore ${2}"
        ;;
      'create-database'  )
        # FIXME: hardcoded path for testing
        COMMAND="sudo ~hf/create-test-site.sh create-database ${2}"
        ;;
      'create-vhost'  )
        # FIXME: hardcoded path for testing
        COMMAND="sudo ~hf/create-test-site.sh create-vhost ${2}"
        ;;
      'drush'  )
        COMMAND="/usr/bin/drush ${2}"
        ;;
      'mysql'  )
        COMMAND="mysql ${2}"
        ;;
  esac

  RESULT=$(/usr/bin/ssh ${SETTINGS["remote-host"]} "$COMMAND")
  echo $RESULT
}

function cloneSite {
  local EXISTING_VHOSTNAME=$1 
  local NEW_VHOSTNAME=$2

  # TODO: Should be in cloneDrupalSite
  if [[ ${SETTINGS["create-tarball"]} == "y" ]]; then
    info "Cloning site ${EXISTING_VHOSTNAME} to tarball"
  else
    info "Cloning site from ${EXISTING_VHOSTNAME} to ${NEW_VHOSTNAME} on ${SETTINGS["remote-host"]}"
  fi
  case ${SETTINGS["site-type"]} in
      drupal  ) cloneDrupalSite "${EXISTING_VHOSTNAME}" "${NEW_VHOSTNAME}";;
  esac
}

function fixSettings {
  case ${SETTINGS["site-type"]} in
      drupal  ) fixDrupalSettings $1 $2;;
  esac
}

#
#
#
function fixPermissions {
  # If location option is set, use that path instead of building one based on hostname + subdirs
  # Is used when calling remotely
  if [[ -n ${SETTINGS["location"]} ]]; then
    local BASE_DIR=${SETTINGS["location"]}
  else
    #local BASE_DIR="/var/www/${1}/public_html"
    local BASE_DIR="/var/www/${1}"
  fi

  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    #for COMMAND in "${COMMANDS[@]}"; do
      #/usr/bin/ssh ${SETTINGS["remote-host"]} "$COMMAND"
    #done
    local RESULT=''
    RESULT=$(runRemoteCommand "fix-permissions" "$BASE_DIR")
  else
    declare -A COMMANDS
    # FIXME: remote chmod... nice
    # TODO: test: no longer /var/www/$1 but /var/www/$1/public_html
    COMMANDS[1]="/bin/chmod -R g+rwX $BASE_DIR"
    COMMANDS[2]="/bin/chgrp -R www-data $BASE_DIR"
    if [[ ${SETTINGS["site-type"]} == drupal && -d ${BASE_DIR}/sites/default ]]; then
      COMMANDS[3]="/bin/chmod -w ${BASE_DIR}/sites/default"
      COMMANDS[4]="/bin/chmod -w ${BASE_DIR}/sites/default/settings.php"
    fi
    for COMMAND in "${COMMANDS[@]}"; do
       $COMMAND
    done
  fi
}

function cloneDrupalSite {
  info "-> Cloning Drupal site"
  local EXISTING_VHOSTNAME=$1 
  local NEW_VHOSTNAME=$2
  local DEST=$NEW_VHOSTNAME;

  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    DEST=${SETTINGS["remote-host"]}:${NEW_VHOSTNAME}
  fi
  
  generateNewDatabaseSettings $NEW_VHOSTNAME
  drupalDrushArchiveDump $EXISTING_VHOSTNAME

  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    # FIXME: remove hardcoded hostname
    scp ${SETTINGS["tmp-dir"]}/${EXISTING_VHOSTNAME}.tgz devel:${SETTINGS["tmp-dir"]}

    local ARCHIVE=${SETTINGS["tmp-dir"]}/${EXISTING_VHOSTNAME}.tgz
    local DESTINATION="/var/www/${NEW_VHOSTNAME}/public_html"

    runRemoteCommand "create-database" "--user ${SETTINGS["database-username"]} --password ${SETTINGS["database-password"]} --name ${SETTINGS["database-name"]}"
    drupalDrushArchiveRestore $ARCHIVE $DESTINATION
  
    # Cleanup
    rm -f $ARCHIVE
  elif [[ ${SETTINGS["create-tarball"]} == "y" ]]; then
    success "Tarball is in ${SETTINGS["tmp-dir"]}/${EXISTING_VHOSTNAME}.tgz"
    success "Now run the following command on the host where you want the site to run:"
    info "Remember to export MYSQL_ADMIN_PASSWORD with the password to your local MySQL root user"
    info ${SETTINGS["script-name"]} "-f ${EXISTING_VHOSTNAME} ${NEW_VHOSTNAME} $HOSTNAME" ${SETTINGS["tmp-dir"]}/${EXISTING_VHOSTNAME}.tgz
    exit
  else
    warning "cloneDrupalSite: Doesn't know what to do"
  fi
}

function fixDrupalSettings {
  local EXISTING_VHOSTNAME=$1 
  local NEW_VHOSTNAME=$2

  info "Fixing Drupal site settings"

  # vget is a like search => use grep to filter
  local EXISTING_SITENAME=$(/usr/bin/drush -r /var/www/${NEW_VHOSTNAME}/public_html vget site_name | grep '^site_name:' | cut -d\" -f2)
  local NEW_SITENAME="${EXISTING_SITENAME} TEST"
  local NEW_SITE="/var/www/${NEW_VHOSTNAME}"
  local NEW_SITE_PUBLIC="${NEW_SITE}/public_html"
  local NEW_SETTINGS_FILE="/var/www/${NEW_VHOSTNAME}/public_html/sites/default/settings.php"
  # TODO: Might pick the wrong IP if there are multiple NICs 
  local INTIP=$(/sbin/ifconfig | egrep -o '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -v "\(^127\|255\)" | head -1)

  declare -A COMMANDS
  # TODO:
  # add -y?
  # add --quiet?
  # file_directory_temp i 6?
  COMMANDS[1]="-r ${NEW_SITE_PUBLIC} vset site_name \"${NEW_SITENAME}\""
  COMMANDS[2]="-r ${NEW_SITE_PUBLIC} vset file_temporary_path ${NEW_SITE}/tmp/"
  COMMANDS[3]="-r ${NEW_SITE_PUBLIC} vset error_level 2"
  if [[ $STAGEMODULE == 'y' ]]; then
    COMMANDS[4]="-r ${NEW_SITE_PUBLIC} dl stage_file_proxy"
    COMMANDS[5]="-r ${NEW_SITE_PUBLIC} -y en stage_file_proxy"
  fi
  COMMANDS[6]="-r ${NEW_SITE_PUBLIC} cc all"

  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    for COMMAND in "${COMMANDS[@]}"; do
      runRemoteCommand 'drush' "$COMMAND"
    done
  else
    for COMMAND in "${COMMANDS[@]}"; do
       /usr/bin/drush $COMMAND
    done
  fi

  # FIXME:
  # - Needs to be run with sudo, aka runRemoteCommand
  if [[ $STAGEMODULE == 'y' ]]; then
    # just add stage_file_proxy stuff to settings. A better way? Drush?
    /usr/bin/ssh ${SETTINGS["remote-host"]} "echo \"\\\$conf['stage_file_proxy_origin'] = 'http://$1';\" >> $NEW_SETTINGS_FILE"
    # adding to hostfile needed because of stage_file_proxy. But only on our servers.
    /usr/bin/ssh ${SETTINGS["remote-host"]} "echo \"$INTIP $1\" >> /etc/hosts"
  fi

  # add the new sitename to /etc/hosts
  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    /usr/bin/ssh ${SETTINGS["remote-host"]} "echo \"${SETTINGS["remote-host-ip"]} ${SETTINGS["new-vhost-name"]}\" >> /etc/hosts"
  else
    echo ${INTIP} ${SETTINGS["new-vhost-name"]} >> /etc/hosts
  fi
}

function generateNewDatabaseSettings {
  # create a database user of maxlength 10 and replace . with _
  # TODO: Also replace other chars like "-"?
  SETTINGS["database-username"]=$(expr substr ${1//./_} 1 10)
  SETTINGS["database-name"]=${1//./_}
  SETTINGS["database-password"]=$(pwgen -N1 -s 10)
}

function drupalDrushArchiveDump {
  # TODO make this an option too, just a quick way for now
  STAGEMODULE="n"
  echo -n "Do you want to to use the stage_file_proxy module (https://drupal.org/project/stage_file_proxy)? (y/N): "
  read STAGEMODULE
  if [[ $STAGEMODULE == "y" ]]; then
    /usr/bin/drush archive-dump -r /var/www/$1/public_html --tar-options=" --exclude=%files" --destination=${SETTINGS["tmp-dir"]}/$1.tgz
  else
    /usr/bin/drush archive-dump -r /var/www/$1/public_html --destination=${SETTINGS["tmp-dir"]}/$1.tgz
  fi
}

function drupalDrushArchiveRestore {
  local ARCHIVE=$1
  local DESTINATION=$2

  if [[ -n $3 ]]; then
    local DB_URL=$3
  else
    local DB_URL="mysql://${SETTINGS["database-username"]}:${SETTINGS["database-password"]}@localhost/${SETTINGS["database-name"]}"
  fi

  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    runRemoteCommand "drush-archive-restore" "--location ${ARCHIVE} --destination ${DESTINATION} --db-url=${DB_URL}"
    #runRemoteCommand "drush" "archive-restore --overwrite ${ARCHIVE} --destination=${DESTINATION} --db-url=mysql://${SETTINGS["database-username"]}:${SETTINGS["database-password"]}@localhost/${SETTINGS["database-name"]} --db-su=${SETTINGS["database-admin-username"]} --db-su-pw=${SETTINGS["database-admin-password"]}"
  else
      #/usr/bin/drush archive-restore --overwrite ${ARCHIVE} --destination=${DESTINATION} --db-url=${DB_URL} --db-su=${SETTINGS["database-admin-username"]} --db-su-pw=${SETTINGS["database-admin-password"]}
    /usr/bin/drush archive-restore --overwrite ${ARCHIVE} --destination=${DESTINATION} --db-url=${DB_URL}
  fi
}

function sendStatusMail {
  info "-> Sending status mail"
  USER="$(whoami)@bellcom.dk"
  CC="mmh@bellcom.dk"
  HOSTNAME=$(hostname)
  echo "$2 created on ${SETTINGS["remote-host"]} from $1 by $USER" | mail -s "Testsite created on $HOSTNAME" -c $CC $USER
  # TODO. Add htaccess info
}

#
# Creates a copy of the site on a remote hosts
#
function mainRemoteClone {
  info "Cloning site to remote"

  checkVhost ${SETTINGS["existing-vhost-name"]}
  checkForExistingSite "/var/www/${SETTINGS["new-vhost-name"]}"
  detectSiteTypeAndVersion "/var/www/${SETTINGS["existing-vhost-name"]}"

  createDirectories ${SETTINGS["new-vhost-name"]}
  fixPermissions ${SETTINGS["new-vhost-name"]}
  cloneSite ${SETTINGS["existing-vhost-name"]} ${SETTINGS["new-vhost-name"]}
  createVHost ${SETTINGS["new-vhost-name"]}
  fixSettings ${SETTINGS["existing-vhost-name"]} ${SETTINGS["new-vhost-name"]}
  sendStatusMail ${SETTINGS["existing-vhost-name"]} ${SETTINGS["new-vhost-name"]}
}

#
# Creates a tar ball which can be downloaded and used to create a copy
#
function mainCreateTar {
  info "Cloning site to tar ball"

  if [[ ${SETTINGS["create-tarball"]} == ${SETTINGS["use-remote-host"]} ]]; then
    error "You can't use remote host with tarball option"
    exit;
  fi

  checkVhost ${SETTINGS["existing-vhost-name"]}
  detectSiteTypeAndVersion "/var/www/${SETTINGS["existing-vhost-name"]}"
  cloneSite ${SETTINGS["existing-vhost-name"]} ${SETTINGS["new-vhost-name"]}
  createVHost ${SETTINGS["new-vhost-name"]}
}

#
# Downloads a remote tar ball and creates a site based on it
#
function mainExtractTar {
  if [[ -z ${SETTINGS["database-admin-password"]} ]]; then
    error "Missing database admin password, please set \$MYSQL_ADMIN_PASSWORD in your environment"
  fi

  info "Fetching and extracting tar ball"
  scp ${TAR_BALL_HOST}:${SETTINGS["location"]} .

  createDirectories ${SETTINGS["new-vhost-name"]}

  generateNewDatabaseSettings ${SETTINGS["new-vhost-name"]}

  local ARCHIVE=${SETTINGS["existing-vhost-name"]}.tgz
  local DESTINATION="/var/www/${SETTINGS["new-vhost-name"]}/public_html"

  drupalDrushArchiveRestore $ARCHIVE $DESTINATION

  fixSettings ${SETTINGS["existing-vhost-name"]} ${SETTINGS["new-vhost-name"]}

  rm $(basename ${SETTINGS["location"]})
  /usr/bin/ssh ${TAR_BALL_HOST} "rm ${SETTINGS["location"]}"
  
  # fixPermissions ${SETTINGS["new-vhost-name"]}

  createVHost ${SETTINGS["new-vhost-name"]}
} 

#
# Run functions
#
echo `date` ": ${MAIN_ACTION}" >> /tmp/create-test-site.log

case $MAIN_ACTION in
  "create-tarball")
    mainCreateTar
    ;;
  "from-tarball")
    mainExtractTar
    ;;
  "clone-drupal")
    mainRemoteClone
    ;;
  "create-dirs")
    echo ${SETTINGS["location"]} >> /tmp/create-test-site.log
    createDirectories ${SETTINGS["location"]}
    ;;
  "fix-permissions")
    echo ${SETTINGS["location"]} >> /tmp/create-test-site.log
    fixPermissions ${SETTINGS["location"]}
    ;;
  "drush-archive-restore")
    echo ${SETTINGS["location"]} >> /tmp/create-test-site.log
    drupalDrushArchiveRestore ${SETTINGS["location"]} ${SETTINGS["destination"]} ${SETTINGS["db-url"]}
    ;;
  "create-database")
    createDatabase ${SETTINGS["user"]} ${SETTINGS["password"]} ${SETTINGS["name"]}
    ;;
  "create-vhost")
    createVHost ${SETTINGS["existing-vhost-name"]}
    ;;
esac
