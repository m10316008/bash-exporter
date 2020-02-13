#!/bin/bash
#writer forking.ch

function call_db() {
    PROJECT_NAMESPACE="java-backend"
    GITLAB_PROJECT_ID=`(curl -s --header "PRIVATE-TOKEN:${GITLAB_USER_TOKEN}" http://${GITLAB_FQDN}/api/v4/projects?per_page=100\&page=1 | jq -r ".[] | select(.namespace.name==\"${PROJECT_NAMESPACE}\") | select(.name==\"${PROJECT_NAME}\") | .id")`
    test -n "${GITLAB_PROJECT_ID}" || GITLAB_PROJECT_ID=`(curl -s --header "PRIVATE-TOKEN:${GITLAB_USER_TOKEN}" http://${GITLAB_FQDN}/api/v4/projects?per_page=100\&page=2 | jq -r ".[] | select(.namespace.name==\"${PROJECT_NAMESPACE}\") | select(.name==\"${PROJECT_NAME}\") | .id")`
    test -n "${GITLAB_PROJECT_ID}" || GITLAB_PROJECT_ID=`(curl -s --header "PRIVATE-TOKEN:${GITLAB_USER_TOKEN}" http://${GITLAB_FQDN}/api/v4/projects?per_page=100\&page=3 | jq -r ".[] | select(.namespace.name==\"${PROJECT_NAMESPACE}\") | select(.name==\"${PROJECT_NAME}\") | .id")`
    test -n "${TAG_NAME}" && GITLAB_PROJECT_LAST_TAG="${TAG_NAME}" || GITLAB_PROJECT_LAST_TAG=`(curl -s --header "PRIVATE-TOKEN:${GITLAB_USER_TOKEN}" http://${GITLAB_FQDN}/api/v4/projects/${GITLAB_PROJECT_ID}/repository/tags | jq -r ".[] | .name" | grep '^v\|^V' | sed 's/V/v/g' | sort -rfV | head -n 1)`
    GITLAB_PROJECT_LAST_CIMMIT=`(curl -s --header "PRIVATE-TOKEN:${GITLAB_USER_TOKEN}" http://${GITLAB_FQDN}/api/v4/projects/${GITLAB_PROJECT_ID}/repository/tags | jq -r ".[] | select(.name==\"${GITLAB_PROJECT_LAST_TAG}\") | .commit.short_id")`
    GITLAB_PROJECT_MASTER_CIMMIT=`(curl -s --header "PRIVATE-TOKEN:${GITLAB_USER_TOKEN}" http://${GITLAB_FQDN}/api/v4/projects/${GITLAB_PROJECT_ID}/repository/commits/master | jq -r .short_id)`
    DOCKER_LAST_TAG="${GITLAB_PROJECT_LAST_TAG}"
    DOCKER_SHA256_TAG="NAN"
    DOCKER_SHA256_UAT="NAN"
    DOCKER_SHA256_PROD="NAN"
}

function call_check() {
    aws ecr --region ap-northeast-1 list-images --registry-id 568227361872 --repository-name ${PROJECT_NAMESPACE}/${PROJECT_NAME} --filter tagStatus="TAGGED" | xargs | sed 's/{/\n{/g' | grep imageTag | awk '{print $3,$5}' | sed 's/,//g' | sed 's/sha256://g' > ${LOG_PATH}/${PROJECT_NAMESPACE}-${PROJECT_NAME}.log
    GITLAB_PROJECT_ID=`(curl -s --header "PRIVATE-TOKEN:${GITLAB_USER_TOKEN}" http://${GITLAB_FQDN}/api/v4/projects?per_page=100\&page=1 | jq -r ".[] | select(.namespace.name==\"${PROJECT_NAMESPACE}\") | select(.name==\"${PROJECT_NAME}\") | .id")`
    test -n "${GITLAB_PROJECT_ID}" || GITLAB_PROJECT_ID=`(curl -s --header "PRIVATE-TOKEN:${GITLAB_USER_TOKEN}" http://${GITLAB_FQDN}/api/v4/projects?per_page=100\&page=2 | jq -r ".[] | select(.namespace.name==\"${PROJECT_NAMESPACE}\") | select(.name==\"${PROJECT_NAME}\") | .id")`
    test -n "${GITLAB_PROJECT_ID}" || GITLAB_PROJECT_ID=`(curl -s --header "PRIVATE-TOKEN:${GITLAB_USER_TOKEN}" http://${GITLAB_FQDN}/api/v4/projects?per_page=100\&page=3 | jq -r ".[] | select(.namespace.name==\"${PROJECT_NAMESPACE}\") | select(.name==\"${PROJECT_NAME}\") | .id")`
    test -n "${TAG_NAME}" && GITLAB_PROJECT_LAST_TAG="${TAG_NAME}" || GITLAB_PROJECT_LAST_TAG=`(curl -s --header "PRIVATE-TOKEN:${GITLAB_USER_TOKEN}" http://${GITLAB_FQDN}/api/v4/projects/${GITLAB_PROJECT_ID}/repository/tags | jq -r ".[] | .name" | grep '^v\|^V' | sed 's/V/v/g' | sort -rfV | head -n 1)`
    GITLAB_PROJECT_LAST_CIMMIT=`(curl -s --header "PRIVATE-TOKEN:${GITLAB_USER_TOKEN}" http://${GITLAB_FQDN}/api/v4/projects/${GITLAB_PROJECT_ID}/repository/tags | jq -r ".[] | select(.name==\"${GITLAB_PROJECT_LAST_TAG}\") | .commit.short_id")`
    GITLAB_PROJECT_MASTER_CIMMIT=`(curl -s --header "PRIVATE-TOKEN:${GITLAB_USER_TOKEN}" http://${GITLAB_FQDN}/api/v4/projects/${GITLAB_PROJECT_ID}/repository/commits/master | jq -r .short_id)`
    test -n "${TAG_NAME}" && DOCKER_LAST_TAG="${TAG_NAME}" || DOCKER_LAST_TAG=`cat ${LOG_PATH}/${PROJECT_NAMESPACE}-${PROJECT_NAME}.log | awk '{print $2}' | grep '^v\|^V' | sed 's/V/v/g' | sort -rfV | head -n 1`
    DOCKER_SHA256_UAT=`cat ${LOG_PATH}/${PROJECT_NAMESPACE}-${PROJECT_NAME}.log | grep uat | awk '{print $1}'`
    DOCKER_SHA256_PROD=`cat ${LOG_PATH}/${PROJECT_NAMESPACE}-${PROJECT_NAME}.log | grep prod | awk '{print $1}'`
    DOCKER_SHA256_TAG=`cat ${LOG_PATH}/${PROJECT_NAMESPACE}-${PROJECT_NAME}.log | grep ${DOCKER_LAST_TAG} | awk '{print $1}'`
}

