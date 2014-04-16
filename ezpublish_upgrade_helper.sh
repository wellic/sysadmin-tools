#!/bin/bash
# ez upgrade script by hf@bellcom.dk
# version 0.2 : Support for upgrading 4.0.4 to 4.1.3
# version 0.3 : Fixes for 4.0.1 -> 4.0.2
# version 0.4 (05-jan-2011): Support from 4.1.3 to 4.4, minor fixes, support cronjobs
# version 0.5 (18-maj-2011): Support from 4.4 to community 2011.5
# version 0.6 (11-okt-2011): Support from community 2011.5 to 2011.9
# version 0.7 (16-jan-2013): Support from community 2011.9 to 2012.8

# Note: skip 2012.5 and go to 2012.6
# Note: skip 4.2011 and go to 2011.5
# Note: skip 2011.{5,6,7,8} and go to 2011.9
# Note: skip from 2011.9 to 2012.2 by setting the to versions to that
EZ_OLDVERSION="2012.6"
EZ_NEWVERSION="2012.8"
EZ_NEW_PATH="ezpublish_community_project-${EZ_NEWVERSION}-with_ezc" 
# pre 2011:
# EZ_NEW_PATH="ezpublish-${EZ_NEWVERSION}-gpl" 
# pre 4.3: 
# EZ_NEW_PATH="ezpublish-${EZ_NEWVERSION}"

EZ_NEW_ARCHIVE="ezpublish_community_project-${EZ_NEWVERSION}-with_ezc.tar.bz2" 
# pre 2011:
# EZ_NEW_ARCHIVE="ezpublishcommunity-${EZ_NEWVERSION}-gpl.tar.gz" 
# pre 4.2:
# EZ_NEW_ARCHIVE="${EZ_NEW_PATH}-gpl.tar.bz2" 

LOCAL_PATH="local_dev" # local / local_dev
DOC_ROOT_PATH="public_html_test" # ez_svn
DOC_UPGRADE_PATH="public_html_upgrade"
SITEACCESSES=`ls ${LOCAL_PATH}/settings/siteaccess`

if [[ ! -f ${EZ_NEW_ARCHIVE} ]]; then
  echo "File ${EZ_NEW_ARCHIVE} not found, exiting now"
  exit 1
fi

echo "Først skal man stå i /var/www/sitenavn"
echo
echo "Running the following commands:"
echo 

echo "extract ${EZ_NEW_ARCHIVE}"

for i in `ls ${LOCAL_PATH}/design/`; do 
  #TODO: use ln's backup function 
  if [[ -d ${EZ_NEW_PATH}/design/${i} ]]; then
    echo "mv ${EZ_NEW_PATH}/design/${i} ${EZ_NEW_PATH}/design/${i}_${EZ_NEWVERSION}"
  fi;
  echo "ln -s ../../${LOCAL_PATH}/design/${i} ${EZ_NEW_PATH}/design/"
done

# Note that there is an "s" in the local dir...
for i in `ls ${LOCAL_PATH}/extensions`; do 
  #TODO: use ln's backup function 
  if [[ -d ${EZ_NEW_PATH}/extension/${i} ]]; then
    echo "mv ${EZ_NEW_PATH}/extension/${i} ${EZ_NEW_PATH}/extension/${i}_${EZ_NEWVERSION}"
  fi;
  echo "ln -s ../../${LOCAL_PATH}/extensions/${i} ${EZ_NEW_PATH}/extension/"
done

echo "mv ${EZ_NEW_PATH}/settings/override ${EZ_NEW_PATH}/settings/override_${EZ_NEWVERSION}"
echo "ln -s ../../${LOCAL_PATH}/settings/override ${EZ_NEW_PATH}/settings/"

for i in `ls ${LOCAL_PATH}/settings/siteaccess`; do 
  #TODO: use ln's backup function 
  if [[ -d ${EZ_NEW_PATH}/settings/siteaccess/${i} ]]; then
    echo "mv ${EZ_NEW_PATH}/settings/siteaccess/${i} ${EZ_NEW_PATH}/settings/siteaccess/${i}_${EZ_NEWVERSION}"
  fi;
  echo "ln -s ../../../${LOCAL_PATH}/settings/siteaccess/${i} ${EZ_NEW_PATH}/settings/siteaccess/"
done

