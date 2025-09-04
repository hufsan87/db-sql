create or replace PROCEDURE          "P_HRI_APP_AGREE_INS" (
      P_SQLCODE               OUT VARCHAR2,
      P_SQLERRM               OUT VARCHAR2,
      P_ENTER_CD              IN  VARCHAR2, -- 회사코드
      P_SABUN									IN  VARCHAR2, -- 신청자사번
      P_APPL_SEQ              IN  NUMBER,   -- 신청서순번(THRI103)
      P_APPL_CD               IN  VARCHAR2, -- 신청서코드
      P_AGREE_SABUN           IN  VARCHAR2, -- 결재자사번
      P_AGREE_SEQ             IN  NUMBER,   -- 결재순번
      P_AGREE_GUBUN           IN  VARCHAR2, -- 작업구분('0' ; 반려, '1':결재)
      P_AGREE_TIME            IN  VARCHAR2, -- 결재일시
      P_MEMO                  IN  VARCHAR2 DEFAULT '', -- 메모(결재/반려사유)
      P_CHKID                 IN  VARCHAR2,  -- 생성자
      P_DEPUTY_ADMIN_YN       VARCHAR2 := 'N' -- 관리자 결재 여부
)
/********************************************************************************/
/*                                                                              */
/*                    (c) Copyright ISU System Inc. 2007                        */
/*                           All Rights Reserved                                */
/*                                                                              */
/********************************************************************************/
/*  PROCEDURE NAME : EHR_DSEC.P_HRI_APP_AGREE_INS                               */
/*                   결재화면에서 [결재],[반려] 버튼 클릭 시 결재진행정보 생성  */
/********************************************************************************/
/*  [ 참조 TABLE ]                                                              */
/*       THRI101 ( 신청서코드 )                                                 */
/********************************************************************************/
/*  [ 생성 TABLE ]                                                              */
/*       THRI103 ( 신청서마스터 )                                               */
/*       THRI107 ( 신청서결재내역 )                                             */
/********************************************************************************/
/*  [ 삭제 TABLE ]                                                              */
/*                                                                              */
/*                                                                              */
/********************************************************************************/
/*  [ PRC 개요 ]                                                                */
/*   결재화면에서 [결재],[반려] 버튼 클릭 시 신청기본자료 생성                  */
/*   1. 신청서마스터 등록                                                       */
/*   2. 신청서결재경로 등록                                                     */
/********************************************************************************/
/*  [ PRC 호출 ]                                                                */
/*  각 결재화면에서 [결재],[반려] 버튼 클릭 시 호출                             */
/*                                                                              */
/********************************************************************************/
/* Date        In Charge       Description                                      */
/********************************************************************************/
/* 2009-11-30  C.Y.G           Initial Release                                  */
/* 2011-08-10  S.H.S           우리투자증권 : 결재일자 --> 결재일시 (THRI107)   */
/* 2012-09-28  S.H.S           골프존 :  출장, 경조휴가 삽입                    */
/* 2013-06-18  S.H.S           OPTI-HR 4.0 :  수정작업                          */
/* 2020-06-05  JYLEE           P_DEPUTY_ADMIN_YN 추가                          */
/********************************************************************************/
IS
   lv_hri101            THRI101%ROWTYPE;           -- 신청서종류정보
--   lv_tra201            TTRA201%ROWTYPE; -- 교육과정
--   lv_edu_method_cd     TTRA101.EDU_METHOD_CD%TYPE; -- 교육시행방법
   lv_hri103            THRI103%ROWTYPE;           -- 신청결재마스터
   ln_appl_seq          THRI103.APPL_SEQ%TYPE;     -- 신청서순번
   ln_agree_seq         THRI107.AGREE_SEQ%TYPE;    -- 결재순번
   lv_agree_sabun       THRI107.AGREE_SABUN%TYPE;  -- 결재자사번(이번 결재자의 사번)
   lv_gubun             THRI107.GUBUN%TYPE;        -- 구분(0:본인,1:결재,3:수신)
   lv_next_agree_sabun  THRI107.AGREE_SABUN%TYPE;  -- 결재자사번(다음결재자의 사번)
   ln_next_seq          THRI107.AGREE_SEQ%TYPE;    -- 결재순번(다음결재자의 결재순번)
   lv_next_gubun        THRI107.GUBUN%TYPE;        -- 다음결재자의 구분(0:본인,1:결재,3:수신)
   lv_appl_type_cd      THRI107.APPL_TYPE_CD%TYPE; -- 결재구분(R10052)
   lv_now_appl_status_cd    THRI103.APPL_STATUS_CD%TYPE;
   lv_biz_cd          TSYS903.BIZ_CD%TYPE := 'HRI';
   lv_object_nm       TSYS903.OBJECT_NM%TYPE := 'P_HRI_APP_AGREE_INS';

   lv_hol_sdate       VARCHAR(8);   -- 경조휴가시작일
   lv_hol_edate       VARCHAR(8);   -- 경조휴가종료일
   
   lv_org_app_yn        THRI107.ORG_APP_YN%TYPE;    -- 조직결재여부

