#!/bin/sh
#resin环境变量
PROJECT_NAME=${PROJECT_NAME:-""}
CMDB_HOST=${CMDB_HOST:-""}
APP_ENV=${APP_ENV:-""}
RESIN_USER=${RESIN_USER:-resin}
RESIN_UID=${RESIN_UID:-500}
RESIN_GID=${RESIN_UID:-500}
JAVA_HOME=/opt/jdk
JVM_ARGS=${JVM_ARGS:--Xms1024M -Xmx1024M -Xmn256M -XX:PermSize=256M -XX:MaxPermSize=512M}
THREAD_MAX=${THREAD_MAX:-1024}
SOCKET_TIMEOUT=${SOCKET_TIMEOUT:-30s}
KEEPALIVED_MAX=${KEEPALIVED_MAX:-512}
KEEPALIVED_TIMEOUT=${KEEPALIVED_TIMEOUT:-60s}
SESSION_MAX=${SESSION_MAX:-1028}
SESSION_TIMEOUT=${SESSION_TIMEOUT:-60}
SHARE_DIR=${SHARE_DIR:-false}
APP_PREFIX=${APP_PREFIX:-/}

if [ "$CMDB_HOST" = "" ];then
    exit 1
elif [ "$PROJECT_NAME" = "" ];then
    exit 1
elif [ "$APP_ENV" = "" ];then
    exit 1
fi

#创建用户
mkdir -p /home/$RESIN_USER
echo "$RESIN_USER:x:$RESIN_UID:$RESIN_GID::/home/$RESIN_USER:/bin/sh" >> /etc/passwd
echo "$RESIN_USER:x:$RESIN_GID:" >> /etc/group
chown $RESIN_USER:$RESIN_USER /home/$RESIN_USER 

#替换resin配置的值
sed -i "/jvm_args  : -Xmx2048m -XX:MaxPermSize=256m/s/-Xmx2048m -XX:MaxPermSize=256m/`echo $JVM_ARGS`/g" /opt/resin/conf/resin.properties

sed -i "/<thread-max>1024<\/thread-max>/s/1024/`echo $THREAD_MAX`/g" /opt/resin/conf/resin.xml

sed -i "/<socket-timeout>30s<\/socket-timeout>/s/30s/`echo $SOCKET_TIMEOUT`/g" /opt/resin/conf/resin.xml

sed -i "/<keepalive-max>512<\/keepalive-max>/s/512/`echo $KEEPALIVED_MAX`/g"  /opt/resin/conf/resin.xml

sed -i "/<keepalive-timeout>60s<\/keepalive-timeout>/s/60s/`echo $KEEPALIVED_TIMEOUT`/g" /opt/resin/conf/resin.xml

sed -i "/<session-max>4096<\/session-max>/s/4096/`echo $SESSION_MAX`/g" /opt/resin/conf/resin.xml

sed -i "/<session-timeout>60<\/session-timeout>/s/60/`echo $SESSION_TIMEOUT`/g" /opt/resin/conf/resin.xml

sed -i "/<web-app id='\/statmgr' root-directory=\"\/data\/jsp\/example.com\/webapps\">/s/\/statmgr/`echo $APP_PREFIX`/g" /opt/resin/conf/resin.xml

sed -i "/root-directory=\"\/data\/jsp\/example.com\/webapps\">/s/example.com/`echo $PROJECT_NAME`/g" /opt/resin/conf/resin.xml

sed -i "/<stdout-log path='\/data\/jsp\/example.com\/logs\/stdout.log' rollover-period='1D'/s/example.com/`echo $PROJECT_NAME`/g" /opt/resin/conf/resin.xml

sed -i "/<stderr-log path='\/data\/jsp\/example.com\/logs\/stderr.log' rollover-period='1D'/s/example.com/`echo $PROJECT_NAME`/g" /opt/resin/conf/resin.xml

sed -i "/<log-handler name=\"\" level=\"all\" path=\"\/data\/jsp\/example.com\/logs\/jvm-default.log\"/s/example.com/`echo $PROJECT_NAME`/g" /opt/resin/conf/resin.xml

sed -i "/<access-log path=\"\/data\/jsp\/example.com\/logs\/access.log\"/s/example.com/`echo $PROJECT_NAME`/g" /opt/resin/conf/cluster-default.xml

#替换application-redis.xml中的host以及port
sed -i "/<constructor-arg name=\"host\" value=\"127.0.0.1\"/s/127.0.0.1/`echo $REDIS_HOST`/g" /opt/webapps/WEB-INF/classes/applicationContext-redis.xml

sed -i "/<constructor-arg name=\"port\" value=\"6379\"/s/6379/`echo $REDIS_PORT`/g" /opt/webapps/WEB-INF/classes/applicationContext-redis.xml


