REPORT y182_emp_salary_report
       LINE-SIZE 130
       LINE-COUNT 60(3)
       NO STANDARD PAGE HEADING.

*---------------------------------------------------------------------*
* Employee Salary Management - Classical Report (Enhanced)
* Tables : Y182M_EMPMST (Employee Master), Y182M_SALMST (Salary Master)
* Features:
*   - Page header (user, date, time, page no) and page footer
*   - Colored headings, grid lines, alternating row shading
*   - Sort options, employee-wise subtotals
*   - Grand totals / average per currency
*   - Double-click on a row to see employee details (pop-up list)
*---------------------------------------------------------------------*

TABLES: y182m_empmst,
        y182m_salmst.

*---------------------------------------------------------------------*
* Types and Data
*---------------------------------------------------------------------*
TYPES: BEGIN OF ty_report,
         empno       TYPE y182m_empmst-empno,
         empnm       TYPE y182m_empmst-empnm,
         gender      TYPE y182m_empmst-gender,
         deptcd      TYPE y182m_empmst-deptcd,
         designation TYPE y182m_empmst-designation,
         phone_no    TYPE y182m_empmst-phone_no,
         salhd       TYPE y182m_salmst-salhd,
         salary      TYPE y182m_salmst-salary,
         waers       TYPE y182m_salmst-waers,
       END OF ty_report.

* Currency-wise totals (COLLECT: char key first, numerics after)
TYPES: BEGIN OF ty_total,
         waers TYPE y182m_salmst-waers,
         total TYPE y182m_salmst-salary,
         cnt   TYPE i,
       END OF ty_total.

DATA: lt_report  TYPE STANDARD TABLE OF ty_report,
      ls_report  TYPE ty_report,
      lt_total   TYPE STANDARD TABLE OF ty_total,
      ls_total   TYPE ty_total,
      gv_hide    TYPE y182m_empmst-empno,
      gv_rec_cnt TYPE i,
      gv_emp_cnt TYPE i,
      gv_prev    TYPE y182m_empmst-empno,
      gv_emp_sum TYPE y182m_salmst-salary,
      gv_emp_cur TYPE y182m_salmst-waers,
      gv_shade   TYPE abap_bool,
      gv_do_sub  TYPE abap_bool,
      gv_avg     TYPE y182m_salmst-salary.

*---------------------------------------------------------------------*
* Selection Screen
*---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE t_b1.
SELECT-OPTIONS: s_empno FOR y182m_empmst-empno,
                s_dept  FOR y182m_empmst-deptcd,
                s_desig FOR y182m_empmst-designation,
                s_sal   FOR y182m_salmst-salary.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE t_b2.
PARAMETERS: r_emp RADIOBUTTON GROUP srt DEFAULT 'X',
            r_dep RADIOBUTTON GROUP srt,
            r_sal RADIOBUTTON GROUP srt.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE t_b3.
PARAMETERS: p_sub AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b3.

*---------------------------------------------------------------------*
INITIALIZATION.
*---------------------------------------------------------------------*
  t_b1 = 'Selection Criteria'.
  t_b2 = 'Sort Order'.
  t_b3 = 'Display Options'.

  %_s_empno_%_app_%-text = 'Employee Number'.
  %_s_dept_%_app_%-text  = 'Department'.
  %_s_desig_%_app_%-text = 'Designation'.
  %_s_sal_%_app_%-text   = 'Salary Amount'.
  %_r_emp_%_app_%-text   = 'Sort by Employee Number'.
  %_r_dep_%_app_%-text   = 'Sort by Department'.
  %_r_sal_%_app_%-text   = 'Sort by Salary (High to Low)'.
  %_p_sub_%_app_%-text   = 'Show Employee-wise Subtotals'.

*---------------------------------------------------------------------*
START-OF-SELECTION.
*---------------------------------------------------------------------*
  SELECT e~empno,
         e~empnm,
         e~gender,
         e~deptcd,
         e~designation,
         e~phone_no,
         s~salhd,
         s~salary,
         s~waers
    FROM y182m_empmst AS e
    INNER JOIN y182m_salmst AS s
      ON e~empno = s~empno
    WHERE e~empno       IN @s_empno
      AND e~deptcd      IN @s_dept
      AND e~designation IN @s_desig
      AND s~salary      IN @s_sal
    INTO TABLE @lt_report.

  IF sy-subrc <> 0 OR lt_report IS INITIAL.
    MESSAGE 'No employee salary records found.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  CASE 'X'.
    WHEN r_emp.
      SORT lt_report BY empno salhd.
    WHEN r_dep.
      SORT lt_report BY deptcd empno salhd.
    WHEN r_sal.
      SORT lt_report BY salary DESCENDING.
  ENDCASE.

