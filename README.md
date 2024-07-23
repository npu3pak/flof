# О проекте
Здесь описан сетап для автономной сборки Android и Flutter проектов без доступа к внешней сети

# Настройка для Android

## Описание идеи:
1. На клиенте перехватываются запросы к серверам maven/google и перенаправляются на сервер с nginx
2. nginx работает как обратный proxy и направляет запросы на raw proxy репозитории nexus
3. nexus скачивает артефакт с сервера, если его нет, и затем отдает
4. Для перехвата https-запросов создаются self-signed ssl-сертификаты. Чтобы их принимал gradle, они собираются в truststore и подкладываются в глобальном конфиге $HOME/.gradle/gradle.properties

Это гарантирует, что все запросы, даже те которые выполняются для транзитивных зависимостей и компонентов Android SDK (в том числе SDK Manager) будут перехвачены и оставят артефакты в Nexus.

## Настройка проекта
Перед началом работы нужно сгенерировать конфиг nginx и сертификаты для перехвата ssl-запросов.
Для этого нужно выполнить скрипт ```setup_project.sh```

## Запуск сервера
1. Устанавливаем Docker и Docker Compose (входят в Docker Desktop)
2. В корне проекта запускаем ```docker compose up```

## Настройка Nexus
1. Открыть Nexus. Для localhost: http://localhost:8081
2. Зайти от админа. Временный пароль будет сгенерирован в ./nexus-data/admin.password.
3. Добавить указанные репозитории

*Совет: Пепед сохранением репозиториев рекомендуется нажимать кнопку View certificate, чтобы проверить доступность сервера. Если сертификат не скачивается или ненадежен, то надо или обновить таблицу IP в extra_hosts в compose.yaml или убедиться что имя и url введены правильно (без пробелов в конце и т.п.)*

|Тип репозитория|Имя репозитория                         | Remote storage                          |
|---------------|----------------------------------------|-----------------------------------------|
|raw (proxy)    |mobile-dl-google-com                    |https://dl.google.com                    |
|raw (proxy)    |mobile-repo-maven-apache-org            |https://repo.maven.apache.org            |
|raw (proxy)    |mobile-repo1-maven-org                  |https://repo1.maven.org                  |
|raw (proxy)    |mobile-maven-google-com                 |https://maven.google.com                 |
|raw (proxy)    |mobile-plugins-gradle-org               |https://plugins.gradle.org               |
|raw (proxy)    |mobile-developer-huawei-com             |https://developer.huawei.com             |
|raw (proxy)    |mobile-jitpack-io                       |https://jitpack.io                       |
|raw (proxy)    |mobile-artifactory-external-vkpartner-ru|https://artifactory-external.vkpartner.ru|
|raw (proxy)    |mobile-mvnrepository-com                |https://mvnrepository.com                |
|raw (proxy)    |mobile-services-gradle-org              |https://services.gradle.org              |
|raw (proxy)    |mobile-repo-gradle-org                  |https://repo.gradle.org                  |
|raw (proxy)    |mobile-jcenter-bintray-com              |https://jcenter.bintray.com              |

## Настройка клиента
1. Добавить в hosts-файл машины разработчика для указанных доменов привязку к IP-адресу хоста nexus.
Пример для localhost:
```
127.0.0.1   dl.google.com
127.0.0.1   repo.maven.apache.org
127.0.0.1   repo1.maven.org
127.0.0.1   maven.google.com
127.0.0.1   plugins.gradle.org
127.0.0.1   developer.huawei.com
127.0.0.1   jitpack.io
127.0.0.1   artifactory-external.vkpartner.ru
127.0.0.1   mvnrepository.com
127.0.0.1   services.gradle.org
127.0.0.1   repo.gradle.org
127.0.0.1   jcenter.bintray.com
```
2. Сбросить кэш dns:
- Для macOS: ```sudo killall -HUP mDNSResponder```
- Для linux: ```sudo /etc/init.d/dns-clean restart && /etc/init.d/networking force-reload```
- Для windows: перезагрузить компьютер

3. Настроить trusted store в глобальном конфиге gradle
- Скопировать файл gradle/gradle-truststore.jks в любой каталог системы, например в $HOME/.gradle/
- В $HOME/.gradle/ создать файл gradle.properties
- Дописать в него путь и пароль к хранилищу сертификатов:
```
systemProp.javax.net.ssl.trustStore=/full/path/to/gradle-truststore.jks
systemProp.javax.net.ssl.trustStorePassword=1q2w3e
```
Пример конфига: gradle/gradle.properties
- Перезагрузить gradle/компьютер, т.к. gradle может игнорировать изменение настроек

## Автоматическая настройка клиента
На Linux/macOS можно использовать скрипт ```./setup_client_android.sh```

## Быстрая проверка
1. Выполнить ```curl -k https://dl.google.com/android/repository/repository2-3.xml```
2. Открыть Nexus. Для localhost: http://localhost:8081
3. Убедиться, что в репозитории mobile-dl-google-com появился указанный файл

