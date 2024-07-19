#!/bin/bash
GRADLE_TRUSTSTORE_PASSWORD=1q2w3e
GRADLE_TRUSTSTORE_PATH=./gradle/gradle-truststore.jks
GRADLE_PROPERTIES_PATH=./gradle/gradle.properties
GRADLE_TARGET_DIR=~/.gradle
GRADLE_TRUSTSTORE_TARGET_PATH=$GRADLE_TARGET_DIR/gradle-truststore.jks
GRADLE_PROPERTIES_TARGET_PATH=$GRADLE_TARGET_DIR/gradle.properties
HOSTS_FILE_PATH=/etc/hosts
SERVER_IP=127.0.0.1

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

function bind_to_localhost() {
    hostname=$1
    # если в hosts нет хоста - добавляем
    if ! grep -q ${hostname} ${HOSTS_FILE_PATH}; then
        echo "" | sudo tee -a ${HOSTS_FILE_PATH}
        echo "$SERVER_IP ${hostname}" | sudo tee -a ${HOSTS_FILE_PATH}
    fi
}

function main {
    # привязка хостов к localhost
    for host in ${hosts[@]}; do
        bind_to_localhost ${host}
    done

    # сбрасываем кэш dns
    # проверка, если macos то один способ, если linux то другой
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sudo killall -HUP mDNSResponder
    else
        sudo /etc/init.d/dns-clean restart && /etc/init.d/networking force-reload
    fi

    echo "Создаем конфиг gradle"
    mkdir -p $GRADLE_TARGET_DIR

    cp $GRADLE_TRUSTSTORE_PATH $GRADLE_TRUSTSTORE_TARGET_PATH

    rm $GRADLE_PROPERTIES_TARGET_PATH 2> /dev/null
    touch $GRADLE_PROPERTIES_TARGET_PATH
    echo "systemProp.javax.net.ssl.trustStore=$GRADLE_TRUSTSTORE_TARGET_PATH" >> $GRADLE_PROPERTIES_TARGET_PATH
    echo "systemProp.javax.net.ssl.trustStorePassword=${GRADLE_TRUSTSTORE_PASSWORD}" >> $GRADLE_PROPERTIES_TARGET_PATH
}

main