#!/bin/bash
if [ ! -f "./authorized_key.json" ]; then
	echo "Положите рядом с install.sh файл authorized_key.json от сервисного аккаунта"
	exit 1
	else
echo "Терраформируем марс! (YandexCloud)"
mkdir ./tf
cd ./tf
git init
git pull https://github.com/Briefklammern/terraform-diploma.git & gitpull=$!
wait $gitpull
cd ..
mkdir ./ansible
cd ./ansible
git init
git pull https://github.com/Briefklammern/ansible-diploma.git & gitpull2=$!
wait $gitpull2
cd ..
set -euo pipefail
target="`pwd`/tf/backend.tfvars"
read -p "Введите название S3 Bucket: " bucket
read -r -p "Введите access_token для Bucket: " access
read -r -s -p "Введите secret_token для Bucket: " token
echo
tmp="$(mktemp "${target}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" <<EOF
bucket = "${bucket}"
secret_key = "${token}"
access_key = "${access}"
EOF
mv "$tmp" "$target"
echo "Файл записан: $target"
terraform -chdir=./tf init -backend-config=backend.tfvars
read -p "Введите Cloud_ID: " cloud_id
read -p "Введите folder_id: " folder_id
terraform -chdir=./tf apply -var="cloud_id=$cloud_id" -var="folder_id=$folder_id" -auto-approve & tfcomplete=$!
wait $tfcomplete
echo "Терраформирование завершено!"
echo "Ждем-с SSH..."
HOST=`cat ./ansible/inventory.ini | grep host | awk -F "host=" {'print $2'} | awk -F " " {'print $1'}`
while ! (echo > /dev/tcp/$HOST/22) 2>/dev/null; do
    echo "SSH на $HOST недоступен, ждём..."
    sleep 5
done
echo "SSH на $HOST доступен, продолжаем работу"
echo "Ставим Докер на терраформированную ВМ!"
ansible-playbook -i ./ansible/inventory.ini ./ansible/install.yaml & ansiblecomplete=$!
wait $ansiblecomplete
echo "Pullяем тестовое приложение на сервак"
ansible-playbook -i ./ansible/inventory.ini ./ansible/app.yaml & appcomplete=$!
wait $appcomplete
echo "==== Проверяй $HOST:8080, Начальник! ===="
echo "##################################################"
echo "#Запршиваем креды от докерхаба и пушим туда образ#"
echo "##################################################"
read -r -p "Пушим образ в DockerHub? [y/n] " ans
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then
                echo "Ну нет так нет"
                exit 0
        else
set -euo pipefail
# --- Настройки ---
VARS_FILE="ansible/secret.vars"
# --- Создание директории ---
mkdir -p "$(dirname "$VARS_FILE")"
# --- Предупреждение, если файл уже существует ---
if [[ -f "$VARS_FILE" ]]; then
    read -r -p "Файл $VARS_FILE уже существует. Перезаписать? [y/N] " ans
    if [[ ! "$ans" =~ ^[Yy]$ ]]; then
        echo "Отменено."
        exit 0
    fi
    rm -f "$VARS_FILE"
fi
# --- Ввод данных ---
echo "Введите креды Docker Hub"
read -r -p "Docker ID (username): " DOCKERHUB_USERNAME
if [[ -z "$DOCKERHUB_USERNAME" ]]; then
    echo " Username не может быть пустым." >&2
    exit 1
fi
read -r -s -p "Personal Access Token: " DOCKERHUB_TOKEN
echo
if [[ -z "$DOCKERHUB_TOKEN" ]]; then
    echo "Токен не может быть пустым." >&2
    exit 1
fi
# --- Запись во временный plaintext-файл ---
PLAIN_FILE="$(mktemp)"
trap 'rm -f "$PLAIN_FILE"' EXIT
chmod 600 "$PLAIN_FILE"
cat > "$PLAIN_FILE" <<EOF
---
dockerhub_username: "${DOCKERHUB_USERNAME}"
dockerhub_token: "${DOCKERHUB_TOKEN}"
EOF
# --- Шифрование через ansible-vault ---
# Если переменная ANSIBLE_VAULT_PASSWORD_FILE задана — ansible-vault
# прочитает пароль оттуда и НЕ будет спрашивать.
# Иначе — спросит интерактивно.
echo "Шифруем $VARS_FILE через ansible-vault..."
if [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
    ansible-vault encrypt --output "$VARS_FILE" "$PLAIN_FILE"
else
    ansible-vault encrypt --output "$VARS_FILE" "$PLAIN_FILE" \
        --ask-vault-pass
fi
chmod 600 "$VARS_FILE"
echo " Готово: $VARS_FILE зашифрован."
echo "Пушим в докер хаб..."
ansible-playbook -i ./ansible/inventory.ini ./ansible/hub_push.yml --ask-vault-pass
fi
fi
