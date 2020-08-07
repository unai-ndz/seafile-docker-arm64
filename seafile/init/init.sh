#!/bin/bash

# Wait for mysql to start up...

sleep 20

if [[ -d "seafile-server-latest" ]]; then
    true
else
    # Copy the source
    cp -r /usr/src/seafile-server .
    cd seafile-server

    # Init mysql databases
    ./setup-seafile-mysql.sh auto -n seafile -i ${SERVER_NAME}:${PORT} -d /data/seafile-data/ -o db -u seafile -q %

    cd ..
    sed -i "s|thirdpart/gunicorn|thirdpart/gunicorn/app/wsgiapp.py|" seafile-server/seahub.sh

    # admin.txt
    cat <<EOF > conf/admin.txt
{
	"email": "${ADMIN_EMAIL}",
	"password": "${ADMIN_PASSWORD}"
}
EOF

    if [ -d "seafile-server-latest" ]; then
	    true
    else
	    echo "Something went wrong! Restarting..."
	    exit 1
    fi

    # gunicorn.conf
    sed -i "s/127.0.0.1/0.0.0.0/g" conf/gunicorn.conf

    if [ ${SSL} -eq 1 ]; then
        SCHEME=https
    else
        SCHEME=http
    fi

    # Perform some changes (according to https://manual.seafile.com/deploy/https_with_nginx.html -> Scroll down to 'Modify settings to use https')
    # seahub_settings.py
    echo "FILE_SERVER_ROOT = '${SCHEME}://${SERVER_NAME}:${PORT}/seafhttp'" >> conf/seahub_settings.py

    # ccnet.conf
    LINENUMBER=$(sed -n '/^SERVICE_URL/=' conf/ccnet.conf)
    sed -i "/^SERVICE_URL/d" conf/ccnet.conf
    sed -i "${LINENUMBER}iSERVICE_URL = ${SCHEME}://${SERVER_NAME}:${PORT}" conf/ccnet.conf

    chown -R 1000:1000 /haiwen
    chown -R 1000:1000 /data
fi

cd seafile-server-latest

chown -R root /data
bash seafile.sh start
bash seahub.sh start
exec "$@"
