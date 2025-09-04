create or replace PROCEDURE             P_HRI_AFTER_PROC_EXEC (
    P_SQLCODE               OUT VARCHAR2,
    P_SQLERRM               OUT VARCHAR2,
    P_ENTER_CD              IN  VARCHAR2, -- 회사코드
    P_SABUN                 IN  VARCHAR2, -- 신청자사번
    P_APPL_SEQ              IN  NUMBER,   -- 신청서순번(THRI103)
    P_APPL_CD               IN  VARCHAR2, -- 신청서코드
    P_OLD_APPL_STATUS_CD    IN  VARCHAR2, -- 이전 결재상태코드 2020.01.14
    P_CHKID                    IN  VARCHAR2  -- 수정자
) IS
/********************************************************************************/
/*                                                                              */
/*                    (c) Copyright ISU System Inc. 2007                        */
/*                           All Rights Reserved                                */
/*                                                                              */
/********************************************************************************/
/*  PROCEDURE NAME : EHR_DSEC.P_HRI_AFTER_PROC_EXEC                             */
/*                   신청서코드관리 값 중 프로시저 여부 'Y' 일때 실행                 */
/********************************************************************************/
/*  [ 참조 TABLE ]                                                              */
/*                                                                               */
/********************************************************************************/
/*  [ 생성 TABLE ]                                                              */
/*                                                                             */
/********************************************************************************/
/*  [ 삭제 TABLE ]                                                              */
/*                                                                              */
/*                                                                              */
/********************************************************************************/
/*  [ PRC 개요 ]                                                                */
/*   결재화면에서 [결재]시 신청서코드 프로시져 여부가 'Y' 이면 실행                   */
/*                                                                             */
/*                                                                           */
/********************************************************************************/
/*  [ PRC 호출 ]                                                                */
/*  각 결재화면에서 [결재]                                                       */
/*                                                                              */
/********************************************************************************/
/* Date        In Charge       Description                                      */
/********************************************************************************/
/* 2018-05-17  KIM.C.S           Initial Release                                  */
/* 2021-05-04  mschoe          Modified                                         */
/********************************************************************************/
    lv_biz_cd          TSYS903.BIZ_CD%TYPE := 'HRI';
    lv_object_nm       TSYS903.OBJECT_NM%TYPE := 'P_HRI_AFTER_PROC_EXEC';

    lv_ymd          VARCHAR2(8);
    lv_sabun        THRM100.SABUN%TYPE;
    lv_sabun2       THRM100.SABUN%TYPE;
    lv_appl_seq     THRI103.APPL_SEQ%TYPE;
    lv_req_yy       NUMBER;
    lv_chkid        VARCHAR2(13);


    LV_EDU_SEQ          VARCHAR2(100);
    LV_EDU_EVENT_SEQ    VARCHAR2(100);
    LV_EDU_SEQ2         VARCHAR2(100);
    LV_EDU_EVENT_SEQ2   VARCHAR2(100);
    LV_APP_MEMO         VARCHAR2(100);
    LV_EDU_SABUN        VARCHAR2(100);
    --LV_HOL_APP_SEQ      TTRA201.HOL_APP_SEQ%TYPE; -- 교육신청 결재 완료 후 생성된 신청근태 코드값 유무를 담기 위한 변수
    --LV_HOL_APP_SEQ_VAL  TTRA201.HOL_APP_SEQ%TYPE; -- 교육신청 결재 완료 후 생성된 신청근태 코드값을 담기 위한 변(교육신청테이블, 신청 마스터 삭제하기 위해 필요)

    lv_s_ymd                TTIM301.S_YMD%TYPE;
    lv_e_ymd                TTIM301.E_YMD%TYPE;

    LV_APPL_YMD             THRI103.APPL_YMD%TYPE;
    LV_APPL_STATUS_CD       THRI103.APPL_STATUS_CD%TYPE;

		/**근태소명신청 추가start**/
    LV_HOL_DAY              NUMBER;
    LV_CLOSE_DAY            NUMBER;
    LV_NEXT_BIZ_DAY         VARCHAR2(8);
    LV_GNT_REQ_REASON       TTIM385.GNT_REQ_REASON%TYPE;
    LV_GNT_CD               TTIM301.GNT_CD%TYPE;

    LV_GNT_GUBUN_CD        VARCHAR2(8);

    LV_SRC_YY               TTIM301.SRC_YY%TYPE;
    LV_SRC_GNT_CD           TTIM301.SRC_GNT_CD%TYPE;
    LV_SRC_USE_S_YMD        TTIM301.SRC_USE_S_YMD%TYPE;
    LV_SRC_USE_E_YMD        TTIM301.SRC_USE_E_YMD%TYPE;
    lv_REQUEST_HOUR         VARCHAR2(10):=NULL;
    lv_REQ_S_HM             VARCHAR2(10):=NULL;
    lv_REQ_E_HM             VARCHAR2(10):=NULL;
		/**근태소명신청 추가end**/

    lv_sdate                VARCHAR2(8);
    lv_edate                VARCHAR2(8);

    /* 리조트신청 사용건수  */
    ln_ben_seq    NUMBER;
    ln_ben_cnt    NUMBER;
    ln_ben_n_cnt  NUMBER;
    ln_ben_s_cnt  NUMBER;
    ln_ben_ss_cnt NUMBER;
    ln_ben_ws_cnt NUMBER;

    LV_TIM131 TTIM131%ROWTYPE; -- 일근태변경신청관리_개인별

		/* 생수 */
		LV_RECV_GB 							TBEN592.RECV_GB%TYPE;
		LV_USE_SEQ							TBEN592.USE_SEQ%TYPE;
		LV_USE_AMT 						  TBEN592.USE_AMT%TYPE;

		/* 경조 -- 한국공항 결재 방법이 홀로 달라 추가적으로 매핑 APPL_SEQ필요 */
		LV_BEN_OCC_APPL_SEQ 		TBEN471.APPL_SEQ%TYPE;

		BEGIN

    P_SQLCODE := NULL;
    P_SQLERRM := NULL;

--     DBMS_OUTPUT.PUT_LINE('P_APPL_SEQ:'||P_APPL_SEQ);

    --P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'1',P_APPL_SEQ||' / '||P_APPL_CD, P_SABUN);

    
  
    ------------------------------------------------------------------------------------------------------------------------------
    -- 신청서 상태 코드 조회 : 파라메터 값이 정확하지 않음으로 다시 조회 함.
    ------------------------------------------------------------------------------------------------------------------------------
    BEGIN
            SELECT A.APPL_STATUS_CD, A.APPL_YMD
              INTO LV_APPL_STATUS_CD, LV_APPL_YMD
              FROM THRI103 A
             WHERE A.ENTER_CD = P_ENTER_CD
               AND A.APPL_SEQ = TO_NUMBER(TRIM(P_APPL_SEQ))
               ;
    EXCEPTION
        WHEN OTHERS THEN
              ROLLBACK;
              P_SQLCODE := SQLCODE;
              P_SQLERRM := '사원 : ' || lv_sabun2 || ', 결재자사번 : ' || lv_sabun2 || ' 인 신청서상태값 조회  시 Error => ' || SQLERRM;
              --P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'38',P_SQLERRM, P_CHKID);
              RETURN;

    END;

/*
    BEGIN
            SELECT A.APPL_STATUS_CD, A.APPL_YMD
              INTO LV_APPL_STATUS_CD, LV_APPL_YMD
              FROM THRI103 A
             WHERE A.ENTER_CD = P_ENTER_CD
               AND A.APPL_SEQ = TO_NUMBER(TRIM(P_APPL_SEQ))
               ;
    EXCEPTION
        WHEN OTHERS THEN
              ROLLBACK;
              P_SQLCODE := SQLCODE;
              P_SQLERRM := '사원 : ' || lv_sabun2 || ', 결재자사번 : ' || lv_sabun2 || ' 인 신청서상태값 조회  시 Error => ' || SQLERRM;
              --P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'38',P_SQLERRM, P_CHKID);
              RETURN;

    END;
 */
    


    /* 신청서코드에 따른 IF */

    P_SQLERRM := ' 신청서코드 : ' || P_APPL_CD || ', 신청서순번 : ' || P_APPL_SEQ || ', 신청자사번 : ' || P_SABUN||', APPL_STATUS_CD(OLD/NEW): ' || P_OLD_APPL_STATUS_CD || '/' || LV_APPL_STATUS_CD;

    --P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'0', P_SQLERRM , P_SABUN);

    ------------------------------------------------------------------------------------------------------------------------------
    -- 출퇴근시간변경신청(30)
    ------------------------------------------------------------------------------------------------------------------------------
--    IF  P_APPL_CD = '30' THEN -- 출퇴근시간변경신청
    IF  P_APPL_CD = '30' AND P_ENTER_CD <> 'KS' THEN -- 한국공항은 출퇴근시간변경신청 로직 제외 합니다. 이후 일근무관리 화면에서 출퇴근신청자 표시 해줍니다. 2024.06.05
        P_SQLERRM := '[출퇴근시간변경신청(30)]' || P_SQLERRM;
        lv_sabun := NULL;
        lv_ymd  := NULL;

        BEGIN
            SELECT A.SABUN, A.YMD
              INTO lv_sabun, lv_ymd
              FROM TTIM345 A, THRI103 B
             WHERE A.ENTER_CD = B.ENTER_CD
               AND A.APPL_SEQ = B.APPL_SEQ
               AND A.ENTER_CD = P_ENTER_CD
               AND A.APPL_SEQ = P_APPL_SEQ;
        EXCEPTION
            WHEN OTHERS THEN
                lv_sabun := NULL;
                lv_ymd := NULL;
        END;

        ---------------
        -- 일근무 갱신
        ---------------
        IF lv_sabun IS NOT NULL THEN
            P_TIM_WORK_HOUR_CHG( P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_ymd, lv_ymd, lv_sabun, '', 'APP_AFTER' );
        END IF;

    ------------------------------------------------------------------------------------------------------------------------------
    -- 직무분장보고(182)
    ------------------------------------------------------------------------------------------------------------------------------
    ELSIF  P_APPL_CD IN ('182')  THEN -- 직무분장보고 (담당임원에 의해서 승인완료가 되어야 담당직무신청 내역의 승인여부가 'Y' 가 된다.

        BEGIN
            SELECT APPLY_YMD
                INTO lv_ymd
            FROM THRM175
            WHERE ENTER_CD = P_ENTER_CD
                AND APPL_SEQ = P_APPL_SEQ
                ;
         EXCEPTION
            WHEN OTHERS THEN
               P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'182-1',P_SQLERRM, P_SABUN);
               lv_ymd := '';
        END
        ;

        -- 적용일자는 신청한 인원중에서 적용일자가 제일 늦은 인원으로
        IF lv_ymd IS NULL THEN
            UPDATE THRM175 A SET APPLY_YMD = (SELECT MAX(B.APPLY_YMD)
                                                                            FROM THRM171 B
                                                                            WHERE B.ENTER_CD = A.ENTER_CD
                                                                                AND B.APPL_SEQ IN (SELECT JOB_APPL_SEQ
                                                                                                              FROM THRM176
                                                                                                              WHERE ENTER_CD = P_ENTER_CD
                                                                                                                  AND APPL_SEQ = P_APPL_SEQ
                                                                                                              )
                                                                        )
            WHERE ENTER_CD = P_ENTER_CD
                AND APPL_SEQ = P_APPL_SEQ
                ;
        END IF
        ;

        IF LV_APPL_STATUS_CD = '99' THEN
            UPDATE THRM171 SET APPL_YN = 'Y', CHKDATE = SYSDATE, CHKID = P_CHKID
            WHERE ENTER_CD = P_ENTER_CD
              AND APPL_SEQ IN (SELECT X.JOB_APPL_SEQ
                               FROM THRM176 X
                               WHERE X.ENTER_CD = P_ENTER_CD
                                 AND X.APPL_SEQ = P_APPL_SEQ
                               )
            ;

        ELSE
            UPDATE THRM171 SET APPL_YN = 'N', CHKDATE = SYSDATE, CHKID = P_CHKID
            WHERE ENTER_CD = P_ENTER_CD
            AND APPL_SEQ IN (SELECT X.JOB_APPL_SEQ
                             FROM THRM176 X
                             WHERE X.ENTER_CD = P_ENTER_CD
                               AND X.APPL_SEQ = P_APPL_SEQ
                            )
            ;
        END IF
        ;
    ------------------------------------------------------------------------------------------------------------------------------
    -- 퇴직신청(99)
    ------------------------------------------------------------------------------------------------------------------------------
    ELSIF  P_APPL_CD IN ('99')  THEN -- 퇴직신청
        P_SQLERRM := '[퇴직신청(99)]' || P_SQLERRM;
        lv_sabun := '';
        lv_ymd  := '';

            -- 퇴직신청 가져오기
            BEGIN
                SELECT NVL(A.RET_SCH_YMD, A.REQ_DATE)
                    INTO lv_ymd
                FROM THRM551 A
                WHERE A.ENTER_CD = P_ENTER_CD
                  AND A.SABUN = P_SABUN
                  AND A.APPL_SEQ = P_APPL_SEQ
                 ;
            EXCEPTION
                WHEN OTHERS THEN
                   P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'99-1',P_SQLERRM, P_SABUN);
                   lv_ymd := TO_CHAR(SYSDATE, 'YYYYMMDD');
            END
            ;


            BEGIN
                P_HRM_RETIRE_CHECK_LIST (
                   P_SQLCODE,
                   P_SQLERRM,
                   P_ENTER_CD,
                   P_APPL_SEQ,
                   lv_ymd,
                   '10',
                   P_SABUN  -- 생성자
                );

            EXCEPTION
                WHEN OTHERS THEN
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'99-4',P_SQLERRM, P_SABUN);
            END;
    ------------------------------------------------------------------------------------------------------------------------------
    -- 근태신청(22)
    ------------------------------------------------------------------------------------------------------------------------------
    ELSIF  P_APPL_CD IN ('22')  THEN -- 근태신청
        P_SQLERRM := '[근태신청(22)]' || P_SQLERRM;
        lv_sabun := '';
        lv_ymd  := '';

          DECLARE CURSOR CSR_GNT IS
              SELECT A.SABUN
                   , A.GNT_CD
                   , A.S_YMD
                   , A.E_YMD
              FROM TTIM301 A
              WHERE A.ENTER_CD = P_ENTER_CD
               AND A.APPL_SEQ = P_APPL_SEQ
               ;
            
            ---------------
            -- 일근무 갱신
            ---------------
            BEGIN
                FOR C_GNT IN CSR_GNT LOOP