## Ошибки
### Не скачивается зависимость
1. Проверить что она доступна без изменения hosts-файла, т.е. убедиться что файл действительно должен быть в указанном репозитории
2. Открыть compose.yaml, найти запись в extra_hosts для сервиса mobile-nexus. Убедиться, что IP указан верно и не устарел. Можно проверить через ```nslookup <ip>```
3. Проверить наличие ошибок для соответствующего репозитория в nexus
4. Попробовать повторно настроить проект ```./setup_project.sh```

# Настройка для Flutter
*Внимание! Перед настройкой для Flutter нужно провести и отладить настройку для Android.*

Для автономной работы Flutter требуется подключить dart proxy, для этого используется самописный плагин https://github.com/npu3pak/nexus-repository-dart-2024. Это форк проекта https://github.com/groupe-edf/nexus-repository-dart, который в данный момент нормально работает с pub.dev в режиме proxy, работа других режимов не проверялась. Скомпилированный плагин уже включен в данный репозиторий.

## Настройка сервера для Flutter
1. Открыть Nexus. Для localhost: http://localhost:8081
2. Зайти от админа
3. Создать указанные репозитории

|Тип репозитория|Имя репозитория                    | Remote storage              |
|---------------|-----------------------------------|-----------------------------|           
|dart (proxy)   |mobile-dart-proxy                  |https://pub.dev              |
|raw (proxy)    |mobile-flutter-storage-proxy       |https://storage.flutter-io.cn|
|maven2 (proxy) |mobile-download-flutter-maven-proxy|http://download.flutter.io   |

## Настройка клиента для Flutter
1. Прописать переменные окружения *PUB_HOSTED_URL* и *FLUTTER_STORAGE_BASE_URL* с указанием на mobile-dart-proxy, например в bashrc/zshrc добавить:
```
export PUB_HOSTED_URL="http://127.0.0.1:8081/repository/mobile-dart-proxy"
export FLUTTER_STORAGE_BASE_URL="http://127.0.0.1:8081/repository/mobile-flutter-storage-proxy"
```
2. В проекте в файле android/build.gradle добавить в allprojects ссылку на mobile-download-flutter-maven-proxy
```
allprojects {
    repositories {
        ...
        maven {
            url 'http://127.0.0.1:8081/repository/mobile-download-flutter-maven-proxy/'
            allowInsecureProtocol = true
        }
        ...
    }
}
```
3. В директории flutter на компьютере в каталоге packages/flutter_tools/gradle/src/main/groovy в файле flutter.groovy добавить allowInsecureProtocol = true для maven в разделе ` Configure the Maven repository` (строки 249-260), должно получиться так:
```
rootProject.allprojects {
            repositories {
                maven {
                    url(repository)
                    allowInsecureProtocol = true
                }
            }
}
```

## Проблемы
### Не скачиваются артефакты
1. Попробовать почистить каталог $HOME/.gradle. Файлы gradle-truststore.jks и gradle.properties удалять не нужно.
2. Попробовать после чистки переоткрыть IDE, завершить процессы gradle или перезагрузить компьютер

# Автономная работа FVM
## Офлайн установка FVM
Можно использовать обычную установку FVM, но если такой возможности нет - можно воспользоваться офлайн-установщиком.
1. Загрузить архив FVM соответствующей вашей ОС и архитектуре https://github.com/leoafarias/fvm/releases
2. Расположить загруженный файл .tar.gz в одном каталоке с fvm/fvm_offline_installer.sh
3. Перейти в каталог fvm, запустить установку ```fvm_offline_installer.sh <загруженный-архив.tar.gz>```

## Настройка git-репозитория
Для работы FVM при установке новых версий Flutter потребуется указать собственный git-репозиторий Flutter.
1. Если ваша организация работает с gitlab или аналогичным репозиторием, можно клонировать репозиторий https://github.com/flutter/flutter.git в git-репозиторий вашей организации.
2. Если вы работаете один или вам нужен офлайн-сетап, вы можете поднять свой локальный gitlab и клонировать репозиторий https://github.com/flutter/flutter.git в него


## Настройка локального git-репозитория
1. Перейти в каталог fvm
2. Выполнить ```docker compose up```
3. Дождаться запуска gitlab: http://localhost:8082
4. Войти под учетной записью root, пароль fvm/gitlab/config/initial_root_password. 
5. Смените пароль root: http://localhost:8082/-/user_settings/password/edit
6. Перейдите в http://localhost:8082/admin/application_settings/general, найдите секцию *Import and export settings* и включите *Repository by URL*, сохраните изменения кнопкой *Save changes*
7. Перейдите в http://localhost:8082/projects/new#import_project и импортируйте https://github.com/flutter/flutter.git как public-репозиторий

## Настройка FVM на клиенте
Добавьте глобальную переменную *FVM_FLUTTER_URL* с указанием вашего git-репозитория
```
export FVM_FLUTTER_URL=http://127.0.0.1:8082/path/to/flutter.git
```

Убедитесь, что установлена переменная окружения *FLUTTER_STORAGE_BASE_URL*
```
export FLUTTER_STORAGE_BASE_URL="http://127.0.0.1:8081/repository/mobile-flutter-storage-proxy"
```