*&---------------------------------------------------------------------*
*& Report ZEVO_CTS_EXTRACT_REQUESTS
*&---------------------------------------------------------------------*
*& Extracts transport/change requests via CTS_API_READ_CHANGE_REQUEST
*& and downloads (or writes) a CSV file.
*&
*& Install
*&   1. SE38 / ADT: create executable program ZEVO_CTS_EXTRACT_REQUESTS
*&   2. Paste this source, activate
*&   3. Confirm CTS_OBJ components in SE11 (PGMID/OBJECT/OBJ_NAME).
*&      If names differ, adjust FORM map_cts_object.
*&
*& CTS_API_READ_CHANGE_REQUEST (remote-enabled)
*&   IMPORTING  REQUEST      TYPE CHAR20
*&   EXPORTING  DESCRIPTION  TYPE TEXT60
*&              CATEGORY     TYPE CHAR01
*&              CLIENT       TYPE CHAR3
*&              OWNER        TYPE CHAR012
*&              STATUS       TYPE CHAR01
*&              RETCODE      TYPE CHAR3
*&              MESSAGE      TYPE TEXT80
*&   TABLES     OBJECTS      TYPE CTS_OBJ
*&---------------------------------------------------------------------*
REPORT zevo_cts_extract_requests.

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
  p_gui  RADIOBUTTON GROUP out DEFAULT 'X',
  p_file RADIOBUTTON GROUP out,
  p_path TYPE string LOWER CASE DEFAULT '/tmp/cts_extract.csv'.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.
PARAMETERS:
  p_hdr AS CHECKBOX DEFAULT 'X',
  p_obj AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE TEXT-004.
PARAMETERS p_max TYPE i DEFAULT 500.
SELECTION-SCREEN END OF BLOCK b4.

TYPES: BEGIN OF ty_header_row,
         request     TYPE char20,
         description TYPE text60,
         category    TYPE char01,
         client      TYPE char3,
         owner       TYPE char12,
         status      TYPE char01,
         retcode     TYPE char3,
         message     TYPE text80,
       END OF ty_header_row.

TYPES: BEGIN OF ty_object_row,
         request     TYPE char20,
         description TYPE text60,
         category    TYPE char01,
         client      TYPE char3,
         owner       TYPE char12,
         status      TYPE char01,
         pgmid       TYPE pgmid,
         object      TYPE trobjtype,
         obj_name    TYPE sobj_name,
         retcode     TYPE char3,
         message     TYPE text80,
       END OF ty_object_row.

DATA: gt_e070     TYPE STANDARD TABLE OF e070 WITH DEFAULT KEY,
      gs_e070     TYPE e070,
      gt_headers  TYPE STANDARD TABLE OF ty_header_row WITH DEFAULT KEY,
      gs_header   TYPE ty_header_row,
      gt_objects  TYPE STANDARD TABLE OF ty_object_row WITH DEFAULT KEY,
      gs_object   TYPE ty_object_row,
      gt_cts_obj  TYPE STANDARD TABLE OF cts_obj WITH DEFAULT KEY,
      gs_cts_obj  TYPE cts_obj,
      gv_desc     TYPE text60,
      gv_category TYPE char01,
      gv_client   TYPE char3,
      gv_owner    TYPE char12,
      gv_status   TYPE char01,
      gv_retcode  TYPE char3,
      gv_message  TYPE text80,
      gt_csv      TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
      gv_line     TYPE string,
      gv_ok       TYPE i,
      gv_fail     TYPE i.

START-OF-SELECTION.
  PERFORM select_requests.
  IF gt_e070 IS INITIAL.
    MESSAGE 'No transport requests found for the given selection.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM extract_via_cts_api.
  PERFORM build_csv.
  PERFORM output_csv.

  MESSAGE |Extracted { gv_ok } request(s), { gv_fail } failed. CSV lines: { lines( gt_csv ) }.|
          TYPE 'S'.

*&---------------------------------------------------------------------*
FORM select_requests.
  CLEAR gt_e070.

  IF p_trkorr IS NOT INITIAL.
    SELECT * FROM e070
      WHERE trkorr  = @p_trkorr
        AND strkorr = @space
      ORDER BY PRIMARY KEY
      INTO TABLE @gt_e070
      UP TO @p_max ROWS.
  ELSE.
    SELECT * FROM e070
      WHERE as4date BETWEEN @p_from AND @p_to
        AND strkorr = @space
        AND ( @p_user   = @space OR as4user    = @p_user )
        AND ( @p_status = @space OR trstatus   = @p_status )
        AND ( @p_funct  = @space OR trfunction = @p_funct )
      ORDER BY PRIMARY KEY
      INTO TABLE @gt_e070
      UP TO @p_max ROWS.
  ENDIF.

  SORT gt_e070 BY trkorr.
ENDFORM.

