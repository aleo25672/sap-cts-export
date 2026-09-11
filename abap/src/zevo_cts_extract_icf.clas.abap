*&---------------------------------------------------------------------*
*& Class ZEVO_CTS_EXTRACT_ICF
*&---------------------------------------------------------------------*
*& ICF HTTP handler around CTS_API_READ_CHANGE_REQUEST.
*&
*& Install
*&   1. SE24 / ADT: create public final class ZEVO_CTS_EXTRACT_ICF
*&   2. Paste this source and activate
*&   3. SICF (default_host → sap → bc): create service ZEVO_CTS_EXTRACT
*&      Handler List: ZEVO_CTS_EXTRACT_ICF
*&      Enable Basic Authentication (or Standard SAP logon)
*&   4. Activate the ICF node
*&
*& URL
*&   https://<host>:<port>/sap/bc/zevo_cts_extract
*&
*& POST application/json
*& {
*&   "requests": ["S4HK900123"],
*&   "owner": "",
*&   "status": "",
*&   "category": "",
*&   "dateFrom": "20260101",
*&   "dateTo": "20261231",
*&   "max": 500,
*&   "format": "json"
*& }
*&
*& GET ?request=S4HK900123&format=csv
*& GET ?dateFrom=20260101&dateTo=20261231&owner=DEVELOPER1&format=json
*&
*& Depends on /UI2/CL_JSON. Adjust CTS_OBJ component mapping in
*& map_cts_object if SE11 names differ on your system.
*&---------------------------------------------------------------------*
CLASS zevo_cts_extract_icf DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_object,
             pgmid    TYPE string,
             object   TYPE string,
             obj_name TYPE string,
           END OF ty_object.
    TYPES tty_object TYPE STANDARD TABLE OF ty_object WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_request,
             request     TYPE string,
             description TYPE string,
             category    TYPE string,
             client      TYPE string,
             owner       TYPE string,
             status      TYPE string,
             retcode     TYPE string,
             message     TYPE string,
             objects     TYPE tty_object,
           END OF ty_request.
    TYPES tty_request TYPE STANDARD TABLE OF ty_request WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_filters,
             requests  TYPE string_table,
             owner     TYPE string,
             status    TYPE string,
             category  TYPE string,
             date_from TYPE as4date,
             date_to   TYPE as4date,
             max       TYPE i,
             format    TYPE string,
           END OF ty_filters.

    " JSON body DTO (string dates → converted after deserialize)
    TYPES: BEGIN OF ty_json_in,
             requests  TYPE string_table,
             owner     TYPE string,
             status    TYPE string,
             category  TYPE string,
             date_from TYPE string,
             date_to   TYPE string,
             max       TYPE i,
             format    TYPE string,
           END OF ty_json_in.

    TYPES: BEGIN OF ty_response,
             adapter    TYPE string,
             fetched_at TYPE string,
             ok         TYPE i,
             failed     TYPE i,
             requests   TYPE tty_request,
           END OF ty_response.

    METHODS handle_extract
      IMPORTING io_server TYPE REF TO if_http_server.

    METHODS parse_filters
      IMPORTING io_request        TYPE REF TO if_http_request
      RETURNING VALUE(rs_filters) TYPE ty_filters.

    METHODS select_request_ids
      IMPORTING is_filters       TYPE ty_filters
      RETURNING VALUE(rt_trkorr) TYPE string_table.

    METHODS read_change_request
      IMPORTING iv_trkorr         TYPE clike
      RETURNING VALUE(rs_request) TYPE ty_request.

    METHODS map_cts_object
      IMPORTING is_cts           TYPE cts_obj
      RETURNING VALUE(rs_object) TYPE ty_object.

    METHODS to_ymd
      IMPORTING iv_raw         TYPE clike
      RETURNING VALUE(rv_date) TYPE as4date.

    METHODS build_csv
      IMPORTING it_requests   TYPE tty_request
      RETURNING VALUE(rv_csv) TYPE string.

    METHODS csv_quote
      IMPORTING iv_raw         TYPE clike
      RETURNING VALUE(rv_out)  TYPE string.

    METHODS json_escape
      IMPORTING iv_raw         TYPE clike
      RETURNING VALUE(rv_out)  TYPE string.
