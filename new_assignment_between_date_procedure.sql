create or replace NONEDITIONABLE PROCEDURE new_assignment_between_date (
            assignment_date			date,
            new_assignment_name varchar
            )
            IS
            not_serializable		EXCEPTION;
            PRAGMA EXCEPTION_INIT(not_serializable,-8177);
            deadlock			EXCEPTION;
            PRAGMA EXCEPTION_INIT(deadlock,-60);
            snapshot_too_old		EXCEPTION;
            PRAGMA EXCEPTION_INIT(snapshot_too_old,-1555);
            integrity_viol			EXCEPTION;
            PRAGMA EXCEPTION_INIT(integrity_viol,-1);
            enrollment_assignment_id INTEGER;
            max_assignment_id  INTEGER;
            random_date varchar(300);
            new_assignment_enrollment_id INTEGER;
            max_enrollment_id INTEGER;
            enrollment_ids   SYS_REFCURSOR;
            final_grade float;
            
            
            BEGIN
                select max(enrollment_id) into max_enrollment_id from enrollments;
                SELECT ROUND(DBMS_RANDOM.value(1, max_enrollment_id)) INTO enrollment_assignment_id FROM dual;
             
                OPEN enrollment_ids FOR
                select enrollment_id
                FROM enrollments
                where course_id = (SELECT course_id
                    FROM enrollments
                    where enrollment_id = enrollment_assignment_id);
                  
                
                select max(assignment_id) into max_assignment_id from assignments;
                loop
                    SELECT TO_CHAR(TO_DATE(assignment_date, 'YYYY-MM-DD HH24:MI:SS') + DBMS_RANDOM.value(0, 7), 'YYYY-MM-DD HH24:MI:SS') into random_date FROM dual;
                    SELECT ROUND(DBMS_RANDOM.VALUE(0, 5), 2) AS random_float into final_grade FROM DUAL;
                    max_assignment_id := max_assignment_id + 1;
                    FETCH enrollment_ids INTO new_assignment_enrollment_id;
                    EXIT WHEN enrollment_ids%NOTFOUND;
                    INSERT INTO Assignments (assignment_id, assignment_name, enrollment_id, assignment_date,grade ) 
                    VALUES (max_assignment_id, new_assignment_name, new_assignment_enrollment_id,to_date( random_date,'YYYY-MM-DD HH24:MI:SS'),final_grade);
                end loop;

                    
            COMMIT;
            EXCEPTION WHEN not_serializable OR deadlock OR snapshot_too_old THEN
            ROLLBACK;
        
        END;