#!/usr/bin/env bash

echo " * Custom site template provisioner - downloads and installs a copy of Laravel latest for testing, building client sites, etc"

# fetch the first host as the primary domain. If none is available, generate a default using the site name
DOMAIN=`get_primary_host "${VVV_SITE_NAME}".test`
SITE_TITLE=`get_config_value 'site_title' "${DOMAIN}"`
DB_NAME=`get_config_value 'db_name' "${VVV_SITE_NAME}"`
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}

# Make a database, if we don't already have one
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
echo -e "\nGranting the laravel user priviledges to the '${DB_NAME}' database"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO laravel@localhost IDENTIFIED BY 'secret';"
echo -e "\n DB operations done.\n\n"

echo "Setting up the log subfolder for Nginx logs"
noroot mkdir -p ${VVV_PATH_TO_SITE}/log
noroot touch ${VVV_PATH_TO_SITE}/log/nginx-error.log
noroot touch ${VVV_PATH_TO_SITE}/log/nginx-access.log

echo "Setting up the public_html subfolder"
noroot mkdir -p ${VVV_PATH_TO_SITE}/public_html

if [ ! "$(ls -A ${VVV_PATH_TO_SITE}/public_html)" ]; then
	echo "Installing Laravel via Composer"
	noroot composer create-project laravel/laravel ${VVV_PATH_TO_SITE}/public_html 2>&1 | tee ${logfolder}/provisioner-"${VVV_SITE_NAME}"-laravel.txt
		
	echo "Configuring Laravel env to access the DB"
	sed -i "s#DB_DATABASE=homestead#DB_DATABASE=${DB_NAME}#" "${VVV_PATH_TO_SITE}/public_html/.env"
	sed -i "s#DB_USERNAME=homestead#DB_USERNAME=laravel#" "${VVV_PATH_TO_SITE}/public_html/.env"
	sed -i "s#DB_PASSWORD=secret#DB_PASSWORD=secret#" "${VVV_PATH_TO_SITE}/public_html/.env"
else
	echo "Something already exists in public_html so not altering it"
fi


echo "Copying the sites Nginx config template ( fork this site template to customise the template )"
cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf.tmpl" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"

if [ -n "$(type -t is_utility_installed)" ] && [ "$(type -t is_utility_installed)" = function ] && `is_utility_installed core tls-ca`; then
  echo "Inserting the SSL key locations into the sites Nginx config"
  VVV_CERT_DIR="/srv/certificates"
  # On VVV 2.x we don't have a /srv/certificates mount, so switch to /vagrant/certificates
  codename=$(lsb_release --codename | cut -f2)
  if [[ $codename == "trusty" ]]; then # VVV 2 uses Ubuntu 14 LTS trusty
    VVV_CERT_DIR="/vagrant/certificates"
  fi
  sed -i "s#{{TLS_CERT}}#ssl_certificate ${VVV_CERT_DIR}/${VVV_SITE_NAME}/dev.crt;#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
  sed -i "s#{{TLS_KEY}}#ssl_certificate_key ${VVV_CERT_DIR}/${VVV_SITE_NAME}/dev.key;#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
else
    sed -i "s#{{TLS_CERT}}##" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
    sed -i "s#{{TLS_KEY}}##" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
fi

echo "Site Template provisioner script completed"