*&---------------------------------------------------------------------*
FORM extract_via_cts_api.
  CLEAR: gt_headers, gt_objects, gv_ok, gv_fail.

  LOOP AT gt_e070 INTO gs_e070.
    CLEAR: gt_cts_obj, gv_desc, gv_category, gv_client,
           gv_owner, gv_status, gv_retcode, gv_message.

    CALL FUNCTION 'CTS_API_READ_CHANGE_REQUEST'
      EXPORTING
        request     = gs_e070-trkorr
      IMPORTING
        description = gv_desc
        category    = gv_category
        client      = gv_client
        owner       = gv_owner
        status      = gv_status
        retcode     = gv_retcode
        message     = gv_message
      TABLES
        objects     = gt_cts_obj.

    IF gv_retcode IS NOT INITIAL AND gv_retcode <> '000'.
      ADD 1 TO gv_fail.
      CLEAR gs_header.
      gs_header-request     = gs_e070-trkorr.
      gs_header-description = gv_desc.
      gs_header-category    = gv_category.
      gs_header-client      = gv_client.
      gs_header-owner       = gv_owner.
      gs_header-status      = gv_status.
      gs_header-retcode     = gv_retcode.
      gs_header-message     = gv_message.
      APPEND gs_header TO gt_headers.
      CONTINUE.
    ENDIF.

    ADD 1 TO gv_ok.

    IF p_hdr = abap_true.
      CLEAR gs_header.
      gs_header-request     = gs_e070-trkorr.
      gs_header-description = gv_desc.
      gs_header-category    = gv_category.
      gs_header-client      = gv_client.
      gs_header-owner       = gv_owner.
      gs_header-status      = gv_status.
      gs_header-retcode     = gv_retcode.
      gs_header-message     = gv_message.
      APPEND gs_header TO gt_headers.
    ENDIF.

    IF p_obj = abap_true.
      LOOP AT gt_cts_obj INTO gs_cts_obj.
        CLEAR gs_object.
        gs_object-request     = gs_e070-trkorr.
        gs_object-description = gv_desc.
        gs_object-category    = gv_category.
        gs_object-client      = gv_client.
        gs_object-owner       = gv_owner.
        gs_object-status      = gv_status.
        gs_object-retcode     = gv_retcode.
        gs_object-message     = gv_message.
        PERFORM map_cts_object USING gs_cts_obj CHANGING gs_object.
        APPEND gs_object TO gt_objects.
      ENDLOOP.
    ENDIF.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Map CTS_OBJ components by name so minor DDIC differences are tolerated.
*& Inspect SE11 structure CTS_OBJ on your system if mapping is empty.
*&---------------------------------------------------------------------*
FORM map_cts_object USING    is_cts TYPE cts_obj
                    CHANGING cs_row TYPE ty_object_row.
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
  DATA: lv_desc TYPE text60,
        lv_msg  TYPE text80,
        lv_name TYPE sobj_name.

  CLEAR gt_csv.

  IF p_obj = abap_true AND gt_objects IS NOT INITIAL.
    gv_line = |REQUEST,DESCRIPTION,CATEGORY,CLIENT,OWNER,STATUS,PGMID,OBJECT,OBJ_NAME,RETCODE,MESSAGE|.
    APPEND gv_line TO gt_csv.
    LOOP AT gt_objects INTO gs_object.
      lv_desc = gs_object-description.
      lv_msg  = gs_object-message.
      lv_name = gs_object-obj_name.
      PERFORM csv_escape CHANGING lv_desc.
      PERFORM csv_escape CHANGING lv_msg.
      PERFORM csv_escape CHANGING lv_name.
      gv_line = |{ gs_object-request },{ lv_desc },{ gs_object-category },| &&
                |{ gs_object-client },{ gs_object-owner },{ gs_object-status },| &&
                |{ gs_object-pgmid },{ gs_object-object },{ lv_name },| &&
                |{ gs_object-retcode },{ lv_msg }|.
      APPEND gv_line TO gt_csv.
    ENDLOOP.
  ELSEIF p_hdr = abap_true.
    gv_line = |REQUEST,DESCRIPTION,CATEGORY,CLIENT,OWNER,STATUS,RETCODE,MESSAGE|.
    APPEND gv_line TO gt_csv.
    LOOP AT gt_headers INTO gs_header.
      lv_desc = gs_header-description.
      lv_msg  = gs_header-message.
      PERFORM csv_escape CHANGING lv_desc.
      PERFORM csv_escape CHANGING lv_msg.
      gv_line = |{ gs_header-request },{ lv_desc },{ gs_header-category },| &&
                |{ gs_header-client },{ gs_header-owner },{ gs_header-status },| &&
                |{ gs_header-retcode },{ lv_msg }|.
      APPEND gv_line TO gt_csv.
    ENDLOOP.
  ENDIF.
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
FORM output_csv.
  DATA: lv_filename TYPE string,
        lv_path     TYPE string.

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
    DATA lv_msg TYPE string.
    lv_path = p_path.
    OPEN DATASET lv_path FOR OUTPUT IN TEXT MODE ENCODING UTF-8 MESSAGE lv_msg.
    IF sy-subrc <> 0.
      MESSAGE |Cannot open dataset { lv_path }: { lv_msg }.| TYPE 'E'.
    ENDIF.
    LOOP AT gt_csv INTO gv_line.
      TRANSFER gv_line TO lv_path.
    ENDLOOP.
    CLOSE DATASET lv_path.
  ENDIF.
ENDFORM.
