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

--------------------------------------------------------------------------------------------------

create or replace NONEDITIONABLE PROCEDURE new_student (
            new_student_name			varchar,
            new_email     varchar,
            new_phone  varchar
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
            max_student_id INTEGER;
            max_course_id INTEGER;
            range_min_course_id INTEGER;
            range_max_course_id INTEGER;
            new_enrollments_student_courses   SYS_REFCURSOR;
            max_enrollment_id INTEGER;
            course_to_student INTEGER;
            
            BEGIN
            
                select max(student_id) into max_student_id from students;
                max_student_id := max_student_id +1;
                INSERT INTO students (student_id, student_name, email, phone_number ) 
                    VALUES (max_student_id, new_student_name, new_email, new_phone);
                
                select max(course_id) into max_course_id from courses;
                SELECT ROUND(DBMS_RANDOM.value(1, max_course_id)) INTO range_min_course_id FROM dual;
                SELECT ROUND(DBMS_RANDOM.value(range_min_course_id, max_course_id)) INTO range_max_course_id FROM dual;
                
                OPEN new_enrollments_student_courses FOR
                select course_id from(
                select course_id, count(student_id) cant_students
                from enrollments
                where course_id between range_min_course_id and range_max_course_id
                group by course_id
                order by cant_students asc
                fetch  first 5 rows only);
                
                
                select max(enrollment_id) into max_enrollment_id from enrollments;
                loop
                    max_enrollment_id := max_enrollment_id +1;
                    FETCH new_enrollments_student_courses INTO course_to_student;
                    EXIT WHEN new_enrollments_student_courses%NOTFOUND;
                    INSERT INTO enrollments (enrollment_id, student_id, course_id ) 
                    VALUES (max_enrollment_id, max_student_id,course_to_student);
                end loop;

                    
            COMMIT;
            EXCEPTION WHEN not_serializable OR deadlock OR snapshot_too_old THEN
            ROLLBACK;
        
        END; 

--------------------------------------------------------------------------------------------------
#Verificar un assignment al azar y ver si perdio la materia y si lo hizo crear un nuevo assignment y asignarselo.

create or replace NONEDITIONABLE PROCEDURE extra_homework (
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
            max_assignment_id  INTEGER;
            select_assignment_id INTEGER;
            random_date varchar(300);
            new_assignment_enrollment_id INTEGER;
            enrollment_ids   SYS_REFCURSOR;
            final_grade float;
            
            
            BEGIN
                select max(assignment_id) into max_assignment_id from assignments;
                SELECT ROUND(DBMS_RANDOM.value(1, max_assignment_id)) INTO select_assignment_id FROM dual;
             
                OPEN enrollment_ids FOR
                select enrollment_id
                from assignments
                where assignment_name = (
                    select assignment_name
                    from assignments
                    where assignment_id = select_assignment_id) 
                and  grade < 2.95;
             
                  
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
        
        BEGIN extra_homework(to_date( '2024-03-02','YYYY-MM-DD HH24:MI:SS'), 'parcial100'); END;
        
-----------------------------------------------------------------------------------

create or replace NONEDITIONABLE PROCEDURE new_teacher_and_enrollment_course_and_students (
           
            new_teacher_name			varchar,
            new_email     varchar,
            new_phone  varchar,
            name_filter  varchar
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
            max_teacher_id INTEGER;
            max_course_id INTEGER;
            max_assignment_id  INTEGER;
            max_enrollment_id INTEGER;
            select_assignment_id INTEGER;
            student_id_to_course INTEGER;
            select_assignment_name varchar(255);
            names_to_select varchar(255);
            student_ids SYS_REFCURSOR;

            
            
            BEGIN

                select max(teacher_id) into max_teacher_id from teachers;
                max_teacher_id := max_teacher_id +1;
                INSERT INTO teachers (teacher_id, teacher_name, email, phone_number ) 
                    VALUES (max_teacher_id, new_teacher_name, new_email, new_phone);
                    
                select max(assignment_id) into max_assignment_id from assignments;
                SELECT ROUND(DBMS_RANDOM.value(1, max_assignment_id)) INTO select_assignment_id FROM dual;
                select assignment_name into select_assignment_name from assignments where assignment_id = select_assignment_id;
                    
                select max(course_id) into max_course_id from courses;
                max_course_id := max_course_id +1;
                INSERT INTO courses (course_id, course_name, teacher_id ) 
                    VALUES (max_course_id, select_assignment_name, max_teacher_id);
                    
                
                select concat(concat('%',name_filter),'%') into names_to_select from dual;
                OPEN student_ids FOR
                select student_id
                from students
                where student_name like names_to_select
                fetch  first 50 rows only;
                
                
                
                select max(enrollment_id) into max_enrollment_id from enrollments;
                loop
                    max_enrollment_id := max_enrollment_id +1;
                    FETCH student_ids INTO student_id_to_course;
                    EXIT WHEN student_ids%NOTFOUND;
                    INSERT INTO enrollments (enrollment_id, student_id, course_id ) 
                    VALUES (max_enrollment_id, student_id_to_course,max_course_id);
                end loop;


                    
            COMMIT;
            EXCEPTION WHEN not_serializable OR deadlock OR snapshot_too_old THEN
            ROLLBACK;
        
        END; 
        
