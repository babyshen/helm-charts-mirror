#!/bin/bash
set -e
# variables
URL="https://kubernetes-charts.storage.googleapis.com"
START_TIME=$(date +%s)
FLAG=0

today(){
   date +%F
}

log(){
  echo -n "[$(date +'%F %H:%M:%S')] "
  echo $@
}

download_chart(){
  #set -x
  local CHART_DIGEST=$(cat chart-list.json|jq -r ".|select(.url==\"$line\")|.digest")
  local CURRENT_TIME=$(date +%s)
  local SPEND_TIME=$[${CURRENT_TIME}-${START_TIME}]
  local TIME_INTERVAL=$[${SPEND_TIME}%10]
  local COMMIT_INTERVAL=$[${SPEND_TIME}%300]
  
  if ls ${line##*/} &> /dev/null;then
    local CURRENT_DIGEST=$(sha256sum ${line##*/}|awk '{print $1}')
  fi

  until [[ ${CHART_DIGEST} == ${CURRENT_DIGEST} ]];do
    curl -sSLo ${line##*/} $line && local CURRENT_DIGEST=$(sha256sum ${line##*/}|awk '{print $1}')
    FLAG=1
  done
  
  if [ $FLAG -eq 1 ];then
    log "${line##*/} update done."
    FLAG=0
  fi
  
  echo $line > last_install
  
  if [ $TIME_INTERVAL -eq 0 ];then
    log "spend time is: $SPEND_TIME"
  fi
  
  if [ $COMMIT_INTERVAL -eq 0 ] ;then
    git_commit
  fi
  #set +x
}

get_chart(){
  mkfifo fifofile
  exec 1000<> fifofile
  rm fifofile
  
  # 4 processor
  seq 1 4 1>& 1000
  while read line;do
    read -u 1000
    {
      download_chart
      echo >& 1000
    } &
  done < /tmp/chart-tgz-list.log
  wait

  exec 1000>&-
  exec 1000<&-
}

set_git(){
  git config --global user.name "babyshen"
  git config --global user.email "455416841@qq.com"
}

checkout_branch(){
    git remote rm origin
    git remote add origin git@github.com:babyshen/helm-charts-mirror.git
    git fetch --all
    if git branch -a|grep 'gh-pages' &> /dev/null;then
      git checkout gh-pages
      git pull
      git branch --set-upstream-to=origin/gh-pages gh-pages
    else
      git checkout -b gh-pages
      git pull
    fi
}

git_commit(){
     local COMMIT_FILES_COUNT=$(git status -s|wc -l)
     local TODAY=$(today)
     if [ $COMMIT_FILES_COUNT -ne 0 ];then
        git pull
        git add -A
        git commit -m "Synchronizing completion at $TODAY"
        git push -u origin gh-pages
     fi
}

get_new_index() {
  curl -SLO https://kubernetes-charts.storage.googleapis.com/index.yaml
}

get_digest(){
  cat index.yaml |yq .|jq '.entries| .[]' > index.json
  cat  index.json |jq '.|.[]| {name: .name,version: .version,digest: .digest,url: .urls[]}' > chart-list.json
  rm index.json
}

get_new_tgz_file() {
  grep -o "${URL}/.*.tgz" index.yaml > /tmp/chart-tgz-list.log
  get_chart
}

clean_temp() {
  rm /tmp/chart*
}


main() {
  set_git
  checkout_branch
  get_new_index
  get_digest
  get_new_tgz_file
  git_commit
  clean_temp
}

main
