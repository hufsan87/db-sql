create or replace PROCEDURE             "P_BEN_PAY_DATA_CREATE_DEL" (
      P_SQLCODE                OUT  VARCHAR2 -- ERROR CODE
    , P_SQLERRM                OUT  VARCHAR2 -- ERROR MESSAGES
    , P_CNT                    OUT  VARCHAR2 -- 복사DATA수
    , P_ENTER_CD             IN  VARCHAR2 -- 회사코드
    , P_BENEFIT_BIZ_CD         IN  VARCHAR2 -- 복리후생업무구분코드(B10230)
    , P_PAY_ACTION_CD         IN  VARCHAR2 -- 급여일자 구분코드
    , P_BUSINESS_PLACE_CD    IN  VARCHAR2 -- 사업장 구분코드
    , P_CHKID                 IN  VARCHAR2 -- 수정자
)
is
/********************************************************************************/
/*                                                                                */
/*                          (c) Copyright ISU System Inc. 2004                    */
/*                                    All Rights Reserved                            */
/*                                                                                */
/********************************************************************************/
/*  PROCEDURE NAME : P_BEN_PAY_DATA_CREATE_DEL                            */
/*                                                                                */
/*              마감코드별 복리후생 이력생성                                        */
/*              10005     : 국민연금 공제자료 생성                                    */
/*              10007     : 건강보험 공제자료 생성                                    */
/********************************************************************************/
/*  [ 삭제 TABLE ]                                                                */
/*                                                                                */
/*     TBEN205 : 건강보험공제이력                                                    */
/*     TBEN105 : 국민연금공제이력                                                    */
/*                                                                                */
/********************************************************************************/
/*  [ PRC 개요 ]                                                                */
/*          < 10007     : 건강보험 공제자료 생성 >                                    */
/*         건강보험공제자료 생성 조건에 해당하는 기존 자료 DELETE                    */
/*                                                                                */
/*          < 10005     : 국민연금 공제자료 생성 >                                    */
/*         국민연금공제자료 생성 조건에 해당하는 기존 자료 DELETE                    */
/*                                                                                */
/*         급여관련사항마감관리(TCPN983) 자료의 처리상태 코드를 작업으로 지정        */
/*                                                                                */
/********************************************************************************/
/*  [ PRC 호출 ]                                                                */
/*                                                                                */
/*                                                                                */
/********************************************************************************/
/* Date          In Charge         Description                                        */
/*--------------------------------------------------------------------------    */
/* 2008-07-22  C.Y.G              Initial Release                                */
/* 2012-09-21  p.b.h              복리후생구분(B10230) 추가                        */
/*                                      (10008 기부금 10009 경조금  10010 장학금)    */
/****************************************************************************/

    /* Local Variables */
    lv_cpn201              TCPN201%ROWTYPE;
    ln_rcnt                NUMBER := 0;
    lv_sdate               VARCHAR2(08);
    ln_max_seq             NUMBER := 0;
    ln_reward_tot_mon      TBEN203.REWARD_TOT_MON%TYPE; -- 보수월액
    ln_reduction_rate      NUMBER := 0;     -- TBEN203.REDUCTION_RATE 감면율

    ln_benefit_biz_cd   VARCHAR2(10); --복리후생업무구분코드(B10230)

    ln_add_self_mon        NUMBER := 0;
    ln_add_comp_mon        NUMBER := 0;
    ln_return_self_mon    NUMBER := 0;
    ln_return_comp_mon    NUMBER := 0;

    lr_ben205                 TBEN205%ROWTYPE;     -- 건강보험공제이력
    lr_ben105                 TBEN105%ROWTYPE;  -- 국민연금공제이력

    LV_CLOSE_ST      TBEN991.CLOSE_ST%TYPE; -- 마감상태(S90003)

    lv_CREATE_PAY_YN     VARCHAR2(10) := NULL ; -- 급여연계처리여부

    LV_BIZ_CD         TSYS903.BIZ_CD%TYPE := 'BEN';
    LV_OBJECT_NM     TSYS903.OBJECT_NM%TYPE := 'P_BEN_PAY_DATA_CREATE_DEL';
    er_PGM_ERROR            EXCEPTION ;

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
                 DECODE(P_BUSINESS_PLACE_CD,NULL,'%',P_BUSINESS_PLACE_CD)
            /*
            AND X.MAP_CD = '1'
              */
           ;

    /* 작업대상자 가져오기
    */
    CURSOR CSR_CPN203 (C_BP_CD IN VARCHAR2) IS
         SELECT A.SABUN
           FROM TCPN203 A     -- 급여대상자 관리 테이블
          WHERE A.ENTER_CD          = P_ENTER_CD
            AND A.PAY_ACTION_CD     = P_PAY_ACTION_CD;
            --AND A.BUSINESS_PLACE_CD = C_BP_CD;
