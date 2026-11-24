# Same MariaDB version and flags as frappe_docker/pwd.yml.
# Data lives in a subfolder of the Render disk (the disk root has lost+found).
FROM mariadb:11.8
CMD ["mariadbd", \
     "--datadir=/var/lib/mysql/data", \
     "--character-set-server=utf8mb4", \
     "--collation-server=utf8mb4_unicode_ci", \
     "--skip-character-set-client-handshake", \
     "--innodb-snapshot-isolation=OFF"]
