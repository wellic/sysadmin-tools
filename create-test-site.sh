#!/bin/bash

# TODO
# Fix cloning sites with subdomains, xxx.bellcom.dk. Seems to fail now
# SSH keys? Sudo?
# Lots of cleanup :)

declare -A SETTINGS
SETTINGS["quiet"]=false
SETTINGS["use-remote-host"]=true
SETTINGS["remote-host"]='devel.bellcom.dk'
SETTINGS["overwrite-existing"]=false
SETTINGS["new-domain-name-suffix"]="devel.dk"
SETTINGS["site-type"]="drupal"
SETTINGS["site-version"]="7"
SETTINGS["tmp-dir"]="/var/www/00-backup"
SETTINGS["vhost-url"]="http://tools.bellcom.dk/vhost.txt"
SETTINGS["database-admin-username"]="root"
SETTINGS["remote-host-ip"]=$(dig +short ${SETTINGS["remote-host"]})
# TODO. Find a better way to get sensitive information
# This is the root password for the remote mysql
SETTINGS["database-admin-password"]=$(cat /root/.mysql_password)

EXISTING_VHOSTNAME=$1
if [[ ! -z ${SETTINGS["new-domain-name-suffix"]} ]]; then
  NEW_VHOSTNAME="${1}.${SETTINGS["new-domain-name-suffix"]}"
else
  NEW_VHOSTNAME="${1}"
fi

# A ":" after a flag indicates it will have an option passed with it.
OPTIONS='ohqr:d:'

function info {
  if [[ ${SETTINGS["quiet"]} == false ]]; then
    echo $1
  fi
}

function warning {
  echo -e "\e[01;33m${1}\e[00m"
}

function error {
  echo -e "\e[00;31m${1}\e[00m"
}

function usage {
cat <<EOF
$0 [OPTION] vhost dest
-h          this help
-q          be quiet
-r VALUE    remote host
-o          overwrite existing site
-d VALUE    append VALUE to vhost name
EOF
}

while getopts $OPTIONS OPTION
do
    case $OPTION in
        h  ) usage; exit;;
        q  ) SETTINGS["quiet"]=true;;
        o  ) SETTINGS["overwrite-existing"]=true;;
        r  ) SETTINGS["remote-host"]=$OPTARG; SETTINGS["use-remote-host"]=true;;
        d  ) SETTINGS["new-domain-name-suffix"]=$OPTARG;;
        \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
        :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
        *  ) echo "Unimplimented option: -$OPTARG" >&2; exit 1;;
    esac
done

function createVHost {
  info "Creating virtual host ${1}"
  local VHOSTPATH="/etc/apache2/sites-available"
  local HTPASSWDFILE="/var/www/.htpasswd"
  HTPASSWD="$(pwgen -N1 -s 6)"
# TODO. better username?
  HTUSER=$1
  ssh ${SETTINGS["remote-host"]} "wget -q --output-document=$VHOSTPATH/$1 ${SETTINGS["vhost-url"]}"
  ssh ${SETTINGS["remote-host"]} "perl -pi -e 's/\\[domain\\]/$1/g' $VHOSTPATH/$1"
  ssh ${SETTINGS["remote-host"]} "sed -i -e '/ServerAlias/d' $VHOSTPATH/$1"
  ssh ${SETTINGS["remote-host"]} "sed -i -e 's/#Include\\ \\/etc\\/apache2\\/limit-bellcom.conf/Include\\ \\/etc\\/apache2\\/limit-bellcom.conf/g' $VHOSTPATH/$1"
  ssh ${SETTINGS["remote-host"]} "a2ensite $1"
  ssh ${SETTINGS["remote-host"]} "/etc/init.d/apache2 reload"
# TODO. Check if htaccess file exists and use -c if it doesnt
  ssh ${SETTINGS["remote-host"]} "htpasswd -b /var/www/.htpasswd $HTUSER $HTPASSWD"

  echo "htaccess login: $HTUSER"
  echo "htaccess password: $HTPASSWD"
}

