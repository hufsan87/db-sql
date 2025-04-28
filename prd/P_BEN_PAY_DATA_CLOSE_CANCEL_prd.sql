create or replace PROCEDURE             "P_BEN_PAY_DATA_CLOSE_CANCEL" (
    P_SQLCODE                OUT VARCHAR2,         -- Error Code
    P_SQLERRM                OUT VARCHAR2,         -- Error Messages
    P_ENTER_CD              IN  VARCHAR2,         -- 회사코드
    P_PAY_ACTION_CD         IN  VARCHAR2,         -- 급여계산코드
    P_BUSINESS_PLACE_CD     IN  VARCHAR2,         -- 급여사업장코드
    P_BENEFIT_BIZ_CD        IN  VARCHAR2,         -- 복리후생업무코드
    P_CHKID                 IN  VARCHAR2          -- 수정자
)
IS
/********************************************************************************/
/*                    (c) Copyright ISU System Inc. 2016                        */
/*                           All Rights Reserved                                */
/********************************************************************************/
/*  PROCEDURE NAME : P_BEN_PAY_DATA_CLOSE_CANCEL                                */
/*                   복리후생업무구분별 작업내역 마감취소                            */
/********************************************************************************/
/*  [ 참조 TABLE ]                                                              */
/*     TORG109 : 조직맵핑항목관리                                                 */
/********************************************************************************/
/*  [ 생성 TABLE ]                                                              */
/*     TBEN991 : 복리후생마감관리                                                 */
/********************************************************************************/
/*  [ 삭제 TABLE ]                                                              */
/*                                                                              */
/********************************************************************************/
/*  [ PRC 개요 ]                                                                */
/*                                                                              */
/*      복리후생 업무구분별, 급여기준사업장별로 마감 취소                             */
/*                                                                              */
/********************************************************************************/
/*  [ PRC 호출 ]                                                                */
/********************************************************************************/
/* Date        In Charge       Description                                      */
/*------------------------------------------------------------------------------*/
/* 2016-08-11  VONG HA IK    Initial Release                                  */
/********************************************************************************/
 lv_biz_cd       TSYS903.BIZ_CD%TYPE    := 'CPN';
 lv_object_nm    TSYS903.OBJECT_NM%TYPE := 'P_BEN_PAY_DATA_CLOSE_CANCEL';
 lv_cpn201       TCPN201%ROWTYPE;

 LV_CLOSE_ST      TBEN991.CLOSE_ST%TYPE; -- 마감상태(S90003)

 LV_PAY_CLOSE_YN  VARCHAR2(1); --급여마감상태

    /* 급여기준사업장별 작업
    */
    CURSOR CSR_MAP IS
        SELECT X.MAP_CD AS BUSINESS_PLACE_CD
             , X.MAP_NM
          FROM TORG109 X
         WHERE X.ENTER_CD = P_ENTER_CD
            AND X.MAP_TYPE_CD = '100' -- 급여기준사업장
            AND DECODE(P_BUSINESS_PLACE_CD,NULL,'%',X.MAP_CD) =
                 DECODE(P_BUSINESS_PLACE_CD,NULL,'%',P_BUSINESS_PLACE_CD);

