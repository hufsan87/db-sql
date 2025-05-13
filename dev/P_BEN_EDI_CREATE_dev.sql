create or replace PROCEDURE P_BEN_EDI_CREATE (
         P_SQLCODE               OUT VARCHAR2, -- Error Code
         P_SQLERRM               OUT VARCHAR2, -- Error Messages
         P_ENTER_CD              IN  VARCHAR2, -- 회사코드
         P_DECLARATION_ORG_CD    IN  VARCHAR2, -- 기관코드
         P_DECLARATION_TYPE      IN  VARCHAR2, -- 신고유형
         P_TARGET_YMD            IN  VARCHAR2, -- 신고일
         P_APPLY_YMD_FROM        IN  VARCHAR2, -- 적용시작일자
         P_APPLY_YMD_TO          IN  VARCHAR2, -- 적용종료일자
         P_CHKID                 IN  VARCHAR2  -- 수정자
)
is

/********************************************************************************/
/*                    (c) Copyright ISU System. 2020                            */
/*                           All Rights Reserved                                */
/********************************************************************************/
/*  PROCEDURE NAME : P_BEN_EDI_CREATE                                           */
/*                   사회보험(국민연금/건강보험/고용보험) 신고대상자 기본값 저장          */
/*                                                                              */
/********************************************************************************/
/*  [ 참조 TABLE ]                                                                */
/*                                                                              */
/*                                                                              */
/********************************************************************************/
/*  [ 생성 TABLE ]                                                               */
/*                                                                              */
/*            사회보험신고 신고서항목값 ( TBEN047 )                                  */
/********************************************************************************/
/*  [ 삭제 TABLE ]                                                               */
/*                                                                              */
/*                                                                              */
/********************************************************************************/
/*  [ PRC 개요 ]                                                                 */
/*            지정 신고유형과 적용기간에 해당하는 대상자 조회                           */
/*                조회 대상사 사회보험 신고서항목값 테이블에 등록 처리                   */
/*                END;                                                          */
/*            END;                                                              */
/*                                                                              */
/********************************************************************************/
/*  [ PRC 호출 ]                                                                */
/*                                                                              */
/********************************************************************************/
/* Date        In Charge       Description                                      */
/*------------------------------------------------------------------------------*/
/* 2020-03-12  Gwanjae.Yoo     Initial Release                                  */
/********************************************************************************/

   /* Local Variables */
   lv_biz_cd                  TSYS903.BIZ_CD%TYPE    := 'BEN';
   lv_object_nm               TSYS903.OBJECT_NM%TYPE := 'P_BEN_EDI_CREATE';
   
   lv_loop_count              NUMBER := 0;
   lv_seq_element_type_cnt    NUMBER := 0;

