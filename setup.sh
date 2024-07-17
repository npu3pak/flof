GRADLE_TRUSTSTORE_PASSWORD=1q2w3e
GRADLE_TRUSTSTORE_PATH=~/gradle-truststore.jks
HOSTS_FILE_PATH=/etc/hosts
NGINX_CONFIG_FILE_NAME=nginx.conf
NGINX_CONFIG_DIR=/opt/homebrew/etc/nginx
NEXUS_URL=http://192.168.1.114:8081

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
)

function create_self_signed_cert() {
    filename=$1
    hostname=$2
    echo "Создание сертификата ${filename}"
    openssl req -x509 -out ${filename}.crt -keyout ${filename}.key -newkey rsa:2048  -days 100000 -nodes -sha256 -subj "/CN=${hostname}" -addext 'subjectAltName = DNS:'${hostname}
}

function add_to_truststore() {
    filename=$1
    keytool -importcert -file ${filename}.crt -keystore ${GRADLE_TRUSTSTORE_PATH} -alias ${filename} -storepass ${GRADLE_TRUSTSTORE_PASSWORD} -noprompt
}

function bind_to_localhost() {
    hostname=$1
    # если в hosts нет хоста - добавляем
    if ! grep -q ${hostname} ${HOSTS_FILE_PATH}; then
        echo "" >> ${HOSTS_FILE_PATH}
        echo "127.0.0.1 ${hostname}" >> ${HOSTS_FILE_PATH}
    fi
}

function generate_nginx_config() {
    touch ${NGINX_CONFIG_FILE_NAME}
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
    

    upstream google_proxy {
        server 127.0.0.1:8081;
    }

    upstream dl_google_proxy {
        server 192.168.1.114:8081;
    }"  >> ${NGINX_CONFIG_FILE_NAME}

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
    " >> ${NGINX_CONFIG_FILE_NAME}
    done
    echo "}" >> ${NGINX_CONFIG_FILE_NAME}
}

rm ${GRADLE_TRUSTSTORE_PATH}
# создание сертификатов
mkdir -p certs
for host in ${hosts[@]}; do
    create_self_signed_cert certs/${host} ${host}
    add_to_truststore certs/${host}
done

echo "Сертификаты созданы и добавлены в truststore ${GRADLE_TRUSTSTORE_PATH}:"
# просмотр всех сертификатов в truststore
keytool -list -keystore ${GRADLE_TRUSTSTORE_PATH} -storepass ${GRADLE_TRUSTSTORE_PASSWORD}

# привязка хостов к localhost
for host in ${hosts[@]}; do
    bind_to_localhost ${host}
done

# сбрасываем кэш dns
# проверка, если macos то один способ, если linux то другой
if [[ "$OSTYPE" == "darwin"* ]]; then
    sudo killall -HUP mDNSResponder
else
    sudo /etc/init.d/nscd restart
fi

# генерация nginx конфига
rm ${NGINX_CONFIG_FILE_NAME}
generate_nginx_config 
echo "nginx конфигурация создана: ${NGINX_CONFIG_FILE_NAME}"

# копируем сертификаты в директорию nginx/certs
mkdir -p ${NGINX_CONFIG_DIR}/certs
cp certs/* ${NGINX_CONFIG_DIR}/certs

# перезаписываем конфиг в директории nginx
cp ${NGINX_CONFIG_FILE_NAME} ${NGINX_CONFIG_DIR}/nginx.conf

# проверяем конфиги nginx
nginx -t

# перезапускаем nginx
if [[ "$OSTYPE" == "darwin"* ]]; then
    sudo brew services restart nginx
else
    sudo systemctl restart nginx
fi

# добавление truststore в глобальный конфиг gradle
echo "добавляем truststore в глобальный конфиг gradle"
mkdir ~/.gradle
rm ~/.gradle/gradle.properties
echo "systemProp.javax.net.ssl.trustStore=${GRADLE_TRUSTSTORE_PATH}" >> ~/.gradle/gradle.properties
echo "systemProp.javax.net.ssl.trustStorePassword=${GRADLE_TRUSTSTORE_PASSWORD}" >> ~/.gradle/gradle.properties
echo "javax.net.ssl.trustStore=${GRADLE_TRUSTSTORE_PATH}" >> ~/.gradle/gradle.properties
echo "javax.net.ssl.trustStorePassword=${GRADLE_TRUSTSTORE_PASSWORD}" >> ~/.gradle/gradle.properties
