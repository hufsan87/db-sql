create or replace FUNCTION           "F_TIM_GET_DAY_GNT_CD" (
                     P_ENTER_CD           IN VARCHAR2,  -- 회사코드
                     P_SABUN              IN VARCHAR2,  -- 사원번호
                     P_YMD                IN VARCHAR2   -- 일자
)
   RETURN VARCHAR2
IS
/********************************************************************************/
/*                    (c) Copyright ISU System Inc. 2004                        */
/*                           All Rights Reserved                                */
/********************************************************************************/
/*  FUNCTION NAME : F_TIM_GET_DAY_GNT_CD                                       */
/*             일자에 해당하는 근태코드  Return      */
/********************************************************************************/
/*  [ FNC 개요 ]                                                                */
/*   해당 일자, 사번의 근태정보 RETURN        */
/********************************************************************************/
/*  [ PRC,FNC 호출 ]                                                            */
/********************************************************************************/
/* Date        In Charge       Description                                      */
/*------------------------------------------------------------------------------*/
/* 2016-11-03                               */
/********************************************************************************/
    -- Local Variables
    lv_ret_value VARCHAR2(500);

    lv_biz_cd        TSYS903.BIZ_CD%TYPE := 'TIM';
    lv_object_nm    TSYS903.OBJECT_NM%TYPE := 'F_TIM_GET_DAY_GNT_CD';

    CURSOR CSR_GNT IS
       SELECT RANK() OVER (ORDER BY A.GNT_CD, A.YMD) AS NUM
            , A.GNT_CD
            , (SELECT GNT_NM FROM TTIM014 WHERE ENTER_CD = A.ENTER_CD AND GNT_CD = A.GNT_CD) AS GNT_NM
         FROM TTIM405 A , THRI103 B, TTIM301 C
        WHERE A.ENTER_CD = B.ENTER_CD
          AND A.APPL_SEQ = B.APPL_SEQ
          AND A.ENTER_CD = C.ENTER_CD
          AND A.APPL_SEQ = C.APPL_SEQ
          AND NVL(A.UPDATE_YN,'N') = 'N'
          AND B.APPL_STATUS_CD = '99'
          AND A.ENTER_CD = P_ENTER_CD
          AND A.SABUN    = P_SABUN
          AND A.YMD      = P_YMD  ;

BEGIN
    lv_ret_value := '';

    FOR C_GNT IN CSR_GNT LOOP
        IF C_GNT.NUM > 1 THEN
            lv_ret_value := lv_ret_value || ',' ;
        END IF;
        lv_ret_value := lv_ret_value || C_GNT.GNT_CD;
    END LOOP;
    RETURN lv_ret_value;

   EXCEPTION
      WHEN OTHERS THEN
         --P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'100',sqlcode || ' => ' || sqlerrm, P_CHKID);
         RETURN '';
END F_TIM_GET_DAY_GNT_CD;