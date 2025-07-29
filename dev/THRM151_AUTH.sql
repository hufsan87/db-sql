create or replace FUNCTION               THRM151_AUTH(    P_ENTER_CD IN VARCHAR2 ,
                                        P_SEARCH_TYPE   IN VARCHAR2 ,
                                        P_SABUN IN VARCHAR2,
                                        P_AUTH_GRP IN VARCHAR2,
                                        P_BASE_DATE IN VARCHAR2   DEFAULT TO_CHAR(SYSDATE,'YYYYMMDD'))
RETURN PKG_AUTH.THRM151_TYPE PIPELINED
AS
    V_CLOB      CLOB;
    lv_hrm151       THRM151%ROWTYPE;
    TYPE DYN_CURSOR_SQLSYNTAX IS REF CURSOR;
    --SQLSYNTAX_CSR DYN_CURSOR_SQLSYNTAX;
    SQLSYNTAX_CSR         SYS_REFCURSOR;
BEGIN

    IF P_SEARCH_TYPE = 'A' THEN
        V_CLOB := '(SELECT * FROM THRM151 WHERE ENTER_CD = ''' || P_ENTER_CD || ''')';
    ELSE

        BEGIN
            SELECT F_COM_GET_SQL_AUTH(P_ENTER_CD
                                                            , ''
                                                            , P_SEARCH_TYPE
                                                            , P_SABUN
                                                            , P_AUTH_GRP
                                                            , P_BASE_DATE
                                                            )
                INTO V_CLOB
            FROM DUAL
            ;
        END
        ;

    END IF
    ;

    OPEN SQLSYNTAX_CSR FOR V_CLOB;
    LOOP
        FETCH SQLSYNTAX_CSR INTO lv_hrm151;
        EXIT WHEN SQLSYNTAX_CSR%NOTFOUND;

        PIPE ROW(lv_hrm151);
    END LOOP
    ;

    -- 2022-05-23 mschoe UPDATE START
    -- CURSOR OPEN 후 CLOSE 하지 않은 오류 수정
    CLOSE SQLSYNTAX_CSR;
    -- 2022-05-23 mschoe UPDATE END

-- 2022-05-23 mschoe UPDATE START
-- CURSOR OPEN 후 CLOSE 하지 않은 오류 수정
EXCEPTION
    WHEN OTHERS THEN
        IF SQLSYNTAX_CSR%ISOPEN THEN
            CLOSE SQLSYNTAX_CSR;
        END IF;
-- 2022-05-23 mschoe UPDATE END
END;