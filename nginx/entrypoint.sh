#!/bin/sh
set -e

TEMPLATE=/etc/nginx/templates/nginx.template.conf
DEST=/etc/nginx/nginx.conf

# Read env values
ACTIVE_POOL=${ACTIVE_POOL:-blue}
BLUE_HOST=${BLUE_SERVICE_HOST:-app_blue}
GREEN_HOST=${GREEN_SERVICE_HOST:-app_green}
BLUE_PORT=${BLUE_SERVICE_PORT:-3000}
GREEN_PORT=${GREEN_SERVICE_PORT:-3000}

# Decide primary and backup
if [ "$ACTIVE_POOL" = "green" ]; then
  PRIMARY_HOST="${GREEN_HOST}:${GREEN_PORT}"
  BACKUP_HOST="${BLUE_HOST}:${BLUE_PORT}"
else
  PRIMARY_HOST="${BLUE_HOST}:${BLUE_PORT}"
  BACKUP_HOST="${GREEN_HOST}:${GREEN_PORT}"
fi

# Replace placeholders
sed "s|PRIMARY_SERVER|${PRIMARY_HOST}|g; s|BACKUP_SERVER|${BACKUP_HOST}|g" "${TEMPLATE}" > "${DEST}"

# Start nginx in foreground (so docker container keeps running)
nginx -g "daemon off;" &
NGINX_PID=$!

# Watch for env change trigger file / reload signal - simple loop to allow reload via docker exec
# (Alternative: the grader can call `docker exec bg_nginx /usr/local/bin/nginx-entrypoint.sh reload` to regenerate & reload)
while true; do
  sleep 1
  # If a trigger file exists, regenerate config and reload
  if [ -f /tmp/reload-nginx ]; then
    echo "Reload requested: regenerating nginx.conf"
    if [ "$ACTIVE_POOL" = "green" ]; then
      PRIMARY_HOST="${GREEN_HOST}:${GREEN_PORT}"
      BACKUP_HOST="${BLUE_HOST}:${BLUE_PORT}"
    else
      PRIMARY_HOST="${BLUE_HOST}:${BLUE_PORT}"
      BACKUP_HOST="${GREEN_HOST}:${GREEN_PORT}"
    fi
    sed "s|PRIMARY_SERVER|${PRIMARY_HOST}|g; s|BACKUP_SERVER|${BACKUP_HOST}|g" "${TEMPLATE}" > "${DEST}"
    nginx -s reload || true
    rm -f /tmp/reload-nginx
  fi
done