BEGIN
   P_SQLCODE := NULL;
   P_SQLERRM := NULL;
   lv_hri101 := NULL;
   lv_hri103 := NULL;
--   lv_tra201 := NULL;
   lv_hol_sdate := NULL;
   lv_hol_edate := NULL;

--P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'99-1',P_APPL_CD || ':' || P_APPL_SEQ || ':' || P_PATH_SEQ || ':' || P_AGREE_SABUN || ':' || P_AGREE_SEQ, P_CHKID);
P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'000',sqlerrm, P_CHKID);
   ------------------------------
   -- 신청서코드 정보 가져오기
   ------------------------------
   BEGIN
      SELECT *
        INTO lv_hri101
        FROM THRI101
       WHERE ENTER_CD = P_ENTER_CD
         AND APPL_CD  = P_APPL_CD;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         ROLLBACK;
         P_SQLCODE := SQLCODE;
         P_SQLERRM := '신청서코드 : ' || P_APPL_CD || ' 의 신청서코드 정보가 존재하지 않습니다.';
         P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'10',P_SQLERRM, P_CHKID);
         RETURN;
      WHEN OTHERS THEN
         ROLLBACK;
         P_SQLCODE := SQLCODE;
         P_SQLERRM := '신청서코드 : ' || P_APPL_CD || ' 의 신청서코드 정보 조회시 Error ==>' || SQLERRM;
         P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'15',P_SQLERRM, P_CHKID);
         RETURN;
   END;

   -- 해당 결재자의 결재구분 구하기 :  참조는 별도 테이블에 관리되므로 해당 로직 주석처리  2013.06.18
   /*
   BEGIN
      SELECT APPL_TYPE_CD
        INTO lv_appl_type_cd
        FROM THRI107
       WHERE ENTER_CD = P_ENTER_CD
         AND APPL_SEQ = P_APPL_SEQ
--         AND PATH_SEQ = P_PATH_SEQ
         AND AGREE_SABUN = P_AGREE_SABUN
         AND AGREE_SEQ = P_AGREE_SEQ;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         lv_appl_type_cd := NULL;
         P_SQLCODE := SQLCODE;
         P_SQLERRM := 'APPL_SEQ=' || P_APPL_SEQ || ',' || '결재자사번=' || P_AGREE_SABUN ||  ' 의 결재자구분 정보가 존재하지 않습니다';
         P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'17',P_SQLERRM, P_CHKID);
         RETURN;
       WHEN OTHERS THEN
         lv_appl_type_cd := NULL;
         P_SQLCODE := SQLCODE;
         P_SQLERRM := 'APPL_SEQ=' || P_APPL_SEQ || ',' || '결재자사번=' || P_AGREE_SABUN ||  ' 의 결재자구분 정보 조회시 Error ==>' || SQLERRM;
         P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'18',P_SQLERRM, P_CHKID);
         RETURN;
   END;
   */


   -- 결재자의 결재구분이 [참조]가 아닌 경우에만 신청서마스터 결재정보 업데이트  --> 별도구분없이 신청서 마스터 업데이트
--   IF lv_appl_type_cd NOT IN ('25') THEN
      ------------------------------
      -- 해당 결재자의 다음 결재자 정보 가져오기
      ------------------------------

      /* 결재순서가 아닌 업무담당자가 승인화면에서 강제로 결재상태를 변경했을 때
         THRI103 의 결재상태를 변경하고 종료.
         그 외의 경우에는 정상적인 프로세스를 거쳐 처리함 */