BEGIN
    P_SQLCODE  := NULL;
    P_SQLERRM  := NULL;
    P_CNT        := '0';

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
       WHEN OTHERS THEN
          ROLLBACK;
          P_SQLCODE := TO_CHAR(SQLCODE);
          P_SQLERRM := '[급여일자코드 : ' || P_PAY_ACTION_CD || '] 의 급여마감(TCPN981)여부 검색시 Error =>' || SQLERRM;
          P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'10',P_SQLERRM, P_CHKID);
    END;

    --급여가 마감된 경우, 복리후생 마감업무 처리를 할 수 없음.
    --IF LV_PAY_CLOSE_YN = 'Y' THEN
    -- HX, 신협적립금 제외 처리 2025.04.23
    IF LV_PAY_CLOSE_YN = 'Y' AND (P_BENEFIT_BIZ_CD != '75' AND P_ENTER_CD = 'HX') THEN
       P_SQLCODE  := '999';
       P_SQLERRM  := '해당 급여가 이미 마감되었습니다. 마감된 급여에 대한 마감은 진행할 수 없습니다. 급여 담당자와 해당 급여의 마감여부를 확인해보시기 바랍니다.';
       RETURN;
    END IF;

    /* P_BENEFIT_BIZ_CD (복리후생업무구분코드(B10230))
        10:국민연금, 15:건강보험, 120:귀성여비, 130:주거보조금, 135:이자보조금, 140:자녀학자금, 150:자녀학자금(대학), 180:대출금    */


    /* 급여사업장 별 작업
    */
    --FOR C_MAP IN CSR_MAP LOOP

        BEGIN
            DELETE FROM TBEN777
              WHERE ENTER_CD = P_ENTER_CD
                AND PAY_ACTION_CD = P_PAY_ACTION_CD
                AND BEN_GUBUN = P_BENEFIT_BIZ_CD
                /*
                AND SABUN IN (SELECT X.SABUN
                                   FROM TCPN203 X
                                  WHERE X.ENTER_CD = P_ENTER_CD
                                    AND X.PAY_ACTION_CD = P_PAY_ACTION_CD
                                    AND X.BUSINESS_PLACE_CD = C_MAP.BUSINESS_PLACE_CD)
              */
             ;
         EXCEPTION
            WHEN OTHERS THEN
               ROLLBACK;
               P_SQLCODE := TO_CHAR(SQLCODE);
               P_SQLERRM := '[급여일자코드 : ' || P_PAY_ACTION_CD || '] 복리후생공제이력 테이블(TBEN777) DELETE Error=>' || SQLERRM;
               RAISE er_PGM_ERROR;
         END;

        /* 급여관련사항마감관리(TCPN983)의 마감상태(S90003)('10001':작업전, '10003':작업완료(마감전), '10005':마감)를 '10003'(작업완료(마감전))으로 한다.          */
        -- 마감상태(S90003)('10001':작업전, '10003':작업완료(마감전), '10005':마감)
        LV_CLOSE_ST := '10001';

        BEGIN
            MERGE INTO TBEN991 A
            USING ( SELECT  P_ENTER_CD       AS ENTER_CD,
                            P_PAY_ACTION_CD  AS PAY_ACTION_CD,
                            P_BENEFIT_BIZ_CD AS BENEFIT_BIZ_CD,
                            --C_MAP.BUSINESS_PLACE_CD AS BUSINESS_PLACE_CD,
                            '1' AS BUSINESS_PLACE_CD,
                            TO_CHAR(SYSDATE, 'YYYYMMDD') AS WORK_SYMD,
                            SYSDATE          AS CHKDATE,
                            P_CHKID          AS CHKID
                      FROM  DUAL    ) B
               ON (     A.ENTER_CD      = B.ENTER_CD
                   AND  A.PAY_ACTION_CD = B.PAY_ACTION_CD
                   AND  A.BENEFIT_BIZ_CD    = B.BENEFIT_BIZ_CD
                   AND  A.BUSINESS_PLACE_CD = B.BUSINESS_PLACE_CD  )
            WHEN MATCHED THEN
                UPDATE SET  A.CLOSE_ST = LV_CLOSE_ST, -- 마감상태(S90003)('10001':작업전, '10003':작업, '10005':마감
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
           WHEN OTHERS THEN
              ROLLBACK;
              P_SQLCODE := TO_CHAR(SQLCODE);
              P_SQLERRM := '[급여일자코드 : ' || P_PAY_ACTION_CD || '],[복리후생구분코드 : ' || P_BENEFIT_BIZ_CD || '] 의 급여관련사항마감(TCPN983) 작업시 Error =>' || SQLERRM;
              RAISE er_PGM_ERROR;
        END;
        --
    --END LOOP; -- 급여사업장 별 작업 END

       ln_benefit_biz_cd := P_BENEFIT_BIZ_CD;

        --수당지급신청과 기타지급신청의 경우 신규생성되는 모든 코드를 나열하기 힘드니 급여마감항목관리에서 'Y'로 관리되는 항목은 모두 동일 로직 적용
        BEGIN
          SELECT MAX('ETC_PAY')
            INTO ln_benefit_biz_cd
            FROM TCPN980
           WHERE ENTER_CD      = P_ENTER_CD
             AND (NVL(ETC_PAY_YN, 'N') = 'Y' OR NVL(DEPT_PART_PAY_YN, 'N') ='Y')
             AND BENEFIT_BIZ_CD = P_BENEFIT_BIZ_CD
             ;
        EXCEPTION
           WHEN NO_DATA_FOUND THEN
              ln_benefit_biz_cd := P_BENEFIT_BIZ_CD;
        END;

        IF ln_benefit_biz_cd IS NULL THEN
           ln_benefit_biz_cd := P_BENEFIT_BIZ_CD;
        END IF;

      CASE ln_benefit_biz_cd

/*
        --200:학자금
        --------------------
        --  학자금 Sample
        --------------------
        WHEN '200' THEN

            BEGIN
              UPDATE TBEN744
                 SET PAY_ACTION_CD = NULL
               WHERE ENTER_CD = P_ENTER_CD
                 AND PAY_YYMM = LV_CPN201.PAY_YM
                 AND PAY_ACTION_CD = P_PAY_ACTION_CD
                 AND MAGAM_YN = 'Y';

              UPDATE TBEN746
                 SET PAY_ACTION_CD = NULL
               WHERE ENTER_CD = P_ENTER_CD
                 AND PAY_YYMM = LV_CPN201.PAY_YM
                 AND PAY_ACTION_CD = P_PAY_ACTION_CD
                 AND MAGAM_YN = 'Y';

              UPDATE TBEN745    --상신신청(업무구분:200)
                 SET PAY_ACTION_CD  = NULL
               WHERE ENTER_CD       = P_ENTER_CD
                 AND BENEFIT_BIZ_CD = '200'
                 AND PAY_YYMM       = LV_CPN201.PAY_YM
                 AND PAY_ACTION_CD = P_PAY_ACTION_CD
                 AND MAGAM_YN       = 'Y';

            EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                P_SQLCODE := TO_CHAR(SQLCODE);
                P_SQLERRM := NVL(P_SQLERRM,SQLERRM);
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'200',P_SQLERRM, P_CHKID);
            END;

        --220:의료비
        --------------------
        --  의료비 Sample
        --------------------
        WHEN '220' THEN

            BEGIN
              UPDATE TBEN483
                 SET PAY_ACTION_CD = NULL
               WHERE ENTER_CD = P_ENTER_CD
                 AND PAY_YYMM = LV_CPN201.PAY_YM
                 AND PAY_ACTION_CD = P_PAY_ACTION_CD
                 AND MAGAM_YN = 'Y';

              UPDATE TBEN745    --상신신청(업무구분:220)
                 SET PAY_ACTION_CD  = NULL
               WHERE ENTER_CD       = P_ENTER_CD
                 AND BENEFIT_BIZ_CD = '220'
                 AND PAY_YYMM       = LV_CPN201.PAY_YM
                 AND PAY_ACTION_CD = P_PAY_ACTION_CD
                 AND MAGAM_YN       = 'Y';

            EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                P_SQLCODE := TO_CHAR(SQLCODE);
                P_SQLERRM := NVL(P_SQLERRM,SQLERRM);
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'220',P_SQLERRM, P_CHKID);
            END;

        --230:대출금
        --------------------
        --  대출원금상환 Sample
        --------------------
        WHEN '230' THEN

            BEGIN
              UPDATE TBEN626
                 SET PAY_ACTION_CD = NULL
                   , PAY_YN = 'N'
               WHERE ENTER_CD = P_ENTER_CD
                 AND PAY_YYMM = LV_CPN201.PAY_YM
                 AND PAY_ACTION_CD = P_PAY_ACTION_CD
                 AND MAGAM_YN = 'Y';
            EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                P_SQLCODE := TO_CHAR(SQLCODE);
                P_SQLERRM := NVL(P_SQLERRM,SQLERRM);
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'230',P_SQLERRM, P_CHKID);
            END;

        --231:대출이자
        --------------------
        --  대출이자 Sample
        --------------------
        WHEN '231' THEN

            BEGIN
              UPDATE TBEN627
                 SET PAY_ACTION_CD = NULL
                   , PAY_YN = 'N'
               WHERE ENTER_CD = P_ENTER_CD
                 AND PAY_YYMM = LV_CPN201.PAY_YM
                 AND PAY_ACTION_CD = P_PAY_ACTION_CD
                 AND MAGAM_YN = 'Y';
            EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                P_SQLCODE := TO_CHAR(SQLCODE);
                P_SQLERRM := NVL(P_SQLERRM,SQLERRM);
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'231',P_SQLERRM, P_CHKID);
            END;

        --232:대출인정이자
        --------------------
        --  대출인정이자 Sample
        --------------------
        WHEN '232' THEN

            BEGIN
              UPDATE TBEN628
                 SET PAY_ACTION_CD = NULL
               WHERE ENTER_CD = P_ENTER_CD
                 AND PAY_YYMM = LV_CPN201.PAY_YM
                 AND PAY_ACTION_CD = P_PAY_ACTION_CD
                 AND MAGAM_YN = 'Y';
            EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                P_SQLCODE := TO_CHAR(SQLCODE);
                P_SQLERRM := NVL(P_SQLERRM,SQLERRM);
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'232',P_SQLERRM, P_CHKID);
            END;
 */


        --------------------
        -- 35 : 학자금
        --------------------
        /*WHEN '50' THEN

            BEGIN
              UPDATE TBEN751
                 SET PAY_ACTION_CD = NULL
               WHERE ENTER_CD      = P_ENTER_CD
                 AND PAY_YM        = LV_CPN201.PAY_YM
                 AND PAY_ACTION_CD = P_PAY_ACTION_CD
                 AND PAY_MON       > 0
                 AND CLOSE_YN      = 'Y';
            EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                P_SQLCODE := TO_CHAR(SQLCODE);
                P_SQLERRM := NVL(P_SQLERRM,SQLERRM);
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'35',P_SQLERRM, P_CHKID);
            END;


        --------------------
        -- 90 : 경조금
        --------------------
        WHEN '90' THEN

            BEGIN
              UPDATE TBEN471_YW
                 SET PAY_ACTION_CD = NULL
               WHERE ENTER_CD      = P_ENTER_CD
                 AND PAY_YM        = LV_CPN201.PAY_YM
                 AND PAY_ACTION_CD = P_PAY_ACTION_CD
                 AND PAY_MON       > 0
                 AND CLOSE_YN      = 'Y';
            EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                P_SQLCODE := TO_CHAR(SQLCODE);
                P_SQLERRM := NVL(P_SQLERRM,SQLERRM);
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'35',P_SQLERRM, P_CHKID);
            END;


        --------------------
        -- 50 : 대출금
        --------------------
        WHEN '50' THEN
          BEGIN
            UPDATE TBEN625
               SET PAY_ACTION_CD = NULL
             WHERE ENTER_CD      = P_ENTER_CD
               AND PAY_YM        = LV_CPN201.PAY_YM
               AND PAY_ACTION_CD = P_PAY_ACTION_CD
               AND REP_MON       > 0
               AND CLOSE_YN      = 'Y';
          EXCEPTION
          WHEN OTHERS THEN
              ROLLBACK;
              P_SQLCODE := TO_CHAR(SQLCODE);
              P_SQLERRM := NVL(P_SQLERRM,SQLERRM);
              P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'50',P_SQLERRM, P_CHKID);
          END;
*/
        --------------------
        -- 52 : 경조, 회람
        --------------------
        WHEN '52' THEN
 					BEGIN
         		UPDATE TBEN475
         			 SET PAY_YN = 'N'
         			 	 , CHKDATE = SYSDATE
         			 	 , CHKID   = P_CHKID
         		WHERE ENTER_CD = P_ENTER_CD
         			AND PAY_YM = LV_CPN201.PAY_YM
					 		--AND LV_CPN201.PAY_CD   <>'A3' -- 대상자테이블을 조인했기 때문에 주석처리
						  AND CIRC_SABUN IN (SELECT X.SABUN FROM TCPN203 X
						 										 WHERE X.ENTER_CD = ENTER_CD
						 										 	 AND X.PAY_ACTION_CD = LV_CPN201.PAY_ACTION_CD)
         			;

          EXCEPTION
          WHEN OTHERS THEN
              ROLLBACK;
              P_SQLCODE := TO_CHAR(SQLCODE);
              P_SQLERRM := '경조,회람 작업취소중 에러 => ' ||NVL(P_SQLERRM,SQLERRM);
              P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'52',P_SQLERRM, P_CHKID);
          END;
        --------------------
        -- 58 : 개인연금
        --------------------
        WHEN '58' THEN
 					BEGIN
         		DELETE TBEN653
         		 WHERE ENTER_CD = P_ENTER_CD
         		 	 AND PAY_YM = LV_CPN201.PAY_YM
         		 	 AND SABUN IN (SELECT X.SABUN FROM TCPN203 X
						 										 WHERE X.ENTER_CD = ENTER_CD
						 										 	 AND X.PAY_ACTION_CD = LV_CPN201.PAY_ACTION_CD)
         		 	 ;

          EXCEPTION
          WHEN OTHERS THEN
              ROLLBACK;
              P_SQLCODE := TO_CHAR(SQLCODE);
              P_SQLERRM := '개인연금 작업취소중 에러 => ' ||NVL(P_SQLERRM,SQLERRM);
              P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'58',P_SQLERRM, P_CHKID);
          END;
        --------------------
        -- 68 : 주택이자보조금
        --------------------
        WHEN '68' THEN
 					BEGIN
         		DELETE TBEN453
         		 WHERE ENTER_CD = P_ENTER_CD
         		 	AND PAY_YM = LV_CPN201.PAY_YM
         		 	AND SABUN IN (SELECT X.SABUN FROM TCPN203 X
						 										 WHERE X.ENTER_CD = ENTER_CD
						 										 	 AND X.PAY_ACTION_CD = LV_CPN201.PAY_ACTION_CD)
         		 	;

          EXCEPTION
          WHEN OTHERS THEN
              ROLLBACK;
              P_SQLCODE := TO_CHAR(SQLCODE);
              P_SQLERRM := '주택이자보조금 작업취소중 에러 => ' ||NVL(P_SQLERRM,SQLERRM);
              P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'68',P_SQLERRM, P_CHKID);
          END;
        --------------------
        -- 71 : 상조상품
        --------------------
        WHEN '71' THEN
 					BEGIN
         		DELETE TBEN532
         		 WHERE ENTER_CD = P_ENTER_CD
         		 AND PAY_YM = LV_CPN201.PAY_YM
       		 	 AND SABUN IN (SELECT X.SABUN FROM TCPN203 X
				 										 WHERE X.ENTER_CD = ENTER_CD
				 										 	 AND X.PAY_ACTION_CD = LV_CPN201.PAY_ACTION_CD)
         		 ;

          EXCEPTION
          WHEN OTHERS THEN
              ROLLBACK;
              P_SQLCODE := TO_CHAR(SQLCODE);
              P_SQLERRM := '상조상품 작업취소중 에러 => ' ||NVL(P_SQLERRM,SQLERRM);
              P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'71',P_SQLERRM, P_CHKID);
          END;
        WHEN '100' THEN
           P_SQLCODE := 'OK' ;
        ELSE
          P_SQLCODE := 'OK' ;
    END CASE;

    /* 복리후생 작업처리 공통 */
    BEGIN
      DELETE TBEN777
       WHERE ENTER_CD      = P_ENTER_CD
         AND PAY_ACTION_CD = P_PAY_ACTION_CD
         AND BEN_GUBUN		 = ln_benefit_biz_cd
         ;
      DELETE TBEN997
       WHERE ENTER_CD      	= P_ENTER_CD
         AND PAY_ACTION_CD 	= P_PAY_ACTION_CD
         AND BENEFIT_BIZ_CD	= ln_benefit_biz_cd
         ;
    EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        P_SQLCODE := TO_CHAR(SQLCODE);
        P_SQLERRM := '복리후생 작업취소중 에러 => ' || NVL(P_SQLERRM,SQLERRM);
        P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'51',P_SQLERRM, P_CHKID);
    END;

    P_SQLCODE := 'OK' ;
    P_SQLERRM := '작업취소가 완료되었습니다.';

    COMMIT;

EXCEPTION
   WHEN er_PGM_ERROR THEN
      ROLLBACK;
      P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'418',P_SQLERRM, P_CHKID);
   WHEN OTHERS       THEN
      ROLLBACK;
      P_SQLCODE := TO_CHAR(SQLCODE);
      P_SQLERRM := 'Others Exception Error' || chr(10) || SQLERRM;
      P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'423',P_SQLERRM, P_CHKID);
END P_BEN_PAY_DATA_CREATE_DEL;