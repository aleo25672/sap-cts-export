*&---------------------------------------------------------------------*
*& Report ZEVO_CTS_EXTRACT_REQUESTS
*&---------------------------------------------------------------------*
*& Extracts transport/change requests and downloads (or writes) CSV.
*&
*& Performance
*&   Default: bulk read E070 / E07T / E071 (fast).
*&   Optional: CTS_API_READ_CHANGE_REQUEST once per request (slow, API mode).
*&
*& Install: abapGit pull into ZEVO_CTS, or SE38 paste + activate.
*& Logical file for app-server output: maintain ZEVO_CTS_EXTRACT in FILE.
*&---------------------------------------------------------------------*
REPORT zevo_cts_extract_requests.


* Global TYPES/DATA must appear before event blocks;
* otherwise they are local and FORMs cannot see GT_*/GV_*.
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_e070_key,
         trkorr     TYPE trkorr,
         as4user    TYPE tr_as4user,
         trfunction TYPE trfunction,
         trstatus   TYPE trstatus,
         as4date    TYPE as4date,
       END OF ty_e070_key.

TYPES: BEGIN OF ty_e07t,
         trkorr  TYPE trkorr,
         as4text TYPE as4text,
       END OF ty_e07t.

TYPES: BEGIN OF ty_e071,
         trkorr   TYPE trkorr,
         pgmid    TYPE pgmid,
         object   TYPE trobjtype,
         obj_name TYPE sobj_name,
       END OF ty_e071.

TYPES: BEGIN OF ty_csv_row,
         request     TYPE trkorr,
         description TYPE as4text,
         category    TYPE trfunction,
         client      TYPE char3,
         owner       TYPE tr_as4user,
         status      TYPE trstatus,
         pgmid       TYPE pgmid,
         object      TYPE trobjtype,
         obj_name    TYPE sobj_name,
         retcode     TYPE char3,
         message     TYPE text80,
       END OF ty_csv_row.

DATA: gt_e070 TYPE STANDARD TABLE OF ty_e070_key WITH DEFAULT KEY,
      gt_e07t TYPE HASHED TABLE OF ty_e07t WITH UNIQUE KEY trkorr,
      gt_e071 TYPE SORTED TABLE OF ty_e071 WITH NON-UNIQUE KEY trkorr,
      gt_csv  TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
      gt_rows TYPE STANDARD TABLE OF ty_csv_row WITH DEFAULT KEY,
      gv_ok   TYPE i,
      gv_fail TYPE i,
      gv_line TYPE string.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS:
  p_trkorr TYPE trkorr,
  p_user   TYPE tr_as4user,
  p_from   TYPE as4date OBLIGATORY DEFAULT sy-datum,
  p_to     TYPE as4date OBLIGATORY DEFAULT sy-datum,
  p_status TYPE trstatus,
  p_funct  TYPE trfunction. " K=Workbench W=Customizing T=ToC
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
PARAMETERS:
  p_gui   RADIOBUTTON GROUP out DEFAULT 'X' USER-COMMAND out,
  p_file  RADIOBUTTON GROUP out,
  p_lfile TYPE filename-fileintern DEFAULT 'ZEVO_CTS_EXTRACT' MODIF ID fil,
  p_path  TYPE string LOWER CASE MODIF ID fil.
SELECTION-SCREEN COMMENT /1(79) TEXT-005 MODIF ID fil.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.
PARAMETERS:
  p_hdr   AS CHECKBOX DEFAULT 'X',
  p_obj   AS CHECKBOX DEFAULT 'X',
  p_usefm AS CHECKBOX DEFAULT ' '. " 1x CTS_API_READ_CHANGE_REQUEST per TR (slow)
SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE TEXT-004.
PARAMETERS p_max TYPE i DEFAULT 500.
SELECTION-SCREEN END OF BLOCK b4.

AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    IF screen-group1 = 'FIL'.
      IF p_gui = abap_true.
        screen-active = '0'.
      ELSE.
        screen-active = '1'.
      ENDIF.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