--P_SQLERRM :=  P_SQLERRM||' , '|| C_GNT.S_YMD||' , '||C_GNT.E_YMD||' , '||C_GNT.SABUN;
--P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'22',P_SQLERRM, P_SABUN);


                    BEGIN
                        IF P_CHKID = 'IF_GW' THEN
                            P_TIM_WORK_HOUR_CHG (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, C_GNT.S_YMD, C_GNT.E_YMD, C_GNT.SABUN, '', P_CHKID );
                        ELSE
                            P_TIM_WORK_HOUR_CHG (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, C_GNT.S_YMD, C_GNT.E_YMD, C_GNT.SABUN, '', 'APP_AFTER' );
                        end if;
                    END;

                END LOOP;
            EXCEPTION
                WHEN OTHERS THEN
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'22',P_SQLERRM, P_SABUN);
            END;

    ------------------------------------------------------------------------------------------------------------------------------
    -- 근태취소신청(23)
    ------------------------------------------------------------------------------------------------------------------------------
    ELSIF  P_APPL_CD IN ('23')  THEN -- 근태취소신청
        P_SQLERRM := '[근태취소신청(23)]' || P_SQLERRM;


          DECLARE CURSOR CSR_GNT2 IS
            SELECT B.SABUN
                 , B.GNT_CD
                 , D.S_YMD
                 , D.E_YMD
              FROM THRI103 A, TTIM383 B,TTIM301 D
             WHERE A.ENTER_CD = P_ENTER_CD
               AND A.APPL_SEQ = P_APPL_SEQ
               AND A.ENTER_CD = B.ENTER_CD
               AND A.APPL_SEQ = B.APPL_SEQ
               AND B.ENTER_CD = D.ENTER_CD
               AND B.B_APPL_SEQ = D.APPL_SEQ
               AND A.ENTER_CD   = P_ENTER_CD
               AND B.SABUN      = P_SABUN
               AND A.APPL_STATUS_CD = '99';

            ---------------
            -- 일근무 갱신
            ---------------
            BEGIN
                FOR C_GNT2 IN CSR_GNT2 LOOP
                    BEGIN
                        P_TIM_WORK_HOUR_CHG (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, C_GNT2.S_YMD, C_GNT2.E_YMD, C_GNT2.SABUN, '', 'APP_AFTER' );
                    END;
                END LOOP;

            EXCEPTION
                WHEN OTHERS THEN
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'23',P_SQLERRM, P_SABUN);
            END;

		 ELSIF  P_APPL_CD IN ('24')  THEN -- 근태취소신청
        P_SQLERRM := '[근태소명신청(24)]' || P_SQLERRM;
        IF LV_APPL_STATUS_CD = '99' THEN
            BEGIN
                FOR V IN (
                  SELECT ROWNUM AS R_NUM, A.VACATION_YMD, A.GNT_CD, C.GNT_GUBUN_CD , B.GNT_REQ_REASON, C.SRC_YY, C.SRC_GNT_CD, C.SRC_USE_S_YMD, C.SRC_USE_E_YMD
                    FROM TTIM387 A, TTIM385 B, TTIM301 C
                    WHERE A.ENTER_CD = P_ENTER_CD
                    AND A.APPL_SEQ = P_APPL_SEQ
                    AND A.ENTER_CD = B.ENTER_CD
                    AND A.GNT_CD = B.GNT_CD
                    AND A.SABUN = B.SABUN
                    AND A.APPL_SEQ = B.APPL_SEQ
                    AND B.ENTER_CD = C.ENTER_CD
                    AND B.B_APPL_SEQ = C.APPL_SEQ
                    ORDER BY A.VACATION_YMD
                ) LOOP
                    IF V.R_NUM = 1 THEN
                        LV_APPL_SEQ := F_COM_GET_SEQ('APPL');
                        LV_S_YMD := V.VACATION_YMD;
                        LV_E_YMD := V.VACATION_YMD;
                        LV_CLOSE_DAY := 1;
                        LV_HOL_DAY := 1;
                        LV_GNT_REQ_REASON := V.GNT_REQ_REASON;
                        LV_GNT_CD := V.GNT_CD;
                        LV_GNT_GUBUN_CD := V.GNT_GUBUN_CD ;
                        LV_SRC_YY := V.SRC_YY;
                        LV_SRC_GNT_CD := V.SRC_GNT_CD;
                        LV_SRC_USE_S_YMD := V.SRC_USE_S_YMD;
                        LV_SRC_USE_E_YMD := V.SRC_USE_E_YMD;

                    ELSE
                        -- +1영업일자 계산 (날짜 선택할때 휴일은 뱉을꺼기 때문에 +1영업일로 체크)
                        BEGIN
                            SELECT SUN_DATE
                                INTO LV_NEXT_BIZ_DAY
                               FROM (
                                          SELECT ROW_NUMBER() OVER (ORDER BY SUN_DATE) AS RN, SUN_DATE, DAY_NM
                                            FROM TSYS007 -- 만세  력
                                           WHERE DAY_NM NOT IN ('토', '일')
                                              AND SUN_DATE >  LV_E_YMD
                                              AND SUN_DATE NOT IN (SELECT YY||MM||DD
                                                                  FROM TTIM001  -- 휴일관리
                                                                WHERE ENTER_CD = P_ENTER_CD
                                                                    AND NVL(GUBUN, 'Y') = 'Y' --양력기준
                                                                   )
                                       )
                             WHERE RN = 1;
                         EXCEPTION
                                WHEN OTHERS THEN
                                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'24-1',P_SQLERRM, P_SABUN);
                         END;


                        IF LV_NEXT_BIZ_DAY = V.VACATION_YMD THEN
                            LV_E_YMD := V.VACATION_YMD;
                            LV_CLOSE_DAY := LV_CLOSE_DAY + 1;

                        ELSE
                            BEGIN
                            		LV_HOL_DAY := (TO_DATE(LV_E_YMD, 'YYYYMMDD') - TO_DATE(LV_S_YMD, 'YYYYMMDD')) + 1;

                                INSERT
                                 INTO TTIM301(ENTER_CD, APPL_SEQ, SABUN, GNT_CD, GNT_GUBUN_CD, S_YMD, E_YMD, HOL_DAY ,CLOSE_DAY, GNT_REQ_RESON, UPDATE_YN, APPL_STATUS_CD, NOTE, CHKDATE, CHKID, SRC_YY, SRC_GNT_CD, SRC_USE_S_YMD, SRC_USE_E_YMD,REQUEST_HOUR, REQ_S_HM , REQ_E_HM)
                                VALUES(P_ENTER_CD, LV_APPL_SEQ, P_SABUN, LV_GNT_CD, LV_GNT_GUBUN_CD, LV_S_YMD, LV_E_YMD, LV_HOL_DAY, LV_CLOSE_DAY, V.GNT_REQ_REASON, 'N', '99', '', sysdate, P_CHKID, LV_SRC_YY, LV_SRC_GNT_CD, LV_SRC_USE_S_YMD, LV_SRC_USE_E_YMD,lv_REQUEST_HOUR,lv_REQ_S_HM,lv_REQ_E_HM);

                                INSERT INTO THRI103(ENTER_CD, APPL_SEQ, TITLE, APPL_CD, APPL_YMD, APPL_SABUN, APPL_IN_SABUN, APPL_STATUS_CD, FILE_SEQ, CHKDATE, CHKID)
                                VALUES(P_ENTER_CD, LV_APPL_SEQ, '근태신청','22', TO_CHAR( SYSDATE, 'YYYYMMDD'), P_SABUN, P_SABUN, '99', NULL, SYSDATE, P_CHKID);

                                --소명신청 결재선을 휴가신청서에 동일하게 생성
                                INSERT INTO THRI107(ENTER_CD, APPL_SEQ, AGREE_SABUN, AGREE_SEQ, PATH_SEQ, APPL_TYPE_CD, AGREE_TIME, GUBUN, MEMO, ORG_NM, JIKCHAK_NM, JIKWEE_NM, DEPUTY_YN, DEPUTY_SABUN, DEPUTY_ORG, DEPUTY_JIKCHAK, DEPUTY_JIKWEE, DEPUTY_ADMIN_YN, CHKDATE, CHKID)
                                    SELECT ENTER_CD, LV_APPL_SEQ, AGREE_SABUN, AGREE_SEQ, PATH_SEQ, APPL_TYPE_CD, AGREE_TIME, GUBUN, MEMO, ORG_NM, JIKCHAK_NM, JIKWEE_NM, DEPUTY_YN, DEPUTY_SABUN, DEPUTY_ORG, DEPUTY_JIKCHAK, DEPUTY_JIKWEE, DEPUTY_ADMIN_YN, CHKDATE, CHKID
                                    FROM THRI107
                                    WHERE ENTER_CD = P_ENTER_CD
                                    AND APPL_SEQ = P_APPL_SEQ;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'24-2',P_SQLERRM, P_SABUN);
                            END;
                            --초기화
                            LV_S_YMD := V.VACATION_YMD;
                            LV_E_YMD := V.VACATION_YMD;
                            LV_APPL_SEQ := F_COM_GET_SEQ('APPL');
                            LV_CLOSE_DAY := 1;
                        END IF;
                    END IF;
               END LOOP;
          EXCEPTION
                WHEN OTHERS THEN
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'24-3',P_SQLERRM, P_SABUN);
          END;
          BEGIN
               LV_HOL_DAY := (TO_DATE(LV_E_YMD, 'YYYYMMDD') - TO_DATE(LV_S_YMD, 'YYYYMMDD')) + 1;


               SELECT B_REQUEST_HOUR
                                INTO lv_REQUEST_HOUR
                                FROM TTIM385
                                WHERE APPL_SEQ = P_APPL_SEQ;
               SELECT B_REQ_S_HM
                                INTO lv_REQ_S_HM
                                FROM TTIM385
                                WHERE APPL_SEQ = P_APPL_SEQ;
               SELECT B_REQ_E_HM
                                INTO lv_REQ_E_HM
                                FROM TTIM385
                                WHERE APPL_SEQ = P_APPL_SEQ;
              IF LV_GNT_GUBUN_CD ='15' THEN  -- 반차
                LV_HOL_DAY := '0.5';
                LV_CLOSE_DAY := '0.5';

              ELSIF  LV_GNT_GUBUN_CD ='16' THEN -- 반반차
                LV_HOL_DAY := '0.25';
                LV_CLOSE_DAY := '0.25';
              ELSE
                LV_HOL_DAY := (TO_DATE(LV_E_YMD, 'YYYYMMDD') - TO_DATE(LV_S_YMD, 'YYYYMMDD')) + 1;
                LV_GNT_GUBUN_CD := '1';
              END IF ;


               INSERT INTO TTIM301(ENTER_CD, APPL_SEQ, SABUN, GNT_CD, GNT_GUBUN_CD, S_YMD, E_YMD, HOL_DAY ,CLOSE_DAY, GNT_REQ_RESON, UPDATE_YN, APPL_STATUS_CD, NOTE, CHKDATE, CHKID, SRC_YY, SRC_GNT_CD, SRC_USE_S_YMD, SRC_USE_E_YMD,REQUEST_HOUR, REQ_S_HM , REQ_E_HM)
                VALUES(P_ENTER_CD, LV_APPL_SEQ, P_SABUN,LV_GNT_CD, LV_GNT_GUBUN_CD, LV_S_YMD, LV_E_YMD, LV_HOL_DAY, LV_CLOSE_DAY, LV_GNT_REQ_REASON, 'N', '99', '', sysdate, P_CHKID, LV_SRC_YY, LV_SRC_GNT_CD, LV_SRC_USE_S_YMD, LV_SRC_USE_E_YMD,lv_REQUEST_HOUR,lv_REQ_S_HM,lv_REQ_E_HM);

               INSERT INTO THRI103(ENTER_CD, APPL_SEQ, TITLE, APPL_CD, APPL_YMD, APPL_SABUN, APPL_IN_SABUN, APPL_STATUS_CD, FILE_SEQ, CHKDATE, CHKID)
                VALUES(P_ENTER_CD, LV_APPL_SEQ, '근태신청','22', TO_CHAR( SYSDATE, 'YYYYMMDD'), P_SABUN, P_SABUN, '99', NULL, SYSDATE, P_CHKID);

               --소명신청 결재선을 휴가신청서에 동일하게 생성
               INSERT INTO THRI107(ENTER_CD, APPL_SEQ, AGREE_SABUN, AGREE_SEQ, PATH_SEQ, APPL_TYPE_CD, AGREE_TIME, GUBUN, MEMO, ORG_NM, JIKCHAK_NM, JIKWEE_NM, DEPUTY_YN, DEPUTY_SABUN, DEPUTY_ORG, DEPUTY_JIKCHAK, DEPUTY_JIKWEE, DEPUTY_ADMIN_YN, CHKDATE, CHKID)
                SELECT ENTER_CD, LV_APPL_SEQ, AGREE_SABUN, AGREE_SEQ, PATH_SEQ, APPL_TYPE_CD, AGREE_TIME, GUBUN, MEMO, ORG_NM, JIKCHAK_NM, JIKWEE_NM, DEPUTY_YN, DEPUTY_SABUN, DEPUTY_ORG, DEPUTY_JIKCHAK, DEPUTY_JIKWEE, DEPUTY_ADMIN_YN, CHKDATE, CHKID
                FROM THRI107
                WHERE ENTER_CD = P_ENTER_CD
                AND APPL_SEQ = P_APPL_SEQ;
         EXCEPTION
                WHEN OTHERS THEN
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'24-4',P_SQLERRM, P_SABUN);
          END;
        END IF;
    ------------------------------------------------------------------------------------------------------------------------------
    -- 연장근무사전신청(110), 연장근무변경신청(111)
    ------------------------------------------------------------------------------------------------------------------------------
    ELSIF  P_APPL_CD IN ('110', '111')  THEN -- 연장근무사전신청

        IF NVL(F_COM_GET_STD_CD_VALUE( P_ENTER_CD, 'TIM_WORK_USE_YN'), 'Y') = 'Y' THEN
            P_SQLERRM := '[연장근무신청('||P_APPL_CD||')]' || P_SQLERRM;


          DECLARE CURSOR CSR_TIM601 IS
                -- 2021-05-04 mschoe UPDATE START
                -- F_COM_GET_WORKTYPE 함수로 취득하는 직군코드(H10050) 값이 A(사무직), B(생산직)의 형태로 셋팅되어 있지 않음. 따라서 직군코드(H10050)의 NOTE1 값이 'A'면 사무직, 'B'면 생산직으로 처리하도록 변경
                --SELECT A.ENTER_CD,A.SABUN, A.YMD, A.REQ_E_HM, B.APPL_STATUS_CD, F_COM_GET_WORKTYPE(A.ENTER_CD, A.SABUN, A.YMD) AS WORK_TYPE
                SELECT A.ENTER_CD,A.SABUN, A.YMD, A.REQ_S_HM, A.REQ_E_HM, B.APPL_STATUS_CD
                     , F_COM_GET_GRCODE_NOTE_VAL(A.ENTER_CD, 'H10050', F_COM_GET_WORKTYPE(A.ENTER_CD, A.SABUN, A.YMD), 1) AS WORK_TYPE
                -- 2021-05-04 mschoe UPDATE END
                  FROM TTIM601 A, THRI103 B
                 WHERE A.ENTER_CD = B.ENTER_CD
                   AND A.APPL_SEQ = B.APPL_SEQ
                  --AND B.APPL_STATUS_CD = '99'  -- 처리완료여부 상관없이 해당일자 근무시간 갱신 하기 위해 주석처리함.
                   AND A.ENTER_CD = P_ENTER_CD
                   AND A.APPL_SEQ = P_APPL_SEQ ;

            ---------------
            -- 일근무 갱신
            ---------------
            BEGIN
                FOR C IN CSR_TIM601 LOOP
	                
	                --25.1.21 추가 : 토파스 법인은 퇴근시간 NULL처리
                    IF P_ENTER_CD = 'TP' THEN
                        C.REQ_E_HM := NULL;
                    END IF;

                    -- [벽산]연장근무신청 처리완료 시 사무직은 퇴근신간 갱신.
                    --IF C.APPL_STATUS_CD = '99' AND C.WORK_TYPE = 'A' THEN
                    IF C.APPL_STATUS_CD = '99' THEN
                        BEGIN
                            UPDATE TTIM335
                               SET IN_HM = NVL(C.REQ_S_HM, IN_HM)
                                 , OUT_HM   = C.REQ_E_HM
                                 , MEMO     = REPLACE(MEMO, '[연장신청 후 퇴근시간 갱신]', '') || '[연장신청 후 퇴근시간 갱신]'
                                 , CHKDATE  = SYSDATE
                                 , CHKID    = P_SABUN
                             WHERE ENTER_CD = C.ENTER_CD
                               AND SABUN    = C.SABUN
                               AND YMD      = C.YMD;
                        EXCEPTION
                            WHEN OTHERS THEN
                                P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'110-1',P_SQLERRM, P_SABUN);
                        END;
                    ELSE
                        -- 근무시간변경 이력 삭제
                        DELETE FROM TTIM337 WHERE ENTER_CD = C.ENTER_CD AND YMD = C.YMD AND SABUN = C.SABUN AND NVL((SELECT MAX(UPDATE_YN)
                                                                                                                     FROM TTIM335
                                                                                                                     WHERE ENTER_CD = C.ENTER_CD
                                                                                                                       AND YMD = C.YMD
                                                                                                                       AND SABUN = C.SABUN
                                                                                                                 ),'N') <> 'Y';


                        DELETE FROM TTIM335 WHERE ENTER_CD = C.ENTER_CD AND YMD = C.YMD AND SABUN = C.SABUN AND NVL(UPDATE_YN,'N') <> 'Y'
                        ;

                    END IF;

                    P_TIM_WORK_HOUR_CHG (  P_SQLCODE, P_SQLERRM, P_ENTER_CD, C.YMD, C.YMD, C.SABUN, '', 'APP_AFTER' );

                END LOOP;
            EXCEPTION
                WHEN OTHERS THEN
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'110-2',P_SQLERRM, P_SABUN);
            END;
        END IF;



    ------------------------------------------------------------------------------------------------------------------------------
    -- [벽산]연장근무추가신청(122)
    ------------------------------------------------------------------------------------------------------------------------------
    /* 결과보고가 되지 않은 연장근무 신청에 대해서는 후처리 작업이 필요없다.
    ELSIF  P_APPL_CD IN ('122')  THEN -- 연장근무추가신청

        P_SQLERRM := '[연장근무추가신청(122)]' || P_SQLERRM;
        lv_sabun := '';
        lv_ymd  := '';
        BEGIN
            SELECT A.SABUN, A.YMD
              INTO lv_sabun, lv_ymd
              FROM TTIM611 A, THRI103 B
             WHERE A.ENTER_CD = B.ENTER_CD
               AND A.APPL_SEQ = B.APPL_SEQ
              --AND B.APPL_STATUS_CD = '99'  -- 처리완료여부 상관없이 해당일자 근무시간 갱신 하기 위해 주석처리함.
               AND A.ENTER_CD = P_ENTER_CD
               AND A.APPL_SEQ = P_APPL_SEQ ;
        EXCEPTION
            WHEN OTHERS THEN
                lv_sabun := '';
                lv_ymd := '';
        END;
        ---------------
        -- 일근무 갱신
        ---------------
        IF lv_sabun IS NOT NULL THEN
            BEGIN
                P_TIM_WORK_HOUR_CHG (  P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_ymd, lv_ymd, lv_sabun, '', 'APP_AFTER' );

            EXCEPTION
                WHEN OTHERS THEN
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'122',P_SQLERRM, P_SABUN);
            END;
        END IF
        ;*/


    ELSIF  P_APPL_CD IN ('123')  THEN -- 연장근무결과보고

        P_SQLERRM := '[연장근무결과보고(123)]' || P_SQLERRM;

        FOR VL_OT IN (SELECT A.SABUN, A.YMD
                        FROM TTIM615 A, THRI103 B
                       WHERE A.ENTER_CD = B.ENTER_CD
                         AND A.APPL_SEQ = B.APPL_SEQ
                         AND A.ENTER_CD = P_ENTER_CD
                         AND A.APPL_SEQ = P_APPL_SEQ)
        LOOP
            BEGIN
	            DBMS_OUTPUT.PUT_LINE('P_OLD_APPL_STATUS_CD: '||P_OLD_APPL_STATUS_CD||' LV_APPL_STATUS_CD: '||LV_APPL_STATUS_CD);
                --IF P_OLD_APPL_STATUS_CD <> LV_APPL_STATUS_CD AND '99' IN (P_OLD_APPL_STATUS_CD, LV_APPL_STATUS_CD) THEN 20250715 백업
                   IF (P_OLD_APPL_STATUS_CD IS NULL OR P_OLD_APPL_STATUS_CD NOT IN ('99')) AND LV_APPL_STATUS_CD = '99' THEN
                    DBMS_OUTPUT.PUT_LINE('P_APPL_SEQ: '||P_APPL_SEQ||' VL_OT.YMD: '||VL_OT.YMD||' VL_OT.SABUN: '||VL_OT.SABUN);
                    P_TIM_WORK_HOUR_CHG (  P_SQLCODE, P_SQLERRM, P_ENTER_CD, VL_OT.YMD, VL_OT.YMD, VL_OT.SABUN, '', 'APP_AFTER' );
                    P_OT_VACATION_CRE (  P_SQLCODE, P_SQLERRM, P_ENTER_CD, VL_OT.YMD, VL_OT.YMD, VL_OT.SABUN, VL_OT.SABUN);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'124',P_SQLERRM, P_SABUN);
            END;

        END LOOP;


    ELSIF  P_APPL_CD IN ('124')  THEN -- 연장근무통합보고

        P_SQLERRM := '[연장근무통합보고(124)]' || P_SQLERRM;

        FOR VL_OT IN (SELECT A.SABUN, A.YMD
                        FROM TTIM616 A, THRI103 B
                       WHERE A.ENTER_CD     = B.ENTER_CD
                         AND A.RES_APPL_SEQ = B.APPL_SEQ
                         AND B.ENTER_CD     = P_ENTER_CD
                         AND B.APPL_SEQ     = P_APPL_SEQ)
        LOOP
            BEGIN
                IF P_OLD_APPL_STATUS_CD <> LV_APPL_STATUS_CD AND '99' IN (P_OLD_APPL_STATUS_CD, LV_APPL_STATUS_CD) THEN
                    P_TIM_WORK_HOUR_CHG (  P_SQLCODE, P_SQLERRM, P_ENTER_CD, VL_OT.YMD, VL_OT.YMD, VL_OT.SABUN, '', 'APP_AFTER' );
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'124-END',P_SQLERRM, P_SABUN);
            END;

        END LOOP;


    ------------------------------------------------------------------------------------------------------------------------------
    -- 휴일근무신청(120)
    ------------------------------------------------------------------------------------------------------------------------------
    ELSIF  P_APPL_CD IN ('120')  THEN -- 휴일근무신청
        IF NVL(F_COM_GET_STD_CD_VALUE( P_ENTER_CD, 'TIM_WORK_USE_YN'), 'Y') = 'Y' THEN
            P_SQLERRM := '[휴일근무신청(120)]' || P_SQLERRM;
            lv_sabun := '';
            lv_ymd  := '';
            BEGIN
                SELECT A.SABUN, A.YMD
                  INTO lv_sabun, lv_ymd
                  FROM TTIM601 A, THRI103 B
                 WHERE A.ENTER_CD = B.ENTER_CD
                   AND A.APPL_SEQ = B.APPL_SEQ
                  --AND B.APPL_STATUS_CD = '99'
                   AND A.ENTER_CD = P_ENTER_CD
                   AND A.APPL_SEQ = P_APPL_SEQ ;
            EXCEPTION
                WHEN OTHERS THEN
                    lv_sabun := '';
                    lv_ymd := '';
            END;
            ---------------
            -- 일근무 갱신
            ---------------
            IF lv_sabun IS NOT NULL THEN
                BEGIN
                    P_TIM_WORK_HOUR_CHG (  P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_ymd, lv_ymd, lv_sabun, '', 'APP_AFTER' );

                EXCEPTION
                    WHEN OTHERS THEN
                        P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'120',P_SQLERRM, P_SABUN);
                END;
            END IF;
        END IF;

    ------------------------------------------------------------------------------------------------------------------------------
    -- 대체휴가신청(121)
    ------------------------------------------------------------------------------------------------------------------------------
    ELSIF  P_APPL_CD IN ('121')  THEN -- 대체휴가신청
        P_SQLERRM := '[대체휴가신청(121)]' || P_SQLERRM;
        lv_sabun := '';
        lv_ymd  := '';


        DECLARE CURSOR CSR_GNT IS
              SELECT A.SABUN
                   , A.GNT_CD
                   , A.S_YMD
                   , A.E_YMD
              FROM TTIM301 A
              WHERE A.ENTER_CD = P_ENTER_CD
               AND A.APPL_SEQ  = P_APPL_SEQ;

            ---------------
            -- 일근무 갱신
            ---------------
            BEGIN
                FOR C_GNT IN CSR_GNT LOOP
                    BEGIN
                        P_TIM_WORK_HOUR_CHG (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, C_GNT.S_YMD, C_GNT.E_YMD, C_GNT.SABUN, '', 'APP_AFTER' );
                    END;

                END LOOP;
            EXCEPTION
                WHEN OTHERS THEN
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'22',P_SQLERRM, P_SABUN);
            END;


    ------------------------------------------------------------------------------------------------------------------------------
    -- 해외출장신청(126)
    -- 근태신청(22)내역 생성
    ------------------------------------------------------------------------------------------------------------------------------
    ELSIF  P_APPL_CD IN ('126')  THEN -- 해외출장신청
        P_SQLERRM := '[해외출장신청(126)]' || P_SQLERRM;

     /*==========================================================================================================
       근태 : 근무스케쥴신청(301)
     ==========================================================================================================*/
     ELSIF  P_APPL_CD = '301' THEN -- 근무스케쥴신청

        P_SQLERRM := '[근무스케쥴신청(301)]' || P_SQLERRM;
        --P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'301',P_SQLERRM,P_CHKID);

        BEGIN
              SELECT SDATE
                   , EDATE
               INTO lv_sdate, lv_edate
               FROM TTIM811 A
              WHERE A.ENTER_CD = P_ENTER_CD
                AND A.APPL_SEQ = P_APPL_SEQ;
        EXCEPTION
            WHEN OTHERS THEN
                P_SQLERRM := P_SQLERRM || ' , 신청내역 조회 시 에러발생 ' || SQLERRM;
                P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'301-0',P_SQLERRM,P_CHKID);
                RETURN;
        END;
        IF (P_OLD_APPL_STATUS_CD IS NULL OR P_OLD_APPL_STATUS_CD NOT IN ('99')) AND LV_APPL_STATUS_CD = '99' THEN

            --P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'301','2222',P_CHKID);

            --  백업 저장
            BEGIN
                DELETE FROM TTIM803
                 WHERE ENTER_CD    = P_ENTER_CD
                   AND APPL_SEQ    = P_APPL_SEQ;

                INSERT INTO TTIM803 (ENTER_CD,APPL_SEQ,SABUN,YMD,WORK_CD,REQUEST_HOUR,APPLY_HOUR,WORK_ORG_CD,TIME_CD,CHKDATE,CHKID )
                SELECT ENTER_CD
                     , P_APPL_SEQ AS APPL_SEQ
                     , SABUN
                     , YMD
                     , WORK_CD
                     , REQUEST_HOUR
                     , APPLY_HOUR
                     , WORK_ORG_CD
                     , TIME_CD
                     , CHKDATE
                     , CHKID
                  FROM TTIM120 A
                 WHERE ENTER_CD = P_ENTER_CD
                   AND YMD BETWEEN lv_sdate AND lv_edate
                   AND SABUN = P_SABUN ;

            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || ' , 이전 근무시간 백업 저장 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'301-1',P_SQLERRM,P_CHKID);
            END;

            -- 개인별 예외근무시간 등록
            BEGIN

                 MERGE INTO TTIM120 T
                 USING
                (
                        SELECT A.ENTER_CD
                             , A.SABUN
                             , A.YMD
                             , A.WORK_ORG_CD
                             , B.AF_TIME_CD AS TIME_CD
                             , P_APPL_SEQ   AS APPL_SEQ
                          FROM TTIM120_V A, TTIM812 B
                         WHERE A.ENTER_CD   = P_ENTER_CD
                           AND A.SABUN      = P_SABUN
                           AND A.ENTER_CD   = B.ENTER_CD
                           AND A.YMD        = B.WORK_YMD
                           AND A.SABUN      = B.SABUN
                           AND B.APPL_SEQ   = P_APPL_SEQ
                ) S
                ON (
                          T.ENTER_CD    = S.ENTER_CD
                     AND  T.SABUN       = S.SABUN
                     AND  T.YMD         = S.YMD
                     AND  T.WORK_ORG_CD = S.WORK_ORG_CD
                )
                WHEN MATCHED THEN
                   UPDATE SET T.CHKDATE     = SYSDATE
                            , T.CHKID     = P_CHKID
                           ,  T.TIME_CD  = S.TIME_CD
                            , T.APPL_SEQ = S.APPL_SEQ
                WHEN NOT MATCHED THEN
                    INSERT (T.ENTER_CD, T.SABUN, T.YMD, T.WORK_ORG_CD, T.TIME_CD, T.APPL_SEQ, T.CHKDATE, T.CHKID)
                    VALUES (S.ENTER_CD, S.SABUN, S.YMD, S.WORK_ORG_CD, S.TIME_CD, S.APPL_SEQ, SYSDATE, P_CHKID);

            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || ' , 개인별 예외근무시간 등록 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'301-3',P_SQLERRM,P_CHKID);
            END;
            ---------------
            -- 일근무 갱신
            ---------------
            BEGIN
                P_TIM_WORK_HOUR_CHG (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_sdate, lv_edate, P_SABUN, '', 'APP_AFTER' );
            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || '==> 일근무 갱신 생성 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'301-4',P_SQLERRM, P_CHKID);
            END;


        END IF;
        -- 신청서 상태 되돌림..
        IF P_OLD_APPL_STATUS_CD IN ('99') AND LV_APPL_STATUS_CD NOT IN ( '99' ) THEN


            P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'303-11',P_SQLERRM,P_CHKID);

            -- 신청 전 상태로 되돌림.
            BEGIN

                DELETE FROM TTIM120
                WHERE ENTER_CD    = P_ENTER_CD
                  AND APPL_SEQ    = P_APPL_SEQ
                  AND YMD BETWEEN lv_sdate AND lv_edate;

                 INSERT INTO TTIM120 (ENTER_CD, SABUN, YMD, WORK_ORG_CD, TIME_CD, CHKDATE, CHKID)
                    SELECT A.ENTER_CD
                         , A.SABUN
                         , A.YMD
                         , A.WORK_ORG_CD
                         , A.TIME_CD
                         , A.CHKDATE
                         , A.CHKID
                      FROM TTIM803 A
                     WHERE A.ENTER_CD   = P_ENTER_CD
                       AND A.APPL_SEQ   = P_APPL_SEQ
                       AND A.SABUN      = P_SABUN
                       AND A.YMD BETWEEN lv_sdate AND lv_edate
                       AND NOT EXISTS ( SELECT 1
                                          FROM TTIM120 X
                                         WHERE X.ENTER_CD    = A.ENTER_CD
                                           AND X.SABUN       = A.SABUN
                                           AND X.YMD         = A.YMD
                                           AND X.WORK_ORG_CD = A.WORK_ORG_CD ) ;

            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || ' , 신청 전 상태로 저장 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'301-11',P_SQLERRM,P_CHKID);
            END;

            ---------------
            -- 일근무 갱신
            ---------------
            BEGIN
                P_TIM_WORK_HOUR_CHG (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_sdate, lv_edate, P_SABUN, '', 'APP_AFTER' );
            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || '==> 일근무 갱신 생성 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'301-12',P_SQLERRM, P_CHKID);
            END;

        END IF;

     /*==========================================================================================================
       근태 : 부서근무스케쥴신청(302)
     ==========================================================================================================*/
     ELSIF  P_APPL_CD = '302' THEN -- 부서근무스케쥴신청

        P_SQLERRM := '[부서근무스케쥴신청(302)]' || P_SQLERRM;
        --P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'301',P_SQLERRM,P_CHKID);

        BEGIN
              SELECT SDATE
                   , EDATE
               INTO lv_sdate, lv_edate
               FROM TTIM811 A
              WHERE A.ENTER_CD = P_ENTER_CD
                AND A.APPL_SEQ = P_APPL_SEQ
                AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS THEN
                P_SQLERRM := P_SQLERRM || ' , 신청내역 조회 시 에러발생 ' || SQLERRM;
                P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'302-0',P_SQLERRM,P_CHKID);
                RETURN;
        END;
        IF (P_OLD_APPL_STATUS_CD IS NULL OR P_OLD_APPL_STATUS_CD NOT IN ('99')) AND LV_APPL_STATUS_CD = '99' THEN

            --P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'301','2222',P_CHKID);

            --  백업 저장
            BEGIN
                DELETE FROM TTIM803
                 WHERE ENTER_CD    = P_ENTER_CD
                   AND APPL_SEQ    = P_APPL_SEQ;

                INSERT INTO TTIM803 (ENTER_CD,APPL_SEQ,SABUN,YMD,WORK_CD,REQUEST_HOUR,APPLY_HOUR,WORK_ORG_CD,TIME_CD,CHKDATE,CHKID )
                SELECT ENTER_CD
                     , P_APPL_SEQ AS APPL_SEQ
                     , SABUN
                     , YMD
                     , WORK_CD
                     , REQUEST_HOUR
                     , APPLY_HOUR
                     , WORK_ORG_CD
                     , TIME_CD
                     , CHKDATE
                     , CHKID
                  FROM TTIM120 A
                 WHERE A.ENTER_CD = P_ENTER_CD
                   AND A.YMD BETWEEN lv_sdate AND lv_edate
                   AND EXISTS ( SELECT 1
                                  FROM TTIM811 X
                                 WHERE X.ENTER_CD = A.ENTER_CD
                                   AND X.APPL_SEQ = P_APPL_SEQ
                                   AND X.SABUN    = A.SABUN
                              );

            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || ' , 이전 근무시간 백업 저장 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'302-1',P_SQLERRM,P_CHKID);
            END;

            -- 개인별 예외근무시간 등록
            BEGIN

                 MERGE INTO TTIM120 T
                 USING
                (
                        SELECT A.ENTER_CD
                             , A.SABUN
                             , A.YMD
                             , A.WORK_ORG_CD
                             , B.AF_TIME_CD AS TIME_CD
                             , P_APPL_SEQ   AS APPL_SEQ
                          FROM TTIM120_V A, TTIM812 B
                         WHERE A.ENTER_CD   = P_ENTER_CD
                           AND A.ENTER_CD   = B.ENTER_CD
                           AND A.YMD        = B.WORK_YMD
                           AND A.SABUN      = B.SABUN
                           AND B.APPL_SEQ   = P_APPL_SEQ
                ) S
                ON (
                          T.ENTER_CD    = S.ENTER_CD
                     AND  T.SABUN       = S.SABUN
                     AND  T.YMD         = S.YMD
                     AND  T.WORK_ORG_CD = S.WORK_ORG_CD
                )
                WHEN MATCHED THEN
                   UPDATE SET T.CHKDATE     = SYSDATE
                            , T.CHKID     = P_CHKID
                           ,  T.TIME_CD  = S.TIME_CD
                            , T.APPL_SEQ = S.APPL_SEQ
                WHEN NOT MATCHED THEN
                    INSERT (T.ENTER_CD, T.SABUN, T.YMD, T.WORK_ORG_CD, T.TIME_CD, T.APPL_SEQ, T.CHKDATE, T.CHKID)
                    VALUES (S.ENTER_CD, S.SABUN, S.YMD, S.WORK_ORG_CD, S.TIME_CD, S.APPL_SEQ, SYSDATE, P_CHKID);

            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || ' , 개인별 예외근무시간 등록 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'302-3',P_SQLERRM,P_CHKID);
            END;
            ---------------
            -- 일근무 갱신
            ---------------
            BEGIN

                FOR C IN (SELECT SABUN
                           FROM TTIM811 A
                          WHERE A.ENTER_CD = P_ENTER_CD
                            AND A.APPL_SEQ = P_APPL_SEQ )
                LOOP
                    P_TIM_WORK_HOUR_CHG (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_sdate, lv_edate, C.SABUN, '', 'APP_AFTER' );
                END LOOP;
            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || '==> 일근무 갱신 생성 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'302-4',P_SQLERRM, P_CHKID);
            END;


        END IF;
        -- 신청서 상태 되돌림..
        IF P_OLD_APPL_STATUS_CD IN ('99') AND LV_APPL_STATUS_CD NOT IN ( '99' ) THEN


            P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'302-11',P_SQLERRM,P_CHKID);

            -- 신청 전 상태로 되돌림.
            BEGIN

                DELETE FROM TTIM120
                WHERE ENTER_CD    = P_ENTER_CD
                  AND APPL_SEQ    = P_APPL_SEQ
                  AND YMD BETWEEN lv_sdate AND lv_edate;

                 INSERT INTO TTIM120 (ENTER_CD, SABUN, YMD, WORK_ORG_CD, TIME_CD, CHKDATE, CHKID)
                    SELECT A.ENTER_CD
                         , A.SABUN
                         , A.YMD
                         , A.WORK_ORG_CD
                         , A.TIME_CD
                         , A.CHKDATE
                         , A.CHKID
                      FROM TTIM803 A
                     WHERE A.ENTER_CD   = P_ENTER_CD
                       AND A.APPL_SEQ   = P_APPL_SEQ
                       AND A.YMD BETWEEN lv_sdate AND lv_edate
                       AND NOT EXISTS ( SELECT 1
                                          FROM TTIM120 X
                                         WHERE X.ENTER_CD    = A.ENTER_CD
                                           AND X.SABUN       = A.SABUN
                                           AND X.YMD         = A.YMD
                                           AND X.WORK_ORG_CD = A.WORK_ORG_CD ) ;

            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || ' , 신청 전 상태로 저장 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'302-21',P_SQLERRM,P_CHKID);
            END;

            ---------------
            -- 일근무 갱신
            ---------------
            BEGIN
                FOR C IN (SELECT SABUN
                           FROM TTIM803 A
                          WHERE A.ENTER_CD = P_ENTER_CD
                            AND A.APPL_SEQ = P_APPL_SEQ
                            AND A.YMD BETWEEN lv_sdate AND lv_edate)
                LOOP
                    P_TIM_WORK_HOUR_CHG (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_sdate, lv_edate, C.SABUN, '', 'APP_AFTER' );
                END LOOP;
            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || '==> 일근무 갱신 생성 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'301-12',P_SQLERRM, P_CHKID);
            END;

        END IF;

     /*==========================================================================================================
       근태 : 월 근무시간신청(303) -- 도이치
     ==========================================================================================================*/
