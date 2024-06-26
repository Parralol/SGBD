#!/usr/local/bin/tclsh8.6
#EDITABLE OPTIONS##################################################
set library Oratcl ;# Oracle OCI Library
set total_iterations 100000000 ;# Number of transactions before logging off
set RAISEERROR "true" ;# Exit script on Oracle error (true or false)
set KEYANDTHINK "false" ;# Time for user thinking and keying (true or false)
set CHECKPOINT "false" ;# Perform Oracle checkpoint when complete (true or false)
set rampup 1;  # Rampup time in minutes before first snapshot is taken
set duration 2;  # Duration in minutes before second AWR snapshot is taken
set mode "Local" ;# HammerDB operational mode
set timesten "false" ;# Database is TimesTen
set systemconnect testadmin/admins@ORCL1 ;# Oracle connect string for system user
set connect test3/admins@ORCL1 ;# Oracle connect string for tpc-c user
#EDITABLE OPTIONS##################################################
#LOAD LIBRARIES AND MODULES
if [catch {package require $library} message] { error "Failed to load $library - $message" }
if [catch {::tcl::tm::path add modules} ] { error "Failed to find modules directory" }
if [catch {package require tpcccommon} ] { error "Failed to load tpcc common functions" } else { namespace import tpcccommon::* }

#LOGON
proc OracleLogon { connectstring lda timesten } {
    set lda [oralogon $connectstring ]
    if { !$timesten } { SetNLS $lda }
    oraautocom $lda on
    return $lda
}
#STANDARD SQL
proc standsql { curn sql } {
    set ftch ""
    if {[catch {orasql $curn $sql} message]} {
        error "SQL statement failed: $sql : $message"
    } else {
        orafetch  $curn -datavariable output
        while { [ oramsg  $curn ] == 0 } {
            lappend ftch $output
            orafetch  $curn -datavariable output
        }
        return $ftch
    }
}
#Default NLS
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

