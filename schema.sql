SELECT table_name, column_name, data_type, nullable
FROM all_tab_columns
WHERE owner= 'INTRO_USER';

SELECT constraint_name, table_name, r_constraint_name, delete_rule
FROM all_constraints
WHERE owner = 'INTRO_USER' AND constraint_type = 'R';


SELECT index_name, table_name, uniqueness
FROM all_indexes
WHERE owner = 'INTRO_USER';

SELECT view_name, text
FROM all_views
WHERE owner = 'INTRO_USER';


SELECT a.table_name, a.column_name, a.constraint_name,
       c_pk.table_name AS r_table_name, c_pk.constraint_name AS r_constraint_name
FROM all_cons_columns a
JOIN all_constraints c ON a.owner = c.owner AND a.constraint_name = c.constraint_name
JOIN all_constraints c_pk ON c.r_owner = c_pk.owner AND c.r_constraint_name = c_pk.constraint_name
WHERE a.owner = 'INTRO_USER' AND c.constraint_type = 'R';

SELECT table_name, column_name, comments
FROM all_col_comments
WHERE owner = 'INTRO_USER';

SELECT table_name, comments
FROM all_tab_comments
WHERE owner = 'INTRO_USER';
