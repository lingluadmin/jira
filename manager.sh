#!/bin/bash

set -e

__root_path=$(cd $(dirname $0); pwd -P)
devops_prj_path="$__root_path/devops"
source $devops_prj_path/base.sh

mysql_image=mysql:5.5
jira_image=cptactionhank/atlassian-jira:7.2.3
confluence_image=cptactionhank/atlassian-confluence:6.0.2

data_path='/opt/data/atlassian'

jira_container=jira
confluence_container=jira-confluence
mysql_container=jira-mysql

run_mysql() {
    args="--restart always"

    args="$args -v $data_path/mysql-data:/var/lib/mysql"

    # auto import data
    args="$args -v $__root_path/data/mysql-init:/docker-entrypoint-initdb.d/"

    # config
    args="$args -v $__root_path/config/mysql/conf/:/etc/mysql/conf.d/"

    # do not use password
    args="$args -e MYSQL_ROOT_PASSWORD='' -e MYSQL_ALLOW_EMPTY_PASSWORD='yes'"
    run_cmd "docker run -d $args --name $mysql_container $mysql_image"
    _wait_mysql
}

_wait_mysql() {
    local cmd="while ! mysqladmin ping -h 127.0.0.1 --silent; do sleep 1; done"
    _run_mysql_command_in_client "$cmd"
}

_run_mysql_command_in_client() {
    local cmd=$1
    run_cmd "docker exec $docker_run_fg_mode $mysql_container bash -c '$cmd'"
}

to_mysql() {
    local cmd="mysql -h 127.0.0.1 -P 3306 -u root -p"
    run_cmd "docker exec $docker_run_fg_mode $mysql_container bash -c '$cmd'"
}

stop_mysql() {
    stop_container $mysql_container
}

restart_mysql() {
    stop_mysql
    run_mysql
}

run_jira() {

    local jira_home_path="$data_path/jira-home"
    local args="--restart always"
    args="$args -p 11280:8081"

    args="$args --user root:root"

    # link to mysql
    args="$args --link $mysql_container"

    # mount home
    args="$args -v $jira_home_path:/var/atlassian/jira"
    
    args="$args -v $__root_path/data/jira/server.xml:/opt/atlassian/jira/conf/server.xml"

    # mount crack jar
    args="$args -v $__root_path/data/jira/atlassian-extras-3.1.2.jar:/opt/atlassian/jira/atlassian-jira/WEB-INF/lib/atlassian-extras-3.1.2.jar"
    run_cmd "docker run -d $args --name $jira_container $jira_image"
}

to_jira() {
    run_cmd "docker exec $docker_run_fg_mode $jira_container bash"
}

stop_jira() {
    stop_container $jira_container
}

restart_jira() {
    stop_jira
    run_jira
}

build_confluence() {
    run_cmd "docker pull $confluence_image"
}

run_confluence() {
    local confluence_home_path="$data_path/confluence-home"
    local args="--restart always"
    args="$args -p 11290:8090"

    args="$args --user root:root"

    # link to mysql
    args="$args --link $mysql_container"
    args="$args --link $jira_container"

    # mouth home
    args="$args -v $confluence_home_path:/var/atlassian/confluence"
    
    # mount crack jar
    args="$args -v $__root_path/data/confluence/atlassian-extras-decoder-v2-3.2.jar:/opt/atlassian/confluence/confluence/WEB-INF/lib/atlassian-extras-decoder-v2-3.2.jar"

    run_cmd "docker run -d $args --name $confluence_container $confluence_image"
}

to_confluence() {
    local args=""
    run_cmd "docker exec $docker_run_fg_mode $args $confluence_container bash"
}

stop_confluence() {
    stop_container "$confluence_container"
}

restart_confluence() {
    stop_confluence
    run_confluence
}

run() {
    run_mysql
    run_jira
    run_confluence
}

stop() {
    stop_confluence
    stop_jira
    stop_mysql
}

restart() {
    stop
    run
}

help() {
	cat <<-EOF
    Usage: mamanger.sh [options]

    Valid options are:

        run
        stop
        restart

        run_mysql
        stop_mysql
        restart_mysql
        to_mysql

        run_jira
        to_jira
        stop_jira
        restart_jira

        run_confluence
        to_confluence
        stop_confluence
        restart_confluence

        -h                      show this help message and exit
EOF
}


ALL_COMMANDS="run stop restart"
ALL_COMMANDS="$ALL_COMMANDS run_mysql stop_mysql to_mysql restart_mysql"
ALL_COMMANDS="$ALL_COMMANDS run_jira stop_jira to_jira restart_jira"
ALL_COMMANDS="$ALL_COMMANDS run_confluence stop_container to_confluence restart_confluence"
list_contains ALL_COMMANDS "$action" || action=help
$action "$@"
