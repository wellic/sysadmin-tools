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
SETTINGS["database-admin-password"]=$MYSQL_ADMIN_PASSWORD

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
$0 [OPTION] vhost dest
-h          this help
-q          be quiet
-r VALUE    remote host
-o          overwrite existing site
-d VALUE    append VALUE to vhost name
-t          create tarball with site (can't be used with -r)
-f          install from tarball
EOF
}

# A ":" after a flag indicates it will have an option passed with it.
OPTIONS='ohqtfr:d:'

while getopts $OPTIONS OPTION
do
    case $OPTION in
        h  ) usage; exit;;
        q  ) SETTINGS["quiet"]="y";;
        o  ) SETTINGS["overwrite-existing"]="y";;
        r  ) SETTINGS["remote-host"]=$OPTARG; SETTINGS["use-remote-host"]="y";;
        d  ) SETTINGS["new-domain-name-suffix"]=$OPTARG;;
        t  ) SETTINGS["create-tarball"]="y"; SETTINGS["use-remote-host"]="n";;
        f  ) SETTINGS["from-tarball"]="y"; SETTINGS["use-remote-host"]="n";;
        \? ) error "Unknown option: -$OPTARG" >&2; exit 1;;
        :  ) error "Missing option argument for -$OPTARG" >&2; exit 1;;
        *  ) error "Unimplimented option: -$OPTARG" >&2; exit 1;;
    esac
done

shift $(($OPTIND - 1))

if [[ -z ${1} ]]; then
  error "Missing virtual host"
  usage
  exit
fi

SETTINGS["existing-vhost-name"]=$1

if [[ ! -z ${SETTINGS["new-domain-name-suffix"]} ]]; then
  SETTINGS["new-vhost-name"]="${1}.${SETTINGS["new-domain-name-suffix"]}"
else
  SETTINGS["new-vhost-name"]="${1}"
fi

if [[ ${SETTINGS["from-tarball"]} == "y" ]]; then
  TAR_BALL_HOST=$3
  TAR_BALL_LOCATION=$4
fi

function createVHost {
  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    info "Creating virtual host ${2}"
    
    local VHOSTPATH="/etc/apache2/sites-available"
    local HTPASSWDFILE="/var/www/.htpasswd"

    HTPASSWD="$(pwgen -N1 -s 6)"
    # TODO. better username?
    HTUSER=$1
    /usr/bin/ssh ${SETTINGS["remote-host"]} "wget -q --output-document=$VHOSTPATH/$2 ${SETTINGS["vhost-url"]}"
    /usr/bin/ssh ${SETTINGS["remote-host"]} "perl -pi -e 's/\\[domain\\]/$2/g' $VHOSTPATH/$2"
    /usr/bin/ssh ${SETTINGS["remote-host"]} "sed -i -e '/ServerAlias/d' $VHOSTPATH/$2"
    /usr/bin/ssh ${SETTINGS["remote-host"]} "sed -i -e 's/#Include\\ \\/etc\\/apache2\\/limit-bellcom.conf/Include\\ \\/etc\\/apache2\\/limit-bellcom.conf/g' $VHOSTPATH/$2"
    /usr/bin/ssh ${SETTINGS["remote-host"]} "a2ensite $2"
    /usr/bin/ssh ${SETTINGS["remote-host"]} "/etc/init.d/apache2 reload"
    # TODO. Check if htaccess file exists and use -c if it doesnt
    /usr/bin/ssh ${SETTINGS["remote-host"]} "htpasswd -b /var/www/.htpasswd $HTUSER $HTPASSWD"

    info "htaccess login: $HTUSER"
    info "htaccess password: $HTPASSWD"
  elif [[ ${SETTINGS["create-tarball"]} == "y" ]]; then
    warning "createVHost: FIXME: copy vhost?"
  else
    warning "createVHost: Doesn't know what to do"
  fi
}

function createDirectories {
  info "Creating directories"
  local DIRS="/var/www/${1}/{public_html,tmp,logs,sessions}"

  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    local RESULT='';
    RESULT=$(runRemoteCommand "create-dirs" $DIRS);
  else
    # We need eval to expand variable
    eval "mkdir -p ${DIRS}"
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
  local PATH=$1 

  info "Checking for existing site"
  local EXISTS="n"
  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    local RESULT='';
    RESULT=$(runRemoteCommand "check-existing-site" "${PATH}");
    #echo "RESULT |${RESULT}|"
    if [[ $RESULT == 'y' ]]; then
      EXISTS="y"
    fi
  else
    if [[ -d ${PATH} ]]; then
      EXISTS="y"
    fi
  fi

  if [[ $EXISTS == "y" ]]; then
    if [[ ${SETTINGS["overwrite-existing"]} == "n" ]]; then
      warning "Site '${PATH}' exists"
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

  RESULT=$(/usr/bin/ssh ${SETTINGS["remote-host"]} "$COMMAND");
  echo $RESULT
}