BEGIN

    /* 0. 실행결과값 초기화 */
    P_SQLCODE  := NULL;
    P_SQLERRM  := NULL;

    /* 1. 대상자 생성 프로시져 실행 */
    P_BEN_EDI_EMP_INS(
          P_SQLCODE
        , P_SQLERRM
        , P_ENTER_CD
        , P_DECLARATION_ORG_CD
        , P_DECLARATION_TYPE
        , P_TARGET_YMD
        , P_APPLY_YMD_FROM
        , P_APPLY_YMD_TO
        , P_CHKID
    );
    
    /* 대상자 생성 프로시져가 정상 처리된 경우 생성된 대상자에 대한 기본값 저장 실행 */
    IF P_SQLCODE IS NULL AND P_SQLERRM IS NULL THEN
    
        /* 신고서 입력항목에 순번 타입이 있는지 조회 */
        SELECT COUNT(E1.ELEMENT_TYPE) INTO lv_seq_element_type_cnt
          FROM TBEN043 E1
             , TBEN041 T1
         WHERE E1.ENTER_CD           = T1.ENTER_CD
           AND E1.DECLARATION_ORG_CD = T1.DECLARATION_ORG_CD
           AND E1.DECLARATION_TYPE   = T1.DECLARATION_TYPE
           AND E1.USE_SDATE          = T1.USE_SDATE
           AND E1.ENTER_CD           = P_ENTER_CD
           AND E1.DECLARATION_ORG_CD = P_DECLARATION_ORG_CD
           AND E1.DECLARATION_TYPE   = P_DECLARATION_TYPE
           AND E1.ELEMENT_TYPE       = 'SEQ'
           AND TO_DATE(P_TARGET_YMD, 'YYYYMMDD') BETWEEN TO_DATE(T1.USE_SDATE, 'YYYYMMDD') AND TO_DATE(NVL(T1.USE_EDATE, '99991231'), 'YYYYMMDD')
        ;
        
        /* P_BEN_EDI_EMP_INS 프로시저 실행으로 생성된 대상자 목록을 조회하여 기본값 저장 */
        /* 커서 선언 */
        DECLARE CURSOR CUR_TARGET IS
                SELECT A.ENTER_CD
                     , A.DECLARATION_ORG_CD
                     , A.DECLARATION_TYPE
                     , A.TARGET_YMD
                     , A.SABUN
                     , B.NAME
                     , B.RES_NO
                  FROM (
                            SELECT ENTER_CD, DECLARATION_ORG_CD, DECLARATION_TYPE, TARGET_YMD, SABUN
                              FROM TBEN047 X
                             WHERE X.ENTER_CD           = P_ENTER_CD
                               AND X.DECLARATION_ORG_CD = P_DECLARATION_ORG_CD
                               AND X.DECLARATION_TYPE   = P_DECLARATION_TYPE
                               AND X.TARGET_YMD         = P_TARGET_YMD
                               AND X.SABUN NOT IN  (SELECT E.SABUN
                                                     FROM TBEN045 T, TBEN047 E
                                                     WHERE   T.ENTER_CD             = E.ENTER_CD
                                                       AND T.DECLARATION_ORG_CD   = E.DECLARATION_ORG_CD 
                                                       AND T.DECLARATION_TYPE     = E.DECLARATION_TYPE
                                                       AND T.TARGET_YMD           = E.TARGET_YMD
                                                       AND T.ENTER_CD             = P_ENTER_CD
                                                       AND T.DECLARATION_ORG_CD   = P_DECLARATION_ORG_CD
                                                       AND T.DECLARATION_TYPE     = P_DECLARATION_TYPE
                                                       AND E.ELEMENT_NM           LIKE '%신고여부%'
                                                       AND E.ELEMENT_VAL          IN ('10', '30') --신고, 신고제외
                                                       AND E.TARGET_YMD           = X.TARGET_YMD
                                                       AND E.SABUN                = X.SABUN                                 
                                                )                                
                             GROUP BY ENTER_CD, DECLARATION_ORG_CD, DECLARATION_TYPE, TARGET_YMD, SABUN
                       ) A
                     , THRM100 B
                 WHERE A.ENTER_CD = B.ENTER_CD
                   AND A.SABUN    = B.SABUN
                 ORDER BY DECODE(lv_seq_element_type_cnt, 0, A.SABUN, CRYPTIT.DECRYPT(B.RES_NO, B.ENTER_CD))
                ;
        BEGIN
        
            lv_loop_count := 1;
            
            -- LOOP 시작
            FOR ITEM IN CUR_TARGET LOOP
                EXIT WHEN CUR_TARGET%NOTFOUND;

                BEGIN
                
                    -- MERGE DATA
                    MERGE INTO TBEN047 T
                    USING (
                            SELECT E.ENTER_CD
                                 , E.DECLARATION_ORG_CD
                                 , E.DECLARATION_TYPE
                                 , P_TARGET_YMD AS TARGET_YMD
                                 , ITEM.SABUN AS SABUN
                                 , E.ELEMENT_NM
                                 , E.ELEMENT_TYPE
                                 , CASE WHEN E.ELEMENT_TYPE = 'RESNO' THEN ITEM.RES_NO
                                        WHEN E.ELEMENT_TYPE = 'NAME'  THEN ITEM.NAME
                                        WHEN E.ELEMENT_TYPE = 'SEQ'   THEN TO_CHAR(lv_loop_count)
                                        WHEN E.SQL_SYNTAX IS NOT NULL THEN F_BEN_GET_EDI_VAL_SQL(E.ENTER_CD, E.DECLARATION_ORG_CD, E.DECLARATION_TYPE, P_TARGET_YMD, ITEM.SABUN, E.ELEMENT_NM)
                                        ELSE
                                             DECODE(E.ELEMENT_FIX_VALUE, NULL, DECODE(E.ELEMENT_DEFAULT_VALUE, NULL, NULL, E.ELEMENT_DEFAULT_VALUE), E.ELEMENT_FIX_VALUE)
                                   END AS ELEMENT_VAL
                                 , DECODE(E.ELEMENT_TYPE, 'RESNO', 'Y', 'N') AS ENCRYPT_YN
                                 , P_CHKID AS CHKID
                              FROM TBEN043 E
                                 , TBEN041 T
                             WHERE E.ENTER_CD           = T.ENTER_CD
                               AND E.DECLARATION_ORG_CD = T.DECLARATION_ORG_CD
                               AND E.DECLARATION_TYPE   = T.DECLARATION_TYPE
                               AND E.ENTER_CD           = P_ENTER_CD
                               AND E.DECLARATION_ORG_CD = P_DECLARATION_ORG_CD
                               AND E.DECLARATION_TYPE   = P_DECLARATION_TYPE
                               AND TO_DATE(P_TARGET_YMD, 'YYYYMMDD') BETWEEN TO_DATE(E.USE_SDATE, 'YYYYMMDD') AND TO_DATE(NVL(T.USE_EDATE, '99991231'), 'YYYYMMDD')
                          ) S
                       ON (
                                   T.ENTER_CD           = S.ENTER_CD
                               AND T.DECLARATION_ORG_CD = S.DECLARATION_ORG_CD
                               AND T.DECLARATION_TYPE   = S.DECLARATION_TYPE
                               AND T.TARGET_YMD         = S.TARGET_YMD
                               AND T.SABUN              = S.SABUN
                               AND T.ELEMENT_NM         = S.ELEMENT_NM
                          )
                    WHEN MATCHED THEN
                         UPDATE SET
                                T.CHKDATE      = SYSDATE
                              , T.CHKID        = S.CHKID
                              , T.ELEMENT_VAL  = S.ELEMENT_VAL
                              , T.ENCRYPT_YN   = S.ENCRYPT_YN
                              , T.ELEMENT_TYPE = S.ELEMENT_TYPE
                    WHEN NOT MATCHED THEN
                         INSERT (
                               T.ENTER_CD
                             , T.DECLARATION_ORG_CD
                             , T.DECLARATION_TYPE
                             , T.TARGET_YMD
                             , T.SABUN
                             , T.ELEMENT_NM
                             , T.ELEMENT_VAL
                             , T.ENCRYPT_YN
                             , T.ELEMENT_TYPE
                             , T.CHKDATE
                             , T.CHKID
                         ) VALUES (
                               S.ENTER_CD
                             , S.DECLARATION_ORG_CD
                             , S.DECLARATION_TYPE
                             , S.TARGET_YMD
                             , S.SABUN
                             , S.ELEMENT_NM
                             , S.ELEMENT_VAL
                             , S.ENCRYPT_YN
                             , S.ELEMENT_TYPE
                             , SYSDATE
                             , S.CHKID
                         )
                    ;
                    
                    lv_loop_count := lv_loop_count + 1;
                
                EXCEPTION
                    WHEN OTHERS THEN
                      ROLLBACK;
                      P_SQLCODE := TO_CHAR(SQLCODE);
                      P_SQLERRM := '기본값 저장 Error ' || SQLERRM;
                      P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'40', P_SQLERRM, P_CHKID);
                      RETURN;
                END;
            END LOOP;
            -- 종료 LOOP

        END;
    
        COMMIT;
        
    END IF;

EXCEPTION
WHEN OTHERS THEN
   ROLLBACK;
   P_SQLCODE := TO_CHAR(SQLCODE);
   P_SQLERRM := '사회보험(국민연금/건강보험/고용보험) 신고대상자 생성 및 데이타 등록 Error ' || SQLERRM;
   P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm, '100', P_SQLERRM, P_CHKID);

END P_BEN_EDI_CREATE;