START-OF-SELECTION.
  PERFORM select_requests.
  IF gt_e070 IS INITIAL.
    MESSAGE 'No transport requests found for the given selection.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF p_usefm = abap_true.
    PERFORM extract_via_cts_api.
  ELSE.
    PERFORM extract_via_tables.
  ENDIF.

  PERFORM build_csv.
  PERFORM output_csv.

  MESSAGE |Extracted { gv_ok } request(s), { gv_fail } failed. CSV lines: { lines( gt_csv ) }.|
          TYPE 'S'.

*&---------------------------------------------------------------------*
*& Select only needed E070 columns; avoid OR on empty filters so indexes
*& on AS4DATE / AS4USER stay usable.
*&---------------------------------------------------------------------*
FORM select_requests.
  CLEAR gt_e070.

  IF p_trkorr IS NOT INITIAL.
    SELECT trkorr, as4user, trfunction, trstatus, as4date
      FROM e070
      WHERE trkorr  = @p_trkorr
        AND strkorr = @space
      ORDER BY PRIMARY KEY
      INTO TABLE @gt_e070
      UP TO @p_max ROWS.
    RETURN.
  ENDIF.

  IF p_user IS NOT INITIAL AND p_status IS NOT INITIAL AND p_funct IS NOT INITIAL.
    SELECT trkorr, as4user, trfunction, trstatus, as4date
      FROM e070
      WHERE as4date    BETWEEN @p_from AND @p_to
        AND strkorr    = @space
        AND as4user    = @p_user
        AND trstatus   = @p_status
        AND trfunction = @p_funct
      ORDER BY PRIMARY KEY
      INTO TABLE @gt_e070
      UP TO @p_max ROWS.

  ELSEIF p_user IS NOT INITIAL AND p_status IS NOT INITIAL.
    SELECT trkorr, as4user, trfunction, trstatus, as4date
      FROM e070
      WHERE as4date  BETWEEN @p_from AND @p_to
        AND strkorr  = @space
        AND as4user  = @p_user
        AND trstatus = @p_status
      ORDER BY PRIMARY KEY
      INTO TABLE @gt_e070
      UP TO @p_max ROWS.

  ELSEIF p_user IS NOT INITIAL AND p_funct IS NOT INITIAL.
    SELECT trkorr, as4user, trfunction, trstatus, as4date
      FROM e070
      WHERE as4date    BETWEEN @p_from AND @p_to
        AND strkorr    = @space
        AND as4user    = @p_user
        AND trfunction = @p_funct
      ORDER BY PRIMARY KEY
      INTO TABLE @gt_e070
      UP TO @p_max ROWS.

  ELSEIF p_status IS NOT INITIAL AND p_funct IS NOT INITIAL.
    SELECT trkorr, as4user, trfunction, trstatus, as4date
      FROM e070
      WHERE as4date    BETWEEN @p_from AND @p_to
        AND strkorr    = @space
        AND trstatus   = @p_status
        AND trfunction = @p_funct
      ORDER BY PRIMARY KEY
      INTO TABLE @gt_e070
      UP TO @p_max ROWS.

  ELSEIF p_user IS NOT INITIAL.
    SELECT trkorr, as4user, trfunction, trstatus, as4date
      FROM e070
      WHERE as4date BETWEEN @p_from AND @p_to
        AND strkorr = @space
        AND as4user = @p_user
      ORDER BY PRIMARY KEY
      INTO TABLE @gt_e070
      UP TO @p_max ROWS.

  ELSEIF p_status IS NOT INITIAL.
    SELECT trkorr, as4user, trfunction, trstatus, as4date
      FROM e070
      WHERE as4date  BETWEEN @p_from AND @p_to
        AND strkorr  = @space
        AND trstatus = @p_status
      ORDER BY PRIMARY KEY
      INTO TABLE @gt_e070
      UP TO @p_max ROWS.

  ELSEIF p_funct IS NOT INITIAL.
    SELECT trkorr, as4user, trfunction, trstatus, as4date
      FROM e070
      WHERE as4date    BETWEEN @p_from AND @p_to
        AND strkorr    = @space
        AND trfunction = @p_funct
      ORDER BY PRIMARY KEY
      INTO TABLE @gt_e070
      UP TO @p_max ROWS.

  ELSE.
    SELECT trkorr, as4user, trfunction, trstatus, as4date
      FROM e070
      WHERE as4date BETWEEN @p_from AND @p_to
        AND strkorr = @space
      ORDER BY PRIMARY KEY
      INTO TABLE @gt_e070
      UP TO @p_max ROWS.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Fast path: 3 bulk SELECTs instead of N FM calls.
