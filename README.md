# О проекте
Здесь описан сетап для автономной сборки Android проектов без доступа к внешней сети

## Описание идеи:
1. На клиенте перехватываются запросы к серверам maven/google и перенаправляются на сервер с nginx
2. nginx работает как обратный proxy и направляет запросы на raw proxy репозитории nexus
3. nexus скачивает артефакт с сервера, если его нет, и затем отдает
4. Для перехвата https-запросов создаются self-signed ssl-сертификаты. Чтобы их переваривал gradle - они собираются в truststore и подкладываются в глобальном конфиге $home/.gradle/gradle.properties

Это гарантирует, что все запросы, даже те которые выполняются для транзитивных зависимостей и компонентов Android SDK (в том числе SDK Manager) будут перехвачены и оставят артефакты в Nexus.

# Настройка сервера и клиентов для автономной сборки Android проектов

## Повторная настройка проекта
Сейчас в репозиторий уже включены заранее сгенерированные сертификаты и конфиг nginx.
Если требуется, повторную генерацию можно выполнить самостоятельно скриптом ```setup_project.sh```

## Запуск сервера
1. Устанавливаем Docker и Docker Compose (входит в Docker Desktop)
2. В корне проекта запускаем ```docker compose up```

## Настройка Nexus
1. Открыть Nexus. Для localhost: ```http://localhost:8081```
2. Зайти от админа. Временный пароль будет сгенерирован в ./nexus-data/admin.password.
3. Добавить репозитории типа *raw (proxy)*
*Совет:* Пепед сохранением репозиториев рекомендуется нажимать кнопку View certificate, чтобы проверить доступность сервера. Если сертификат не скачивается или ненадежен, то надо или обновить таблицу IP в extra_hosts в compose.yaml или убедиться что имя и url введены правильно (без пробелов в конце и т.п.)

|Имя репозитория                         | Remote storage                           |
|----------------------------------------|------------------------------------------|
|mobile-dl-google-com                    | https://dl.google.com                    |
|mobile-repo-maven-apache-org            | https://repo.maven.apache.org            |
|mobile-repo1-maven-org                  | https://repo1.maven.org                  |
|mobile-maven-google-com                 | https://maven.google.com                 |
|mobile-plugins-gradle-org               | https://plugins.gradle.org               |
|mobile-developer-huawei-com             | https://developer.huawei.com             |
|mobile-jitpack-io                       | https://jitpack.io                       |
|mobile-artifactory-external-vkpartner-ru| https://artifactory-external.vkpartner.ru|
|mobile-mvnrepository-com                | https://mvnrepository.com                |
|mobile-services-gradle-org              | https://services.gradle.org              |

## Настройка клиента
1. Добавить в hosts настройку для указанных хостов на IP-адрес сервера.
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
```
2. Сбросить кэш dns:
- Для macOS: ```sudo killall -HUP mDNSResponder```
- Для linux: ```sudo /etc/init.d/dns-clean restart && /etc/init.d/networking force-reload```
- Для windows: перезагрузить компьютер

3. Настроить trusted store в глобальном конфиге gradle
- Скопировать файл gradle/gradle-truststore.jks в любой каталог системы
- В домашнем каталоге в каталоге .gradle создать файл gradle.properties
- Дописать в него путь и пароль к хранилищу:
```
systemProp.javax.net.ssl.trustStore=/full/path/to/gradle-truststore.jks
systemProp.javax.net.ssl.trustStorePassword=1q2w3e
```
Пример конфига: gradle/gradle.properties
- Перезагрузить gradle/компьютер, т.к. gradle может игнорировать изменение настроек

## Автоматическая настройка клиента
На Linux/macOS можно использовать скрипт ```./setup_client.sh```

## Быстрая проверка
1. Выполнить ```curl -k https://dl.google.com/android/repository/repository2-3.xml```
2. Открыть Nexus. Для localhost: ```http://localhost:8081```
3. Убедиться, что в репозитории mobile-dl-google-com появился указанный файл

# Ошибки
### Не скачивается зависимость
1. Проверить что она доступна без изменения hosts, убедиться что файл действительно должен быть в указанном репозитории
2. Убедиться, что IP для хоста в compose.yaml указан верно и не устарел
3. Проверить наличие ошибок для репозитория в nexus