if { [ chk_thread ] eq "FALSE" } {
    error "AWR Snapshot Script must be run in Thread Enabled Interpreter"
}
set rema [ lassign [ findvuposition ] myposition totalvirtualusers ]
if { [ string toupper $timesten ] eq "TRUE"} { 
    set timesten 1 
    set systemconnect $connect
} else { 
    set timesten 0 
}
switch $myposition {
    1 { 
        if { $mode eq "Local" || $mode eq "Primary" } {
            set lda [ OracleLogon $systemconnect lda $timesten ]
            set curn1 [oraopen $lda ] 
            set lda1 [ OracleLogon $connect lda1 $timesten ]
            set curn2 [oraopen $lda1 ]
            if { $timesten } {
                puts "For TimesTen use external ttStats utility for performance reports"
                set sql1 "select (xact_commits + xact_rollbacks) from sys.monitor"
            } else {
                set sql1 "BEGIN dbms_workload_repository.create_snapshot(); END;"
                oraparse $curn1 $sql1
            }
            set ramptime 0
            puts "Beginning rampup time of $rampup minutes"
            set rampup [ expr $rampup*60000 ]
            while {$ramptime != $rampup} {
                if { [ tsv::get application abort ] } { break } else { after 6000 }
                set ramptime [ expr $ramptime+6000 ]
                if { ![ expr {$ramptime % 60000} ] } {
                    puts "Rampup [ expr $ramptime / 60000 ] minutes complete ..."
                }
            }
            if { [ tsv::get application abort ] } { break }
            if { $timesten } {
                puts "Rampup complete, Taking start Transaction Count."
                set start_trans [ standsql $curn2 $sql1 ]
            } else {
                puts "Rampup complete, Taking start AWR snapshot."
                if {[catch {oraplexec $curn1 $sql1} message]} { error "Failed to create snapshot : $message" }
                set sql2 "SELECT INSTANCE_NUMBER, INSTANCE_NAME, DB_NAME, DBID, SNAP_ID, TO_CHAR(END_INTERVAL_TIME,'DD MON YYYY HH24:MI') FROM (SELECT DI.INSTANCE_NUMBER, DI.INSTANCE_NAME, DI.DB_NAME, DI.DBID, DS.SNAP_ID, DS.END_INTERVAL_TIME FROM DBA_HIST_SNAPSHOT DS, DBA_HIST_DATABASE_INSTANCE DI WHERE DS.DBID=DI.DBID AND DS.INSTANCE_NUMBER=DI.INSTANCE_NUMBER AND DS.STARTUP_TIME=DI.STARTUP_TIME ORDER BY DS.END_INTERVAL_TIME DESC) WHERE ROWNUM=1"
                if {[catch {orasql $curn1 $sql2} message]} {
                    error "SQL statement failed: $sql2 : $message"
                } else {
                    orafetch  $curn1 -datavariable firstsnap
                    split  $firstsnap " "
                    puts "Start Snapshot [ lindex $firstsnap 4 ] taken at [ lindex $firstsnap 5 ] of instance [ lindex $firstsnap 1 ] ([lindex $firstsnap 0]) of database [ lindex $firstsnap 2 ] ([lindex $firstsnap 3])"
            }}
            set sql4 "select count(*) from assignments"
            set start_nopm [ standsql $curn2 $sql4 ]
            puts "Timing test period of $duration in minutes"
            set testtime 0
            set durmin $duration
            set duration [ expr $duration*60000 ]
            while {$testtime != $duration} {
                if { [ tsv::get application abort ] } { break } else { after 6000 }
                set testtime [ expr $testtime+6000 ]
                if { ![ expr {$testtime % 60000} ] } {
                    puts -nonewline  "[ expr $testtime / 60000 ]  ...,"
                }
            }
            if { [ tsv::get application abort ] } { break }
            if { $timesten } {
                puts "Test complete, Taking end Transaction Count."
                set end_trans [ standsql $curn2 $sql1 ]
                set end_nopm [ standsql $curn2 $sql4 ]
                set tpm [ expr {($end_trans - $start_trans)/$durmin} ]
                set nopm [ expr {($end_nopm - $start_nopm)/$durmin} ]
                puts "[ expr $totalvirtualusers - 1 ] Active Virtual Users configured"
                puts [ testresult $nopm $tpm TimesTen ]
            } else {
                puts "Test complete, Taking end AWR snapshot."
                oraparse $curn1 $sql1
                if {[catch {oraplexec $curn1 $sql1} message]} { error "Failed to create snapshot : $message" }
                if {[catch {orasql $curn1 $sql2} message]} {
                    error "SQL statement failed: $sql2 : $message"
                } else {
                    orafetch  $curn1 -datavariable endsnap
                    split  $endsnap " "
                    puts "End Snapshot [ lindex $endsnap 4 ] taken at [ lindex $endsnap 5 ] of instance [ lindex $endsnap 1 ] ([lindex $endsnap 0]) of database [ lindex $endsnap 2 ] ([lindex $endsnap 3])"
                    puts "Test complete: view report from SNAPID  [ lindex $firstsnap 4 ] to [ lindex $endsnap 4 ]"
                    set sql3 "select round((sum(tps)*60)) as TPM from (select e.stat_name, (e.value - b.value) / (select avg( extract( day from (e1.end_interval_time-b1.end_interval_time) )*24*60*60+ extract( hour from (e1.end_interval_time-b1.end_interval_time) )*60*60+ extract( minute from (e1.end_interval_time-b1.end_interval_time) )*60+ extract( second from (e1.end_interval_time-b1.end_interval_time)) ) from dba_hist_snapshot b1, dba_hist_snapshot e1 where b1.snap_id = [ lindex $firstsnap 4 ] and e1.snap_id = [ lindex $endsnap 4 ] and b1.dbid = [lindex $firstsnap 3] and e1.dbid = [lindex $endsnap 3] and b1.instance_number = [lindex $firstsnap 0] and e1.instance_number = [lindex $endsnap 0] and b1.startup_time = e1.startup_time and b1.end_interval_time < e1.end_interval_time) as tps from dba_hist_sysstat b, dba_hist_sysstat e where b.snap_id = [ lindex $firstsnap 4 ] and e.snap_id = [ lindex $endsnap 4 ] and b.dbid = [lindex $firstsnap 3] and e.dbid = [lindex $endsnap 3] and b.instance_number = [lindex $firstsnap 0] and e.instance_number = [lindex $endsnap 0] and b.stat_id = e.stat_id and b.stat_name in ('user commits','user rollbacks') and e.stat_name in ('user commits','user rollbacks') order by 1 asc)"
                    set tpm [ standsql $curn1 $sql3 ]
                    set end_nopm [ standsql $curn2 $sql4 ]
                    set nopm [ expr {($end_nopm - $start_nopm)/$durmin} ]
                    set sql6 {select value from v$parameter where name = 'cluster_database'}
                    oraparse $curn1 $sql6
                    set israc [ standsql $curn1 $sql6 ]
                    if { $israc != "FALSE" } {
                        set ractpm 0
                        set sql7 {select max(inst_number) from v$active_instances}
                        oraparse $curn1 $sql7
                        set activinst [ standsql $curn1 $sql7 ]
                        for { set a 1 } { $a <= $activinst } { incr a } {
                            set firstsnap [ lreplace $firstsnap 0 0 $a ]
                            set endsnap [ lreplace $endsnap 0 0 $a ]
                            set sqlrac "select round((sum(tps)*60)) as TPM from (select e.stat_name, (e.value - b.value) / (select avg( extract( day from (e1.end_interval_time-b1.end_interval_time) )*24*60*60+ extract( hour from (e1.end_interval_time-b1.end_interval_time) )*60*60+ extract( minute from (e1.end_interval_time-b1.end_interval_time) )*60+ extract( second from (e1.end_interval_time-b1.end_interval_time)) ) from dba_hist_snapshot b1, dba_hist_snapshot e1 where b1.snap_id = [ lindex $firstsnap 4 ] and e1.snap_id = [ lindex $endsnap 4 ] and b1.dbid = [lindex $firstsnap 3] and e1.dbid = [lindex $endsnap 3] and b1.instance_number = [lindex $firstsnap 0] and e1.instance_number = [lindex $endsnap 0] and b1.startup_time = e1.startup_time and b1.end_interval_time < e1.end_interval_time) as tps from dba_hist_sysstat b, dba_hist_sysstat e where b.snap_id = [ lindex $firstsnap 4 ] and e.snap_id = [ lindex $endsnap 4 ] and b.dbid = [lindex $firstsnap 3] and e.dbid = [lindex $endsnap 3] and b.instance_number = [lindex $firstsnap 0] and e.instance_number = [lindex $endsnap 0] and b.stat_id = e.stat_id and b.stat_name in ('user commits','user rollbacks') and e.stat_name in ('user commits','user rollbacks') order by 1 asc)"
                            set ractpm [ expr $ractpm + [ standsql $curn1 $sqlrac ]]
                        }
                        set tpm $ractpm
                    }
                    puts "[ expr $totalvirtualusers - 1 ] Active Virtual Users configured"
                    puts [ testresult $nopm $tpm Oracle ]
                }
            }
            tsv::set application abort 1
            if { $mode eq "Primary" } { eval [subst {thread::send -async $MASTER { remote_command ed_kill_vusers }}] }
            if { $CHECKPOINT } {
                puts "Checkpoint"
                if { $timesten } {
                    set sql4 "call ttCkptBlocking"
                }	else {
                    set sql4 "alter system checkpoint"
                    if {[catch {orasql $curn1 $sql4} message]} {
                        error "SQL statement failed: $sql4 : $message"
                    }
                    set sql5 "alter system switch logfile"
                    if {[catch {orasql $curn1 $sql5} message]} {
                        error "SQL statement failed: $sql5 : $message"
                }}
                puts "Checkpoint Complete"
            }
            oraclose $curn1
            oraclose $curn2
            oralogoff $lda
            oralogoff $lda1
        } else {
            puts "Operating in Replica Mode, No Snapshots taken..."
        }
    }
    default {
        #RANDOM STRING
        proc GenerateRandomString { length_min length_max } {
            set globArray [ list 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z ]
            set chalen [ llength $globArray ]
            return [MakeAlphaString $length_min $length_max $globArray $chalen]
        }

        #random phone number
        proc GenerateRandomPhoneNumbers { } {
            return "+573[RandomNumber 0 9999][RandomNumber 0 9999]"
        }

        #Random email
        proc GenerateRandomEmails { } {
            return "[GenerateRandomString 4 10]@[GenerateRandomString 4 5].[GenerateRandomString 2 3]"
        }

        #TIMESTAMP
        proc gettimestamp { } {
            set tstamp [ clock format [ clock seconds ] -format %Y%m%d%H%M%S ]
            return $tstamp
        }


        #NEW assignment
        proc newassignment { curn_no RAISEERROR } {
            set new_name_assignment [GenerateRandomString 10 30]
            set date_initial "2024-[RandomNumber 2 6]-[RandomNumber 1 28] [RandomNumber 0 23]:[RandomNumber 0 59]:[RandomNumber 0 59]"
            orabind $curn_no :date_initial $date_initial :name_assignment $new_name_assignment
            if {[catch {oraexec $curn_no} message]} {
                if { $RAISEERROR } {
                    error "New assignment : $message [ oramsg $curn_no all ]"
                } else {
                    ;
                } } 
        }
        #new student enrollment to courses
        proc newstudentenrollmenttocourses { curn_enco RAISEERROR } {
            set new_student_name [GenerateRandomString 10 20]
            set new_phone [GenerateRandomPhoneNumbers]
            set new_email [GenerateRandomEmails]
            orabind $curn_enco :student_name $new_student_name :email $new_email :phone $new_phone
            if {[ catch {oraexec $curn_enco} message]} {
                if { $RAISEERROR } {
                    error "new student : $message [ oramsg $curn_enco all ]"
                } else {
                    ;
                } } else {
                orafetch  $curn_enco -datavariable output
                ;
            }
        }


        #extra homework
        proc extra_homework { curn_eh  RAISEERROR } {
            set new_name_assignment [GenerateRandomString 10 30]
            set date_initial "2024-[RandomNumber 2 6]-[RandomNumber 1 28] [RandomNumber 0 23]:[RandomNumber 0 59]:[RandomNumber 0 59]"
            orabind $curn_eh :date_initial $date_initial :name_assignment $new_name_assignment
            if {[catch {oraexec $curn_eh} message]} {
                if { $RAISEERROR } {
                    error "extra homework : $message [ oramsg $curn_eh all ]"
                } else {
                    ;
                } } 
        }

        # teacher_and_enrollment_course_and_students
        proc teacher_and_enrollment_course_and_students { curn_te  RAISEERROR } {
            set new_teacher_name [GenerateRandomString 10 30]
            set new_phone [GenerateRandomPhoneNumbers]
            set new_email [GenerateRandomEmails] 
            set new_filter_student_name [GenerateRandomString 2 2]
            orabind $curn_te :teacher_name $new_teacher_name :email $new_email :phone $new_phone :student_name_filter $new_filter_student_name
            if {[catch {oraexec $curn_te} message]} {
                if { $RAISEERROR } {
                    error "teacher and enrollment : $message [ oramsg $curn_te all ]"
                } else {
                    ;
                } } 
        }

        proc update_student_email_with_same_course {curn_sc curn_us RAISEERROR } {
            set sql "SELECT student_id FROM enrollments WHERE course_id = (SELECT ROUND(DBMS_RANDOM.value(1, (SELECT MAX(course_id) FROM courses))) FROM dual)"
            set students_ids [ standsql $curn_sc $sql ]
            set maxIteration [llength $students_ids]
            for {set i 1} {$i <= $maxIteration } {incr  i} {
                set st_id [lindex $students_ids $i]
                set new_email [GenerateRandomEmails] 
                orabind $curn_us :email $new_email :student_id $st_id
                if {[catch {oraexec $curn_us} message]} {
                    if { $RAISEERROR } {
                        error "update student : $message [ oramsg $curn_te all ]"
                    } else {
                    ;} 
                } 
            }
            
        }

        proc prep_statement { lda curn_st } {
            switch $curn_st {
                new_teacher_and_enrollment_course_and_students {
                    set curn_te [oraopen $lda ]
                    set sql_os "BEGIN new_teacher_and_enrollment_course_and_students(:teacher_name,:email,:phone,:student_name_filter); END;"
                    oraparse $curn_te $sql_os
                    return $curn_te
                }
                new_extra_homework {
                    set curn_os [oraopen $lda ]
                    set sql_os "BEGIN extra_homework(to_date( :date_initial,'YYYY-MM-DD HH24:MI:SS'), :name_assignment); END;"
                    oraparse $curn_os $sql_os
                    return $curn_os
                }
                new_student_enrollment_to_courses {
                    set curn_py [oraopen $lda ]
                    set sql_py "BEGIN new_student(:student_name,:email,:phone); END;"
                    oraparse $curn_py $sql_py
                    return $curn_py
                }
                curn_new_assignment {
                    set curn_no [oraopen $lda ]
                    set sql_no "BEGIN new_assignment_between_date(to_date( :date_initial,'YYYY-MM-DD HH24:MI:SS'), :name_assignment); END;"
                    oraparse $curn_no $sql_no
                    return $curn_no
                }
                curn_new_assignment {
                    set curn_no [oraopen $lda ]
                    set sql_no "BEGIN new_assignment_between_date(to_date( :date_initial,'YYYY-MM-DD HH24:MI:SS'), :name_assignment); END;"
                    oraparse $curn_no $sql_no
                    return $curn_no
                }
                curn_to_select {
                    set curn_no [oraopen $lda ]
                    return $curn_no
                }
                curn_update_email_students {
                    set curn_no [oraopen $lda ]
                    set sql_no "UPDATE students SET email = :email WHERE student_id = :student_id "
                    oraparse $curn_no $sql_no
                    return $curn_no
                }
            }
        }
        #RUN TPC-C
        set lda [ OracleLogon $connect lda $timesten ]
        foreach curn_st {curn_new_assignment new_student_enrollment_to_courses new_extra_homework new_teacher_and_enrollment_course_and_students curn_to_select curn_update_email_students} { set $curn_st [ prep_statement $lda $curn_st ] }
        set curn1 [oraopen $lda ]
        set sql3 "BEGIN DBMS_RANDOM.initialize (val => TO_NUMBER(TO_CHAR(SYSDATE,'MMSS')) * (USERENV('SESSIONID') - TRUNC(USERENV('SESSIONID'),-5))); END;"
        oraparse $curn1 $sql3
        if {[catch {oraplexec $curn1 $sql3} message]} {
        error "Failed to initialise DBMS_RANDOM $message have you run catoctk.sql as sys?" }
        oraclose $curn1
        puts "Processing $total_iterations transactions with output suppressed..."
        set abchk 1; set abchk_mx 1024; set hi_t [ expr {pow([ lindex [ time {if {  [ tsv::get application abort ]  } { break }} ] 0 ],2)}]
        for {set it 0} {$it < $total_iterations} {incr it} {
            if { [expr {$it % $abchk}] eq 0 } { if { [ time {if {  [ tsv::get application abort ]  } { break }} ] > $hi_t }  {  set  abchk [ expr {min(($abchk * 2), $abchk_mx)}]; set hi_t [ expr {$hi_t * 2} ] } }
            set choice [ RandomNumber 1 17 ]
            if {$choice <= 3} {
                if { $KEYANDTHINK } { keytime 18 }
                newassignment $curn_new_assignment $RAISEERROR
                if { $KEYANDTHINK } { thinktime 12 }
            } elseif {$choice <= 8} {
                if { $KEYANDTHINK } { keytime 3 }
                newstudentenrollmenttocourses $new_student_enrollment_to_courses $RAISEERROR
                if { $KEYANDTHINK } { thinktime 12 }
            } elseif {$choice <= 11} {
                if { $KEYANDTHINK } { keytime 2 }
                extra_homework $new_extra_homework $RAISEERROR
                if { $KEYANDTHINK } { thinktime 10 }
            } elseif {$choice <= 15} {
                if { $KEYANDTHINK } { keytime 2 }
                teacher_and_enrollment_course_and_students $new_teacher_and_enrollment_course_and_students $RAISEERROR
                if { $KEYANDTHINK } { thinktime 5 }
            } elseif {$choice <= 17} {
                if { $KEYANDTHINK } { keytime 2 }
                update_student_email_with_same_course $curn_to_select $curn_update_email_students $RAISEERROR
                if { $KEYANDTHINK } { thinktime 5 }
            }
        }
        oraclose $curn_new_assignment
        oraclose $new_student_enrollment_to_courses
        oraclose $new_extra_homework
        oraclose $new_teacher_and_enrollment_course_and_students
        oraclose $curn_to_select
        oraclose $curn_update_email_students
        oralogoff $lda
    }
}