*&---------------------------------------------------------------------*
FORM extract_via_tables.
  DATA: ls_e070    TYPE ty_e070_key,
        ls_e07t    TYPE ty_e07t,
        ls_e071    TYPE ty_e071,
        ls_row     TYPE ty_csv_row,
        lt_keys    TYPE STANDARD TABLE OF trkorr WITH DEFAULT KEY,
        lv_has_obj TYPE abap_bool.

  CLEAR: gt_e07t, gt_e071, gt_rows, gv_ok, gv_fail.

  LOOP AT gt_e070 INTO ls_e070.
    APPEND ls_e070-trkorr TO lt_keys.
  ENDLOOP.

  IF lt_keys IS INITIAL.
    RETURN.
  ENDIF.

  SELECT trkorr, as4text
    FROM e07t
    FOR ALL ENTRIES IN @lt_keys
    WHERE trkorr = @lt_keys-table_line
      AND langu  = @sy-langu
    INTO TABLE @gt_e07t.

  IF p_obj = abap_true.
    SELECT trkorr, pgmid, object, obj_name
      FROM e071
      FOR ALL ENTRIES IN @lt_keys
      WHERE trkorr = @lt_keys-table_line
      INTO TABLE @gt_e071.
  ENDIF.

  LOOP AT gt_e070 INTO ls_e070.
    CLEAR ls_row.
    ls_row-request  = ls_e070-trkorr.
    ls_row-category = ls_e070-trfunction.
    ls_row-owner    = ls_e070-as4user.
    ls_row-status   = ls_e070-trstatus.
    ls_row-retcode  = '000'.

    READ TABLE gt_e07t INTO ls_e07t WITH TABLE KEY trkorr = ls_e070-trkorr.
    IF sy-subrc = 0.
      ls_row-description = ls_e07t-as4text.
    ENDIF.

    ADD 1 TO gv_ok.

    IF p_obj = abap_true.
      lv_has_obj = abap_false.
      LOOP AT gt_e071 INTO ls_e071 WHERE trkorr = ls_e070-trkorr.
        lv_has_obj = abap_true.
        ls_row-pgmid    = ls_e071-pgmid.
        ls_row-object   = ls_e071-object.
        ls_row-obj_name = ls_e071-obj_name.
        APPEND ls_row TO gt_rows.
      ENDLOOP.
      IF lv_has_obj = abap_false AND p_hdr = abap_true.
        CLEAR: ls_row-pgmid, ls_row-object, ls_row-obj_name.
        APPEND ls_row TO gt_rows.
      ENDIF.
    ELSEIF p_hdr = abap_true.
      APPEND ls_row TO gt_rows.
    ENDIF.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Slow path: CTS_API_READ_CHANGE_REQUEST once per request (API-faithful).