--   IF  P_AGREE_SEQ  IS NULL  THEN
--      P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm, 'XX', 'ln_agree_seq : NULL !! ', P_CHKID);
--   ELSE
--      P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm, 'XX', 'ln_agree_seq : ' || P_AGREE_SEQ, P_CHKID);
--   END IF;
      IF  P_AGREE_SEQ  IS NULL  THEN   -- 결재순번이 없는 경우 (결재순서가 아닌 담당자)
      		 lv_gubun := '3';   -- 수신처리자로 설정
           lv_next_agree_sabun := NULL;   -- 다음 결재자는 없음
           ln_next_seq := NULL;   -- 다음 결재순번은 없음
           lv_next_gubun := NULL; -- 다음 결재구분도 없음

      ELSE	  -- 정상적인 결재순번을 가진 담당자의 경우
					  -- 정상적인 결재순번에 대한 결재자사번이 무엇인지 추출
            BEGIN

               SELECT A.AGREE_SABUN
                    , NVL(ORG_APP_YN, 'N')
                 INTO lv_agree_sabun   -- 이번 결재자사번
                    , lv_org_app_yn
                 FROM THRI107  A
                WHERE A.ENTER_CD = P_ENTER_CD
                  AND A.APPL_SEQ = P_APPL_SEQ
                  AND A.AGREE_SEQ   = P_AGREE_SEQ;
            EXCEPTION
               WHEN OTHERS THEN
                  ROLLBACK;
                  P_SQLCODE := SQLCODE;
                  P_SQLERRM := '금번 결재자사번  조회 시 Error => ' || SQLERRM;
                  P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'20',P_SQLERRM, P_CHKID);
                  RETURN;

            END;

            -- 2017-11-29 김정현 수정
            -- 조직결재일 경우 조직코드로 비교가 되기 때문에 lv_agree_sabun <> P_AGREE_SABUN 가 TRUE 가 된다.
            -- 따라서 조직결재가 아닌 케이스만 대결을 체크하도록 한다.
            IF  lv_agree_sabun <> P_AGREE_SABUN  AND lv_org_app_yn = 'N'  THEN  -- 원래 결재자가 아닌 직원이 결재하는 경우 (대결자인 경우)
           
								-- 대결자 신상을 결재내역 테이블에 업데이트

				BEGIN 

                    UPDATE  THRI107  A
                       SET  ( A.DEPUTY_SABUN, A.DEPUTY_ORG, A.DEPUTY_JIKWEE, A.DEPUTY_JIKCHAK, A.DEPUTY_YN, A.DEPUTY_ADMIN_YN ) --  DEPUTY_ADMIN_YN 추가 .. 2020.01.15
                         =  ( SELECT  P_AGREE_SABUN, F_COM_GET_ORG_NM(X.ENTER_CD, X.ORG_CD, X.SDATE),
                                      F_COM_GET_GRCODE_NAME(X.ENTER_CD, 'H20030', X.JIKWEE_CD),
                                      F_COM_GET_GRCODE_NAME(X.ENTER_CD, 'H20020', X.JIKCHAK_CD),
                                      'Y',
                                      P_DEPUTY_ADMIN_YN  --  DEPUTY_ADMIN_YN 추가 .. 2020.01.15
                                FROM  THRM151 X
                               WHERE  X.ENTER_CD = A.ENTER_CD
                                 AND  X.SABUN = P_AGREE_SABUN
                                 AND  TO_CHAR(SYSDATE, 'YYYYMMDD') BETWEEN X.SDATE AND NVL(X.EDATE, '99991231') )
                     WHERE  A.ENTER_CD = P_ENTER_CD
                       AND  A.APPL_SEQ = P_APPL_SEQ
                       AND  A.AGREE_SABUN = lv_agree_sabun
                       AND  A.AGREE_SEQ = P_AGREE_SEQ;

                EXCEPTION
                   WHEN OTHERS THEN
                      ROLLBACK;
                      P_SQLCODE := SQLCODE;
                      P_SQLERRM := '대결자신상 업데이트 시 Error => ' || SQLERRM;
                      P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'70',P_SQLERRM, P_CHKID);
                      RETURN;

                END;

            END IF;

            BEGIN
               SELECT A.AGREE_SEQ
                     ,A.GUBUN
                     ,B.NEXT_AGREE_SABUN
                     ,B.NEXT_SEQ
                     ,B.NEXT_GUBUN
                 INTO ln_agree_seq        -- 결재순번
                     ,lv_gubun
                     ,lv_next_agree_sabun -- 결재자사번(다음결재자의 사번)
                     ,ln_next_seq         -- 결재순번(다음결재자의 결재순번)
                     ,lv_next_gubun       -- 구분(0:본인,1:결재,3:수신)
                 FROM (SELECT AGREE_SABUN, AGREE_SEQ, GUBUN
                             ,DENSE_RANK() OVER (ORDER BY AGREE_SEQ ) AS SEQ
                         FROM THRI107
                        WHERE ENTER_CD = P_ENTER_CD
                          AND APPL_SEQ = P_APPL_SEQ
      --                    AND PATH_SEQ = P_PATH_SEQ
      --                    AND APPL_TYPE_CD NOT IN ('25')
                      ) A
                     ,(SELECT AGREE_SABUN AS NEXT_AGREE_SABUN, AGREE_SEQ AS NEXT_SEQ, GUBUN AS NEXT_GUBUN
                             ,DENSE_RANK() OVER (ORDER BY AGREE_SEQ ) AS SEQ
                         FROM THRI107
                        WHERE ENTER_CD = P_ENTER_CD
                          AND APPL_SEQ = P_APPL_SEQ
      --                    AND PATH_SEQ = P_PATH_SEQ
      --                    AND APPL_TYPE_CD NOT IN ('25')
                      ) B
                WHERE (A.SEQ + 1)   = B.SEQ(+)
                  AND A.AGREE_SABUN = lv_agree_sabun   -- 대결자가 결재자사번으로 넘어오는 경우를 대비하여 수정
