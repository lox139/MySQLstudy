#!/bin/bash
###################################
#auto intall mysql7 for centos7
#created by 玄真  2020/05/10
####################################

groupadd mysql
useradd -r -g mysql -s /bin/false mysql

yum install -y wget libaio numactl

version=$1
if [ -z "$1" ];then
    version="5.7.30"
fi
echo $version
basedir="/usr/local"
cd /usr/local
wget "https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-community-client-$version-1.el7.x86_64.rpm"
wget "https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-community-common-$version-1.el7.x86_64.rpm"
wget "https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-community-libs-compat-$version-1.el7.x86_64.rpm"
wget "https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-community-libs-$version-1.el7.x86_64.rpm"
wget "https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-$version-el7-x86_64.tar.gz"

rpm -ivh "mysql-community-common-$version-1.el7.x86_64.rpm"
rpm -ivh "mysql-community-libs-$version-1.el7.x86_64.rpm"
rpm -ivh "mysql-community-libs-compat-$version-1.el7.x86_64.rpm"
rpm -ivh "mysql-community-client-$version-1.el7.x86_64.rpm"



tar xzvf "mysql-$version-el7-x86_64.tar.gz"
ln -snf "mysql-$version-el7-x86_64" mysql
wget -P /usr/local/mysql/support-files http://mirrors.66boc.com/linux/mysql/my7.cnf
cp mysql/support-files/my7.cnf /etc/my.cnf
cd /etc
chown root:root my.cnf
chmod 644 my.cnf
datadir=$(cat my.cnf | grep datadir | awk -F'=' '{ print $2 }' | sed s/[[:space:]]//g)
logdir=$(cat my.cnf | grep innodb_log_group_home_dir | awk -F'=' '{ print $2 }' | sed s/[[:space:]]//g)
secure_file_priv=$(cat my.cnf | grep secure_file_priv | awk -F'=' '{ print $2 }' | sed s/[[:space:]]//g)
mkdir -p $datadir $logdir $secure_file_priv
chmod 750 $datadir $logdir $secure_file_priv
chown -R mysql:mysql $datadir
chown -R mysql:mysql $logdir
chown -R mysql:mysql $secure_file_priv 

cores=$(cat /proc/cpuinfo| grep "processor"| wc -l)
hfcores=`expr $cores / 2`
mem_total=`free | awk '/Mem/ {print $2}'`

#5.7.25以下的版本使用innodb_flush_method=O_DIRECT
lver=${version##*.}
if [ $lver -lt 25 ];then
    innodb_flush_method=$(cat my.cnf | grep innodb_flush_method)
    sed -i "s/$innodb_flush_method/innodb_flush_method=O_DIRECT/"  my.cnf
fi
#根据cpu核数和内存大小调整部分参数
innodb_write_io_threads=$(cat my.cnf | grep innodb_write_io_threads)
sed -i "s/$innodb_write_io_threads/innodb_write_io_threads=$cores/"  my.cnf

innodb_read_io_threads=$(cat my.cnf | grep innodb_read_io_threads)
sed -i "s/$innodb_read_io_threads/innodb_read_io_threads=$cores/"  my.cnf

slave_parallel_workers=$(cat my.cnf | grep slave-parallel-workers)
sed -i "s/$slave_parallel_workers/slave-parallel-workers=$cores/"  my.cnf

innodb_purge_threads=$(cat my.cnf | grep innodb_purge_threads)
sed -i "s/$innodb_purge_threads/innodb_purge_threads=$hfcores/"  my.cnf

innodb_page_cleaners=$(cat my.cnf | grep innodb_page_cleaners)
sed -i "s/$innodb_page_cleaners/innodb_page_cleaners=$hfcores/"  my.cnf

innodb_buffer_pool_size=$(cat my.cnf | grep innodb_buffer_pool_size)
ibpzvalue=$[$mem_total * 7 / 10  / 1024 / 1024 + 1]
sed -i "s/$innodb_buffer_pool_size/innodb_buffer_pool_size=$ibpzvalue/"  my.cnf

cd /usr/local/mysql
bin/mysqld --defaults-file=/etc/my.cnf --initialize
wget -P /usr/local/mysql/support-files http://mirrors.66boc.com/linux/mysql/mysqld7.service
mv /usr/local/mysql/support-files/mysqld7.service /etc/systemd/system/mysqld.service
cd /etc/systemd/system
chmod 644 mysqld.service
cd /usr/lib/tmpfiles.d
touch mysql.conf
chmod 644 mysql.conf
echo "d $datadir 0750 mysql mysql -" > mysql.conf
systemctl enable mysqld.service
systemctl start mysqld
systemctl status mysqld