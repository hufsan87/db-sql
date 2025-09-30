create or replace PACKAGE BODY            "PKG_COM_INTERFACE_BEN_API"
IS


-- 생수불출내역
PROCEDURE INT_P_TBEN592 (
                    P_SQLCODE          OUT VARCHAR2,  -- Error Code
                    P_SQLERRM          OUT VARCHAR2,  -- Error Messages
                    P_INTF_CD          IN  VARCHAR2,  -- 인터페이스 코드
                    P_INTF_SEQ         IN  VARCHAR2,  -- 인터페이스 순번
                    P_INTF_SDATE       IN  VARCHAR2,  -- 인터페이스 일자
                    P_CHK_ENTER_CD     IN  VARCHAR2,  -- 수정자회사코드
                    P_CHKID            IN  VARCHAR2   -- 수정자
            )

IS

/********************************************************************************/
/*                                                                              */
/*                    (c) Copyright ISU System Inc. 2023                        */
/*                           All Rights Reserved                                */
/*                                                                              */
/********************************************************************************/
/*  PROCEDURE NAME : INT_P_TBEN592                                               */
/*                   생수불출내역                                                 */
/********************************************************************************/
/*  [ 참조 TABLE ]                                                               */
/*                                                                              */
/*                                                                              */
/********************************************************************************/
/*  [ 생성 TABLE ]                                                               */
/*                                                                              */
/*            TBEN592(생수불출 포인트 내역),TBEN593(생수불출 용량별 내역)              */
/********************************************************************************/
/*  [ 삭제 TABLE ]                                                              */
/*                                                                              */
/*                                                                              */
/********************************************************************************/
/*  [ PRC 개요 ]
       ----------------------------------------------
       -- 1. 생수불출 포인트 내역 자료(INT_TBEN592) CURSOR 생성
       -- 2. 생수불출 용량별 내역 자료(INT_TBEN593) CURSOR 생성
       -- 3. Data별 관련 테이블에 반영 작업
       -- 3.1 생수불출 포인트 내역(TBEN592) 등록
       -- 3.2 생수불출 용량별 내역(TBEN593) 등록
       -- 4. Error 내용 존재시 Log 테이블에 등록
       -- 5. 인터페이스 건수 업데이트
       -- 6. 인터페이스 DB 처리 종료시간 업데이트
       ----------------------------------------------
*/
/********************************************************************************/
/*  [ PRC 호출 ]                                                                */
/*                                                                              */
/*                                                                              */
/********************************************************************************/
/* Date        In Charge       Description                                      */
/*------------------------------------------------------------------------------*/
/* 2023-09-25                  Initial Release                                  */
/********************************************************************************/
    lv_error_tmp    THRI_TMP_LOG.MEMO%TYPE; -- Error Log 내용(KEY)
    lv_error_log    THRI_TMP_LOG.MEMO%TYPE; -- Error Log 내용
    lv_object_nm    TSYS903.OBJECT_NM%TYPE := 'INT_P_TBEN592';
    lv_table_nm     VARCHAR2(100)          := 'TBEN592';
    lv_json_real_cnt NUMBER                := 0;

    ----------------------------------------------
    -- 1. 생수불출 포인트 내역 자료(INT_TBEN592) CURSOR 생성
    ----------------------------------------------
    CURSOR CSR_POINT_DATA IS
      SELECT  P_CHK_ENTER_CD            AS ENTER_CD
            , RECEIVE_EMP_NO            AS SABUN
            , RECEIVE_DATE              AS RECEIVE_DATE
            , RECEIVE_TIME              AS RECEIVE_TIME
            , RECEIVE_TYPE              AS RECEIVE_TYPE
            , SUM(WATER_POINT)          AS WATER_POINT
        FROM INT_TBEN592
       WHERE INTF_SEQ       = P_INTF_SEQ
         AND INTF_SDATE     = NVL(P_INTF_SDATE,TO_CHAR(SYSDATE, 'YYYYMMDD'))
         AND RECEIVE_TYPE   in ('M','C') -- 직접수령(모바일, 하치장)
       GROUP BY RECEIVE_EMP_NO, RECEIVE_DATE, RECEIVE_TIME, RECEIVE_TYPE
      ORDER BY RECEIVE_EMP_NO;

    ----------------------------------------------
    -- 2. 생수불출 용량별 내역 자료(INT_TBEN593) CURSOR 생성
    ----------------------------------------------
    CURSOR CSR_BOX_DATA IS
      SELECT  INTF_ROW_NUM              AS INTF_ROW_NUM
            , INTF_SEQ                  AS INTF_SEQ
            , INTF_SDATE                AS INTF_SDATE
            , P_CHK_ENTER_CD            AS ENTER_CD
            , RECEIVE_EMP_NO            AS SABUN
            , RECEIVE_DATE              AS RECEIVE_DATE    --수령일자
            , RECEIVE_TIME              AS RECEIVE_TIME    --수령시간
            , RECEIVE_TYPE              AS RECEIVE_TYPE    --수령타입(M:모바일,D:택배,C:하치장PC
            , WATER_TYPE                AS WATER_TYPE      --생수타입(1.5L/500ml/0.33ml)
            , WATER_BOX                 AS WATER_BOX       --수령박스수
            , WATER_POINT               AS WATER_POINT     --차감포인트
        FROM INT_TBEN592
       WHERE INTF_SEQ       = P_INTF_SEQ
         AND INTF_SDATE     = NVL(P_INTF_SDATE,TO_CHAR(SYSDATE, 'YYYYMMDD'))
         AND RECEIVE_TYPE   in ('M','C') -- 직접수령(모바일, 하치장)
      ORDER BY RECEIVE_EMP_NO;


BEGIN
-----------------------------------------------------------------------------------
P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, P_INTF_CD,'00', 'Object :'||lv_object_nm||'start...', P_CHKID);
-----------------------------------------------------------------------------------

        p_sqlcode  := NULL;
        p_sqlerrm  := NULL;

       ----------------------------------------------
       -- 3. Data별 관련 테이블에 반영 작업
       ----------------------------------------------
       FOR C_P_DATA IN CSR_POINT_DATA LOOP
          -- Error Log 변수 초기화
          lv_error_log := NULL;
          lv_error_tmp := '사번(' || to_char(C_P_DATA.SABUN) || ')';

          BEGIN