--                  AND A.AGREE_SABUN = P_AGREE_SABUN
                  AND A.AGREE_SEQ   = P_AGREE_SEQ;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  ROLLBACK;
                  P_SQLCODE := SQLCODE;
--                  P_SQLERRM := '사원 : ' || P_SABUN || ' 의 ' || lv_hri101.APPL_NM || ' 신청서의 결재 정보 자료가 존재하지 않습니다.' || 'ENTER_CD : ' || P_ENTER_CD || ' P_APPL_SEQ : ' || TO_CHAR(P_APPL_SEQ) || ' P_AGREE_SABUN : ' || P_AGREE_SABUN || ' P_AGREE_SEQ : ' || TO_CHAR(P_AGREE_SEQ);
                  P_SQLERRM := '사원 : ' || P_SABUN || ' 의 ' || lv_hri101.APPL_NM || ' 신청서의 결재 정보 자료가 존재하지 않습니다.';
                  P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'20',P_SQLERRM, P_CHKID);
                  RETURN;
               WHEN OTHERS THEN
                  ROLLBACK;
                  P_SQLCODE := SQLCODE;
                  P_SQLERRM := '사원 : ' || P_SABUN || ' 의 ' || lv_hri101.APPL_NM || ' 신청서의 결재 정보 조회 시 Error => ' || SQLERRM;
                  P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'25',P_SQLERRM, P_CHKID);
                  RETURN;
            END;

      END IF;

   --P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'30',ln_agree_seq || ':' || lv_next_agree_sabun || ':' || ln_next_seq, P_CHKID);
      ------------------------------
      -- 작업구분(결재/반려) 및 신청서코드 정보에 다른 신청서상태코드 값 구하기
      ------------------------------
      lv_hri103.AGREE_SABUN := P_AGREE_SABUN; -- 결재자사번 (이 값은 대결자 사번일 수도 있음)
      lv_hri103.AGREE_YMD   := SUBSTR(P_AGREE_TIME, 1, 8); -- 결재일자
      lv_hri103.FINISH_YN   := 'N'; -- 프로세스완료여부
      -- 반려일 경우
      IF P_AGREE_GUBUN = '0' THEN
         -- 구분(0:본인,1:결재,3:수신)
         IF lv_gubun = '3' THEN
            lv_hri103.APPL_STATUS_CD := '33'; -- 수신반려
            lv_hri103.FINISH_YN      := 'N';
         ELSE
            lv_hri103.APPL_STATUS_CD := '23'; -- 결재반려
            lv_hri103.FINISH_YN      := 'N';
         END IF;
      -- 결재일 경우
      ELSE
      --결재자가 담당자가 아닐 경우에만 처리(2013.09.30 Kosh)
      IF  P_AGREE_SEQ  IS NOT NULL  THEN
      	-- 해당 결재자가 최종결재자일 경우
         IF lv_next_agree_sabun IS NULL THEN
         	/* THRI101, AGREE_END_YN(결재완료시처리완료여부(Y/N)) 추가, 옵션에 따라 승인요청(98), 처리완료(99) 로 처리, 
               복리후생 담당자가 승인 화면에서 결재완료건(기존 처리완료)에 대해 승인요청(98)으로 조회 하여 처리완료(99) 로 처리 하기 위해 추가.
               2016.07.07, CBS */
            -- 수신처리필요여부 가 N 일 경우
            --IF lv_hri101.APPRV_YN = 'N' THEN
            IF lv_hri101.AGREE_END_YN = 'Y' THEN
				lv_hri103.APPL_STATUS_CD := '99'; -- 처리완료
            ELSE
            	lv_hri103.APPL_STATUS_CD := '98'; -- 승인요청
            END IF;
               lv_hri103.FINISH_YN      := 'Y'; -- 프로세스완료여부
            --ELSE
            --   lv_hri103.APPL_STATUS_CD := '31'; -- 승인처리중
            --END IF;
         ELSE
            -- 구분(0:본인,1:결재,3:수신)
            IF lv_next_gubun = '3' THEN
               lv_hri103.APPL_STATUS_CD := '31'; -- 수신처리중
               lv_hri103.FINISH_YN      := 'N';
            ELSE
               lv_hri103.APPL_STATUS_CD := '21'; -- 결재처리중
               lv_hri103.FINISH_YN      := 'N';
            END IF;
            lv_hri103.AGREE_SABUN := lv_next_agree_sabun; -- 다음결재자사번
            lv_hri103.AGREE_YMD := NULL; -- 결재일자
         END IF;
      ELSE
            /* P_AGREE_SEQ 가 NULL일때는 바로 처리 완료?( 모르겠음....확인해봐야함....2013.09.30 Kosh) */
            /* THRI101, AGREE_END_YN(결재완료시처리완료여부(Y/N)) 추가, 옵션에 따라 승인요청(98), 처리완료(99) 로 처리, 
               복리후생 담당자가 승인 화면에서 결재완료건(기존 처리완료)에 대해 승인요청(98)으로 조회 하여 처리완료(99) 로 처리 하기 위해 추가.
               2016.07.07, CBS */
            IF lv_hri101.AGREE_END_YN = 'Y' THEN
				lv_hri103.APPL_STATUS_CD := '99'; -- 처리완료
            ELSE
            	lv_hri103.APPL_STATUS_CD := '98'; -- 승인요청
            END IF;
               lv_hri103.FINISH_YN      := 'Y'; -- 프로세스완료여부
      END IF;

      END IF;

      ------------------------------
      -- 신청서마스터 등록
      ------------------------------

      BEGIN

          /*관리자가 강제로 처리완료 하였을 경우를 위한 처리
             다음 처리상태가 아닌 강제로 처리완료로 하기 위함 */
          BEGIN
            SELECT APPL_STATUS_CD
                INTO lv_now_appl_status_cd
             FROM THRI103
             WHERE ENTER_CD = P_ENTER_CD
                AND APPL_SEQ = P_APPL_SEQ;
          END;
          IF lv_now_appl_status_cd = '99' THEN
            lv_hri103.APPL_STATUS_CD := lv_now_appl_status_cd;
          END IF;


        IF lv_hri103.APPL_STATUS_CD IS NOT NULL THEN
          UPDATE THRI103
          SET APPL_STATUS_CD = lv_hri103.APPL_STATUS_CD
               ,AGREE_SABUN    = lv_hri103.AGREE_SABUN
               ,AGREE_YMD      = lv_hri103.AGREE_YMD
               ,FINISH_YN      = NVL(lv_hri103.FINISH_YN,'N')
               ,CHKDATE        = SYSDATE
               ,CHKID          = P_CHKID
          WHERE ENTER_CD = P_ENTER_CD
            AND APPL_SEQ = P_APPL_SEQ;
        END IF;


         EXCEPTION
            WHEN OTHERS THEN
               ROLLBACK;
               P_SQLCODE := SQLCODE;
               P_SQLERRM := '사원 : ' || P_SABUN || ', 결재자사번 : ' || P_AGREE_SABUN || ' 인 신청서종류(' || lv_hri101.APPL_NM || ') 결재 정보 등록 시 Error => ' || SQLERRM;
               P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'30',P_SQLERRM, P_CHKID);
               RETURN;
      END;

   ------------------------------
   -- 신청서결재내역 등록
   --    작업구분 -> '0':반려,'1':결재
   --    결재상태코드(R10050) --> 10:결재요청, 20:결재완료, 30:반려
   ------------------------------
   -- 반려처리
   IF P_AGREE_GUBUN = '0'  THEN
      BEGIN
         UPDATE THRI107
            SET AGREE_STATUS_CD = '30'
               ,AGREE_TIME      = SYSDATE --TO_DATE(P_AGREE_TIME, 'YYYYMMDDHH24MMSS')
               ,MEMO            = NVL(P_MEMO, '')
               ,CHKDATE         = SYSDATE
               ,CHKID           = P_CHKID
          WHERE ENTER_CD = P_ENTER_CD
            AND APPL_SEQ = P_APPL_SEQ
