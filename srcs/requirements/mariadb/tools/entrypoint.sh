#!/bin/bash
set -e

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "First run: setting up the database..."

    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --auth-root-authentication-method=normal > /dev/null

    mariadbd --user=mysql &
    pid="$!"

    until mysqladmin ping --silent 2>/dev/null; do
        sleep 1
    done

    mysql -u root <<-EOSQL
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
        FLUSH PRIVILEGES;
EOSQL

    mysqladmin -u root -p"${DB_ROOT_PASSWORD}" shutdown
    wait "$pid"
fi

exec mariadbd --user=mysql
#!/bin/bash
set -e

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "First run: setting up the database..."

    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --auth-root-authentication-method=normal > /dev/null

    mariadbd --user=mysql &
    pid="$!"

    until mysqladmin ping --silent 2>/dev/null; do
        sleep 1
    done

    mysql -u root <<-EOSQL
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
        FLUSH PRIVILEGES;
EOSQL

    mysqladmin -u root -p"${DB_ROOT_PASSWORD}" shutdown
    wait "$pid"
fi

exec mariadbd --user=mysql
