# Итоговый проект курса «DevOps-инженер с нуля» Сафронов П.А.

## 0. Требования
- Должны быть установлены **terraform**, **ansible**, **git**.

## 1. Инфраструктура
- Создание инфраструктуры (VPC, Subnet, Compute Instance) выполняется с помощью Terraform на Яндекс Облаке.
  [Репозиторий с конфигом](https://github.com/Briefklammern/terraform-diploma)

## 2. Работа Ansible 
- [Установка Docker на созданную ранее ВМ](https://github.com/Briefklammern/ansible-diploma/blob/main/install.yaml)
- Скачивание и запуск [тестового приложения](https://github.com/Briefklammern/ansible-diploma/blob/main/app.yaml)
- Сборка образа Docker и [отправка](https://github.com/Briefklammern/ansible-diploma/blob/main/hub_push.yml) его в [Docker Hub](https://hub.docker.com/repository/docker/devillis/test-app-diploma)

## 3. Настройка CI
- В GitHub репозитории приложения в разделе Actions необходимо создать Docker runner
  ![action1](./img/1.PNG)
