set library Oratcl
if [catch {package require $library} message] { error "Failed to load $library - $message" }
if [catch {::tcl::tm::path add modules} ] { error "Failed to find modules directory" }
if [catch {package require tpcccommon} ] { error "Failed to load tpcc common functions" } else { namespace import tpcccommon::* }

proc SetNLS { lda } {
    set curn_nls [oraopen $lda ]
    set nls(1) "alter session set NLS_LANGUAGE = AMERICAN"
    set nls(2) "alter session set NLS_TERRITORY = AMERICA"
    for { set i 1 } { $i <= 2 } { incr i } {
        if {[ catch {orasql $curn_nls $nls($i)} message ] } {
            puts "$message $nls($i)"
            puts [ oramsg $curn_nls all ]
        }
    }
    oraclose $curn_nls
}

proc GenerateRandomStrings { num_strings length_min length_max } {
    set globArray [ list 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z ]
    set chalen [ llength $globArray ]
    set result {}
    for {set i 0} {$i < $num_strings} {incr i} {
        lappend result [MakeAlphaString $length_min $length_max $globArray $chalen]
    }
    return $result
}


proc GenerateRandomPhoneNumbers { num_numbers } {
    set result {}
    for {set i 0} {$i < $num_numbers} {incr i} {
        lappend result "+573[RandomNumber 0 9999][RandomNumber 0 9999]"
    }
    return $result
}

proc GenerateRandomDates { } {

    return "2024-[RandomNumber 2 6]-[RandomNumber 1 28] [RandomNumber 0 23]:[RandomNumber 0 59]:[RandomNumber 0 59]"
}

proc GenerateRandomGrades { num_grades } {
    set result {}
    for {set i 0} {$i < $num_grades} {incr i} {
        lappend result [expr {rand() * 100}]
    }
    return $result
}

proc InsertTeachers { lda num_teachers} {
    # Insert teacher
    set curn [oraopen $lda ]
    puts "Generate random teachers"
    set ids {}
    for {set j 1} {$j <= $num_teachers} {incr j} {
        lappend ids $j
    }
    set teacher_names [GenerateRandomStrings $num_teachers 8 20]
    set emails [GenerateRandomEmails $num_teachers]
    set phone_numbers [GenerateRandomPhoneNumbers $num_teachers]
    set sql "INSERT INTO Teachers (teacher_id, teacher_name, email, phone_number) VALUES ( :teacher_id, :teacher_name, :email, :phone_number )"
    oraparse $curn $sql
    orabind $curn -arraydml :teacher_id $ids :teacher_name $teacher_names :email $emails :phone_number $phone_numbers
    oraexec $curn
    oracommit $lda
    oraclose $curn
    
}

proc InsertCourses { lda course_names num_teachers } {
    # Insert courses
    set curn [oraopen $lda ]
    puts "Generate random courses"
    set course_ids {}
    set teachhers_ids {}
    for {set j 1} {$j <= $course_names} {incr j} {
        lappend course_ids $j
        lappend teachhers_ids [ RandomNumber 1 $num_teachers ]
    }
    set course_names [GenerateRandomStrings $course_names 5 20]
    set sql "INSERT INTO Courses (course_id, course_name, teacher_id) VALUES (:course_id, :course_name, :teacher_id)"
    oraparse $curn $sql
    orabind $curn -arraydml :course_id $course_ids :course_name $course_names :teacher_id $teachhers_ids
    oraexec $curn
    oracommit $lda
    oraclose $curn
    
    return $course_ids
}

proc InsertStudents { lda num_students} {
    # Insert students
    puts "Generate random students"
    set curn [oraopen $lda ]
    set student_ids {}
    for {set j 1} {$j <= $num_students} {incr j} {
        lappend student_ids $j
    }
    set student_names [GenerateRandomStrings $num_students 8 20]
    set emails [GenerateRandomEmails $num_students]
    set phone_numbers [GenerateRandomPhoneNumbers $num_students]
    set sql "INSERT INTO Students (student_id, student_name, email, phone_number) VALUES (:student_id, :student_name, :email, :phone_number)"
    oraparse $curn $sql
    orabind $curn -arraydml :student_id $student_ids :student_name $student_names :email $emails :phone_number $phone_numbers
    oraexec $curn
    oracommit $lda
    oraclose $curn

}

proc InsertEnrollments { lda num_enrrolments num_courses num_students} {
    # Insert enrollments
    puts "Generate random enrollments"
    set curn [oraopen $lda ]
    set sql "INSERT INTO Enrollments (enrollment_id, student_id, course_id) VALUES (:enrollment_id, :student_id, :course_id)"
    oraparse $curn $sql
    for {set i 1} {$i <= $num_enrrolments} {incr i} {
        set students_ids [ RandomNumber 1 $num_students ]
        set course_ids [ RandomNumber 1 $num_courses ]
        orabind $curn  :enrollment_id $i :student_id $students_ids :course_id $course_ids
        oraexec $curn
        oracommit $lda
        if { [expr {$i % 10}] eq 0 } {
            puts "Generate enrollment $i"
        }
    }
    oraclose $curn
}

proc InsertAssignments { lda num_assignments num_enrrolments } {
    # Insert enrollments
    puts "Generate random Assignments"
    set curn [oraopen $lda ]
    set sql "INSERT INTO Assignments (assignment_id, assignment_name, enrollment_id, assignment_date, grade) VALUES (:assignment_id, :assignment_name, :enrollment_id, to_date( :assignment_date,'YYYY-MM-DD HH24:MI:SS'), ROUND(:grade, 2))"
    oraparse $curn $sql
    for {set i 1} {$i <= $num_assignments} {incr i} {
        set assignment_names [lindex [GenerateRandomStrings 1 10 20] 0]
        set enrollment_ids [ RandomNumber 1 $num_enrrolments ]
        set assignment_dates [ GenerateRandomDates ]
        set numero_aleatorio [expr {rand()}]
        set grades [expr {$numero_aleatorio * 5}]
        orabind $curn  :assignment_id $i :assignment_name $assignment_names :enrollment_id $enrollment_ids :assignment_date $assignment_dates :grade $grades
        oraexec $curn
        oracommit $lda
        if { [expr {$i % 1000}] eq 0 } {
            puts "Generate Assignments $i"
        }
    }
    oraclose $curn
}

proc GenerateRandomEmails { num_emails } {
    set result {}
    for {set i 0} {$i < $num_emails} {incr i} {
        lappend result "[GenerateRandomStrings 1 4 10]@[GenerateRandomStrings 1 4 5].[GenerateRandomStrings 1 2 3]"
    }
    return $result
}

proc OptimizeTransactions {tpcc_user tpcc_pass instance} {
    puts "Optimizing Transactions"
    set connect $tpcc_user/$tpcc_pass@$instance
    set lda [ oralogon $connect ]
    SetNLS $lda
    puts "Optimizing Transactions"
    
    set num_assignments 600000
    set num_students 60000
    set num_courses 1000
    set num_teachers 3000
    set num_enrrolments 300000

    InsertTeachers $lda $num_teachers
    InsertStudents $lda $num_students
    InsertCourses $lda $num_courses $num_teachers
    InsertEnrollments $lda $num_enrrolments $num_courses $num_students
    InsertAssignments $lda $num_assignments  $num_enrrolments
}

#OptimizeTransactions user password instant
OptimizeTransactions test3 admins ORCL1

