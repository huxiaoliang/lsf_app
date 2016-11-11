#!/bin/bash

function init_log()
{
    LOGFILE="$1"
    if [ ! -e "$LOGFILE" ];then
        touch "$LOGFILE"
        if [ $? != 0 ];then
            echo "ERROR: failed to initial logging. can't create log file $LOGFILE"
        fi
    fi
}

function init_share_dir()
{
    # share the conf/work dir for recover
    mkdir -p $HOME_DIR/lsf/conf
    mkdir -p $HOME_DIR/lsf/work
    mkdir -p $HOME_DIR/mariadb
    mkdir -p $HOME_DIR/tools
    if [ "$ROLE" = "master" ]; then
        # delete duplicate host
        sed -i "/\b$MYHOST\b/d" $HOME_DIR/lsf/conf/hosts
        cat /etc/hosts |grep $MYHOST >> $HOME_DIR/lsf/conf/hosts
        if [ ! -d $HOME_DIR/lsf/work/cluster1 ]; then
            cp -arp $LSF_TOP/conf/* $HOME_DIR/lsf/conf
            cp -arp $LSF_TOP/work/* $HOME_DIR/lsf/work
        fi
        rm -rf $LSF_TOP/conf/ && ln -s $HOME_DIR/lsf/conf/ /$LSF_TOP/
        rm -rf $LSF_TOP/work/ && ln -s $HOME_DIR/lsf/work/ /$LSF_TOP/
    else
        # update master hostname
        sed -i "s/$MYHOST/$LSF_MASTER_LIST/g" $LSF_TOP/conf/lsf.cluster.cluster1
        sed -i "s/$MYHOST/$LSF_MASTER_LIST/g" $LSF_TOP/conf/ego/cluster1/kernel/ego.conf
        sed -i "s/$MYHOST/$LSF_MASTER_LIST/g" $LSF_TOP/conf/lsf.conf
        while true; do
             
            if [ ! -e $HOME_DIR/lsf/conf/hosts ];then
                sleep 2
                log_info "waiting for lsf master service startup ..."
            else
                break
            fi
        done
        # delete duplicate host
        sed -i "/\b`hostname -i`\b/d" $HOME_DIR/lsf/conf/hosts
        cat /etc/hosts |grep $MYHOST >> $HOME_DIR/lsf/conf/hosts
        ln -s $HOME_DIR/lsf/conf/hosts $LSF_TOP/conf/hosts
    fi
}

function log()
{
    echo `date` "$@" | tee -a "$LOGFILE"
}

function log_info()
{
    log "INFO:" "$@"
}

function log_error()
{
    log "ERROR:" "$@"
}

function log_warn()
{
    log "WARN:" "$@"
}

function init_database()
{
    while true; do
        </dev/tcp/127.0.0.1/3306 && break
        sleep 3
        log_info "waiting for maria database service startup ..."
    done
    (
cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<ds:DataSources xmlns:ds="http://www.ibm.com/perf/2006/01/datasource" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xsi:schemaLocation="http://www.ibm.com/perf/2006/01/datasource datasource.xsd">
   <ds:DataSource Name="ReportDB"
        Driver="org.gjt.mm.mysql.Driver"
        Connection="jdbc:mysql://127.0.0.1:3306/pac"
        Default="true"
        Cipher="des56"
        UserName="uOTzmooF4Qw="
        Password="uOTzmooF4Qw=">
        <ds:Properties>
            <ds:Property>
                <ds:Name>maxActive</ds:Name>
                <ds:Value>30</ds:Value>
            </ds:Property>
        </ds:Properties>
   </ds:DataSource>
</ds:DataSources>
EOF
    ) > $PAC_TOP/perf/conf/datasource.xml
    log_info "check whether database already exists."
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -D$DB_NAME -h127.0.0.1 -e "select count(1) from PMC_USER;"
    if [ $? -eq 0 ]; then
        log_info "pac database already exists."
        return
    fi
    log_info "creating MYSQL database for Platform Application Center"
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -e "create database if not exists $DB_NAME default character set utf8 default collate utf8_bin;"
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -e "GRANT ALL ON $DB_NAME.* TO pacuser@127.0.0.1 IDENTIFIED BY 'pacuser';"
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/perf/lsf/10.0/DBschema/MySQL/lsf_sql.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/perf/ego/1.2/DBschema/MySQL/egodata.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/perf/lsf/10.0/DBschema/MySQL/lsfdata.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/gui/DBschema/MySQL/create_schema.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/gui/DBschema/MySQL/create_pac_schema.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/gui/DBschema/MySQL/init.sql
    log_info "MYSQL database for Platform Application Center is created."
}

function start_lsf()
{
    log_info "Start LSF services on $ROLE host $MYHOST..."
    source $LSF_TOP/conf/profile.lsf
    lsadmin limstartup >>$LOGFILE 2>&1
    lsadmin resstartup >>$LOGFILE 2>&1
    badmin hstartup >>$LOGFILE 2>&1
    log_info "LSF services on $ROLE host $MYHOST started."
}

function start_pac()
{
    log_info "Start PAC services on $ROLE host $MYHOST..."
    source  $PAC_TOP/profile.platform
    perfadmin start all >>$LOGFILE 2>&1
    pmcadmin start >>$LOGFILE 2>&1
}

function generate_lock()
{
    log_info "generate lock file."
    echo 1 > $LOCKFILE
}

function config_lsfce()
{
    # the host name from base image
    IMAGE_HOST=`awk -F'"' '/MASTER_LIST/ {print $(NF-1)}' $LSF_TOP/conf/lsf.conf`

    find $LSF_TOP/work/cluster1/logdir \
        $LSF_TOP/conf \
        $PAC_TOP/gui/conf \
        $PAC_TOP/perf/conf \
        $PAC_TOP/rule-engine/conf/rule-engine-config.xml \
    -type f -print0 | xargs -0 sed -i "s/$IMAGE_HOST/$MYHOST/g"

    # make lsf read hosts file when new hosts added to cluster
    echo "LSF_HOST_CACHE_NTTL=0" >> $LSF_TOP/conf/lsf.conf
    echo "LSF_DHCP_ENV=y" >> $LSF_TOP/conf/lsf.conf
    echo "LSF_HOST_CACHE_DISABLE=y" >> $LSF_TOP/conf/lsf.conf
    echo "LSF_DYNAMIC_HOST_TIMEOUT=10m" >> $LSF_TOP/conf/lsf.conf
    # enable floating client
    sed -i "/# FLOAT_CLIENTS_ADDR_RANGE=/a\FLOAT_CLIENTS_ADDR_RANGE=*.*.*.*" $LSF_TOP/conf/lsf.cluster.cluster1
    sed -i "/# FLOAT_CLIENTS=/a\FLOAT_CLIENTS=10" $LSF_TOP/conf/lsf.cluster.cluster1
}

###############################  main  ############################################

############## CMD parameter from docker run ##########
#lsf master or slave
ROLE=$1

# db root password
MYSQL_PASSWORD=$2

#lsf master host name
LSF_MASTER_LIST=$3

log_info "CMD parameter: ROLE=$1 MYSQL_PASSWORD=$2 LSF_MASTER_LIST=$3"

#######################################

MYHOST=`uname -n`
HOME_DIR="/home/lsfadmin"
LSF_TOP="/opt/ibm/lsf"
PAC_TOP="/opt/ibm/pac"
LOGFILE="/tmp/start_lsf_ce_$MYHOST.log"
LOCKFILE="$LSF_TOP/lsf_ce_$MYHOST.lock"
DB_NAME="pac"



if [ -f "$LOCKFILE" ]; then
    log_info "lock file exists in $LOCKFILE, just start LSF service."
else
    init_log $LOGFILE
    config_lsfce
    if [ "$ROLE" = "master" ]; then
        init_database
    fi
    init_share_dir
fi

start_lsf

if [ "$ROLE" = "master" ]; then
    start_pac
fi

generate_lock


# hang here now
while true; do
    if test $(pgrep -f lim | wc -l) -eq 0
    then
        log_error "LIM process has exited due to a fatal error."
        log_error `tail -n 20 $LSF_TOP/log/lim.log.*`
        exit 1
    else
        log_info "LSF is running -:) ..."
    fi
    sleep 600
done
