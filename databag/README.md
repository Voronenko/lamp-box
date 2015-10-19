all subfolders with sql inside will be imported into vagrant mysql db

Naming convention:
DB_NAME/any_file_with_extension.sql

the most recent sql file will be imported into DB_NAME with collation utf8_general_ci

Upon import, flag file called .nodbs  will be created to prevent database overrides on next provision run