P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, lv_object_nm||'TEST','100',C_P_DATA.RECEIVE_DATE||C_P_DATA.RECEIVE_TIME, P_CHKID);
             ----------------------------------------------
             -- 3.1 생수불출 포인트 내역(TBEN592) 등록
             ----------------------------------------------
             MERGE INTO TBEN592 T
                USING   (
                            SELECT    C_P_DATA.ENTER_CD                               AS ENTER_CD         --회사구분(TORG900)
                                    , C_P_DATA.SABUN                                  AS SABUN            --사원번호
                                    , SUBSTR(C_P_DATA.RECEIVE_DATE,0,6)               AS BAS_YM           --포인트적용년월
                                    , C_P_DATA.RECEIVE_DATE                           AS USE_YMD          --사용일자
                                    , DECODE(C_P_DATA.RECEIVE_TYPE ,'M','01','C','03', C_P_DATA.RECEIVE_TYPE)    AS USE_GB           --수령방법(01 직접수령, 02 택배)
                                    , C_P_DATA.RECEIVE_DATE||C_P_DATA.RECEIVE_TIME    AS USE_SEQ          --일련번호
                                    , C_P_DATA.WATER_POINT                            AS USE_POINT        --사용포인트
                                    , SYSDATE                                         AS CHKDATE          --최종수정시간
                              FROM   DUAL
                    ) S
                    ON ( T.ENTER_CD     = S.ENTER_CD
                    AND T.SABUN         = S.SABUN
                    AND T.BAS_YM        = S.BAS_YM
                    AND T.USE_GB        = S.USE_GB
                    AND T.USE_SEQ       = S.USE_SEQ
                    )
                WHEN MATCHED THEN
                    UPDATE SET
                                  T.USE_POINT       = S.USE_POINT
                                , T.CHKID           = P_CHKID
                                , T.CHKDATE         = S.CHKDATE
                WHEN NOT MATCHED THEN
                    INSERT
                    (
                          T.ENTER_CD
                        , T.SABUN
                        , T.BAS_YM
                        , T.USE_YMD
                        , T.USE_GB
                        , T.USE_SEQ
                        , T.USE_POINT
                        , T.CHKID
                        , T.CHKDATE
                    )
                    VALUES
                    (
                          S.ENTER_CD
                        , S.SABUN
                        , S.BAS_YM
                        , S.USE_YMD
                        , S.USE_GB
                        , S.USE_SEQ
                        , S.USE_POINT
                        , P_CHKID
                        , S.CHKDATE
                    );

                    lv_json_real_cnt := lv_json_real_cnt + 1;
          EXCEPTION
             WHEN DUP_VAL_ON_INDEX THEN
                lv_error_log := lv_error_log || (CASE WHEN lv_error_log IS NULL THEN '' ELSE CHR(10) END) ||
                                      lv_error_tmp || ' ==> 생수불출 포인트 내역등록 시 중복된 자료 존재';
                P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, lv_object_nm,'101',lv_error_log, P_CHKID);
             WHEN INVALID_NUMBER THEN
                lv_error_log := lv_error_log || (CASE WHEN lv_error_log IS NULL THEN '' ELSE CHR(10) END) ||
                                      lv_error_tmp || ' ==> 생수불출 포인트 내역등록 시 숫자로 변환 될 수 없는 값이 존재';
                P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, lv_object_nm,'102',lv_error_log, P_CHKID);
             WHEN ROWTYPE_MISMATCH THEN
                lv_error_log := lv_error_log || (CASE WHEN lv_error_log IS NULL THEN '' ELSE CHR(10) END) ||
                                      lv_error_tmp || ' ==> 생수불출 포인트 내역등록 시 잘못된 Data Type 값이 존재';
                P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, lv_object_nm,'103',lv_error_log, P_CHKID);
             WHEN VALUE_ERROR THEN
                lv_error_log := lv_error_log || (CASE WHEN lv_error_log IS NULL THEN '' ELSE CHR(10) END) ||
                                      lv_error_tmp || ' ==> 생수불출 포인트 내역등록 시 잘못된 Data의 길이가 맞지 않는 값이 존재';
                P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, lv_object_nm,'104',lv_error_log, P_CHKID);
             WHEN OTHERS THEN
                lv_error_log := lv_error_log || (CASE WHEN lv_error_log IS NULL THEN '' ELSE CHR(10) END) ||
                                      lv_error_tmp || ' ==> 생수불출 포인트 내역등록 시 ' || SQLERRM;
                P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, lv_object_nm,'105',lv_error_log, P_CHKID);
          END;
         -------------------------
         COMMIT;
         -------------------------
       END LOOP;   -- END LOOP CSR_DATA


       FOR C_DATA IN CSR_BOX_DATA LOOP
          -- Error Log 변수 초기화
          lv_error_log := NULL;
          lv_error_tmp := '사번(' || to_char(C_DATA.SABUN) || ')';

          BEGIN
             ----------------------------------------------
             -- 3.2 생수불출 용량별 내역(TBEN593) 등록
             ----------------------------------------------
             MERGE INTO TBEN593 T
                USING   (
                            SELECT    C_DATA.ENTER_CD                                               AS ENTER_CD         --회사구분(TORG900)
                                    , C_DATA.SABUN                                                  AS SABUN            --사원번호
                                    , SUBSTR(C_DATA.RECEIVE_DATE,0,6)                               AS BAS_YM           --포인트적용년월
                                    , DECODE(C_DATA.RECEIVE_TYPE ,'M','01','C','03', C_DATA.RECEIVE_TYPE)    AS USE_GB           --수령방법(01 직접수령, 02 택배)
                                    , C_DATA.RECEIVE_DATE||C_DATA.RECEIVE_TIME                      AS USE_SEQ          --일련번호
                                    , DECODE(C_DATA.WATER_TYPE, '330ml','01', '500ml','02', '1.5L','03', '5G/L','04','190ml','05', C_DATA.WATER_TYPE)  AS USE_LT_CD        --사용포인트, 190ml 추가 2025.09.30
                                    , C_DATA.WATER_BOX                                              AS USE_LT_CNT       --사용포인트
                                    , SYSDATE                                                       AS CHKDATE          --최종수정시간
                              FROM   DUAL
                    ) S
                    ON ( T.ENTER_CD     = S.ENTER_CD
                    AND T.SABUN         = S.SABUN
                    AND T.BAS_YM        = S.BAS_YM
                    AND T.USE_GB        = S.USE_GB
                    AND T.USE_SEQ       = S.USE_SEQ
                    AND T.USE_LT_CD     = S.USE_LT_CD
                    )
                WHEN MATCHED THEN
                    UPDATE SET
                                  T.USE_LT_CNT      = S.USE_LT_CNT
                                , T.CHKID           = P_CHKID
                                , T.CHKDATE         = S.CHKDATE
                WHEN NOT MATCHED THEN
                    INSERT
                    (
                          T.ENTER_CD
                        , T.SABUN
                        , T.BAS_YM
                        , T.USE_GB
                        , T.USE_SEQ
                        , T.USE_LT_CD
                        , T.USE_LT_CNT
                        , T.CHKID
                        , T.CHKDATE
                    )
                    VALUES
                    (
                          S.ENTER_CD
                        , S.SABUN
                        , S.BAS_YM
                        , S.USE_GB
                        , S.USE_SEQ
                        , S.USE_LT_CD
                        , S.USE_LT_CNT
                        , P_CHKID
                        , S.CHKDATE
                    );

                    lv_json_real_cnt := lv_json_real_cnt + 1;
          EXCEPTION
             WHEN DUP_VAL_ON_INDEX THEN
                lv_error_log := lv_error_log || (CASE WHEN lv_error_log IS NULL THEN '' ELSE CHR(10) END) ||
                                      lv_error_tmp || ' ==> 생수불출 용량별 내역 등록 시 중복된 자료 존재';
                P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, lv_object_nm,'201',lv_error_log, P_CHKID);
             WHEN INVALID_NUMBER THEN
                lv_error_log := lv_error_log || (CASE WHEN lv_error_log IS NULL THEN '' ELSE CHR(10) END) ||
                                      lv_error_tmp || ' ==> 생수불출 용량별 내역 등록 시 숫자로 변환 될 수 없는 값이 존재';
                P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, lv_object_nm,'202',lv_error_log, P_CHKID);
             WHEN ROWTYPE_MISMATCH THEN
                lv_error_log := lv_error_log || (CASE WHEN lv_error_log IS NULL THEN '' ELSE CHR(10) END) ||
                                      lv_error_tmp || ' ==> 생수불출 타입별 내역등록 시 잘못된 Data Type 값이 존재';
                P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, lv_object_nm,'203',lv_error_log, P_CHKID);
             WHEN VALUE_ERROR THEN
                lv_error_log := lv_error_log || (CASE WHEN lv_error_log IS NULL THEN '' ELSE CHR(10) END) ||
                                      lv_error_tmp || ' ==> 생수불출 타입별 내역등록 시 잘못된 Data의 길이가 맞지 않는 값이 존재';
                P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, lv_object_nm,'204',lv_error_log, P_CHKID);
             WHEN OTHERS THEN
                lv_error_log := lv_error_log || (CASE WHEN lv_error_log IS NULL THEN '' ELSE CHR(10) END) ||
                                      lv_error_tmp || ' ==> 생수불출 타입별 내역등록 시 ' || SQLERRM;
                P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, lv_object_nm,'205',lv_error_log, P_CHKID);
          END;

        ----------------------------------------------
        -- 4. Error 내용 존재시 Log 테이블에 등록
        ----------------------------------------------
        IF lv_error_log IS NOT NULL THEN
            P_COM_INTERFACE_LOG(    C_DATA.INTF_SEQ
                                    ,C_DATA.INTF_SDATE
                                    ,P_INTF_CD
                                    ,C_DATA.ENTER_CD
                                    ,lv_table_nm
                                    ,lv_error_log
                                    ,P_CHKID);
            -- 해당 작업진행상태 UPDATE
            UPDATE INT_TBEN592 SET INTF_SUCCESS_FLAG = 'ERROR', ERR_MSG = lv_error_log
             WHERE INTF_SEQ     = C_DATA.INTF_SEQ
               AND INTF_SDATE   = C_DATA.INTF_SDATE
               AND INTF_ROW_NUM = C_DATA.INTF_ROW_NUM
               ;

         ELSE
            UPDATE INT_TBEN592 SET INTF_SUCCESS_FLAG = 'SUCCESS'
             WHERE INTF_SEQ     = C_DATA.INTF_SEQ
               AND INTF_SDATE   = C_DATA.INTF_SDATE
               AND INTF_ROW_NUM = C_DATA.INTF_ROW_NUM
               ;
         END IF;
         -------------------------
         COMMIT;
         -------------------------

       END LOOP;   -- END LOOP CSR_DATA

       ----------------------------------------------
       -- 5. 인터페이스 건수 업데이트
       ----------------------------------------------
       PKG_COM_INTERFACE_SYS_API.INT_P_JSON_REAL_CNT_UPDATE(P_SQLCODE, P_SQLERRM, P_INTF_CD, P_INTF_SEQ, P_INTF_SDATE, lv_json_real_cnt, P_CHK_ENTER_CD, P_CHKID);
       ----------------------------------------------
       -- 6. 인터페이스 DB 처리 종료시간 업데이트
       ----------------------------------------------
       PKG_COM_INTERFACE_SYS_API.INT_P_TIME_UPDATE(P_SQLCODE, P_SQLERRM, P_INTF_CD, P_INTF_SEQ, P_INTF_SDATE, 'E', P_CHK_ENTER_CD, P_CHKID);

-----------------------------------------------------------------------------------
P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, P_INTF_CD,'01', 'Object :'||lv_object_nm||'end...', P_CHKID);
-----------------------------------------------------------------------------------

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      P_SQLCODE := P_SQLCODE;
      P_SQLERRM := NVL(P_SQLERRM,SQLERRM);
      P_COM_SET_LOG(P_CHK_ENTER_CD, g_biz_cd, lv_object_nm,'00', P_SQLERRM, P_CHKID);

END INT_P_TBEN592;

END PKG_COM_INTERFACE_BEN_API;