*&---------------------------------------------------------------------*
FORM extract_via_cts_api.
  DATA: ls_e070    TYPE ty_e070_key,
        ls_row     TYPE ty_csv_row,
        lt_cts_obj TYPE STANDARD TABLE OF cts_obj WITH DEFAULT KEY,
        ls_cts     TYPE cts_obj,
        lv_desc    TYPE text60,
        lv_cat     TYPE char01,
        lv_client  TYPE char3,
        lv_owner   TYPE char12,
        lv_status  TYPE char01,
        lv_ret     TYPE char3,
        lv_msg     TYPE text80,
        lv_total   TYPE i,
        lv_idx     TYPE i,
        lv_pct     TYPE i.

  CLEAR: gt_rows, gv_ok, gv_fail.
  lv_total = lines( gt_e070 ).

  LOOP AT gt_e070 INTO ls_e070.
    lv_idx = lv_idx + 1.
    IF lv_total > 0 AND ( lv_idx = 1 OR lv_idx MOD 10 = 0 OR lv_idx = lv_total ).
      lv_pct = ( lv_idx * 100 ) DIV lv_total.
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING
          percentage = lv_pct
          text       = |CTS API { lv_idx } / { lv_total }|.
    ENDIF.

    CLEAR: lt_cts_obj, lv_desc, lv_cat, lv_client, lv_owner, lv_status, lv_ret, lv_msg.

    CALL FUNCTION 'CTS_API_READ_CHANGE_REQUEST'
      EXPORTING
        request     = ls_e070-trkorr
      IMPORTING
        description = lv_desc
        category    = lv_cat
        client      = lv_client
        owner       = lv_owner
        status      = lv_status
        retcode     = lv_ret
        message     = lv_msg
      TABLES
        objects     = lt_cts_obj.

    CLEAR ls_row.
    ls_row-request     = ls_e070-trkorr.
    ls_row-description = lv_desc.
    ls_row-category    = lv_cat.
    ls_row-client      = lv_client.
    ls_row-owner       = lv_owner.
    ls_row-status      = lv_status.
    ls_row-retcode     = lv_ret.
    ls_row-message     = lv_msg.

    IF lv_ret IS NOT INITIAL AND lv_ret <> '000'.
      ADD 1 TO gv_fail.
      IF p_hdr = abap_true OR p_obj = abap_true.
        APPEND ls_row TO gt_rows.
      ENDIF.
      CONTINUE.
    ENDIF.

    ADD 1 TO gv_ok.

    IF p_obj = abap_true AND lt_cts_obj IS NOT INITIAL.
      LOOP AT lt_cts_obj INTO ls_cts.
        PERFORM map_cts_object USING ls_cts CHANGING ls_row.
        APPEND ls_row TO gt_rows.
      ENDLOOP.
    ELSEIF p_hdr = abap_true.
      CLEAR: ls_row-pgmid, ls_row-object, ls_row-obj_name.
      APPEND ls_row TO gt_rows.
    ENDIF.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
FORM map_cts_object USING    is_cts TYPE cts_obj
                    CHANGING cs_row TYPE ty_csv_row.
  FIELD-SYMBOLS: <pgmid>    TYPE any,
                 <object>   TYPE any,
                 <obj_name> TYPE any,
                 <objname>  TYPE any.

  ASSIGN COMPONENT 'PGMID' OF STRUCTURE is_cts TO <pgmid>.
  IF <pgmid> IS ASSIGNED.
    cs_row-pgmid = <pgmid>.
  ENDIF.
  ASSIGN COMPONENT 'OBJECT' OF STRUCTURE is_cts TO <object>.
  IF <object> IS ASSIGNED.
    cs_row-object = <object>.
  ENDIF.
  ASSIGN COMPONENT 'OBJ_NAME' OF STRUCTURE is_cts TO <obj_name>.
  IF <obj_name> IS ASSIGNED.
    cs_row-obj_name = <obj_name>.
  ELSE.
    ASSIGN COMPONENT 'OBJNAME' OF STRUCTURE is_cts TO <objname>.
    IF <objname> IS ASSIGNED.
      cs_row-obj_name = <objname>.
    ENDIF.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
FORM build_csv.
  DATA: ls_row  TYPE ty_csv_row,
        lv_desc TYPE as4text,
        lv_msg  TYPE text80,
        lv_name TYPE sobj_name.

  CLEAR gt_csv.
  IF gt_rows IS INITIAL.
    RETURN.
  ENDIF.

  IF p_obj = abap_true.
    APPEND |REQUEST,DESCRIPTION,CATEGORY,CLIENT,OWNER,STATUS,PGMID,OBJECT,OBJ_NAME,RETCODE,MESSAGE|
      TO gt_csv.
  ELSE.
    APPEND |REQUEST,DESCRIPTION,CATEGORY,CLIENT,OWNER,STATUS,RETCODE,MESSAGE|
      TO gt_csv.
  ENDIF.

  LOOP AT gt_rows INTO ls_row.
    lv_desc = ls_row-description.
    lv_msg  = ls_row-message.
    lv_name = ls_row-obj_name.
    PERFORM csv_escape CHANGING lv_desc.
    PERFORM csv_escape CHANGING lv_msg.
    IF p_obj = abap_true.
      PERFORM csv_escape CHANGING lv_name.
      gv_line = |{ ls_row-request },{ lv_desc },{ ls_row-category },{ ls_row-client },| &&
                |{ ls_row-owner },{ ls_row-status },{ ls_row-pgmid },{ ls_row-object },| &&
                |{ lv_name },{ ls_row-retcode },{ lv_msg }|.
    ELSE.
      gv_line = |{ ls_row-request },{ lv_desc },{ ls_row-category },{ ls_row-client },| &&
                |{ ls_row-owner },{ ls_row-status },{ ls_row-retcode },{ lv_msg }|.
    ENDIF.
    APPEND gv_line TO gt_csv.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
