# О проекте
Здесь описан сетап для автономной сборки Android и Flutter проектов без доступа к внешней сети

## Описание идеи:
1. На клиенте перехватываются запросы к серверам maven/google и перенаправляются на сервер с nginx
2. nginx работает как обратный proxy и направляет запросы на raw proxy репозитории nexus
3. nexus скачивает артефакт с сервера, если его нет, и затем отдает
4. Для перехвата https-запросов создаются self-signed ssl-сертификаты. Чтобы их принимал gradle, они собираются в truststore и подкладываются в глобальном конфиге $HOME/.gradle/gradle.properties

Это гарантирует, что все запросы, даже те которые выполняются для транзитивных зависимостей и компонентов Android SDK (в том числе SDK Manager) будут перехвачены и оставят артефакты в Nexus.

# Настройка проекта и запуск сервера
## Настройка проекта
Перед началом работы нужно сгенерировать конфиг nginx и сертификаты для работы ssl-запросов
- Для Linux/macOS: ```setup_project.sh```
- Для Windows в Git Bash: ```setup_project_windows.sh```

В результате:
- В каталоге nginx появится конфиг и каталог certs с self-signed ssl-сертификатами
- В каталоге gradle появится файл gradle-truststore.jks и пример gradle.properties, которые нужно передать клиентам

## Запуск сервера
1. Установить Docker и Docker Compose (входят в Docker Desktop)
2. В корне проекта запустить ```docker compose up```

## Настройка Nexus
1. Открыть Nexus. Для localhost: http://localhost:8081
2. Зайти от админа. Временный пароль будет сгенерирован в ./nexus-data/admin.password.
3. Добавить указанные репозитории

*Совет: Перед сохранением репозиториев рекомендуется нажимать кнопку View certificate, чтобы проверить доступность сервера. Если сертификат не скачивается или ненадежен, то надо или обновить таблицу IP в extra_hosts в compose.yaml или убедиться что имя и url введены правильно (без пробелов в конце и т.п.)*

*Примечание: Для автономной работы Flutter требуется подключить dart proxy, для этого используется самописный плагин https://github.com/npu3pak/nexus-repository-dart-2024. Это форк проекта https://github.com/groupe-edf/nexus-repository-dart, который в данный момент нормально работает с pub.dev в режиме proxy, работа других режимов не проверялась. Скомпилированный плагин уже включен в данный репозиторий.*

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
|raw (proxy)    |mobile-flutter-storage-proxy            |https://storage.flutter-io.cn            |
|dart (proxy)   |mobile-dart-proxy                       |https://pub.dev                          |
|maven2 (proxy) |mobile-download-flutter-maven-proxy     |http://download.flutter.io               |

## Настройка git-репозитория
Для автономной работы FVM при установке новых версий Flutter потребуется указать кастомный git-репозиторий Flutter.
1. Если ваша организация работает с gitlab или аналогичным репозиторием, можно клонировать репозиторий https://github.com/flutter/flutter.git в git-репозиторий вашей организации.
2. Если вы работаете один или вам нужен офлайн-сетап, вы можете поднять свой локальный gitlab и клонировать репозиторий https://github.com/flutter/flutter.git в него. Этот сценарий описан далее.

### Настройка локального репозитория gitlab
1. Перейти в каталог fvm
2. Выполнить ```docker compose up```
3. Дождаться запуска gitlab: http://localhost:8082
4. Войти под учетной записью root, пароль fvm/gitlab/config/initial_root_password. 
5. Смените пароль root: http://localhost:8082/-/user_settings/password/edit
6. Перейдите в http://localhost:8082/admin/application_settings/general, найдите секцию *Import and export settings* и включите *Repository by URL*, сохраните изменения кнопкой *Save changes*
7. Перейдите в http://localhost:8082/projects/new#import_project и импортируйте https://github.com/flutter/flutter.git как public-репозиторий

# Автономная установка и настройка Flutter на клиенте с Linux/macOS
## Установка зависимостей (только Linux)
Пример для Ubuntu/Mint:
```
sudo apt-get update -y
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa libc6:amd64 libstdc++6:amd64 libbz2-1.0:amd64 libncurses5:amd64 libc6:i386 libncurses5:i386 libstdc++6:i386 lib32z1 libbz2-1.0:i386
```

## Настройка hosts
1. Дописать в файл /etc/hosts привязку указанных хостов к IP сервера nginx+nexus. Пример для localhost:
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

## Настройка Gradle
- Скопировать файл gradle/gradle-truststore.jks в любой каталог системы, например в $HOME/.gradle/
- В $HOME/.gradle/ создать файл gradle.properties
- Дописать в него путь и пароль к хранилищу сертификатов:
```
systemProp.javax.net.ssl.trustStore=/full/path/to/gradle-truststore.jks
systemProp.javax.net.ssl.trustStorePassword=1q2w3e
```