* Subtotals only make sense when rows of one employee are together
  IF p_sub = abap_true AND r_sal = abap_false.
    gv_do_sub = abap_true.
  ENDIF.

*---------------------------------------------------------------------*
END-OF-SELECTION.
*---------------------------------------------------------------------*
  IF lt_report IS INITIAL.
    RETURN.
  ENDIF.

  LOOP AT lt_report INTO ls_report.

*   Employee changed -> print subtotal of previous employee
    IF ls_report-empno <> gv_prev.
      IF gv_prev IS NOT INITIAL AND gv_do_sub = abap_true.
        PERFORM print_subtotal.
      ENDIF.
      gv_emp_cnt = gv_emp_cnt + 1.
      CLEAR gv_emp_sum.
      gv_prev = ls_report-empno.
      IF gv_shade = abap_true.
        gv_shade = abap_false.
      ELSE.
        gv_shade = abap_true.
      ENDIF.
    ENDIF.

*   Row color (alternating per employee)
    IF gv_shade = abap_true.
      FORMAT COLOR COL_NORMAL INTENSIFIED ON.
    ELSE.
      FORMAT COLOR COL_NORMAL INTENSIFIED OFF.
    ENDIF.

    WRITE: / sy-vline NO-GAP,
           3(10)  ls_report-empno,
           14 sy-vline NO-GAP,
           16(25) ls_report-empnm,
           42 sy-vline NO-GAP,
           44(6)  ls_report-gender,
           51 sy-vline NO-GAP,
           53(8)  ls_report-deptcd,
           62 sy-vline NO-GAP,
           64(20) ls_report-designation,
           85 sy-vline NO-GAP,
           87(12) ls_report-salhd,
           100 sy-vline NO-GAP,
           102(15) ls_report-salary CURRENCY ls_report-waers,
           118 sy-vline NO-GAP,
           120(5) ls_report-waers,
           130 sy-vline.

*   Remember employee number for double-click
    gv_hide = ls_report-empno.
    HIDE gv_hide.

*   Accumulate totals
    gv_rec_cnt = gv_rec_cnt + 1.
    gv_emp_sum = gv_emp_sum + ls_report-salary.
    gv_emp_cur = ls_report-waers.

    CLEAR ls_total.
    ls_total-waers = ls_report-waers.
    ls_total-total = ls_report-salary.
    ls_total-cnt   = 1.
    COLLECT ls_total INTO lt_total.

  ENDLOOP.

* Subtotal of the last employee
  IF gv_do_sub = abap_true.
    PERFORM print_subtotal.
  ENDIF.

  FORMAT RESET.
  ULINE.

* ---- Summary section ----------------------------------------------
  SKIP.
  FORMAT COLOR COL_HEADING INTENSIFIED ON.
  WRITE: / sy-vline NO-GAP, 3(126) 'SUMMARY' CENTERED, 130 sy-vline.
  FORMAT RESET.
  ULINE.

  FORMAT COLOR COL_KEY INTENSIFIED ON.
  WRITE: / sy-vline NO-GAP,
         3 'Total Employees',
         30 ':',
         32 gv_emp_cnt LEFT-JUSTIFIED,
         130 sy-vline.
  WRITE: / sy-vline NO-GAP,
         3 'Total Salary Records',
         30 ':',
         32 gv_rec_cnt LEFT-JUSTIFIED,
         130 sy-vline.
  FORMAT RESET.
  ULINE.

  FORMAT COLOR COL_HEADING INTENSIFIED ON.
  WRITE: / sy-vline NO-GAP,
         3 'Currency',
         20 'Records',
         40 'Total Amount',
         70 'Average Amount',
         130 sy-vline.
  FORMAT RESET.
  ULINE.

  LOOP AT lt_total INTO ls_total.
    gv_avg = ls_total-total / ls_total-cnt.
    FORMAT COLOR COL_TOTAL INTENSIFIED ON.
    WRITE: / sy-vline NO-GAP,
           3 ls_total-waers,
           20 ls_total-cnt,
           34(20) ls_total-total CURRENCY ls_total-waers,
           64(20) gv_avg CURRENCY ls_total-waers,
           130 sy-vline.
  ENDLOOP.
  FORMAT RESET.
  ULINE.

  SKIP.
  WRITE: / '*** End of Report - Double-click an employee row for details ***'.

