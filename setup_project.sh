#!/bin/bash
GRADLE_TRUSTSTORE_PASSWORD=1q2w3e
GRADLE_TEMP_DIR=./gradle
GRADLE_TRUSTSTORE_FILE_NAME="gradle-truststore.jks"
# GRADLE_TRUSTSTORE_PATH="$GRADLE_TEMP_DIR/$GRADLE_TRUSTSTORE_FILE_NAME"
GRADLE_TRUSTSTORE_PATH=~/gradle-truststore.jks
GRADLE_PROPERTIES_PATH="$GRADLE_TEMP_DIR/gradle.properties"
NGINX_CERTS_PATH=./nginx/certs
NGINX_CONFIG_PATH=./nginx/nginx.conf
NEXUS_URL=http://172.16.0.2:8081

# массив хостов, для которых нужно переопределить настройки
hosts=(
    dl.google.com
    repo.maven.apache.org
    repo1.maven.org
    maven.google.com
    plugins.gradle.org
    developer.huawei.com
    jitpack.io
    artifactory-external.vkpartner.ru
    mvnrepository.com
    services.gradle.org
    repo.gradle.org
)

function create_self_signed_cert() {
    filename=$1
    hostname=$2
    echo "Создание сертификата ${filename}"
    openssl req -x509 -out ${filename}.crt -keyout ${filename}.key -newkey rsa:2048  -days 100000 -nodes -sha256 -subj "/CN=${hostname}" -addext 'subjectAltName = DNS:'${hostname}
}

function add_to_truststore() {
    filename=$1
    keytool -importcert -file ${NGINX_CERTS_PATH}/${filename}.crt -keystore ${GRADLE_TRUSTSTORE_PATH} -alias ${filename} -storepass ${GRADLE_TRUSTSTORE_PASSWORD} -noprompt
}

function generate_nginx_config() {
    rm ${NGINX_CONFIG_PATH} 2> /dev/null
    touch ${NGINX_CONFIG_PATH}
    echo "worker_processes  1;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;
    send_timeout 1800;
    sendfile on;
    keepalive_timeout 6500;
    "  >> ${NGINX_CONFIG_PATH}

    for host in ${hosts[@]}; do
        nexus_repo_name=$(echo mobile-${host} | sed 's/\./-/g')

        echo "    server {
        listen 443 ssl;
        server_name ${host};

        ssl_certificate certs/${host}.crt;
        ssl_certificate_key certs/${host}.key;

        location / {
            proxy_pass ${NEXUS_URL}/repository/${nexus_repo_name}/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
    " >> ${NGINX_CONFIG_PATH}
    done
    echo "}" >> ${NGINX_CONFIG_PATH}

    echo "nginx конфигурация создана: ${NGINX_CONFIG_PATH}"
}


function main {
    mkdir -p $GRADLE_TEMP_DIR

    rm ${GRADLE_TRUSTSTORE_PATH} 2> /dev/null
    # создание сертификатов
    mkdir -p $NGINX_CERTS_PATH
    for host in ${hosts[@]}; do
        create_self_signed_cert $NGINX_CERTS_PATH/${host} ${host}
        add_to_truststore ${host}
    done

    echo "Сертификаты созданы и добавлены в truststore ${GRADLE_TRUSTSTORE_PATH}:"
    # просмотр всех сертификатов в truststore
    keytool -list -keystore ${GRADLE_TRUSTSTORE_PATH} -storepass ${GRADLE_TRUSTSTORE_PASSWORD}


    # генерация nginx конфига
    generate_nginx_config

    echo "Создаем пример конфига gradle"
    rm $GRADLE_PROPERTIES_PATH 2> /dev/null
    echo "systemProp.javax.net.ssl.trustStore=${GRADLE_TRUSTSTORE_PATH}" >> $GRADLE_PROPERTIES_PATH
    echo "systemProp.javax.net.ssl.trustStorePassword=${GRADLE_TRUSTSTORE_PASSWORD}" >> $GRADLE_PROPERTIES_PATH
}

main