/*
     ELSIF  P_APPL_CD = '303' THEN -- 근무시간신청

        P_SQLERRM := '[근무시간신청(303)]' || P_SQLERRM;
        --P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'303',P_SQLERRM,P_CHKID);

        -- 근무조 변경 하는 로직
        IF P_OLD_APPL_STATUS_CD NOT IN ('99') AND LV_APPL_STATUS_CD = '99' THEN

            BEGIN  -- 전월 마지막날짜
                  SELECT YM||'01'
                       , TO_CHAR(TO_DATE(YM||'01', 'YYYYMMDD')-1, 'YYYYMMDD')
                   INTO lv_sdate, lv_edate
                   FROM TTIM801 A
                  WHERE A.ENTER_CD = P_ENTER_CD
                    AND A.APPL_SEQ = P_APPL_SEQ;
            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || ' , 신청내역 조회 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'303-0',P_SQLERRM,P_CHKID);
                    RETURN;
            END;

            FOR CR IN (
                            SELECT A.TG_SABUN AS SABUN
                                 , A.AF_WORK_ORG_CD
                                 , B.MAP_CD AS WORK_ORG_CD
                                 , B.SDATE
                                 , B.EDATE
                                 , A.YM
                                 , TO_CHAR(LAST_DAY(TO_DATE(A.YM||'01', 'YYYYMMDD')), 'YYYYMMDD') AS EDATE3 --일근무갱신 시 마지막일짜

                                 , ( SELECT TO_CHAR(TO_DATE(MIN(X.SDATE), 'YYYYMMDD')-1, 'YYYYMMDD')
                                       FROM TORG113 X
                                      WHERE X.ENTER_CD    = A.ENTER_CD
                                        AND X.MAP_TYPE_CD = '500'
                                        AND X.SABUN       = A.TG_SABUN
                                        AND X.SDATE       > A.YM||'01' ) AS EDATE2

                              FROM TTIM802 A
                                 , ( SELECT SABUN
                                          , MAX(MAP_CD) KEEP(DENSE_RANK FIRST ORDER BY SDATE DESC) AS MAP_CD
                                          , MAX(SDATE) AS SDATE
                                          , MAX(EDATE) KEEP(DENSE_RANK FIRST ORDER BY SDATE DESC) AS EDATE
                                       FROM TORG113 X
                                      WHERE X.ENTER_CD    = P_ENTER_CD
                                        AND X.MAP_TYPE_CD = '500'
                                        AND lv_sdate BETWEEN X.SDATE AND NVL(X.EDATE, '29991231')
                                        AND EXISTS ( SELECT 1 FROM TTIM802 Y WHERE  Y.ENTER_CD = P_ENTER_CD AND Y.APPL_SEQ = P_APPL_SEQ AND  Y.TG_SABUN = X.SABUN )
                                      GROUP BY SABUN  -- 현재 근무조
                                   ) B
                              WHERE A.ENTER_CD  = P_ENTER_CD
                                AND A.APPL_SEQ  = P_APPL_SEQ
                                AND A.TG_SABUN  = B.SABUN(+)
                                AND NOT( A.AF_WORK_ORG_CD = NVL(B.MAP_CD,'1') AND B.EDATE IS NULL )
                       )
            LOOP
                -- 이전 근무조 종료일자 업데이트
                IF CR.WORK_ORG_CD IS NOT NULL THEN
                    BEGIN
                        UPDATE TORG113
                           SET EDATE       = lv_edate
                         WHERE ENTER_CD    = P_ENTER_CD
                           AND MAP_TYPE_CD = '500'
                           AND SABUN       = CR.SABUN
                           AND MAP_CD      = CR.WORK_ORG_CD
                           AND SDATE       = CR.SDATE;

                    EXCEPTION
                        WHEN OTHERS THEN
                            P_SQLERRM := P_SQLERRM || '==>근무시간신청 : ' || P_APPL_SEQ || ' , 이전 근무조 종료일바 변경 저장 시 에러발생 ' || SQLERRM;
                            P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'303-1',P_SQLERRM,P_CHKID);
                    END;
                END IF;

                -- 근무조 예외 이력 생성
                BEGIN

                          MERGE INTO TORG113 T
                         USING
                        (
                               SELECT P_ENTER_CD           AS  ENTER_CD
                                    , CR.SABUN           AS  SABUN
                                    , '500'              AS  MAP_TYPE_CD
                                    , CR.AF_WORK_ORG_CD  AS  MAP_CD
                                    , CR.YM || '01'      AS  SDATE
                                    , CR.EDATE2          AS  EDATE
                                    , SYSDATE            AS  CHKDATE
                                    , P_CHKID            AS  CHKID
                                    , P_APPL_SEQ         AS  APPL_SEQ
                                FROM DUAL
                        ) S
                        ON (
                                  T.ENTER_CD    = S.ENTER_CD
                             AND  T.SABUN       = S.SABUN
                             AND  T.MAP_TYPE_CD = S.MAP_TYPE_CD
                             AND  T.SDATE       = S.SDATE
                        )
                        WHEN MATCHED THEN
                           UPDATE SET T.CHKDATE     = SYSDATE
                                    , T.CHKID     = S.CHKID
                                   ,  T.MAP_CD   = S.MAP_CD
                                    , T.EDATE     = S.EDATE
                                    , T.APPL_SEQ = S.APPL_SEQ

                        WHEN NOT MATCHED THEN
                            INSERT (T.ENTER_CD, T.SABUN, T.MAP_TYPE_CD, T.MAP_CD, T.SDATE, T.EDATE, T.CHKDATE, T.CHKID, T.MEMO, T.APPL_SEQ)
                            VALUES (S.ENTER_CD, S.SABUN, S.MAP_TYPE_CD, S.MAP_CD, S.SDATE, S.EDATE, S.CHKDATE, S.CHKID, '[근무시간신청]', S.APPL_SEQ);

                EXCEPTION
                    WHEN OTHERS THEN
                        P_SQLERRM := P_SQLERRM || '==>근무시간신청 : ' || P_APPL_SEQ || ' , 근무조 생성 저장 시 에러발생 ' || SQLERRM;
                        P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'303-5',P_SQLERRM,P_CHKID);
                END;
                ---------------
                -- 근무스케쥴 생성
                ---------------
                BEGIN
                    --한달단위 스케쥴 생성
                    P_TIM_SCHEDULE_CREATE (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, CR.YM, CR.YM, '', CR.SABUN, 'APP_AFTER' );
                EXCEPTION
                    WHEN OTHERS THEN
                        P_SQLERRM := P_SQLERRM || '==> 근무스케쥴 생성 시 에러발생 ' || SQLERRM;
                        P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'303-6',P_SQLERRM,P_CHKID);
                END;
                ---------------
                -- 일근무 갱신
                ---------------
                BEGIN
                    --한달단위 근무 갱신
                    P_TIM_WORK_HOUR_CHG (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, CR.YM || '01', CR.EDATE3, CR.SABUN, '', 'APP_AFTER' );
                EXCEPTION
                    WHEN OTHERS THEN
                        P_SQLERRM := P_SQLERRM || '==> 일근무 갱신 생성 시 에러발생 ' || SQLERRM;
                        P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'303-7',P_SQLERRM, P_CHKID);
                END;

            END LOOP;

        END IF;

        -- 신청서 상태 되돌림..
        IF P_OLD_APPL_STATUS_CD IN ('99') AND LV_APPL_STATUS_CD NOT IN ( '99' ) THEN

            BEGIN
                DELETE FROM TORG113
                 WHERE ENTER_CD    = P_ENTER_CD
                   AND MAP_TYPE_CD = '500'
                   AND APPL_SEQ    = P_APPL_SEQ;
            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || '==>근무시간신청 : ' || P_APPL_SEQ || ' , 근무조 생성 저장 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'303-21',P_SQLERRM,P_CHKID);
            END;
            FOR CR IN (
                           SELECT A.SABUN
                                , A.MAP_CD
                                , A.SDATE
                                , ( SELECT TO_CHAR(TO_DATE(MIN(X.SDATE), 'YYYYMMDD')-1, 'YYYYMMDD')
                                      FROM TORG113 X
                                     WHERE X.ENTER_CD = A.ENTER_CD
                                       AND X.MAP_TYPE_CD = A.MAP_TYPE_CD
                                       AND X.SABUN       = A.SABUN
                                       AND X.SDATE > A.EDATE ) AS EDATE
                             FROM TORG113 A, TTIM802 B
                            WHERE A.ENTER_CD    = P_ENTER_CD
                              AND A.MAP_TYPE_CD = '500'
                              AND A.ENTER_CD    = B.ENTER_CD
                              AND A.SABUN       = B.TG_SABUN
                              AND B.APPL_SEQ    = P_APPL_SEQ
                              AND A.EDATE = TO_CHAR(LAST_DAY(TO_DATE(B.YM||'01', 'YYYYMMDD')-1), 'YYYYMMDD')
                       )
            LOOP
                -- 이전 근무조 종료일자 업데이트
                BEGIN
                    UPDATE TORG113
                       SET EDATE       = CR.EDATE
                     WHERE ENTER_CD    = P_ENTER_CD
                       AND MAP_TYPE_CD = '500'
                       AND SABUN       = CR.SABUN
                       AND MAP_CD      = CR.MAP_CD
                       AND SDATE       = CR.SDATE;

                EXCEPTION
                    WHEN OTHERS THEN
                        P_SQLERRM := P_SQLERRM || '==>근무시간신청 : ' || P_APPL_SEQ || ' , 이전 근무조 종료일바 변경 저장 시 에러발생 ' || SQLERRM;
                        P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'303-22',P_SQLERRM,P_CHKID);
                END;


            END LOOP;

            FOR CR IN (
                           SELECT A.TG_SABUN AS SABUN
                                , A.YM
                                , A.YM || '01' AS SDATE
                                , TO_CHAR(LAST_DAY(TO_DATE(A.YM||'01', 'YYYYMMDD')), 'YYYYMMDD') AS EDATE
                             FROM TTIM802 A
                            WHERE A.ENTER_CD    = P_ENTER_CD
                              AND A.APPL_SEQ    = P_APPL_SEQ
                       )
            LOOP

                ---------------
                -- 근무스케쥴 생성
                ---------------
                BEGIN
                    --한달단위 스케쥴 생성
                    P_TIM_SCHEDULE_CREATE (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, CR.YM, CR.YM, '', CR.SABUN, 'APP_AFTER' );
                EXCEPTION
                    WHEN OTHERS THEN
                        P_SQLERRM := P_SQLERRM || '==> 근무스케쥴 생성 시 에러발생 ' || SQLERRM;
                        P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'303-23',P_SQLERRM,P_CHKID);
                END;
                ---------------
                -- 일근무 갱신
                ---------------
                BEGIN
                    --한달단위 근무 갱신
                    P_TIM_WORK_HOUR_CHG (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, CR.SDATE, CR.EDATE, CR.SABUN, '', 'APP_AFTER' );
                EXCEPTION
                    WHEN OTHERS THEN
                        P_SQLERRM := P_SQLERRM || '==> 일근무 갱신 생성 시 에러발생 ' || SQLERRM;
                        P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'303-24',P_SQLERRM, P_CHKID);
                END;

            END LOOP;

        END IF;

        /*  근무스케쥴 예외등록 -- 삭제할 것 (참고)   2020.02.10 근무조 예외 변경 하는 것으로 수정 .. 당월 변경 없을 시 전월 근무시간으로 유지 하기 위해서.
        BEGIN
              SELECT A.YM || '01' AS SDATE
                   , TO_CHAR(LAST_DAY(TO_DATE(A.YM || '01','YYYYMMDD')),'YYYYMMDD') AS EDATE
               INTO lv_sdate, lv_edate
               FROM TTIM801 A
              WHERE A.ENTER_CD = P_ENTER_CD
                AND A.APPL_SEQ = P_APPL_SEQ;
        EXCEPTION
            WHEN OTHERS THEN
                P_SQLERRM := P_SQLERRM || '==>근무시간신청 : ' || P_APPL_SEQ || ' , 신청내역 조회 시 에러발생 ' || SQLERRM;
                P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'303-0',P_SQLERRM,P_CHKID);
                RETURN;
        END;
        IF P_OLD_APPL_STATUS_CD NOT IN ('99') AND LV_APPL_STATUS_CD = '99' THEN
            --  백업 저장
            BEGIN
                DELETE FROM TTIM803
                 WHERE ENTER_CD    = P_ENTER_CD
                   AND APPL_SEQ    = P_APPL_SEQ;

                INSERT INTO TTIM803 (ENTER_CD,APPL_SEQ,SABUN,YMD,WORK_CD,REQUEST_HOUR,APPLY_HOUR,WORK_ORG_CD,TIME_CD,CHKDATE,CHKID )
                SELECT ENTER_CD
                     , P_APPL_SEQ AS APPL_SEQ
                     , SABUN
                     , YMD
                     , WORK_CD
                     , REQUEST_HOUR
                     , APPLY_HOUR
                     , WORK_ORG_CD
                     , TIME_CD
                     , CHKDATE
                     , CHKID
                  FROM TTIM120 A
                 WHERE ENTER_CD = P_ENTER_CD
                   AND YMD BETWEEN lv_sdate AND lv_edate
                   AND EXISTS ( SELECT 1
                                  FROM TTIM802 X
                                 WHERE X.ENTER_CD = P_ENTER_CD
                                   AND X.APPL_SEQ = P_APPL_SEQ
                                   AND X.TG_SABUN = A.SABUN ) ;

            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || '==>근무시간신청 : ' || P_APPL_SEQ || ' , 이전 근무시간 백업 저장 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'303-1',P_SQLERRM,P_CHKID);
            END;

            -- 개인별 예외근무시간 등록
            BEGIN

                 MERGE INTO TTIM120 T
                 USING
                (
                        SELECT A.ENTER_CD
                             , A.SABUN
                             , A.YMD
                             , A.WORK_ORG_CD
                             , B.AF_TIME_CD AS TIME_CD
                             , P_APPL_SEQ   AS APPL_SEQ
                          FROM TTIM120_V A, TTIM802 B
                         WHERE A.ENTER_CD   = P_ENTER_CD
                           AND A.YMD BETWEEN lv_sdate AND lv_edate
                           AND A.WORK_YN    = 'N'
                           AND A.ENTER_CD   = B.ENTER_CD
                           AND B.APPL_SEQ   = P_APPL_SEQ
                           AND A.SABUN      = B.TG_SABUN
                ) S
                ON (
                          T.ENTER_CD    = S.ENTER_CD
                     AND  T.SABUN       = S.SABUN
                     AND  T.YMD         = S.YMD
                     AND  T.WORK_ORG_CD = S.WORK_ORG_CD
                )
                WHEN MATCHED THEN
                   UPDATE SET T.CHKDATE     = SYSDATE
                            , T.CHKID     = P_CHKID
                           ,  T.TIME_CD  = S.TIME_CD
                            , T.APPL_SEQ = S.APPL_SEQ
                WHEN NOT MATCHED THEN
                    INSERT (T.ENTER_CD, T.SABUN, T.YMD, T.WORK_ORG_CD, T.TIME_CD, T.APPL_SEQ, T.CHKDATE, T.CHKID)
                    VALUES (S.ENTER_CD, S.SABUN, S.YMD, S.WORK_ORG_CD, S.TIME_CD, S.APPL_SEQ, SYSDATE, P_CHKID);

            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || '==>근무시간신청 : ' || P_APPL_SEQ || ' , 개인별 예외근무시간 등록 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'303-3',P_SQLERRM,P_CHKID);
            END;
            ---------------
            -- 일근무 갱신
            ---------------
            BEGIN
                FOR CR IN ( SELECT TG_SABUN
                              FROM TTIM802 A
                             WHERE A.ENTER_CD = P_ENTER_CD
                               AND A.APPL_SEQ = P_APPL_SEQ )
                LOOP
                    BEGIN
                        --한달단위 근무 갱신
                        P_TIM_WORK_HOUR_CHG (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_sdate, lv_edate, CR.TG_SABUN, '', 'APP_AFTER' );
                    END;

                END LOOP;
            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || '==> 일근무 갱신 생성 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'303-4',P_SQLERRM, P_CHKID);
            END;


        END IF;
        -- 신청서 상태 되돌림..
        IF P_OLD_APPL_STATUS_CD IN ('99') AND LV_APPL_STATUS_CD NOT IN ( '99' ) THEN


            P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'[LOG]303-11',P_SQLERRM,P_CHKID);

            -- 신청 전 상태로 되돌림.
            BEGIN

                DELETE FROM TTIM120
                WHERE ENTER_CD    = P_ENTER_CD
                  AND APPL_SEQ    = P_APPL_SEQ
                  AND YMD BETWEEN lv_sdate AND lv_edate;

                 INSERT INTO TTIM120 (ENTER_CD, SABUN, YMD, WORK_ORG_CD, TIME_CD, CHKDATE, CHKID)
                    SELECT A.ENTER_CD
                         , A.SABUN
                         , A.YMD
                         , A.WORK_ORG_CD
                         , A.TIME_CD
                         , A.CHKDATE
                         , A.CHKID
                      FROM TTIM803 A
                     WHERE A.ENTER_CD   = P_ENTER_CD
                       AND A.APPL_SEQ   = P_APPL_SEQ
                       AND A.YMD BETWEEN lv_sdate AND lv_edate
                       AND NOT EXISTS ( SELECT 1
                                          FROM TTIM120 X
                                         WHERE X.ENTER_CD    = A.ENTER_CD
                                           AND X.SABUN       = A.SABUN
                                           AND X.YMD         = A.YMD
                                           AND X.WORK_ORG_CD = A.WORK_ORG_CD ) ;

            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || '==>근무시간신청 : ' || P_APPL_SEQ || ' , 신청 전 상태로 저장 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'303-11',P_SQLERRM,P_CHKID);
            END;

            ---------------
            -- 일근무 갱신
            ---------------
            BEGIN
                FOR CR IN ( SELECT TG_SABUN
                              FROM TTIM802 A
                             WHERE A.ENTER_CD = P_ENTER_CD
                               AND A.APPL_SEQ = P_APPL_SEQ )
                LOOP
                    BEGIN
                        --한달단위 근무 갱신
                        P_TIM_WORK_HOUR_CHG (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_sdate, lv_edate, CR.TG_SABUN, '', 'APP_AFTER' );
                    END;

                END LOOP;
            EXCEPTION
                WHEN OTHERS THEN
                    P_SQLERRM := P_SQLERRM || '==> 일근무 갱신 생성 시 에러발생 ' || SQLERRM;
                    P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'303-12',P_SQLERRM, P_CHKID);
            END;

        END IF; */



    /*==========================================================================================================
      복리후생 : 경조신청 (104,904)
    ==========================================================================================================*/
    ELSIF  P_APPL_CD = '104' THEN --경조신청(담당자전용)
    		IF P_ENTER_CD <> 'KS' THEN -- 한국공항X 동작
	     		P_BEN_CRE_TIM_DATA(P_SQLCODE, P_SQLERRM, P_OLD_APPL_STATUS_CD, LV_APPL_STATUS_CD, P_ENTER_CD, P_APPL_SEQ, P_SABUN, P_CHKID, P_APPL_CD);
    		ELSE -- 한국공항
    			BEGIN
    				SELECT APPL_SEQ
    			  	  INTO LV_BEN_OCC_APPL_SEQ
    				  FROM TBEN471
    				 WHERE ENTER_CD = P_ENTER_CD
    				   AND AP_APPL_SEQ = P_APPL_SEQ
    					;
			    	P_BEN_CRE_TIM_DATA(P_SQLCODE, P_SQLERRM, P_OLD_APPL_STATUS_CD, LV_APPL_STATUS_CD, P_ENTER_CD, LV_BEN_OCC_APPL_SEQ, P_SABUN, P_CHKID, P_APPL_CD);
			    EXCEPTION
			        WHEN OTHERS THEN
			            P_SQLERRM := '그룹웨어 경조신청 매핑시 : ' || P_APPL_SEQ || ' , 매핑 신청SEQ 조회 에러' || SQLERRM;
			            P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'104-1',P_SQLERRM,P_CHKID);
			    END;
    		END IF;

	ELSIF  P_APPL_CD = '904' THEN --경조신청(직원전용)
    		IF P_ENTER_CD = 'KS' THEN
     		P_BEN_CRE_TIM_DATA(P_SQLCODE, P_SQLERRM,
     				P_OLD_APPL_STATUS_CD, LV_APPL_STATUS_CD, P_ENTER_CD, P_APPL_SEQ, P_SABUN, P_CHKID, P_APPL_CD);
            --P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'904-1','P_OLD_APPL_STATUS_CD'||P_OLD_APPL_STATUS_CD||'LV_APPL_STATUS_CD'||LV_APPL_STATUS_CD||'P_APPL_SEQ'||P_APPL_SEQ||'P_SABUN'||P_SABUN||'P_APPL_CD'||P_APPL_CD,P_CHKID);                    
    		END IF;
	  /*==========================================================================================================
	    복리후생 : 생수신청 (107)
	  ==========================================================================================================*/
	  ELSIF  P_APPL_CD = '107' THEN
		BEGIN
			SELECT
			  A.RECV_GB			    AS RECV_GB -- 단기건
			  INTO LV_RECV_GB
			FROM TBEN594 A
			WHERE 1=1
				-- A
				AND A.ENTER_CD = P_ENTER_CD
				AND A.APPL_SEQ = P_APPL_SEQ;
    EXCEPTION
        WHEN OTHERS THEN
            P_SQLERRM := '생수승인 : ' || P_APPL_SEQ || ' , 단기건 조회 시 에러' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'107-1',P_SQLERRM,P_CHKID);
    END;

		IF LV_RECV_GB = 'S' THEN -- 단기건만 동작
			IF LV_APPL_STATUS_CD = '99' THEN
				/* 필요데이터 가공 */
			  BEGIN
		  		-- 일련번호
					SELECT TO_CHAR(SYSDATE,'YYYYMMDD')||LPAD(S_TBEN592.NEXTVAL,5,'0') INTO LV_USE_SEQ FROM DUAL;

					-- 지원금액
					SELECT
					 SUM(B.USE_LT_CNT  * C.BOX_AMT) AS  USE_AMT
					 INTO LV_USE_AMT
					FROM THRI103 A, TBEN595 B, TBEN590 C
					WHERE 1=1
						-- A
						AND A.ENTER_CD = P_ENTER_CD
						AND A.APPL_SEQ = P_APPL_SEQ
						-- B
						AND A.ENTER_CD  = B.ENTER_CD
						AND A.APPL_SEQ  = B.APPL_SEQ
						-- C
						AND B.ENTER_CD  = C.ENTER_CD
						AND B.USE_LT_CD = C.LT_CD
						AND C.GB_CD     = '02' -- 공제
						AND A.APPL_YMD  BETWEEN C.USE_SDATE AND C.USE_EDATE ;
				EXCEPTION
        WHEN OTHERS THEN
            P_SQLERRM := '생수승인 : ' || P_APPL_SEQ || ' , 택배 기준데이터 가공 생성 에러' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'107-3',P_SQLERRM,P_CHKID);
   			END;

				/* 데이터 생성 */
				BEGIN
					/* 생수기본 내역 */
				  INSERT INTO TBEN592
				  (ENTER_CD,SABUN,BAS_YM,USE_GB,USE_SEQ,RECV_GB,USE_YMD,APPL_SEQ,USE_POINT,USE_AMT,DELI_AMT,DELI_YM,POST_NO,ADDR_NM,ADDR_DET_NM,CHKDATE,CHKID,RECV_NAME,PHONE_NO)
					SELECT
						 A.ENTER_CD
						 , B.SABUN
						 , SUBSTR(A.APPL_YMD, 0,6)  AS BAS_YM
						 , '02'	 							AS USE_GB  -- 유형(택배)
						 , LV_USE_SEQ					AS USE_SEQ -- 일련번호			///////////////////////
						 , B.RECV_GB			    AS RECV_GB -- 단기건
						 , A.AGREE_YMD 			  AS USE_YMD -- 사용일자는 승인날짜로
						,  A.APPL_SEQ 				AS APPL_SEQ
						 , B.USE_POINT				AS USE_POINT
						 , LV_USE_AMT					AS USE_AMT
						 , B.DELI_AMT 				AS DELI_AMT
						 , B.USE_SDATE				AS DELI_YM -- 단기건은 해당 월로
						 , B.POST_NO          AS POST_NO
						 , B.ADDR_NM 			    AS ADDR_NM
						 , B.ADDR_DET_NM 			AS ADDR_DET_NM
						 , SYSDATE 					  AS CHKDATE
						 , 'HRI_AFT_PROC'			AS CHKID
						 , B.RECV_NAME  			AS RECV_NAME
						 , B.PHONE_NO 				AS PHONE_NO
					FROM THRI103 A, TBEN594 B
						WHERE 1=1
						-- A
						AND A.ENTER_CD = P_ENTER_CD
						AND A.APPL_SEQ = P_APPL_SEQ
						-- B
						AND A.ENTER_CD  = B.ENTER_CD
						AND A.APPL_SEQ  = B.APPL_SEQ
						AND B.RECV_GB   = 'S' -- 단기건
					;

					/* 생수종류 내역 */
					INSERT INTO TBEN593
					SELECT
						A.ENTER_CD
						, A.SABUN
						, TO_CHAR(ADD_MONTHS(TO_DATE(A.USE_SDATE, 'YYYYMM'), -1), 'YYYYMM')			 	AS BAS_YM -- 택배신청만들어오기 때문에 무조건 -1
					 	, '02'			 				AS USE_GB  -- 유형(택배)
					 	, LV_USE_SEQ 		 	 	AS USE_SEQ -- 내역 업로드시 사용하는 거기 때문에 필요없음
					 	, B.USE_LT_CD  			AS USE_LT_CD
					 	, B.USE_LT_CNT 			AS USE_LT_CNT
						, SYSDATE 	   			AS CHKDATE
						, 'HRI_AFT_PROC'		AS CHKID
						, P_APPL_SEQ				AS APPL_SEQ
						, 'N'								AS DELI_ST_YN
						, ''								AS DELI_ST_MEMO
					FROM TBEN594 A, TBEN595 B
					WHERE 1=1
						AND A.ENTER_CD = P_ENTER_CD
						AND A.APPL_SEQ = P_APPL_SEQ
						-- B
						AND A.ENTER_CD  = B.ENTER_CD
						AND A.APPL_SEQ  = B.APPL_SEQ;
 				EXCEPTION
        WHEN OTHERS THEN
            P_SQLERRM := '생수승인 : ' || P_APPL_SEQ || ' , 택배내역 생성 에러' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'107-4',P_SQLERRM,P_CHKID);
   			END;
      ELSE
 				BEGIN
 					DELETE TBEN593 A
 					WHERE 1=1
 					AND A.ENTER_CD = P_ENTER_CD
 					AND A.USE_SEQ = (SELECT USE_SEQ FROM TBEN592 B WHERE 1=1 AND B.ENTER_CD = P_ENTER_CD AND B.APPL_SEQ = P_APPL_SEQ)
 					;

 					DELETE TBEN592 B
 					WHERE 1=1
 					AND B.ENTER_CD = P_ENTER_CD
 					AND B.APPL_SEQ = P_APPL_SEQ
 					;

				EXCEPTION
        WHEN OTHERS THEN
            P_SQLERRM := '생수승인취소 : ' || P_APPL_SEQ || ' , 택배내역 삭제 에러' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD,lv_biz_cd,lv_object_nm,'107-4',P_SQLERRM,P_CHKID);
   			END;
			END IF;

		-- 장기건 중 99에서 임시저장으로 바꿨을 경우
		-- 종료일자 및 유지상태 초기화,, 하면안되지만 혹시몰라 예외처리
		ELSIF LV_RECV_GB = 'L' AND (P_OLD_APPL_STATUS_CD = '99' AND LV_APPL_STATUS_CD = '11') THEN
			UPDATE TBEN594
			SET USE_EDATE = ''
				, USE_STS = 'M'
			WHERE 1=1
				AND ENTER_CD = P_ENTER_CD
				AND APPL_SEQ = P_APPL_SEQ
				AND SABUN    = P_SABUN
				;
		END IF;
	  /*==========================================================================================================
	    복리후생 : 항공권할인신청 (112)
	  ==========================================================================================================*/
	  ELSIF  P_APPL_CD = '112' THEN
        IF P_OLD_APPL_STATUS_CD NOT IN ('99') AND LV_APPL_STATUS_CD  IN ( '99' )  THEN
          -------------------
          -- 항공권할인신청 내역생성
          -------------------
          BEGIN
              P_BEN_CRE_FLT_DISC(P_SQLCODE, P_SQLERRM, P_ENTER_CD,P_APPL_SEQ, P_SABUN ,P_CHKID);
          EXCEPTION
          WHEN OTHERS THEN
              P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'112-0',P_SQLERRM, P_SABUN);
          END;

        ELSIF P_OLD_APPL_STATUS_CD IN ('99') AND LV_APPL_STATUS_CD NOT IN ( '99' ) THEN
          -------------------
          -- 항공권할인신청 내역삭제
          -------------------
          BEGIN
              P_BEN_BACK_FLT_DISC(P_SQLCODE, P_SQLERRM, P_ENTER_CD,P_APPL_SEQ, P_SABUN ,P_CHKID);
          EXCEPTION
          WHEN OTHERS THEN
              P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'112-1',P_SQLERRM, P_SABUN);
          END;

        END IF;
 	 /*==========================================================================================================
	   복리후생 : 자녀보육비 변경 승인 (113)
	 ==========================================================================================================*/

	  ELSIF  LV_APPL_STATUS_CD='99' AND P_APPL_CD = '113' THEN
        BEGIN
            P_BEN_CHD_DET_LAST_UPD(P_SQLCODE, P_SQLERRM,P_ENTER_CD, P_SABUN, P_APPL_SEQ, LV_APPL_YMD, P_CHKID);
        EXCEPTION
        WHEN OTHERS THEN
            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'113-0',P_SQLERRM, P_SABUN);
        END;

 	 /*==========================================================================================================
	   복리후생 : 장기근속여행비 신청 (116)
	 ==========================================================================================================*/
	  ELSIF  P_APPL_CD = '116'THEN
	  	IF (P_OLD_APPL_STATUS_CD IS NULL OR  P_OLD_APPL_STATUS_CD = '11') AND LV_APPL_STATUS_CD  IN ('21','31')  THEN
        BEGIN
            P_BEN_LONG_REWARD_APP_UPD(P_ENTER_CD, P_SABUN, P_APPL_SEQ, LV_APPL_YMD, P_CHKID);
        EXCEPTION
        WHEN OTHERS THEN
            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'116-0',P_SQLERRM, P_SABUN);
        END;
	  	END IF;
    END IF;

     --근태종합신청서
    IF P_APPL_CD IN ('25') THEN
        -- 유연근무신청 자료 존재여부 체크.
        BEGIN
            FOR CSR_GNT_MERGE IN (
                SELECT A.SABUN
                  FROM TTIM135 A
                 WHERE 1 = 1
                   AND A.ENTER_CD = P_ENTER_CD
                   AND A.APPL_SEQ = P_APPL_SEQ
                ) LOOP
                IF CSR_GNT_MERGE.SABUN IS NOT NULL THEN
                   IF LV_APPL_STATUS_CD = '99' THEN
                       P_TIM_GNT_MERGE_CONFIRM(P_SQLCODE,P_SQLERRM, P_ENTER_CD, P_APPL_SEQ, CSR_GNT_MERGE.SABUN, 'AFTER');
                   ELSIF LV_APPL_STATUS_CD <> '99' AND P_OLD_APPL_STATUS_CD = '99' THEN
                       P_TIM_GNT_MERGE_CANCEL(P_SQLCODE,P_SQLERRM, P_ENTER_CD, P_APPL_SEQ, CSR_GNT_MERGE.SABUN, 'AFTER');
                   END IF;
               END IF;
            END LOOP;
        END;
    END IF;

     --유연근무신청
    IF P_APPL_CD IN ('40') THEN
        -- 유연근무신청 자료 존재여부 체크.
        BEGIN
           LV_TIM131 := NULL;
           -- 신청자료에 해당하는 근태정보 가져오기
           BEGIN
              SELECT *
                INTO LV_TIM131
                FROM TTIM131 A
               WHERE ENTER_CD = P_ENTER_CD
                 AND APPL_SEQ = P_APPL_SEQ ;
           EXCEPTION
           WHEN NO_DATA_FOUND THEN
              LV_TIM131 := NULL;
           WHEN OTHERS THEN
              P_SQLERRM := '유연근무 신청  : 해당 유연근무신청서 조회 시 에러발생 ' || SQLERRM;
              P_COM_SET_LOG_NOCOMMIT(P_ENTER_CD,LV_BIZ_CD,LV_OBJECT_NM,'40-1',P_SQLERRM,P_CHKID);
           END;

           IF LV_TIM131.ENTER_CD IS NOT NULL THEN
           -- P_COM_SET_LOG(P_ENTER_CD, 'TEST_HRI', lv_object_nm,'유연근무신청 결재 승인 후 ' || LV_APPL_STATUS_CD,P_SQLERRM, P_SABUN);
               IF LV_APPL_STATUS_CD = '99' THEN
                   P_TIM_AGILE_WORK_CONFIRM(P_SQLCODE,P_SQLERRM, LV_TIM131.ENTER_CD, LV_TIM131.APPL_SEQ, LV_TIM131.SABUN, 'AFTER');
               ELSIF LV_APPL_STATUS_CD <> '99' AND P_OLD_APPL_STATUS_CD = '99' THEN
                   P_TIM_AGILE_WORK_CANCEL(P_SQLCODE,P_SQLERRM, LV_TIM131.ENTER_CD, LV_TIM131.APPL_SEQ, LV_TIM131.SABUN, 'AFTER');
               END IF;
           END IF;
        END;
    END IF;

     --휴가취합신청
    IF LV_APPL_STATUS_CD='99' AND P_APPL_CD IN ('28') THEN
        -- 유연근무신청 자료 존재여부 체크.
        BEGIN
            P_TIM_VACATION_PLAN_RES_INS(P_SQLCODE, P_SQLERRM, P_ENTER_CD, P_APPL_SEQ, P_CHKID);
        END;
    END IF;

    IF LV_APPL_STATUS_CD='99' AND P_APPL_CD IN ('26') AND P_ENTER_CD = 'KS' THEN
        LV_APPL_SEQ := F_COM_GET_SEQ('APPL');
        BEGIN
            UPDATE TTIM544 A
                SET RES_APPL_SEQ = LV_APPL_SEQ
            WHERE A.ENTER_CD = P_ENTER_CD AND A.SABUN = P_SABUN AND A.PLAN_APPL_SEQ = P_APPL_SEQ;
            
            INSERT INTO THRI103(ENTER_CD, APPL_SEQ, TITLE, APPL_CD, APPL_YMD, APPL_SABUN, APPL_IN_SABUN, APPL_STATUS_CD, FILE_SEQ, CHKDATE, CHKID)
                                VALUES(P_ENTER_CD, LV_APPL_SEQ, '휴가계획취합','28', TO_CHAR( SYSDATE, 'YYYYMMDD'), P_SABUN, P_SABUN, '99', NULL, SYSDATE, P_CHKID);

            --취합테스트중 20250723
             P_TIM_VACATION_PLAN_RES_INS(P_SQLCODE, P_SQLERRM, P_ENTER_CD, LV_APPL_SEQ, P_CHKID);
        END;
    END IF;

    /* 결재상태코드에 따른 IF
    IF  LV_APPL_STATUS_CD = '11'  THEN --임시저장
        P_SQLERRM := '임시저장 : ' || P_APPL_CD || ', 신청자사번 : ' || P_SABUN;
        --P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'20',P_SQLERRM, P_SABUN);
    ELSIF LV_APPL_STATUS_CD = '21'  THEN -- 신청
        P_SQLERRM := '신청 : ' || P_APPL_CD || ', 신청자사번 : ' || P_SABUN;
        --P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'20',P_SQLERRM, P_SABUN);

    ELSIF LV_APPL_STATUS_CD = '99'  THEN -- 결재완료
        IF  P_APPL_CD = '131'  THEN -- 교육 결과보고 결재완료시 실행
            --결과보고 결재 완료 후 교육이력관리에 저장
            --P_TRA_EDUEVENT_RESULT_INS(P_SQLCODE,P_SQLERRM,P_ENTER_CD,'','',P_SABUN,'',P_APPL_SEQ);
        --ELSE
        P_SQLERRM := '결재상태코드: '|| LV_APPL_STATUS_CD ||', 결재완료 신청서코드: ' || P_APPL_CD || ', 신청자사번 : ' || P_SABUN;
        --P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'20',P_SQLERRM, P_SABUN);
        END IF;
    ELSE
        P_SQLERRM := '신청서코드 : ' || P_APPL_CD || ', 신청자사번 : ' || P_SABUN;
        --P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'20',P_SQLERRM, P_SABUN);
    END IF;
     */

		/* 개인연금 */
    IF P_APPL_CD IN ('106') AND LV_APPL_STATUS_CD = '99' THEN
         BEGIN
          P_BEN_PNSN_TRGTR_CRE (   P_SQLCODE, P_SQLERRM, P_ENTER_CD, P_SABUN,P_APPL_SEQ ,P_CHKID);
         EXCEPTION
         WHEN OTHERS THEN
          P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'106-0',P_SQLERRM, P_SABUN);
         END;
     END IF;
     
     /*==========================================================================================================
	   복리후생 : 보험금 지급 신청 (723) (20250110 원복 by hslee)
	 ==========================================================================================================*/     
--     IF P_APPL_CD IN ('723') AND LV_APPL_STATUS_CD = '99' THEN
--         BEGIN
--            SELECT SABUN
--                INTO lv_sabun
--              FROM TBEN545
--             WHERE ENTER_CD = P_ENTER_CD
--               AND APPL_SEQ = P_APPL_SEQ;
--            P_BEN_SELF_INS_PAY(P_SQLCODE, P_SQLERRM, P_ENTER_CD, lv_sabun,P_APPL_SEQ ,P_CHKID);                    
--         EXCEPTION
--         WHEN OTHERS THEN
--          P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'723-0',P_SQLERRM, P_SABUN);
--         END;
--     END IF;

END P_HRI_AFTER_PROC_EXEC;