FORM csv_escape CHANGING cv TYPE clike.
  DATA lv TYPE string.
  lv = cv.
  IF lv CS ',' OR lv CS '"' OR lv CS cl_abap_char_utilities=>cr_lf
     OR lv CS cl_abap_char_utilities=>newline.
    REPLACE ALL OCCURRENCES OF '"' IN lv WITH '""'.
    lv = |"{ lv }"|.
  ENDIF.
  cv = lv.
ENDFORM.

*&---------------------------------------------------------------------*
FORM resolve_appserver_path CHANGING cv_path TYPE string.
  DATA: lv_logical TYPE filename-fileintern,
        lv_phys    TYPE string,
        lv_param1  TYPE c LENGTH 50,
        lv_param2  TYPE c LENGTH 50.

  IF p_path IS NOT INITIAL.
    cv_path = p_path.
    RETURN.
  ENDIF.

  lv_logical = p_lfile.
  IF lv_logical IS INITIAL.
    MESSAGE 'Enter a logical file name (transaction FILE) or a physical path.' TYPE 'E'.
  ENDIF.

  lv_param1 = |{ sy-datum }|.
  lv_param2 = |{ sy-uzeit }|.

  CALL FUNCTION 'FILE_GET_NAME'
    EXPORTING
      logical_filename = lv_logical
      including_dir    = 'X'
      parameter_1      = lv_param1
      parameter_2      = lv_param2
    IMPORTING
      file_name        = lv_phys
    EXCEPTIONS
      file_not_found   = 1
      OTHERS           = 2.
  IF sy-subrc <> 0 OR lv_phys IS INITIAL.
    MESSAGE |Logical file { lv_logical } not found. Maintain it in transaction FILE.| TYPE 'E'.
  ENDIF.

  cv_path = lv_phys.
ENDFORM.

*&---------------------------------------------------------------------*
FORM output_csv.
  DATA: lv_filename TYPE string,
        lv_path     TYPE string,
        lv_msg      TYPE string.

  IF gt_csv IS INITIAL.
    MESSAGE 'Nothing to write to CSV.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF p_gui = abap_true.
    lv_filename = |cts_extract_{ sy-datum }_{ sy-uzeit }.csv|.
    CALL METHOD cl_gui_frontend_services=>gui_download
      EXPORTING
        filename              = lv_filename
        filetype              = 'ASC'
        write_field_separator = space
        codepage              = '4110'
      CHANGING
        data_tab              = gt_csv
      EXCEPTIONS
        file_write_error        = 1
        no_batch                = 2
        gui_refuse_filetransfer = 3
        OTHERS                  = 4.
    IF sy-subrc <> 0.
      MESSAGE |GUI download failed (sy-subrc={ sy-subrc }).| TYPE 'E'.
    ENDIF.
  ELSE.
    PERFORM resolve_appserver_path CHANGING lv_path.
    OPEN DATASET lv_path FOR OUTPUT IN TEXT MODE ENCODING UTF-8 MESSAGE lv_msg.
    IF sy-subrc <> 0.
      MESSAGE |Cannot open dataset { lv_path }: { lv_msg }.| TYPE 'E'.
    ENDIF.
    LOOP AT gt_csv INTO gv_line.
      TRANSFER gv_line TO lv_path.
    ENDLOOP.
    CLOSE DATASET lv_path.
    MESSAGE |CSV written to { lv_path }.| TYPE 'S'.
  ENDIF.
ENDFORM.