#判断是否需要数据库配置,使用curl获取数据库json格式
database_url=http://${CMDB_HOST}/cmdb/api/service/search/\?env\=${APP_ENV}\&project\=${PROJECT_NAME}\&type\=datasource
curl $database_url > /opt/resin/conf/datasource.log
if [[ `cat /opt/resin/conf/datasource.log | jq-linux64  .code` -eq 0 ]]; then
    i=0
    while [[ "`cat /opt/resin/conf/datasource.log | jq-linux64 .data[${i}]`" != "null" ]]; do
        echo "<database>" >> /opt/resin/conf/database.xml
        echo -e "<jndi-name>`cat /opt/resin/conf/datasource.log | jq-linux64 -r .data[${i}].jndi_name`</jndi-name>" >> /opt/resin/conf/database.xml
        #need pass
        echo -e "<driver type=\"org.gjt.mm.mysql.Driver\">" >> /opt/resin/conf/database.xml
        db_name=`cat /opt/resin/conf/datasource.log | jq-linux64 -r .data[${i}].db_name`
        db_host=`cat /opt/resin/conf/datasource.log | jq-linux64 -r .data[${i}].db_host`
        db_port=`cat /opt/resin/conf/datasource.log | jq-linux64 -r .data[${i}].db_port`
        db_url=jdbc:mysql://${db_host}:${db_port}/${db_name}
        echo -e "<url>`echo ${db_url}`</url>" >> /opt/resin/conf/database.xml
        echo -e "<user>`cat /opt/resin/conf/datasource.log | jq-linux64 -r .data[${i}].db_user`</user>" >> /opt/resin/conf/database.xml
        echo -e "<password>`cat /opt/resin/conf/datasource.log | jq-linux64 -r .data[${i}].db_password`</password>" >> /opt/resin/conf/database.xml
        echo -e "<init-param useUnicode=\"TRUE\"/>" >> /opt/resin/conf/database.xml
        echo -e "<init-param characterEncoding=\"UTF-8\"/>" >> /opt/resin/conf/database.xml
        echo -e "</driver>" >> /opt/resin/conf/database.xml
        echo -e "<max-connections>`cat /opt/resin/conf/datasource.log | jq-linux64 -r .data[${i}].connection_pool_size`</max-connections>" >> /opt/resin/conf/database.xml
        echo -e "<max-idle-time>`cat /opt/resin/conf/datasource.log | jq-linux64 -r .data[${i}].idle_timeout`</max-idle-time>" >> /opt/resin/conf/database.xml
        #need pass
        echo -e "<connection-wait-time>5s</connection-wait-time>" >> /opt/resin/conf/database.xml
        echo -e "<max-active-time>`cat /opt/resin/conf/datasource.log | jq-linux64 -r .data[${i}].max_active_time`</max-active-time>" >> /opt/resin/conf/database.xml
        echo -e "<max-overflow-connections>`cat /opt/resin/conf/datasource.log | jq-linux64 -r .data[${i}].overflow_connections`</max-overflow-connections>" >> /opt/resin/conf/database.xml
        #need pass
        echo -e "<prepared-statement-cache-size>2048</prepared-statement-cache-size>" >> /opt/resin/conf/database.xml
        echo -e "</database>" >> /opt/resin/conf/database.xml
        let "i++";
    done
    sed -i "/<\!\-\-database-config\-\->/r /opt/resin/conf/database.xml" /opt/resin/conf/resin.xml
fi


#执行研发自定义脚本
scripts=/opt/scripts/scripts.sh
if [ -f "$scripts" ]; then
    sh /opt/scripts/scripts.sh
fi


#挂载ceph文件系统并将日志写入
ceph_url=http://${CMDB_HOST}/cmdb/api/service/search/\?env\=${CEPH_ENV}\&project\=${CEPH_PROJECT}\&type\=ceph
curl ${ceph_url} > /opt/resin/conf/ceph.log
if [[ `cat /opt/resin/conf/ceph.log | jq-linux64 .code` -eq 0 ]]; then
    key=`cat /opt/resin/conf/ceph.log | jq-linux64 -r .data[0].other_param | jq-linux64 -r .CEPH_AUTH_KEY`
    echo -e "[client.admin]" > /etc/ceph/ceph.client.admin.keyring
    echo -e "\tkey = `echo ${key}`" >> /etc/ceph/ceph.client.admin.keyring
else
    echo "Please set the ceph configurations!!!"
    exit 1
fi
CEPH_MON=`cat /opt/resin/conf/ceph.log | jq-linux64 -r .data[0].ip_address`:`cat /opt/resin/conf/ceph.log | jq-linux64 -r .data[0].port`
/usr/local/ceph/bin/ceph-fuse -k /etc/ceph/ceph.client.admin.keyring -m $CEPH_MON /mnt/cephfs


#程序和日志路径创建,程序必须放到/opt/webapps
#获取宿主机ip以及端口(HOST,PORT_8080)
host_ip=`dig $HOST +short`
su - $RESIN_USER -c "mkdir -p /data/jsp/$PROJECT_NAME"
chown $RESIN_USER:$RESIN_USER /opt/webapps -R
chown $RESIN_USER:$RESIN_USER /opt/resin -R
ln -s /opt/webapps /data/jsp/$PROJECT_NAME/webapps
log_dir=/mnt/cephfs/data/$PROJECT_NAME/$APP_ENV/logs/$host_ip"_"${PORT_8080}

if [ ! -d "$log_dir" ];then 
    su - $RESIN_USER -c "mkdir -p $log_dir"    
fi

logs_dir=/data/jsp/$PROJECT_NAME/logs
if [ ! -L "$logs_dir" ]; then
    ln -s $log_dir $logs_dir
fi

 

#是否需要共享目录
if [ "$SHARE_DIR" = "true" ]; then

    share_dir=/mnt/cephfs/data/$PROJECT_NAME/$APP_ENV/data
    if [ ! -d "$share_dir" ]; then
        su - $RESIN_USER -c "mkdir -p $share_dir"
    fi

    shares_dir=/opt/webapps/data
    if [[ ! -L "shares_dir" ]]; then
        ln -s  $share_dir  /opt/webapps/data
    fi
    
fi

su $RESIN_USER -c "/opt/resin/bin/resin.sh console"