BEGIN
   P_SQLCODE    := NULL;
   P_SQLERRM    := NULL;

  -- 급여계산일자 정보가져오기
   lv_cpn201 := F_CPN_GET_201_INFO(P_ENTER_CD, P_PAY_ACTION_CD);

    --급여마감여부 확인하기
    BEGIN
      SELECT CLOSE_YN
        INTO LV_PAY_CLOSE_YN
        FROM TCPN981
       WHERE ENTER_CD      = P_ENTER_CD
         AND PAY_ACTION_CD = P_PAY_ACTION_CD
         ;
    EXCEPTION
       WHEN NO_DATA_FOUND THEN
          LV_PAY_CLOSE_YN := 'N';
       WHEN OTHERS        THEN
          ROLLBACK;
          P_SQLCODE := TO_CHAR(SQLCODE);
          P_SQLERRM := '급여일자코드 : '     || P_PAY_ACTION_CD
                    || ' 의 급여마감(TCPN981)여부 검색시 Error =>' || SQLERRM;
         P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'10',P_SQLERRM, P_CHKID);
    END;

    --급여가 마감된 경우, 복리후생 마감업무 처리를 할 수 없음.
    IF LV_PAY_CLOSE_YN = 'Y' THEN
       P_SQLCODE  := '999';
       P_SQLERRM  := '해당 급여가 이미 마감되었습니다. 마감된 급여에 대한 마감은 진행할 수 없습니다. 급여 담당자와 해당 급여의 마감여부를 확인해보시기 바랍니다.';
       RETURN;
    END IF;

    -- 마감상태(S90003)('10001':작업전, '10003':작업완료(마감전), '10005':마감)
    LV_CLOSE_ST := '10003';
    /* 급여사업장 별 작업  */
    FOR C_MAP IN CSR_MAP LOOP
        BEGIN
            MERGE INTO TBEN991 A
            USING ( SELECT  P_ENTER_CD       AS ENTER_CD,
                            P_PAY_ACTION_CD  AS PAY_ACTION_CD,
                            P_BENEFIT_BIZ_CD AS BENEFIT_BIZ_CD,
                            C_MAP.BUSINESS_PLACE_CD AS BUSINESS_PLACE_CD,
                            TO_CHAR(SYSDATE, 'YYYYMMDD') AS WORK_SYMD,
                            SYSDATE          AS CHKDATE,
                            P_CHKID          AS CHKID
                      FROM  DUAL    ) B
               ON (     A.ENTER_CD      = B.ENTER_CD
                   AND  A.PAY_ACTION_CD = B.PAY_ACTION_CD
                   AND  A.BENEFIT_BIZ_CD    = B.BENEFIT_BIZ_CD
                   AND  A.BUSINESS_PLACE_CD = B.BUSINESS_PLACE_CD  )
            WHEN MATCHED THEN
                UPDATE SET  A.CLOSE_ST = LV_CLOSE_ST, -- 마감상태(S90003)('10001':작업전, '10003':작업완료(마감전), '10005':마감)
                            A.CHKDATE  = SYSDATE,
                            A.CHKID    = P_CHKID
            WHEN NOT MATCHED THEN
                INSERT
                (
                 ENTER_CD, PAY_ACTION_CD, BUSINESS_PLACE_CD, BENEFIT_BIZ_CD, CLOSE_ST, CHKDATE, CHKID
                )
                VALUES
                (
                 B.ENTER_CD, B.PAY_ACTION_CD, B.BUSINESS_PLACE_CD, B.BENEFIT_BIZ_CD, LV_CLOSE_ST, B.CHKDATE, B.CHKID
                );

        EXCEPTION
           WHEN NO_DATA_FOUND THEN
              NULL;
           WHEN OTHERS        THEN
              ROLLBACK;
              P_SQLCODE := TO_CHAR(SQLCODE);
              P_SQLERRM := '급여일자코드 : '     || P_PAY_ACTION_CD
                        || '복리후생구분코드 : ' || P_BENEFIT_BIZ_CD
                        || ' 의 급여관련사항마감(TBEN991) 작업시 Error =>' || SQLERRM;
              P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'50',P_SQLERRM, P_CHKID);
        END;
        
        /* 근로복지기금 */
		  IF P_BENEFIT_BIZ_CD = '74' THEN
		        BEGIN
		        	UPDATE TBEN625 A
		        		SET A.CLOSE_YN = 'N'
		        	WHERE A.ENTER_CD = P_ENTER_CD
		        		AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
		        		;
		        EXCEPTION
		           WHEN OTHERS        THEN
		              ROLLBACK;
		              P_SQLCODE := TO_CHAR(SQLCODE);
		              P_SQLERRM := '급여일자코드 : '     || P_PAY_ACTION_CD
		                        || '복리후생구분코드 : ' || P_BENEFIT_BIZ_CD
		                        || ' 근로복지기금(TBEN625) 마감취소 CLOSE_YN UPDATE작업시 Error =>' || SQLERRM;
		             P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'169',P_SQLERRM, P_CHKID);
		        END;
         END IF;
         
         /* 신협대출 */
         IF P_BENEFIT_BIZ_CD = '76' THEN						
		        BEGIN
		        	UPDATE TBEN639 A
		        		SET A.CLOSE_YN = 'N'
		        	WHERE A.ENTER_CD = P_ENTER_CD
		        		AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
		        		;
		        EXCEPTION
		           WHEN OTHERS        THEN
		              ROLLBACK;
		              P_SQLCODE := TO_CHAR(SQLCODE);
		              P_SQLERRM := '급여일자코드 : '     || P_PAY_ACTION_CD
		                        || '복리후생구분코드 : ' || P_BENEFIT_BIZ_CD
		                        || ' 신협대출(TBEN639) 마감취소 CLOSE_YN UPDATE작업시 Error =>' || SQLERRM;
		             P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'170',P_SQLERRM, P_CHKID);
		        END;
        END IF;
				/* 신협적립금
        BEGIN
        	DELETE TBEN632 A
        	WHERE A.ENTER_CD = P_ENTER_CD
        		AND A.PAY_YM = (SELECT PAY_YM FROM TCPN201 WHERE ENTER_CD = A.ENTER_CD AND PAY_ACTION_CD = P_PAY_ACTION_CD)
        		;
        EXCEPTION
           WHEN OTHERS        THEN
              ROLLBACK;
              P_SQLCODE := TO_CHAR(SQLCODE);
              P_SQLERRM := '급여일자코드 : '     || P_PAY_ACTION_CD
                        || '복리후생구분코드 : ' || P_BENEFIT_BIZ_CD
                        || ' 신협적립금(TBEN632) 마감취소 DELETE작업시 Error =>' || SQLERRM;
             P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'169',P_SQLERRM, P_CHKID);
        END;*/

       BEGIN
         UPDATE TBEN997 -- 복리후생집계
            SET  CLOSE_ST = LV_CLOSE_ST, -- 마감상태(S90003)('10001':작업전, '10003':작업완료(마감전), '10005':마감)
                 CHKDATE  = SYSDATE,
                 CHKID    = P_CHKID
            WHERE 1=1
               AND ENTER_CD		   = P_ENTER_CD
               AND PAY_ACTION_CD  = P_PAY_ACTION_CD
               AND BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD;
        EXCEPTION
           WHEN OTHERS        THEN
              ROLLBACK;
              P_SQLCODE := TO_CHAR(SQLCODE);
              P_SQLERRM := '급여일자코드 : '     || P_PAY_ACTION_CD
                        || '복리후생구분코드 : ' || P_BENEFIT_BIZ_CD
                        || ' 의 급여관련사항마감취소(TBEN997) 작업시 Error =>' || SQLERRM;
             P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'150',P_SQLERRM, P_CHKID);
        END;
    END LOOP;

   P_SQLCODE := 'OK';
   P_SQLERRM := '마감취소 되었습니다.';
   COMMIT;
   --
EXCEPTION
   WHEN OTHERS       THEN
      ROLLBACK;
      P_SQLCODE := TO_CHAR(SQLCODE);
      P_SQLERRM := 'Others Exception Error'  || SQLERRM;
      P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'166',P_SQLERRM, P_CHKID);
END P_BEN_PAY_DATA_CLOSE_CANCEL;