Пример конфига: gradle/gradle.properties
- Перезагрузить gradle/компьютер, т.к. gradle может игнорировать изменение настроек

### Автоматическая настройка клиента
Для автоматического выполнения указанных выше шагов в Linux/macOS можно использовать скрипт ```./setup_client_android.sh```

### Быстрая проверка
1. Выполнить ```curl -k https://dl.google.com/android/repository/repository2-3.xml```
2. Открыть Nexus. Для localhost: http://localhost:8081
3. Убедиться, что в репозитории mobile-dl-google-com появился указанный файл

## Установка Android Studio
Скачать и установить Android Studio https://developer.android.com/studio
- При установке нужно запомнить каталог с Android SDK
- Будут предупреждения о том, что используется недоверенное HTTPS-соединение, на все предупреждения нужно отвечать Accept
- Из-за того что часть артефактов может отсутствовать в nexus, могут быть таймауты ожидания ответа сервера, в этом случае нужно просто повторять попытку

## Офлайн установка FVM
Можно использовать обычную установку FVM, но если такой возможности нет - можно воспользоваться офлайн-установщиком.
1. Загрузить архив FVM соответствующей вашей ОС и архитектуре https://github.com/leoafarias/fvm/releases
2. Распаковать архив в любой каталог
3. В .bashrc (для bash) или .zshrc (для zsh) добавить
```
export PATH="$PATH":"path/to/fvm"
```

## Установка переменных окружения
Нужно добавить и настроить следующие переменные окружения в файл .bashrc (для bash) или .zshrc (для zsh):
```
# Этот каталог будет создан при установке глобальной версии flutter.
export PATH="$PATH":"~/fvm/default/bin"
# Указываются пути к репозиториям в Nexus
export PUB_HOSTED_URL="http://127.0.0.1:8081/repository/mobile-dart-proxy"
export FLUTTER_STORAGE_BASE_URL="http://127.0.0.1:8081/repository/mobile-flutter-storage-proxy"
# Для автономной установки нужно указать одинаковый путь к git-репозиторию flutter в двух переменных
export FVM_FLUTTER_URL=http://127.0.0.1:8082/root/flutter.git
export FLUTTER_GIT_URL=http://127.0.0.1:8082/root/flutter.git 
```

## Установка глобальной версии flutter
1. После настройки fvm нужно выполнить команду ```fvm global <версия flutter>```
2. Выполнить команду flutter config --android-sdk <каталог с Android SDK>
3. Выполнить команду flutter doctor и следовать рекомендациям, если будут найдены проблемы, связанные с Android-разработкой
4. Выполнить команду flutter precache

# Автономная установка и настройка Flutter на клиенте с Windows
## Настройка hosts
1. Дописать в файл C:\Windows\System32\drivers\etc\hosts привязку указанных хостов к IP сервера nginx+nexus. Пример для localhost:
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
2. Перезагрузить компьютер

## Настройка Gradle
- Скопировать файл gradle/gradle-truststore.jks в любой каталог системы, например в $HOME/.gradle/
- В $HOME/.gradle/ создать файл gradle.properties
- Дописать в него путь и пароль к хранилищу сертификатов:
```
systemProp.javax.net.ssl.trustStore=C:\\full\\path\\to\\gradle-truststore.jks
systemProp.javax.net.ssl.trustStorePassword=1q2w3e
```

Пример конфига: gradle/gradle.properties
- Перезагрузить gradle/компьютер, т.к. gradle может игнорировать изменение настроек

## Установка Android Studio
Скачать и установить Android Studio https://developer.android.com/studio
- При установке нужно запомнить каталог с Android SDK
- Будут предупреждения о том, что используется недоверенное HTTPS-соединение, на все предупреждения нужно отвечать Accept
- Из-за того что часть артефактов может отсутствовать в nexus, могут быть таймауты ожидания ответа сервера, в этом случае нужно просто повторять попытку