for i in `ls ${LOCAL_PATH}/cronjobs`; do 
  #TODO: use ln's backup function 
  echo "ln -s ../../${LOCAL_PATH}/cronjobs/${i} ${EZ_NEW_PATH}/cronjobs/"
done

echo "mv ${EZ_NEW_PATH}/var ${EZ_NEW_PATH}/var_${EZ_NEWVERSION}"
echo "ln -s ../${LOCAL_PATH}/var ${EZ_NEW_PATH}/"
echo 
echo "sudo chown -R www-data: ${EZ_NEW_PATH}/"
echo "sudo chmod -R g+rwX ${EZ_NEW_PATH}/"
echo "sudo find ${EZ_NEW_PATH} -type d -exec chmod g+s {} \;"
#echo "sudo mv ${DOC_ROOT_PATH} ${DOC_ROOT_PATH}_${EZ_NEWVERSION}"
#echo "sudo mv ${EZ_NEW_PATH} ${DOC_ROOT_PATH}"
echo "sudo ln -fs ${EZ_NEW_PATH} ${DOC_UPGRADE_PATH}"

echo
echo "Ctrl+C to abort, proceding in 10 sec"
echo

sleep 10

echo "Extracting..."
case ${EZ_NEW_ARCHIVE##*.} in
  bz2)
    tar jxf ${EZ_NEW_ARCHIVE} ;;
  gz)
    tar zxf ${EZ_NEW_ARCHIVE} ;;
  * )
   echo "Unknown archive format: ${EZ_NEW_ARCHIVE##*.}"
   exit 1
esac

if [[ ! -d ${EZ_NEW_PATH} ]]; then
  echo "Dir ${EZ_NEW_PATH} does not exist"
  exit 1
fi

for i in `ls ${LOCAL_PATH}/design/`; do 
  #TODO: use ln's backup function 
  if [[ -d ${EZ_NEW_PATH}/design/${i} ]]; then
    mv ${EZ_NEW_PATH}/design/${i} ${EZ_NEW_PATH}/design/${i}_${EZ_NEWVERSION}
  fi;
  ln -s ../../${LOCAL_PATH}/design/${i} ${EZ_NEW_PATH}/design/
done

for i in `ls ${LOCAL_PATH}/extensions`; do 
  #TODO: use ln's backup function 
  if [[ -d ${EZ_NEW_PATH}/extension/${i} ]]; then
    mv ${EZ_NEW_PATH}/extension/${i} ${EZ_NEW_PATH}/extension/${i}_${EZ_NEWVERSION}
  fi;
  ln -s ../../${LOCAL_PATH}/extensions/${i} ${EZ_NEW_PATH}/extension/
done

if [[ -d ${EZ_NEW_PATH}/settings/override ]]; then
  mv ${EZ_NEW_PATH}/settings/override ${EZ_NEW_PATH}/settings/override_${EZ_NEWVERSION}
else
  echo "${EZ_NEW_PATH}/settings/override does not exist, probably extracted from ezpublish-4.3.0-light-gpl.tar.gz"
fi
ln -s ../../${LOCAL_PATH}/settings/override ${EZ_NEW_PATH}/settings/

for i in `ls ${LOCAL_PATH}/settings/siteaccess`; do 
  #TODO: use ln's backup function 
  if [[ -d ${EZ_NEW_PATH}/settings/siteaccess/${i} ]]; then
    mv ${EZ_NEW_PATH}/settings/siteaccess/${i} ${EZ_NEW_PATH}/settings/siteaccess/${i}_${EZ_NEWVERSION}
  fi;
  ln -s ../../../${LOCAL_PATH}/settings/siteaccess/${i} ${EZ_NEW_PATH}/settings/siteaccess/
done

for i in `ls ${LOCAL_PATH}/cronjobs`; do 
  #TODO: use ln's backup function 
  ln -s ../../${LOCAL_PATH}/cronjobs/${i} ${EZ_NEW_PATH}/cronjobs/
done

mv ${EZ_NEW_PATH}/var ${EZ_NEW_PATH}/var_${EZ_NEWVERSION}
ln -s ../${LOCAL_PATH}/var ${EZ_NEW_PATH}/