function createDirectories {
  info "Creating directories"
  local DIRS="/var/www/${1}/{public_html,tmp,logs,sessions}"
  if [[ ${SETTINGS["use-remote-host"]} == true ]]; then
    local RESULT='';
    RESULT=$(runRemoteCommand "create-dirs" $DIRS);
  else
    mkdir -p $DIRS
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

function createDb {
  info "Creating database"

  declare -A COMMANDS
  COMMANDS["create"]="-u ${SETTINGS["database-admin-username"]} --password=${SETTINGS["database-admin-password"]} -e 'CREATE DATABASE ${SETTINGS["database-name"]}'"
  COMMANDS["grant"]="-u ${SETTINGS["database-admin-username"]} --password=${SETTINGS["database-admin-password"]} -e \"GRANT ALL ON ${SETTINGS["database-name"]}.* TO ${SETTINGS["database-username"]}@localhost IDENTIFIED BY '${SETTINGS["database-password"]}'\"";

  if [[ ${SETTINGS["use-remote-host"]} == true ]]; then
    for COMMAND in "${COMMANDS[@]}"; do
      runRemoteCommand 'mysql' "$COMMAND"
    done
  else
    for COMMAND in "${COMMANDS[@]}"; do
       mysql $COMMAND
    done
  fi
}

function checkForExistingDb {
  info "Checking for existing database"
  error "-> Not implemented"
}

function checkForExistingSite {
  info "Checking for existing site"
  local EXISTS=false
  if [[ ${SETTINGS["use-remote-host"]} == true ]]; then
    local RESULT='';
    RESULT=$(runRemoteCommand "check-existing-site" "$1");
    #echo "RESULT |${RESULT}|"
    if [[ $RESULT == 'y' ]]; then
      EXISTS=true
    fi
  else
    if [[ -d $1 ]]; then
      EXISTS=true
    fi
  fi

  if [[ $EXISTS == true ]]; then
    if [[ ${SETTINGS["overwrite-existing"]} == false ]]; then
      warning "Site '${1}' exists"
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
  info "Checking virtual host '${1}'"
  if [[ ! -e "/etc/apache2/sites-enabled/${1}" ]]; then
    error "Virtual host '/etc/apache2/sites-enabled/${1}' not found"
    exit;
  fi
}

function confirmSettings {
# TODO: 
  local RESPONSE
  info "Please confirm settings:"
  info "..."
}

function runRemoteCommand {
  local COMMAND='exit'
  local RESULT=''
  case $1 in
      'check-existing-site'  )
        COMMAND="if [[ -d ${2} ]]; then echo y; else echo n; fi"
        ;;
      'create-dirs'  )
        COMMAND="mkdir -p ${2}"
        ;;
      'drush'  )
        COMMAND="/usr/bin/drush ${2}"
        ;;
      'mysql'  )
        COMMAND="mysql ${2}"
        ;;
  esac

  RESULT=$(ssh ${SETTINGS["remote-host"]} "$COMMAND");
  echo $RESULT
}

function cloneSite {
  info "Cloning site from $1 to $2 on ${SETTINGS["remote-host"]}"
  case ${SETTINGS["site-type"]} in
      drupal  ) cloneDrupalSite "$1" "$2";;
  esac
}

function cloneDb {
  # TODO: args missing
  info "Cloning database from $1 to $2 on ${SETTINGS["remote-host"]}"
  case ${SETTINGS["site-type"]} in
    drupal  ) cloneDrupalDb;;
  esac
}

function fixSettings {
  case ${SETTINGS["site-type"]} in
      drupal  ) fixDrupalSettings $1 $2;;
  esac
}

function fixPermissions {
  declare -A COMMANDS
  COMMANDS[1]="/bin/chmod -R g+rwX /var/www/$1"
  COMMANDS[2]="/bin/chgrp -R www-data /var/www/$1"
  if [[ ${SETTINGS["site-type"]} == drupal ]]; then
    COMMANDS[3]="/bin/chmod -w /var/www/$1/public_html/sites/default"
    COMMANDS[4]="/bin/chmod -w /var/www/$1/public_html/sites/default/settings.php"
  fi

  if [[ ${SETTINGS["use-remote-host"]} == true ]]; then
    for COMMAND in "${COMMANDS[@]}"; do
      ssh ${SETTINGS["remote-host"]} "$COMMAND"
    done
  else
    for COMMAND in "${COMMANDS[@]}"; do
       $COMMAND
    done
  fi
}