ENDCLASS.


CLASS zevo_cts_extract_icf IMPLEMENTATION.

  METHOD if_http_extension~handle_request.
    DATA lv_method TYPE string.

    lv_method = server->request->get_method( ).

    server->response->set_header_field(
      name = 'Access-Control-Allow-Origin' value = '*' ).
    server->response->set_header_field(
      name  = 'Access-Control-Allow-Headers'
      value = 'Content-Type, Authorization' ).
    server->response->set_header_field(
      name  = 'Access-Control-Allow-Methods'
      value = 'GET, POST, OPTIONS' ).

    IF lv_method = 'OPTIONS'.
      server->response->set_status( code = 204 reason = 'No Content' ).
      RETURN.
    ENDIF.

    IF lv_method <> 'GET' AND lv_method <> 'POST'.
      server->response->set_status( code = 405 reason = 'Method Not Allowed' ).
      server->response->set_header_field(
        name = 'Content-Type' value = 'application/json; charset=utf-8' ).
      server->response->set_cdata( '{"error":"Use GET or POST"}' ).
      RETURN.
    ENDIF.

    handle_extract( server ).
  ENDMETHOD.


  METHOD handle_extract.
    DATA: ls_filters  TYPE ty_filters,
          lt_ids      TYPE string_table,
          lv_id       TYPE string,
          ls_request  TYPE ty_request,
          lt_requests TYPE tty_request,
          ls_response TYPE ty_response,
          lv_json     TYPE string,
          lv_csv      TYPE string,
          lv_ok       TYPE i VALUE 0,
          lv_fail     TYPE i VALUE 0,
          lx_json     TYPE REF TO cx_root.

    ls_filters = parse_filters( io_server->request ).
    IF ls_filters-max <= 0.
      ls_filters-max = 500.
    ENDIF.
    IF ls_filters-format IS INITIAL.
      ls_filters-format = 'json'.
    ENDIF.

    lt_ids = select_request_ids( ls_filters ).

    LOOP AT lt_ids INTO lv_id.
      CLEAR ls_request.
      ls_request = read_change_request( lv_id ).
      IF ls_request-retcode IS NOT INITIAL AND ls_request-retcode <> '000'.
        ADD 1 TO lv_fail.
      ELSE.
        ADD 1 TO lv_ok.
      ENDIF.
      APPEND ls_request TO lt_requests.
    ENDLOOP.

    IF ls_filters-format = 'csv'.
      lv_csv = build_csv( lt_requests ).
      io_server->response->set_status( code = 200 reason = 'OK' ).
      io_server->response->set_header_field(
        name = 'Content-Type' value = 'text/csv; charset=utf-8' ).
      io_server->response->set_header_field(
        name  = 'Content-Disposition'
        value = 'attachment; filename="cts_extract.csv"' ).
      io_server->response->set_cdata( lv_csv ).
      RETURN.
    ENDIF.

    ls_response-adapter    = 'icf'.
    ls_response-fetched_at = |{ sy-datum }T{ sy-uzeit }|.
    ls_response-ok         = lv_ok.
    ls_response-failed     = lv_fail.
    ls_response-requests   = lt_requests.

    TRY.
        /ui2/cl_json=>serialize(
          EXPORTING
            data        = ls_response
            pretty_name = /ui2/cl_json=>pretty_mode-camel_case
            compress    = abap_false
          RECEIVING
            r_json      = lv_json ).
      CATCH cx_root INTO lx_json.
        io_server->response->set_status( code = 500 reason = 'JSON Error' ).
        io_server->response->set_header_field(
          name = 'Content-Type' value = 'application/json; charset=utf-8' ).
        io_server->response->set_cdata(
          |\{"error":"{ json_escape( lx_json->get_text( ) ) }"\}| ).
        RETURN.
    ENDTRY.

    io_server->response->set_status( code = 200 reason = 'OK' ).
    io_server->response->set_header_field(
      name = 'Content-Type' value = 'application/json; charset=utf-8' ).
    io_server->response->set_cdata( lv_json ).
  ENDMETHOD.


  METHOD parse_filters.
    DATA: lv_body     TYPE string,
          lv_form     TYPE string,
          lt_requests TYPE string_table,
          lv_req      TYPE string,
          ls_json     TYPE ty_json_in,
          lx_json     TYPE REF TO cx_root.

    CLEAR rs_filters.
    rs_filters-date_from = sy-datum.
    rs_filters-date_to   = sy-datum.
    rs_filters-max       = 500.
    rs_filters-format    = 'json'.

    lv_form = io_request->get_form_field( 'request' ).
    IF lv_form IS INITIAL.
      lv_form = io_request->get_form_field( 'requests' ).
    ENDIF.
    IF lv_form IS NOT INITIAL.
      SPLIT lv_form AT ',' INTO TABLE lt_requests.
      LOOP AT lt_requests INTO lv_req.
        CONDENSE lv_req.
        TRANSLATE lv_req TO UPPER CASE.
        IF lv_req IS NOT INITIAL.
          APPEND lv_req TO rs_filters-requests.
        ENDIF.
      ENDLOOP.
    ENDIF.

    rs_filters-owner    = io_request->get_form_field( 'owner' ).
    rs_filters-status   = io_request->get_form_field( 'status' ).
    rs_filters-category = io_request->get_form_field( 'category' ).

    IF io_request->get_form_field( 'dateFrom' ) IS NOT INITIAL.
      rs_filters-date_from = to_ymd( io_request->get_form_field( 'dateFrom' ) ).
    ENDIF.
    IF io_request->get_form_field( 'dateTo' ) IS NOT INITIAL.
      rs_filters-date_to = to_ymd( io_request->get_form_field( 'dateTo' ) ).
    ENDIF.
    IF io_request->get_form_field( 'max' ) IS NOT INITIAL.
      rs_filters-max = io_request->get_form_field( 'max' ).
    ENDIF.
    IF io_request->get_form_field( 'format' ) IS NOT INITIAL.
      rs_filters-format = to_lower( io_request->get_form_field( 'format' ) ).
    ENDIF.

    lv_body = io_request->get_cdata( ).
    IF lv_body IS NOT INITIAL.
      TRY.
          /ui2/cl_json=>deserialize(
            EXPORTING
              json        = lv_body
              pretty_name = /ui2/cl_json=>pretty_mode-camel_case
            CHANGING
              data        = ls_json ).

          IF ls_json-requests IS NOT INITIAL.
            CLEAR rs_filters-requests.
            LOOP AT ls_json-requests INTO lv_req.
              CONDENSE lv_req.
              TRANSLATE lv_req TO UPPER CASE.
              IF lv_req IS NOT INITIAL.
                APPEND lv_req TO rs_filters-requests.
              ENDIF.
            ENDLOOP.
          ENDIF.
          IF ls_json-owner IS NOT INITIAL.
            rs_filters-owner = ls_json-owner.
          ENDIF.
          IF ls_json-status IS NOT INITIAL.
            rs_filters-status = ls_json-status.
          ENDIF.
          IF ls_json-category IS NOT INITIAL.
            rs_filters-category = ls_json-category.
          ENDIF.
          IF ls_json-date_from IS NOT INITIAL.
            rs_filters-date_from = to_ymd( ls_json-date_from ).
          ENDIF.
          IF ls_json-date_to IS NOT INITIAL.
            rs_filters-date_to = to_ymd( ls_json-date_to ).
          ENDIF.
          IF ls_json-max IS NOT INITIAL.
            rs_filters-max = ls_json-max.
          ENDIF.
          IF ls_json-format IS NOT INITIAL.
            rs_filters-format = to_lower( ls_json-format ).
          ENDIF.
        CATCH cx_root INTO lx_json. "#EC NEEDED
          " Keep query-string filters when body is not JSON
      ENDTRY.
    ENDIF.

    TRANSLATE rs_filters-owner    TO UPPER CASE.
    TRANSLATE rs_filters-status   TO UPPER CASE.
    TRANSLATE rs_filters-category TO UPPER CASE.
  ENDMETHOD.


  METHOD select_request_ids.
    DATA: lt_e070     TYPE STANDARD TABLE OF e070 WITH DEFAULT KEY,
          ls_e070     TYPE e070,
          lv_id       TYPE string,
          lv_max      TYPE i,
          lv_from     TYPE as4date,
          lv_to       TYPE as4date,
          lv_owner    TYPE as4user,
          lv_status   TYPE trstatus,
          lv_category TYPE trfunction,
          lv_blank    TYPE c LENGTH 1 VALUE space.

    CLEAR rt_trkorr.
    lv_max = is_filters-max.
    IF lv_max <= 0.
      lv_max = 500.
    ENDIF.

    IF is_filters-requests IS NOT INITIAL.
      LOOP AT is_filters-requests INTO lv_id.
        CONDENSE lv_id.
        TRANSLATE lv_id TO UPPER CASE.
        IF lv_id IS NOT INITIAL.
          APPEND lv_id TO rt_trkorr.
        ENDIF.
      ENDLOOP.
      RETURN.
    ENDIF.

    " Open SQL host variables must be elementary (not STRING).
    lv_from     = is_filters-date_from.
    lv_to       = is_filters-date_to.
    lv_owner    = is_filters-owner.
    lv_status   = is_filters-status.
    lv_category = is_filters-category.

    " Header requests only (STRKORR blank). Prefer explicit REQUEST list when possible.
    SELECT * FROM e070
      WHERE as4date BETWEEN @lv_from AND @lv_to
        AND strkorr = @lv_blank
        AND ( @lv_owner    = @lv_blank OR as4user    = @lv_owner )
        AND ( @lv_status   = @lv_blank OR trstatus   = @lv_status )
        AND ( @lv_category = @lv_blank OR trfunction = @lv_category )
      ORDER BY PRIMARY KEY
      INTO TABLE @lt_e070
      UP TO @lv_max ROWS.

    SORT lt_e070 BY trkorr.
    LOOP AT lt_e070 INTO ls_e070.
      lv_id = ls_e070-trkorr.
      APPEND lv_id TO rt_trkorr.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_change_request.
    DATA: lt_objects  TYPE STANDARD TABLE OF cts_obj WITH DEFAULT KEY,
          ls_cts      TYPE cts_obj, " SE11: CTS_OBJ — adjust if typed differently
          ls_object   TYPE ty_object,
          lv_desc     TYPE text60,
          lv_category TYPE char01,
          lv_client   TYPE char3,
          lv_owner    TYPE char12,
          lv_status   TYPE char01,
          lv_retcode  TYPE char3,
          lv_message  TYPE text80.

    CLEAR rs_request.
    rs_request-request = iv_trkorr.

    CALL FUNCTION 'CTS_API_READ_CHANGE_REQUEST'
      EXPORTING
        request     = iv_trkorr
      IMPORTING
        description = lv_desc
        category    = lv_category
        client      = lv_client
        owner       = lv_owner
        status      = lv_status
        retcode     = lv_retcode
        message     = lv_message
      TABLES
        objects     = lt_objects.

    rs_request-description = lv_desc.
    rs_request-category    = lv_category.
    rs_request-client      = lv_client.
    rs_request-owner       = lv_owner.
    rs_request-status      = lv_status.
    rs_request-retcode     = lv_retcode.
    rs_request-message     = lv_message.

    LOOP AT lt_objects INTO ls_cts.
      ls_object = map_cts_object( ls_cts ).
      APPEND ls_object TO rs_request-objects.
    ENDLOOP.
  ENDMETHOD.


  METHOD map_cts_object.
    FIELD-SYMBOLS: <pgmid>    TYPE any,
                   <object>   TYPE any,
                   <obj_name> TYPE any,
                   <objname>  TYPE any.

    CLEAR rs_object.
    ASSIGN COMPONENT 'PGMID' OF STRUCTURE is_cts TO <pgmid>.
    IF <pgmid> IS ASSIGNED.
      rs_object-pgmid = <pgmid>.
    ENDIF.

    ASSIGN COMPONENT 'OBJECT' OF STRUCTURE is_cts TO <object>.
    IF <object> IS ASSIGNED.
      rs_object-object = <object>.
    ENDIF.

    ASSIGN COMPONENT 'OBJ_NAME' OF STRUCTURE is_cts TO <obj_name>.
    IF <obj_name> IS ASSIGNED.
      rs_object-obj_name = <obj_name>.
    ELSE.
      ASSIGN COMPONENT 'OBJNAME' OF STRUCTURE is_cts TO <objname>.
      IF <objname> IS ASSIGNED.
        rs_object-obj_name = <objname>.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD to_ymd.
    DATA lv TYPE string.
    CLEAR rv_date.
    lv = iv_raw.
    REPLACE ALL OCCURRENCES OF '-' IN lv WITH ''.
    REPLACE ALL OCCURRENCES OF '/' IN lv WITH ''.
    CONDENSE lv NO-GAPS.
    IF strlen( lv ) >= 8.
      rv_date = lv(8).
    ENDIF.
  ENDMETHOD.


  METHOD build_csv.
    DATA: ls_req   TYPE ty_request,
          ls_obj   TYPE ty_object,
          lv_line  TYPE string,
          lt_lines TYPE string_table.

    APPEND
      |REQUEST,DESCRIPTION,CATEGORY,CLIENT,OWNER,STATUS,PGMID,OBJECT,OBJ_NAME,RETCODE,MESSAGE|
      TO lt_lines.

    LOOP AT it_requests INTO ls_req.
      IF ls_req-objects IS INITIAL.
        lv_line =
          |{ ls_req-request },{ csv_quote( ls_req-description ) },{ ls_req-category },| &&
          |{ ls_req-client },{ ls_req-owner },{ ls_req-status },,,,| &&
          |{ ls_req-retcode },{ csv_quote( ls_req-message ) }|.
        APPEND lv_line TO lt_lines.
        CONTINUE.
      ENDIF.

      LOOP AT ls_req-objects INTO ls_obj.
        lv_line =
          |{ ls_req-request },{ csv_quote( ls_req-description ) },{ ls_req-category },| &&
          |{ ls_req-client },{ ls_req-owner },{ ls_req-status },| &&
          |{ ls_obj-pgmid },{ ls_obj-object },{ csv_quote( ls_obj-obj_name ) },| &&
          |{ ls_req-retcode },{ csv_quote( ls_req-message ) }|.
        APPEND lv_line TO lt_lines.
      ENDLOOP.
    ENDLOOP.

    CONCATENATE LINES OF lt_lines INTO rv_csv
      SEPARATED BY cl_abap_char_utilities=>newline.
    rv_csv = |{ rv_csv }{ cl_abap_char_utilities=>newline }|.
  ENDMETHOD.


  METHOD csv_quote.
    DATA lv TYPE string.
    lv = iv_raw.
    IF lv CS ',' OR lv CS '"' OR lv CS cl_abap_char_utilities=>newline
       OR lv CS cl_abap_char_utilities=>cr_lf.
      REPLACE ALL OCCURRENCES OF '"' IN lv WITH '""'.
      rv_out = |"{ lv }"|.
    ELSE.
      rv_out = lv.
    ENDIF.
  ENDMETHOD.


  METHOD json_escape.
    rv_out = iv_raw.
    REPLACE ALL OCCURRENCES OF '\' IN rv_out WITH '\\'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_out WITH '\"'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN rv_out WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN rv_out WITH '\n'.
  ENDMETHOD.

ENDCLASS.