LOG_PATH="${PWD}"
GITLAB_FQDN="gitlab.innotech.org"
GITLAB_USER_TOKEN="Pwd9xd-LTrkF8WzhydFJ"
LIST_NAMESPACE="databases java-backend frontend"
LIST_DATABASES="tiger-sqlddl inno-sqlddl lekima-sqlddl"
LIST_BACKEND="\
    tiger-common tiger-admin tiger-user tiger-schedule tiger-payment tiger-websocket tiger-thirdparty \
    inno-common inno-admin inno-business inno-game inno-order inno-payment inno-user inno-websocket inno-chat inno-chatcrawler\
    inno-odds inno-correlation"
LIST_FRONTEND="\
    tiger-admin tiger-portal \
    inno-sport inno-chatroom \
    "
for PROJECT_NAMESPACE in ${LIST_NAMESPACE}
do
    if [ "${PROJECT_NAMESPACE}" == "databases" ]; then
        PROJECT_LIST="${LIST_DATABASES}"
    elif [ "${PROJECT_NAMESPACE}" == "java-backend" ]; then
        PROJECT_LIST="${LIST_BACKEND}"
    elif [ "${PROJECT_NAMESPACE}" == "frontend" ]; then
        PROJECT_LIST="${LIST_FRONTEND}"
    else
        echo "no match NAMESPACE"
        exit 1
    fi
    for PROJECT_NAME in ${PROJECT_LIST}
    do
        TAG_NAME=""
        MSG=""
        if [[ "${PROJECT_NAME}" == *-sqlddl ]] || [[ "${PROJECT_NAME}" == *-common ]]; then
            call_db
        else
            call_check
        fi
        if [[ "${GITLAB_PROJECT_LAST_TAG}" == "${DOCKER_LAST_TAG}" ]] && \
        [[ "${GITLAB_PROJECT_LAST_CIMMIT}" == "${GITLAB_PROJECT_MASTER_CIMMIT}" ]] && \
        [[ "${DOCKER_SHA256_TAG}" == "${DOCKER_SHA256_UAT}" ]] && \
        [[ "${DOCKER_SHA256_TAG}" == "${DOCKER_SHA256_PROD}" ]]
        then
            #CHECK=`echo "\033[36mok\033[0m"`
            CHECK=`echo "1"`
        else
            #CHECK=`echo "\033[1;31;43mfail\033[0m"`
            CHECK=`echo "0"`
            test "${GITLAB_PROJECT_LAST_TAG}" != "${DOCKER_LAST_TAG}" && MSG=`echo "${MSG} tag_name"`
            test "${GITLAB_PROJECT_LAST_CIMMIT}" != "${GITLAB_PROJECT_MASTER_CIMMIT}" && MSG=`echo "${MSG} tag_cimmit"`
            test "${DOCKER_SHA256_TAG}" != "${DOCKER_SHA256_UAT}" && MSG=`echo "${MSG} tag_uat"`
            test "${DOCKER_SHA256_TAG}" != "${DOCKER_SHA256_PROD}" && MSG=`echo "${MSG} tag_prod"`
        fi
        #echo -e "Group: \033[32m${PROJECT_NAMESPACE}\033[0m \t Project: \033[34m${PROJECT_NAME}\033[0m \t Gitlab: \033[33m${GITLAB_PROJECT_LAST_TAG}\033[0m \t Docker: \033[35m${DOCKER_LAST_TAG}\033[0m \t Check: ${CHECK} \t \033[31m${MSG}\033[0m"
        echo -e "[{"Group":"${PROJECT_NAMESPACE}","Project":"${PROJECT_NAME}","Gitlab":"${GITLAB_PROJECT_LAST_TAG}","Docker":"${DOCKER_LAST_TAG}","Check":"${CHECK}","debug":"${MSG}"}]"
        cat <<EOF > /root/bash-exporter/examples/${PROJECT_NAME}.sh
#!/bin/sh
echo '{"labels": { \
"group":"${PROJECT_NAMESPACE}",\
"project":"${PROJECT_NAME}",\
"gitlab":"${GITLAB_PROJECT_LAST_TAG}",\
"docker":"${DOCKER_LAST_TAG}",\
"msg":"${MSG}" \
},\
 "results": {"check": ${CHECK}} }'
exit 0
EOF
chmod 755 /root/bash-exporter/examples/${PROJECT_NAME}.sh
    done
done