*---------------------------------------------------------------------*
TOP-OF-PAGE.
*---------------------------------------------------------------------*
  FORMAT COLOR COL_HEADING INTENSIFIED ON.
  WRITE: /1(130) 'EMPLOYEE SALARY MANAGEMENT REPORT' CENTERED.
  FORMAT RESET.
  WRITE: / 'User :', sy-uname,
         35 'Date :', sy-datum DD/MM/YYYY,
         65 'Time :', sy-uzeit USING EDIT MASK '__:__:__',
         110 'Page :', sy-pagno.
  ULINE.

  FORMAT COLOR COL_HEADING INTENSIFIED ON.
  WRITE: / sy-vline NO-GAP,
         3 'Emp No',
         14 sy-vline NO-GAP,
         16 'Employee Name',
         42 sy-vline NO-GAP,
         44 'Gender',
         51 sy-vline NO-GAP,
         53 'Dept',
         62 sy-vline NO-GAP,
         64 'Designation',
         85 sy-vline NO-GAP,
         87 'Salary Head',
         100 sy-vline NO-GAP,
         102 '         Salary',
         118 sy-vline NO-GAP,
         120 'Curr',
         130 sy-vline.
  FORMAT RESET.
  ULINE.

*---------------------------------------------------------------------*
END-OF-PAGE.
*---------------------------------------------------------------------*
  ULINE.
  WRITE: / 'Employee Salary Report', 110 'Page', sy-pagno.

*---------------------------------------------------------------------*
AT LINE-SELECTION.
*---------------------------------------------------------------------*
  IF gv_hide IS INITIAL.
    MESSAGE 'Please double-click on an employee row.' TYPE 'S'.
    RETURN.
  ENDIF.

  SELECT SINGLE empno, empnm, gender, deptcd, designation, phone_no
    FROM y182m_empmst
    WHERE empno = @gv_hide
    INTO @DATA(ls_emp).

  IF sy-subrc <> 0.
    MESSAGE 'Employee details not found.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  WINDOW STARTING AT 10 4 ENDING AT 90 20.

  FORMAT COLOR COL_HEADING INTENSIFIED ON.
  WRITE: / 'EMPLOYEE DETAILS'.
  FORMAT RESET.
  ULINE AT /1(78).
  WRITE: / 'Employee No  :', ls_emp-empno,
         / 'Name         :', ls_emp-empnm,
         / 'Gender       :', ls_emp-gender,
         / 'Department   :', ls_emp-deptcd,
         / 'Designation  :', ls_emp-designation,
         / 'Phone No     :', ls_emp-phone_no.
  ULINE AT /1(78).

  FORMAT COLOR COL_HEADING INTENSIFIED ON.
  WRITE: / 'Salary Head', 25 'Salary', 50 'Curr'.
  FORMAT RESET.
  ULINE AT /1(78).

  LOOP AT lt_report INTO DATA(ls_sal) WHERE empno = gv_hide.
    WRITE: / ls_sal-salhd,
           20(15) ls_sal-salary CURRENCY ls_sal-waers,
           50 ls_sal-waers.
  ENDLOOP.
  ULINE AT /1(78).

*---------------------------------------------------------------------*
* Form: employee subtotal line
*---------------------------------------------------------------------*
FORM print_subtotal.
  FORMAT COLOR COL_TOTAL INTENSIFIED ON.
  WRITE: / sy-vline NO-GAP,
         64 'Employee Total :',
         100 sy-vline NO-GAP,
         102(15) gv_emp_sum CURRENCY gv_emp_cur,
         118 sy-vline NO-GAP,
         120(5) gv_emp_cur,
         130 sy-vline.
  CLEAR gv_hide.
  HIDE gv_hide.
  FORMAT RESET.
  ULINE.
ENDFORM.