function cloneSite {
  local EXISTING_VHOSTNAME=$1 
  local NEW_VHOSTNAME=$2

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

function fixPermissions {
  declare -A COMMANDS
  COMMANDS[1]="/bin/chmod -R g+rwX /var/www/$1"
  COMMANDS[2]="/bin/chgrp -R www-data /var/www/$1"
  if [[ ${SETTINGS["site-type"]} == drupal ]]; then
    COMMANDS[3]="/bin/chmod -w /var/www/$1/public_html/sites/default"
    COMMANDS[4]="/bin/chmod -w /var/www/$1/public_html/sites/default/settings.php"
  fi

  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    for COMMAND in "${COMMANDS[@]}"; do
      /usr/bin/ssh ${SETTINGS["remote-host"]} "$COMMAND"
    done
  else
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
    # TODO: remove hardcoded hostname
    scp ${SETTINGS["tmp-dir"]}/${EXISTING_VHOSTNAME}.tgz devel:${SETTINGS["tmp-dir"]}

    local ARCHIVE=${SETTINGS["tmp-dir"]}/${EXISTING_VHOSTNAME}.tgz
    local DESTINATION="/var/www/${NEW_VHOSTNAME}/public_html"
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
    if [[ $UID -ne 0 ]]; then
      echo ${INTIP} ${SETTINGS["new-vhost-name"]} | sudo tee -a /etc/hosts
    else
      echo ${INTIP} ${SETTINGS["new-vhost-name"]} >> /etc/hosts
    fi
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

  if [[ ${SETTINGS["use-remote-host"]} == "y" ]]; then
    runRemoteCommand "drush" "archive-restore --overwrite ${ARCHIVE} --destination=${DESTINATION} --db-url=mysql://${SETTINGS["database-username"]}:${SETTINGS["database-password"]}@localhost/${SETTINGS["database-name"]} --db-su=${SETTINGS["database-admin-username"]} --db-su-pw=${SETTINGS["database-admin-password"]}"
  else
    /usr/bin/drush archive-restore --overwrite ${ARCHIVE} --destination=${DESTINATION} --db-url=mysql://${SETTINGS["database-username"]}:${SETTINGS["database-password"]}@localhost/${SETTINGS["database-name"]} --db-su=${SETTINGS["database-admin-username"]} --db-su-pw=${SETTINGS["database-admin-password"]}
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
  cloneSite ${SETTINGS["existing-vhost-name"]} ${SETTINGS["new-vhost-name"]}
  createVHost ${SETTINGS["existing-vhost-name"]} ${SETTINGS["new-vhost-name"]}
  fixSettings ${SETTINGS["existing-vhost-name"]} ${SETTINGS["new-vhost-name"]}
  fixPermissions ${SETTINGS["new-vhost-name"]}
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
  createVHost ${SETTINGS["existing-vhost-name"]} ${SETTINGS["new-vhost-name"]}
}

#
# Downloads a remote tar ball and creates a site based on it
#
function mainExtractTar {
  if [[ -z ${SETTINGS["database-admin-password"]} ]]; then
    error "Missing database admin password, please set \$MYSQL_ADMIN_PASSWORD in your environment"
  fi

  info "Fetching and extracting tar ball"
  scp ${TAR_BALL_HOST}:${TAR_BALL_LOCATION} .

  createDirectories ${SETTINGS["new-vhost-name"]}

  generateNewDatabaseSettings ${SETTINGS["new-vhost-name"]}

  local ARCHIVE=${SETTINGS["existing-vhost-name"]}.tgz
  local DESTINATION="/var/www/${SETTINGS["new-vhost-name"]}/public_html"

  drupalDrushArchiveRestore $ARCHIVE $DESTINATION

  fixSettings ${SETTINGS["existing-vhost-name"]} ${SETTINGS["new-vhost-name"]}

  rm $(basename ${TAR_BALL_LOCATION})
  /usr/bin/ssh ${TAR_BALL_HOST} "rm ${TAR_BALL_LOCATION}"
  
  # fixPermissions ${SETTINGS["new-vhost-name"]}

  createVHost ${SETTINGS["existing-vhost-name"]} ${SETTINGS["new-vhost-name"]}
} 

if [[ ${SETTINGS["create-tarball"]} == "n" && ${SETTINGS["from-tarball"]} == "n" ]]; then
  mainRemoteClone
fi

if [[ ${SETTINGS["create-tarball"]} == "y" ]]; then
  mainCreateTar
fi

if [[ ${SETTINGS["from-tarball"]} == "y" ]]; then
  mainExtractTar
fi