function cloneDrupalSite {
  info "-> Cloning Drupal site"
  local DEST=$2;
  if [[ ${SETTINGS["use-remote-host"]} == true ]]; then
    DEST=${SETTINGS["remote-host"]}:${2}
  fi
# create a database user of maxlength 10 and replace . with _
# TODO. Also replace other chars like "-"?
  SETTINGS["database-username"]=$(expr substr ${2//./_} 1 10)
  SETTINGS["database-name"]=${2//./_}
  SETTINGS["database-password"]=$(pwgen -N1 -s 10)
# make this an option too, just a quick way for now
  STAGEMODULE=n
  echo -n "Do you want to to use the stage_file_proxy module (https://drupal.org/project/stage_file_proxy)? (y/N): "
  read STAGEMODULE
  if [[ $STAGEMODULE == 'y' ]]; then
    /usr/bin/drush archive-dump -r /var/www/$1/public_html --tar-options=" --exclude=%files" --destination=${SETTINGS["tmp-dir"]}/$1.tgz
  else
    /usr/bin/drush archive-dump -r /var/www/$1/public_html --destination=${SETTINGS["tmp-dir"]}/$1.tgz
  fi
  scp ${SETTINGS["tmp-dir"]}/$1.tgz ${SETTINGS["remote-host"]}:${SETTINGS["tmp-dir"]}
  runRemoteCommand "drush" "archive-restore --overwrite ${SETTINGS["tmp-dir"]}/$1.tgz --destination=/var/www/$2/public_html --db-url=mysql://${SETTINGS["database-username"]}:${SETTINGS["database-password"]}@localhost/${SETTINGS["database-name"]} --db-su=${SETTINGS["database-admin-username"]} --db-su-pw=${SETTINGS["database-admin-password"]}"
# Cleanup
  rm -f ${SETTINGS["tmp-dir"]}/$1.tgz
}

function fixDrupalSettings {
  info "Fixing Drupal site settings"

  # vget is a like search => use grep to filter
  local EXISTING_SITENAME=$(/usr/bin/drush -r /var/www/${1}/public_html vget site_name | grep '^site_name:' | cut -d\" -f2)
  local NEW_SITENAME="${EXISTING_SITENAME} TEST"
  local NEW_SITE="/var/www/${2}"
  local NEW_SITE_PUBLIC="${NEW_SITE}/public_html"
  local NEW_SETTINGS_FILE="/var/www/${2}/public_html/sites/default/settings.php"
  local INTIP=$(/sbin/ifconfig | egrep -o '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -v "\(^127\|255\)")

  declare -A COMMANDS
  # TODO
  # add -y?
  # add --quiet?
  # file_directory_temp i 6?
#  COMMANDS["site_name"]="-r ${NEW_SITE_PUBLIC} vset site_name \'${NEW_SITENAME}\'"
#  COMMANDS["file_temporary_path"]="-r ${NEW_SITE_PUBLIC} vset file_temporary_path /var/www/${NEW_SITE}/tmp/"
#  COMMANDS["error_level"]="-r ${NEW_SITE_PUBLIC} vset error_level 2"
#  COMMANDS["download_stage_file_proxy"]="-r ${NEW_SITE_PUBLIC} dl stage_file_proxy"
#  COMMANDS["enable_stage_file_proxy"]="-r ${NEW_SITE_PUBLIC} -y en stage_file_proxy"
# baah. associative array order seems to be kinda random...
  COMMANDS[1]="-r ${NEW_SITE_PUBLIC} vset site_name \"${NEW_SITENAME}\""
  COMMANDS[2]="-r ${NEW_SITE_PUBLIC} vset file_temporary_path ${NEW_SITE}/tmp/"
  COMMANDS[3]="-r ${NEW_SITE_PUBLIC} vset error_level 2"
  if [[ $STAGEMODULE == 'y' ]]; then
    COMMANDS[4]="-r ${NEW_SITE_PUBLIC} dl stage_file_proxy"
    COMMANDS[5]="-r ${NEW_SITE_PUBLIC} -y en stage_file_proxy"
  fi
  COMMANDS[6]="-r ${NEW_SITE_PUBLIC} cc all"

  if [[ ${SETTINGS["use-remote-host"]} == true ]]; then
    for COMMAND in "${COMMANDS[@]}"; do
      runRemoteCommand 'drush' "$COMMAND"
    done
  else
    for COMMAND in "${COMMANDS[@]}"; do
       /usr/bin/drush $COMMAND
    done
  fi

  if [[ $STAGEMODULE == 'y' ]]; then
    # just add stage_file_proxy stuff to settings. A better way? Drush?
    ssh ${SETTINGS["remote-host"]} "echo \"\\\$conf['stage_file_proxy_origin'] = 'http://$1';\" >> $NEW_SETTINGS_FILE"
    # adding to hostfile needed because of stage_file_proxy. But only on our servers.
    ssh ${SETTINGS["remote-host"]} "echo \"$INTIP $1\" >> /etc/hosts"
  fi

  # add the new sitename to /etc/hosts
  ssh ${SETTINGS["remote-host"]} "echo \"${SETTINGS["remote-host-ip"]} $NEW_VHOSTNAME=\" >> /etc/hosts"
}

#function cloneDrupalDb {
#  info "-> Cloning Drupal database"
#  warning "Not complete"
#  # NOTE sql-sync can create db before import!!
#  drush -vvv -r "/var/www/${EXISTING_VHOSTNAME}/public_html" sql-sync --no-cache --no-dump --source-db-url=mysql://root:my5QLpw@127.0.0.1/mi_dk --target-db-url=mysql://root:my5QLpw@localdev2/mi_dk
#}

shift $(($OPTIND - 1))

if [[ -z $1 ]]; then
  error "Missing virtual host"
  usage
  exit
fi

function sendStatusMail {
  info "-> Sending status mail"
  USER="$(whoami)@bellcom.dk"
  CC="mmh@bellcom.dk"
  HOSTNAME=$(hostname)
  echo "$2 created on ${SETTINGS["remote-host"]} from $1 by $USER" | mail -s "Testsite created on $HOSTNAME" -c $CC $USER
# TODO. Add htaccess info
}

info "Cloning site"
checkVhost $EXISTING_VHOSTNAME
checkForExistingSite "/var/www/${NEW_VHOSTNAME}"
detectSiteTypeAndVersion "/var/www/${EXISTING_VHOSTNAME}"
confirmSettings
createDirectories $NEW_VHOSTNAME
createVHost $NEW_VHOSTNAME
cloneSite $EXISTING_VHOSTNAME $NEW_VHOSTNAME
fixSettings $EXISTING_VHOSTNAME $NEW_VHOSTNAME
fixPermissions $NEW_VHOSTNAME
sendStatusMail $EXISTING_VHOSTNAME $NEW_VHOSTNAME