--            AND PATH_SEQ  = P_PATH_SEQ
            AND AGREE_SABUN = lv_agree_sabun   -- 대결자가 결재자사번으로 넘어오는 경우를 대비하여 수정
--            AND AGREE_SABUN = P_AGREE_SABUN
            AND AGREE_SEQ   = P_AGREE_SEQ;
      EXCEPTION
         WHEN OTHERS THEN
            ROLLBACK;
            P_SQLCODE := SQLCODE;
            P_SQLERRM := '사원 : ' || P_SABUN || ', 결재자사번 : ' || lv_agree_sabun || ' 인 신청서종류(' || lv_hri101.APPL_NM || ') 결재반려 처리 시 Error => ' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'40',P_SQLERRM, P_CHKID);
            RETURN;
      END;
   -- 결재처리
   ELSE
      -- 해당 결재자의 결재상태 변경(결재완료)
      BEGIN
         UPDATE THRI107
            SET AGREE_STATUS_CD = '20'
               ,AGREE_TIME      = SYSDATE --TO_DATE(P_AGREE_TIME, 'YYYYMMDDHH24MMSS')
               ,MEMO            = NVL(P_MEMO, '')
               ,CHKDATE         = SYSDATE
               ,CHKID           = P_CHKID
          WHERE ENTER_CD = P_ENTER_CD
            AND APPL_SEQ = P_APPL_SEQ
