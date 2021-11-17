#!/bin/bash

# To tinker with this manually:
#   cf ssh <APPNAME>
#   /tmp/lifecycle/shell
#   source .profile
#
# To initialize the environment exactly as CF does before starting the app:
#   cf ssh <APPNAME> -t -c "/tmp/lifecycle/launcher /home/vcap/app bash ''"
#   <COMMAND> # eg "$SQUIDCLIENT -p 8080 https://www.example.com"

set -o errexit
set -o pipefail

echo "Grabbing parameters from the environment..."

# function vcap_get_service () {
#   local path name
#   name="$1"
#   path="$2"
#   service_name=${APP_NAME}-${name}
#   echo $VCAP_SERVICES | jq --raw-output --arg service_name "$service_name" ".[][] | select(.name == \$service_name) | $path"
# }

# # We need to know the application name ...
# export APP_NAME=$(echo $VCAP_APPLICATION | jq -r '.application_name')
# export APP_URL=$(echo $VCAP_APPLICATION | jq -r '.application_uris[0]')

# # Extract credentials from VCAP_SERVICES
# export REDIS_HOST=$(vcap_get_service redis .credentials.host)
# export REDIS_PASSWORD=$(vcap_get_service redis .credentials.password)
# export REDIS_PORT=$(vcap_get_service redis .credentials.port)
# export SAML2_PRIVATE_KEY=$(vcap_get_service secrets .credentials.SAML2_PRIVATE_KEY)

echo "Generating configuration for squid..."
mkdir -p squid/spool
mkdir -p squid/cache

export SQUID_ROOT=${HOME}/../deps/0/apt
export SQUID=${SQUID_ROOT}/usr/sbin/squid
export SQUIDCLIENT=${SQUID_ROOT}/usr/bin/squidclient

# The following config file was based on the defaul config for Squid 3.5.27 
cat > squid.conf << EOF
# Turn on logging so we can see what's going on
debug_options ALL,2

# Log to stdout
cache_log stdio:/dev/stdout
access_log stdio:/dev/stdout
cache_store_log stdio:/dev/stdout

# Listen on the provided PORT env var
http_port ${PORT} 

# Core dumps can't go to /var/spool/squid; put them in a local dir instead
coredump_dir squid/spool

# Tell servers who we're proxying for
forwarded_for on

# Set the email address to use for error pages
# What should the default be?
# cache_mgr support@cloud.gov

# Let squid know the non-default paths where these are available
mime_table ${SQUID_ROOT}/usr/share/squid/mime.conf
unlinkd_program ${SQUID_ROOT}/usr/lib/squid/unlinkd
logfile_daemon ${SQUID_ROOT}/usr/lib/squid/log_file_daemon
diskd_program ${SQUID_ROOT}/usr/lib/squid/diskd
pinger_program ${SQUID_ROOT}/usr/lib/squid/pinger
icon_directory ${SQUID_ROOT}/usr/share/squid/icons
error_directory ${SQUID_ROOT}/usr/share/squid/errors/templates
err_page_stylesheet ${SQUID_ROOT}/etc/squid/errorpage.css

# Boilerplate from here on except where noted 
acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http
acl CONNECT method CONNECT
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager

# ====== OUR CUSTOM ALLOWLIST ======
acl allowlist url_regex "allowlist.txt"
http_access allow allowlist 
# ==================================

http_access allow localhost

# This would normally cause this to be an open proxy, but since it's running on apps.internal access is controlled via 
#   cf add-network-policy SOURCE_APP squid-proxy [-s DEST_SPACE [-o DEST_ORG] --protocol tcp --port 8080
http_access deny all

refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern (Release|Packages(.gz)*)$      0       20%     2880
refresh_pattern .               0       20%     4320
EOF

echo "Verifying configuration..."
${SQUID} -k parse -f squid.conf

echo "Do any initialization needed by the config..."
${SQUID} -z -f squid.conf
                
echo 'Try starting it: ${SQUID} -N -f squid.conf'
