--el tablespace se administra con monitoreo, no definicion previa
--pool
ALTER SYSTEM SET shared_pool_size = 1G;
ALTER SYSTEM SET db_cache_size = 2G;

--paralelismo
ALTER SYSTEM SET parallel_max_servers = 16;
ALTER SYSTEM SET parallel_threads_per_cpu = 2;

--logs
ALTER DATABASE ADD LOGFILE GROUP 4 ('/u01/oracle/redo04.log') SIZE 100M;
ALTER DATABASE DROP LOGFILE GROUP 1;

--modo de optmizador
ALTER SYSTEM SET optimizer_mode = 'ALL_ROWS';
EXEC DBMS_STATS.GATHER_DATABASE_STATS();

--tamaño de archivo de recuperacion
ALTER SYSTEM SET db_recovery_file_dest_size = '10G';

--rutina anual borrar logs antiguos de hace un año

CREATE OR REPLACE PROCEDURE eliminar_redo_logs_antiguos IS
BEGIN
  FOR log_file IN (
    SELECT 'ALTER DATABASE DROP LOGFILE GROUP ' || GROUP# || ';' AS SQL_statement
    FROM V$LOG
    WHERE FIRST_TIME < SYSDATE - INTERVAL '1' YEAR
  ) LOOP
    EXECUTE IMMEDIATE log_file.SQL_statement;
  END LOOP;
END eliminar_redo_logs_antiguos;
/