--            AND PATH_SEQ  = P_PATH_SEQ
            AND AGREE_SABUN = lv_agree_sabun   -- 대결자가 결재자사번으로 넘어오는 경우를 대비하여 수정
--            AND AGREE_SABUN = P_AGREE_SABUN
            AND AGREE_SEQ   = P_AGREE_SEQ;
      EXCEPTION
         WHEN OTHERS THEN
            ROLLBACK;
            P_SQLCODE := SQLCODE;
            P_SQLERRM := '사원 : ' || P_SABUN || ', 결재자사번 : ' || lv_agree_sabun || ' 인 신청서종류(' || lv_hri101.APPL_NM || ') 결재완료 처리 시 Error => ' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'50',P_SQLERRM, P_CHKID);
            RETURN;
      END;
   END IF;

   -- [참조] 결재자가 아닐 경우 다음 결재자 정보 업데이트
--   IF lv_appl_type_cd NOT IN ('25') THEN
      -- 다음 결재자 존재시 다음 결재자 결재상태 변경(결재요청)(반려 처리시에는 제외)
      IF lv_next_agree_sabun IS NOT NULL AND P_AGREE_GUBUN <> '0' THEN
         BEGIN
            UPDATE THRI107
               SET AGREE_STATUS_CD = '10'
                  ,CHKDATE         = SYSDATE
                  ,CHKID           = P_CHKID
             WHERE ENTER_CD = P_ENTER_CD
               AND APPL_SEQ = P_APPL_SEQ
--               AND PATH_SEQ  = P_PATH_SEQ
               AND AGREE_SABUN = lv_next_agree_sabun
               AND AGREE_SEQ   = ln_next_seq;
         EXCEPTION
            WHEN OTHERS THEN
               ROLLBACK;
               P_SQLCODE := SQLCODE;
               P_SQLERRM := '사원 : ' || P_SABUN || ', 결재자사번 : ' || lv_agree_sabun || ' 인 신청서종류(' || lv_hri101.APPL_NM || ') 결재요청 처리 시 Error => ' || SQLERRM;
               P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'60',P_SQLERRM, P_CHKID);
               RETURN;
         END;

      END IF;
--   END IF;

   COMMIT;

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      P_SQLCODE := TO_CHAR(SQLCODE);
      P_SQLERRM := NVL(P_SQLERRM,SQLERRM);
      P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'100',P_SQLERRM, P_CHKID);
END;