sudo chown -R www-data: ${EZ_NEW_PATH}/
sudo chmod -R g+rwX ${EZ_NEW_PATH}/
sudo find ${EZ_NEW_PATH} -type d -exec chmod g+s {} \;
#sudo mv ${DOC_ROOT_PATH} ${DOC_ROOT_PATH}_${EZ_OLDVERSION}
#sudo mv ${EZ_NEW_PATH} ${DOC_ROOT_PATH}
if [[ -L ${DOC_UPGRADE_PATH} ]]; then
  rm ${DOC_UPGRADE_PATH}
  sudo ln -fs ${EZ_NEW_PATH} ${DOC_UPGRADE_PATH}
else
  echo "Please make sure that apache can find the new doc root if you are going to test the site"
  echo "No symlink from ${EZ_NEW_PATH} to ${DOC_UPGRADE_PATH} was created"
  echo "Create it manully with: sudo ln -fs ${EZ_NEW_PATH} ${DOC_UPGRADE_PATH}"
fi

echo
echo "For at køre de ekstra opgraderings kommandoer skal man stå i /var/www/sitenavn/public_html"
echo

if [[ ${EZ_OLDVERSION} == '4.0.0' && ${EZ_NEWVERSION} == '4.0.1' ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Loop igennem siteaccesses"
 echo "php update/common/scripts/4.0/fixobjectremoteid.php -s <siteaccess>"
 echo "# Kun hvis mysql tabellerne ikke er innodb"
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.0/dbupdate-4.0.0-to-4.0.1.sql"
 echo "# Edit settings/override/site.ini.append.php tilføj: ActiveExtensions[]=ezurlaliasmigration"
 echo "# Kun hvis man har custom extensions"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php extension/ezurlaliasmigration/scripts/migrate.php --create-migration-table"
 echo "# Loop igennem siteaccesses"
 echo "php extension/ezurlaliasmigration/scripts/migrate.php -s <siteaccess>"
 echo "php extension/ezurlaliasmigration/scripts/migrate.php --migrate"
 echo "# i mysql: TRUNCATE ezurlalias_ml;"
 echo "php bin/php/ezcache.php --clear-all --purge"
 echo "php bin/php/updateniceurls.php"
 echo "php extension/ezurlaliasmigration/scripts/migrate.php --restore"
 echo "# Vhost ændringer: RewriteRule content/treemenu/?$ /index_treemenu.php [L] -> RewriteRule content/treemenu/? /index_treemenu.php [L]"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '4.0.1' && ${EZ_NEWVERSION} == '4.0.2' ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.0/dbupdate-4.0.1-to-4.0.2.sql"
 echo "mysql -u <username> -p<password> <database> < extension/ezurlaliasmigration/sql/mysql/schema.sql"
 echo "php extension/ezurlaliasmigration/scripts/migrate.php --create-migration-table"
 echo "php extension/ezurlaliasmigration/scripts/migrate.php --migrate-alias"
 echo "# i mysql: TRUNCATE ezurlalias_ml;"
 echo "php bin/php/ezcache.php --clear-all --purge"
 echo "php bin/php/updateniceurls.php"
 echo "php extension/ezurlaliasmigration/scripts/migrate.php --restore-alias"
 echo "php update/common/scripts/4.0/initurlaliasmlid.php"
 echo "php update/common/scripts/4.0/fixezurlobjectlinks.php"
 echo "php update/common/scripts/4.0/fixclassremoteid.php"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi
 
if [[ ${EZ_OLDVERSION} == '4.0.2' && ${EZ_NEWVERSION} == '4.0.3' ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.0/dbupdate-4.0.2-to-4.0.3.sql"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '4.0.3' && ${EZ_NEWVERSION} == '4.0.4' ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.0/dbupdate-4.0.3-to-4.0.4.sql"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '4.0.4' && ${EZ_NEWVERSION} == '4.1.0' ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Add to vhost: RewriteRule ^/var/[^/]+/cache/public/.* - [L]"
 echo "# Install ezcomponents: "
 echo "sudo pear channel-discover components.ez.no"
 echo "sudo pear install -a ezc/eZComponents"
 echo "php update/common/scripts/4.1/updateimagesystem.php"
 echo "# Edit update/database/mysql/4.1/dbupdate-4.0.0-to-4.1.0.sql remove sql for old versions"
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.1/dbupdate-4.0.0-to-4.1.0.sql"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php update/common/scripts/4.1/addlockstategroup.php"
 echo "php update/common/scripts/4.1/fixclassremoteid.php"
 echo "php update/common/scripts/4.1/fixezurlobjectlinks.php"
 echo "php update/common/scripts/4.1/fixobjectremoteid.php"
 echo "php update/common/scripts/4.1/initurlaliasmlid.php "
 echo "php bin/php/ezcache.php --clear-all --purge"
 echo "# Activate ezoe extension in admin"
fi

if [[ ${EZ_OLDVERSION} == '4.1.0' && ${EZ_NEWVERSION} == '4.1.1' ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.1/dbupdate-4.1.0-to-4.1.1.sql"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "mysql -u <username> -p<password> <database> < extension/ezoe/update/database/5.0/dbupdate-5.0.0-to-5.0.1.sql"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '4.1.1' && ${EZ_NEWVERSION} == '4.1.2' ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.1/dbupdate-4.1.1-to-4.1.2.sql"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php update/common/scripts/4.1/fixclassremoteid.php"
 echo "php update/common/scripts/4.1/fixobjectremoteid.php"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '4.1.2' && ${EZ_NEWVERSION} == '4.1.3' ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.1/dbupdate-4.1.2-to-4.1.3.sql"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '4.1.3' && ${EZ_NEWVERSION} == '4.1.4' ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.1/dbupdate-4.1.3-to-4.1.4.sql"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '4.1.3' && ${EZ_NEWVERSION} == '4.1.4' ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.1/dbupdate-4.1.3-to-4.1.4.sql"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '4.1.4' && ${EZ_NEWVERSION} == '4.2.0' ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Minimum required ezcomponents is 2009.1, upgrade using: sudo pear upgrade ezc/eZComponents"
 echo "# Vhost changes: "
 echo "# Add:"
 echo "RewriteRule ^/var/[^/]+/cache/public/.* - [L]"
 echo "# Only run the next script if a table called ezimage exist"
 echo "php update/common/scripts/4.1/updateimagesystem.php # yes 4.1"
 echo "# Edit update/database/mysql/4.2/dbupdate-4.1.0-to-4.2.0.sql" and remove old versions
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.2/dbupdate-4.1.0-to-4.2.0.sql"
 echo "php update/common/scripts/4.1/correctxmlalign.php # yes 4.1" 
 echo "php update/common/scripts/4.2/fixorphanimages.php # only if var is the correct dir !!"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '4.2.0' && ${EZ_NEWVERSION} == '4.3.0' ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Minimum required ezcomponents is 2009.2.1, upgrade using: sudo pear upgrade ezc/eZComponents"
 echo "# Vhost changes: "
 echo "# Replace:"
 echo "RewriteRule ^/var/cache/texttoimage/.* - [L]
 RewriteRule  ^/var/[^/]+/cache/(texttoimage|public)/.* - [L]"
 echo "# With:"
 echo "RewriteRule ^/var/([^/]+/)?cache/(texttoimage|public)/.* - [L]"
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.3/dbupdate-4.2.0-to-4.3.0.sql"
 echo "# Enable extensions: edit settings/siteaccess/ADMIN_SITEACCESS/site.ini.append.php OR settings/override/site.ini.append.php"
echo "[ExtensionSettings]
ActiveExtensions[]=ezmultiupload
ActiveExtensions[]=ezjscore
ActiveExtensions[]=ezoe
ActiveExtensions[]=ezodf
ActiveExtensions[]=ezie
# ActiveExtensions[]=ezcomments
# ActiveExtensions[]=ezscriptmonitor"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php update/common/scripts/4.3/updatenodeassignment.php"
 echo "# Enable admin2 design: edit settings/siteaccess/ADMIN_SITEACCESS/site.ini.append.php"
 echo "[DesignSettings]
SiteDesign=admin2
AdditionalSiteDesignList[]=admin"
 echo "# Enable new tools: edit settings/siteaccess/ADMIN_SITEACCESS/toolbar.ini.append.php" 
 echo "[Toolbar_admin_right]
Tool[]
Tool[]=admin_current_user
Tool[]=admin_bookmarks
Tool[]=admin_preferences"
 echo "# Non-admins might need a new policy (content -> dashboard) to gain access to the dashboard."
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '4.3.0' && ${EZ_NEWVERSION} == '4.4.0' ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# http://doc.ez.no/eZ-Publish/Upgrading/Upgrading-to-4.4/Upgrading-from-4.3.x-to-4.4.x"
 echo "# Note that ${EZ_NEWVERSION} uses session files instead of the db, check is the session path is correct in the vhost, else login to the admin interface will fail"
 echo "# Problem with extra spaces caused by <p>&nbsp;</p>, fix plain_site/templates/content/datatype/view/ezxmltags/paragraph.tpl"
 echo "# ezi18n() is deprecated in 4.3, and removed from 4.4, replace it with ezpI18n::tr()"
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.4/dbupdate-4.3.0-to-4.4.0.sql"
 echo "# Fix vhost:"
 echo "# Replace: "
 echo "RewriteRule ^/extension/[^/]+/design/[^/]+/(stylesheets|flash|images|javascripts?)/.* - [L]"
 echo "# with:"
 echo "RewriteRule ^/extension/[^/]+/design/[^/]+/(stylesheets|flash|images|lib|javascripts?)/.* - [L]"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php update/common/scripts/4.4/updatesectionidentifier.php"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '4.4.0' && ${EZ_NEWVERSION} == '4.2011' ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Skip this and go to 2011.5"
fi

if [[ (${EZ_OLDVERSION} == '4.2011' && ${EZ_NEWVERSION} == '2011.5') || (${EZ_OLDVERSION} == '4.4.0' && ${EZ_NEWVERSION} == '2011.5') ]]; then
 echo "# Upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# http://share.ez.no/download-develop/downloads/ez-publish-community-project-2011.5/upgrading-from-ez-publish-community-project-4.2011-to-2011.5"
 echo "# Change site.ini.append.php to use mysqli:"
 echo "[DatabaseSettings]"
 echo "DatabaseImplementation=ezmysqli"
 echo "mysql -u <username> -p<password> <database> < update/database/mysql/4.5/dbupdate-4.4.0-to-4.5.0.sql"
 echo "# Extra sql:"
 echo "CREATE TABLE ezorder_nr_incr (
  id int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY  (id)
) ENGINE=InnoDB;"
 echo "# check that ezjscore is enabled, and at the top of activeextensions"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php update/common/scripts/4.5/updatesectionidentifier.php"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '2011.5' && ${EZ_NEWVERSION} == '2011.6' ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Skip this and go to 2011.9"
fi

if [[ ${EZ_OLDVERSION} == '2011.5' && ${EZ_NEWVERSION} == '2011.9' ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Add to vhost:"
 echo "RewriteRule ^/api/ /index_rest\.php [L]"
 echo "# Run SQL:"
 echo "UPDATE ezworkflow_event SET data_text5 = data_text3, data_text3 = '' WHERE workflow_type_string = 'event_ezmultiplexer';"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php update/common/scripts/4.6/removetrashedimages.php -s <SITE_ACCESS>"
 echo "php update/common/scripts/4.6/updateordernumber.php -s <SITE_ACCESS>"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

# Note: set oldversion to 2011.9 and new version to 2012.2
if [[ ${EZ_OLDVERSION} == '2011.9' && ${EZ_NEWVERSION} == '2011.10' ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Skip this and go to 2012.2"
fi

if [[ ${EZ_OLDVERSION} == '2011.10' && ${EZ_NEWVERSION} == '2011.11' ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Skip this and go to 2012.2"
fi

if [[ ${EZ_OLDVERSION} == '2011.11' && ${EZ_NEWVERSION} == '2011.12' ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Skip this and go to 2012.2"
fi

if [[ ${EZ_OLDVERSION} == '2011.12' && ${EZ_NEWVERSION} == '2012.1' ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Skip this and go to 2012.2"
fi

# Note: set oldversion to 2011.9 and new version to 2012.2
if [[ ${EZ_OLDVERSION} == '2011.9' && ${EZ_NEWVERSION} == '2012.2' ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Run SQL:"
 echo "ALTER TABLE ezpending_actions ADD COLUMN id int(11) AUTO_INCREMENT PRIMARY KEY;"
 echo "DELETE FROM ezuser_accountkey WHERE user_id IN ( SELECT user_id FROM ezuser_setting WHERE is_enabled = 1 );"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '2012.2' && ${EZ_NEWVERSION} == '2012.3' ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Run SQL:"
 echo "SET storage_engine=InnoDB;"
 echo "UPDATE ezsite_data SET value='4.7.0beta1' WHERE name='ezpublish-version';"
 echo "UPDATE ezsite_data SET value='1' WHERE name='ezpublish-release';"
 echo ""
 echo "ALTER TABLE ezcontentobject_attribute MODIFY COLUMN data_float double DEFAULT NULL;" 
 echo "ALTER TABLE ezcontentclass_attribute MODIFY COLUMN data_float1 double DEFAULT NULL;"
 echo "ALTER TABLE ezcontentclass_attribute MODIFY COLUMN data_float2 double DEFAULT NULL;"
 echo "ALTER TABLE ezcontentclass_attribute MODIFY COLUMN data_float3 double DEFAULT NULL;"
 echo "ALTER TABLE ezcontentclass_attribute MODIFY COLUMN data_float4 double DEFAULT NULL;"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '2012.3' && ${EZ_NEWVERSION} == '2012.4' ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Run SQL:"
 echo "SET storage_engine=InnoDB;"
 echo "UPDATE ezsite_data SET value='4.7.0rc1' WHERE name='ezpublish-version';"
 echo "UPDATE ezsite_data SET value='1' WHERE name='ezpublish-release';"
 echo "UPDATE eztrigger SET name = 'pre_updatemainassignment', function_name = 'updatemainassignment'"
 echo "  WHERE name = 'pre_UpdateMainAssignment' AND function_name = 'UpdateMainAssignment';"
 echo "# If clustering is used:"
 echo 'ALTER TABLE `ezdfsfile` CHANGE `datatype` `datatype` VARCHAR(255);'
 echo 'ALTER TABLE `ezdbfile` CHANGE `datatype` `datatype` VARCHAR(255);'
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

if [[ ${EZ_OLDVERSION} == '2012.4' && ${EZ_NEWVERSION} == '2012.5' ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Skip this and go to 2012.6"
fi

if [[ ( ${EZ_OLDVERSION} == '2012.5' && ${EZ_NEWVERSION} == '2012.6' ) || ( ${EZ_OLDVERSION} == '2012.4' && ${EZ_NEWVERSION} == '2012.6' ) ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# Run SQL:"
 echo "SET storage_engine=InnoDB;
UPDATE ezsite_data SET value='5.0.0alpha1' WHERE name='ezpublish-version';
UPDATE ezsite_data SET value='1' WHERE name='ezpublish-release';

ALTER TABLE ezcobj_state_group_language ADD COLUMN real_language_id int(11) NOT NULL DEFAULT 0;
UPDATE ezcobj_state_group_language SET real_language_id = language_id & ~1;
ALTER TABLE ezcobj_state_group_language DROP PRIMARY KEY, ADD PRIMARY KEY(contentobject_state_group_id, real_language_id);"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php update/common/scripts/5.0/deduplicatecontentstategrouplanguage.php -s <SITE_ACCESS>"
 echo "php bin/php/ezcache.php --clear-all --purge"
fi

# No version 2012.7 !!

if [[ ${EZ_OLDVERSION} == '2012.6' && ${EZ_NEWVERSION} == '2012.8' ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "php bin/php/ezpgenerateautoloads.php --extension"
 echo "php update/common/scripts/5.0/restorexmlrelations.php -s <SITE_ACCESS>"
 echo "# Edit settings/siteaccess/<ADMIN_SITE_ACCESS>/override.ini.append.php"
 echo "# and remove window_controls and windows blocks"
 echo "php bin/php/ezcache.php --clear-all --purge"
 echo "# Make sure that rewrite rules match the latest vhost example in the docs"
fi

if [[ ${EZ_OLDVERSION} == '2012.8' && ${EZ_NEWVERSION} == '2012.9' ]]; then
 echo "# upgrade fra ${EZ_OLDVERSION} -> ${EZ_NEWVERSION}"
 echo "# First build that requires an installation of ez 5"
fi

echo ""
echo "#######################################################################"
echo "# Remember to move robots.txt + other files that exist in document root"
if [[ -L ${DOC_ROOT_PATH}/index_ajax.php ]]; then
  echo "# Remember to symlink index_ajax.php to file in ezjscore extension"
fi

PATHARRAY=( `echo ${PWD} | tr '/' ' '`)
if [[ ${PATHARRAY[2]} == 'sik.dk'  ]]; then
  echo "# Husk film"
fi
if [[ -e /usr/bin/symlinks ]]; then
  echo "# Checking symlinks:"
  symlinks -r .
fi
echo "#"
echo "# Husk at reenable cronjobs"
echo "#"
echo "#######################################################################"
echo ""
echo ""

