alter session set "_ORACLE_SCRIPT"=true;
create user intro_user IDENTIFIED BY admins;
grant create session to intro_user;
grant create any table to intro_user;
grant delete any table to intro_user;
grant alter any table to intro_user;
grant view to intro_user;
