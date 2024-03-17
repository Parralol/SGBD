//Comentarios de tabla

COMMENT ON TABLE Teachers IS 'Tabla que almacena informaci�n sobre profesores';
COMMENT ON TABLE Courses IS 'Tabla que almacena informaci�n sobre cursos, incluyendo el profesor asignado a cada curso';
COMMENT ON TABLE Students IS 'Tabla que almacena informaci�n sobre estudiantes';
COMMENT ON TABLE Assignments IS 'Tabla que almacena informaci�n sobre asignaciones, incluyendo el curso y el estudiante asociado con cada asignaci�n';
COMMENT ON TABLE Enrollments IS 'Tabla que almacena informaci�n sobre las inscripciones de estudiantes en cursos';

// Comentarios de Columnas
COMMENT ON COLUMN Teachers.teacher_id IS 'Identificador �nico para profesores';
COMMENT ON COLUMN Teachers.teacher_name IS 'Nombre del profesor';
COMMENT ON COLUMN Teachers.email IS 'Correo electr�nico del profesor';
COMMENT ON COLUMN Teachers.phone_number IS 'N�mero de tel�fono del profesor';

COMMENT ON COLUMN Courses.course_id IS 'Identificador �nico para cursos';
COMMENT ON COLUMN Courses.course_name IS 'Nombre del curso';
COMMENT ON COLUMN Courses.teacher_id IS 'Clave externa que referencia al profesor que imparte el curso';

COMMENT ON COLUMN Students.student_id IS 'Identificador �nico para estudiantes';
COMMENT ON COLUMN Students.student_name IS 'Nombre del estudiante';
COMMENT ON COLUMN Students.email IS 'Correo electr�nico del estudiante';
COMMENT ON COLUMN Students.phone_number IS 'N�mero de tel�fono del estudiante';

COMMENT ON COLUMN Assignments.assignment_id IS 'Identificador �nico para asignaciones';
COMMENT ON COLUMN Assignments.assignment_name IS 'Nombre de la asignaci�n';
COMMENT ON COLUMN Assignments.course_id IS 'Clave externa que referencia al curso al que pertenece la asignaci�n';
COMMENT ON COLUMN Assignments.student_id IS 'Clave externa que referencia al estudiante que entreg� la asignaci�n';
COMMENT ON COLUMN Assignments.assignment_date IS 'Fecha en que se entreg� la asignaci�n';
COMMENT ON COLUMN Assignments.grade IS 'Calificaci�n recibida para la asignaci�n';

COMMENT ON COLUMN Enrollments.enrollment_id IS 'Identificador �nico para inscripciones';
COMMENT ON COLUMN Enrollments.student_id IS 'Clave externa que referencia al estudiante inscrito en el curso';
COMMENT ON COLUMN Enrollments.course_id IS 'Clave externa que referencia al curso en el que est� inscrito el estudiante';