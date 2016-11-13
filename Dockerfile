# IBM Spectrum LSF Community Edition 10.1
#
# VERSION 0.1
#
# set base image
FROM centos:6.8

MAINTAINER XiaoLiang Hu <xlhuxa@cn.ibm.com>

# set package name
ENV LSF=lsfce10.1-x86_64.tar.gz PAC=pac10.1_basic_linux-x64.tar.Z PMPI=pmpi-09.01.02.00u.tar.gz

# install required packages
Run yum -q clean all \
    && yum -y -q install ed \
                         initscripts \
                         lsof \
                         sysstat \
                         gettext \
                         mysql \
                         openssh-server \
                         openssh-clients \
                         wget \
                         mysql-connector-java \

# copy LSF packages
    && echo "down load LSF CE package..." \
    && wget -P /var/lsfce 9.111.250.208/$LSF 2>/dev/null \
    && wget -P /var/lsfce 9.111.250.208/$PMPI 2>/dev/null \
    && wget -P /var/lsfce 9.111.250.208/start_lsf_ce.sh 2>/dev/null \
    && echo "LSF CE package is saved." \

# create lsfadmin user and set password to lsfadmin
    && useradd -s /bin/bash -m lsfadmin \
    && echo "lsfadmin:lsfadmin" | chpasswd \

# uncompress package 
    && cd /var/lsfce \
    && tar xzf $LSF \
    && tar xzf lsfce10.1-x86_64/lsf/lsf10.1_lsfinstall_linux_x86_64.tar.Z -C /var/lsfce/lsfce10.1-x86_64/lsf \
    && tar xzf lsfce10.1-x86_64/pac/$PAC -C /var/lsfce/lsfce10.1-x86_64/pac \

# prepare LSF install configuration file
    && cd /var/lsfce/lsfce10.1-x86_64/lsf/lsf10.1_lsfinstall \
    && echo "LSF_TOP=/opt/ibm/lsf" >> install.config \
    && echo "LSF_ADMINS=lsfadmin" >> install.config \
    && echo "LSF_CLUSTER_NAME=cluster1" >> install.config \
    && echo "LSF_MASTER_LIST=`hostname`" >> install.config \
    && echo "LSF_TARDIR=/var/lsfce/lsfce10.1-x86_64/lsf" >> install.config \
    && echo "ENABLE_STREAM=Y" >> install.config \ 
    && echo "SILENT_INSTALL=Y" >> install.config \
    && echo "LSF_SILENT_INSTALL_TARLIST=ALL" >> install.config \
    && echo "LSF_DYNAMIC_HOST_WAIT_TIME=1" >> install.config \
    && echo "ENABLE_DYNAMIC_HOSTS=Y" >> install.config \

# install LSF
    && echo "start install LSF..." \
    && ./lsfinstall -f install.config \
    && source /opt/ibm/lsf/conf/profile.lsf \
    && lsadmin limstartup \
    && lsadmin resstartup \
    && badmin hstartup \
    && echo "LSF installation has successfully completed." \

# prepare PAC install configuration file
    && cd /var/lsfce/lsfce10.1-x86_64/pac/pac10.1_basic_linux-x64 \
    && sed -i '/export PAC_TOP=/a\export PAC_TOP="/opt/ibm/pac"' pacinstall.sh \
    && sed -i '/export USE_REMOTE_DB=/a\export USE_REMOTE_DB="Y"' pacinstall.sh \
    && sed -i '/export MYSQL_JDBC_DRIVER_JAR=/a\export MYSQL_JDBC_DRIVER_JAR="/usr/share/java/mysql-connector-java.jar"' pacinstall.sh \
    && sed -i 's/4096/2048/g' pacinstall.sh \
    && export USER=`whoami` \
    && export USE_REMOTE_DB="Y" \

# install PAC
    && echo "start install PAC..." \
    && ./pacinstall.sh -s -y \
    && echo "PAC installation has successfully completed." \

# install MPI install
    && echo "start install PMPI..." \
    && cd /var/lsfce/ \
    && tar zxf $PMPI -C /opt/ibm/ \
    && echo "PMPI installation has successfully completed." \

# clean up package
    && mv /var/lsfce/start_lsf_ce.sh / \
    && chmod +x /start_lsf_ce.sh \
    && rm -rf /opt/ibm/lsf/work/cluster1/logdir/#lsb.event.lock \
    && rm -rf /var/lsfce \
    && rm -rf /opt/ibm/lsf/10.1/install \
    && rm -rf /opt/ibm/lsf/log/* \
    && rm -rf /opt/ibm/pac/install.log \
    && rm -rf /opt/ibm/pac/gui/logs/* \
    && rm -rf /opt/ibm/pac/perf/logs/* \
    && rm -rf /tmp/*

# Expose ports
EXPOSE 7869/udp 7869 6878 6881 6882 22 8080

ENTRYPOINT ["/start_lsf_ce.sh"]