## Установка и настройка FVM
1. Скачать fvm для Windows https://github.com/leoafarias/fvm/releases
2. Разархивировать, сохранить путь к каталогу fvm
3. В каталоге с fvm рядом с файлом fvm.bat сделать текстовый файл fvm без расширения,  
в который нужно вставить и отрадактировать следующее содержимое:
```
#!/bin/bash
# Нужно указать свой путь к каталогу fvm, например /c/tools/fvm/
/drive_letter/path/to/fvm/fvm.bat $@
```
4. В домашнем каталоге пользователя создать файл .bashrc 
в который нужно вставить и отрадактировать указанные переменные:
```
# Нужно указать путь fvm, например /c/tools/fvm/fvm.bat $@
export PATH="$PATH":"/drive_letter/path/to/fvm/"
# Нужно указать путь к каталогу fvm/default/bin в домашнем каталоге. 
# Этот каталог будет создан при установке глобальной версии flutter.
export PATH="$PATH":"/c/Users/<имя пользователя>/fvm/default/bin"
# Указываются пути к репозиториям в Nexus
export PUB_HOSTED_URL="http://127.0.0.1:8081/repository/mobile-dart-proxy"
export FLUTTER_STORAGE_BASE_URL="http://127.0.0.1:8081/repository/mobile-flutter-storage-proxy"
# Для автономной установки нужно указать одинаковый путь к репозиторию flutter в двух переменных
export FVM_FLUTTER_URL=http://127.0.0.1:8082/root/flutter.git
export FLUTTER_GIT_URL=http://127.0.0.1:8082/root/flutter.git 
```
5. В настройках Windows добавить те же самые переменные окружения, что и в файле .bashrc,
но нужно использовать пути не в стиле Unix а в стиле Windows, например вместо /c/Users/... использовать c:\Users...
```
PUB_HOSTED_URL="http://127.0.0.1:8081/repository/mobile-dart-proxy"
FLUTTER_STORAGE_BASE_URL="http://127.0.0.1:8081/repository/mobile-flutter-storage-proxy"
# Для автономной установки нужно указать одинаковый путь к git-репозиторию flutter в двух переменных
FVM_FLUTTER_URL=http://127.0.0.1:8082/root/flutter.git
FLUTTER_GIT_URL=http://127.0.0.1:8082/root/flutter.git 
```
Также нужно в PATH-переменную добавить каталоги C:\Users\<имя пользователя>\fvm\default\bin и каталог с fvm из шага 2.
6. Открыть git bash и cmd и убедиться, что в них доступна команда fvm

## Установка глобальной версии flutter
1. После настройки fvm нужно выполнить команду ```fvm global <версия flutter>```
2. Если будет ошибка, что у текущего пользователя недостаточно прав, повторно открыть консоль с правами администратора и повторить попытку
3. Выполнить команду flutter config --android-sdk <каталог с Android SDK>
4. Выполнить команду flutter doctor и следовать рекомендациям, если будут найдены проблемы, связанные с Android-разработкой
5. Выполнить команду flutter precache

# Настройка Flutter-проектов
В проекте в файле android/build.gradle последним пунктом добавить в allprojects ссылку на mobile-download-flutter-maven-proxy
```
allprojects {
    repositories {
        ...
        maven {
            url 'http://127.0.0.1:8081/repository/mobile-download-flutter-maven-proxy/'
            allowInsecureProtocol = true
        }
    }
}
```

# Типовые проблемы
### Не скачивается зависимость
1. Открыть compose.yaml, найти запись в extra_hosts для сервиса mobile-nexus. Убедиться, что IP указан верно и не устарел. Можно проверить через ```nslookup <ip>```
2. Проверить наличие ошибок для соответствующего репозитория в nexus
3. Попробовать повторно настроить проект ```./setup_project.sh``` или ```./setup_project_windows.sh```, перезапустить сервер и обновить gradle-truststore.jsk на клиенте
4. Попробовать почистить каталог $HOME/.gradle. Файлы gradle-truststore.jks и gradle.properties удалять не нужно.
5. Проверить что файл $HOME/.gradle/gradle.properties. Убедиться что путь к файлу указан полностью, убедиться что на windows используется двойная косая черта в пути (С:\\path\\to\\gradle-truststore.jsk)

### Gradle игнорирует параметр allowInsecureProtocol = true для кастомного maven-репозитория
При запуске или сборке android приложения появилась похожая ошибка:
```
 Using insecure protocols with repositories, without explicit opt-in, is unsupported. Switch Maven repository 'maven2(http://127.0.0.1:8081/repository/mobile-flutter-storage-proxy/download.flutter.io)' to redirect to a secure protocol (like HTTPS) or allow insecure protocols.
 ```
 При этом `flutter pub get` отрабатывает корректно. 

 1. В директории flutter на компьютере в каталоге packages/flutter_tools/gradle/src/main/groovy в файле flutter.groovy добавить allowInsecureProtocol = true для maven в разделе ` Configure the Maven repository` (строки 249-260), должно получиться так:
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
### Проекты очень долго собираются
В android/build.gradle нужно убедиться, что репозиторий mobile-download-flutter-maven-proxy является последним пунктом в списке.

### В релизных сборках ошибка на шаге ":app:uploadCrashlyticsMappingFileInternalRelease"
Описание ошибки примерно следующее:
```
Execution failed for task ':app:uploadCrashlyticsMappingFileInternalRelease'.
> javax.net.ssl.SSLHandshakeException: PKIX path building failed: sun.security.provider.certpath.SunCertPathBuilderException: unable to find valid certification path to requested target
```

Можно отключить отгрузку mapping-файлов crashlytics в android/app/build.gradle
```
productFlavors {
        yourFlavorName {
            firebaseCrashlytics {
                mappingFileUploadEnabled false
            }
        }
    }
```
Описание: https://firebase.google.com/docs/crashlytics/get-deobfuscated-reports?platform=android
