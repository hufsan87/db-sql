create or replace PROCEDURE "P_BEN_MTH_SHLOAN_HIST_CRE" (
    p_sqlcode            OUT        VARCHAR2,
    p_sqlerrm            OUT        VARCHAR2,
    P_ENTER_CD            IN        VARCHAR2,
    P_PAY_ACTION_CD       IN        VARCHAR2,  -- 급여계산코드
    P_PAY_RUN_TYPE				IN 				VARCHAR2,  -- 급여, 상여 구분코드
    P_PAY_YM							IN 				VARCHAR2,  -- 급여일자
    P_REQ_INT_RATE				IN 				NUMBER,  	 -- 변경 이자율
    P_CHKID               IN        VARCHAR2,   -- 수정자
    P_GUBUN								IN			  VARCHAR2  --신협여부
) IS
    lv_biz_cd        TSYS903.BIZ_CD%TYPE := 'BEN';
    lv_object_nm     TSYS903.OBJECT_NM%TYPE := 'P_BEN_MTH_SHLOAN_HIST_CRE';

    ln_cnt           NUMBER;
    lv_appl_seq      THRI103.APPL_SEQ%TYPE; -- 신청서순번
    lv_ben639      	 TBEN639%ROWTYPE;  -- 상환내역
    lv_cpn201        TCPN201%ROWTYPE;  -- 급여일자

    /* 마감여부*/
    lv_close_st      TBEN991.CLOSE_ST%TYPE; -- 마감상태(S90003)
    lv_close_yn      TCPN981.CLOSE_YN%TYPE; -- 마감상태(Y,N)
    lv_is_close_cnt NUMBER;
    LV_APPL_CNT      NUMBER;

BEGIN
    p_sqlcode   := NULL;
    p_sqlerrm   := NULL;
    ln_cnt := 0;
    --------------------------------------------------------------------------------------------------------------
    -- A. 벨리데이션을 위한 급여정보
    --------------------------------------------------------------------------------------------------------------
    -- A-1. 벨리데이션을 위한 급여정보
    BEGIN
        SELECT *
          INTO lv_cpn201
          FROM TCPN201
         WHERE ENTER_CD      = P_ENTER_CD
           AND PAY_ACTION_CD = P_PAY_ACTION_CD;
           --- TCPN051
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            P_SQLCODE := TO_CHAR(SQLCODE);
            P_SQLERRM := 'PAY_ACTION_CD:'||P_PAY_ACTION_CD||', 급여일자 내역 조회 시 Error =>' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'A-1',P_SQLERRM, P_CHKID);
            RETURN;
    END;

    --------------------------------------------------------------------------------------------------------------
    -- B. 복리후생 대출 진행 여부.
    --------------------------------------------------------------------------------------------------------------
    -- 중도상환 마감건 중 상환일자가 더큰 값이 존재할 경우
    BEGIN
				SELECT COUNT(1)
					INTO LV_APPL_CNT
				  FROM TBEN638 A
				WHERE 1=1
					AND A.ENTER_CD = P_ENTER_CD
					AND A.REP_YMD  > lv_cpn201.PAYMENT_YMD
					AND A.APPLY_YN = 'Y'
							;
    EXCEPTION
    WHEN OTHERS THEN
        P_SQLCODE := TO_CHAR(SQLCODE);
        P_SQLERRM := '복리후생 신협대출 마감건 조회 Error =>' || SQLERRM;
        P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'B',P_SQLERRM, P_CHKID);
        RETURN;
    END;
    IF LV_APPL_CNT <> 0 THEN
        p_sqlcode   := '0';
        p_sqlerrm   := '지급일 이후에 상환마감된 중도상환건이 있습니다.\n마감 취소  후 진행해 주십시오.';
        RETURN;
    END IF;


    --------------------------------------------------------------------------------------------------------------
    -- C. 복리후생 마감여부 확인.
    --------------------------------------------------------------------------------------------------------------
    -- C-1. 해당 로직이 마감건인 경우
    BEGIN
        SELECT CLOSE_ST
          INTO lv_close_st
          FROM TBEN991
         WHERE ENTER_CD      = P_ENTER_CD
           AND PAY_ACTION_CD = P_PAY_ACTION_CD
           AND BENEFIT_BIZ_CD = '76';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            lv_close_st := null;
        WHEN OTHERS THEN
            P_SQLCODE := TO_CHAR(SQLCODE);
            P_SQLERRM := 'PAY_ACTION_CD:'||P_PAY_ACTION_CD||', 신협대출 해당 급여관련  마감여부 조회 시 Error =>' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'C-1',P_SQLERRM, P_CHKID);
            RETURN;
    END;
    IF lv_close_st IS NOT NULL AND lv_close_st = '10005' THEN
        p_sqlcode   := '1-1';
        p_sqlerrm   := '복리후생이 마감되어 작업할 수 없습니다.';
        RETURN;
    END IF;

    -- C-2. 마감 안된건 있으면 돌리면 안됨
    /* 마감계산을 1개 이상 진행할 수 없음 순차적으로 마감진행 후 계산해야 함 */
    BEGIN
        SELECT COUNT(1)
          INTO lv_is_close_cnt
          FROM TBEN639
         WHERE ENTER_CD      = P_ENTER_CD
         	 AND PAY_ACTION_CD <> P_PAY_ACTION_CD
         	 AND CLOSE_YN 		 = 'N'
           ;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            lv_is_close_cnt := 0;
        WHEN OTHERS THEN
            P_SQLCODE := TO_CHAR(SQLCODE);
            P_SQLERRM := '신협대출 전체 마감여부 조회 시 Error =>' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'C-2',P_SQLERRM, P_CHKID);
            RETURN;
    END;
    IF lv_is_close_cnt <> 0 THEN
        p_sqlcode   := 'C-2';
        p_sqlerrm   := '신협대출 미마감 상환계산데이터가 있습니다.';
        RETURN;
    END IF;

    -- C-3. 상환일자 이후 기마감건이 있는경우
    BEGIN
        SELECT COUNT(1)
          INTO lv_is_close_cnt
          FROM TBEN639
         WHERE ENTER_CD      = P_ENTER_CD
         	 AND PAY_ACTION_CD <> P_PAY_ACTION_CD
         	 AND CLOSE_YN 		 = 'Y'
         	 AND REP_YMD > lv_cpn201.PAYMENT_YMD
           ;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            lv_is_close_cnt := 0;
        WHEN OTHERS THEN
            P_SQLCODE := TO_CHAR(SQLCODE);
            P_SQLERRM := '신협대출 상환일자 이후 기마감건 조회 시 Error =>' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'C-3',P_SQLERRM, P_CHKID);
            RETURN;
    END;
    IF lv_is_close_cnt <> 0 THEN
        p_sqlcode   := 'C-3';
        p_sqlerrm   := '상환일자 이후 기마감건이 있습니다.';
        RETURN;
    END IF;

    -- C-4. 자기자신 마감됬는지
    BEGIN
        SELECT COUNT(1)
          INTO lv_is_close_cnt
          FROM TBEN639
         WHERE ENTER_CD      = P_ENTER_CD
         	 AND PAY_ACTION_CD = P_PAY_ACTION_CD
         	 AND CLOSE_YN 		 = 'Y'
           ;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            lv_is_close_cnt := 0;
        WHEN OTHERS THEN
            P_SQLCODE := TO_CHAR(SQLCODE);
            P_SQLERRM := '신협대출 기마감건 조회 시 Error =>' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'C-4',P_SQLERRM, P_CHKID);
            RETURN;
    END;
    IF lv_is_close_cnt <> 0 THEN
        p_sqlcode   := 'C-4';
        p_sqlerrm   := '해당신협대출상환은 마감되었습니다.';
        RETURN;
    END IF;

    --------------------------------------------------------------------------------------------------------------
    -- D. 급여관련 VALIDATION
    --------------------------------------------------------------------------------------------------------------
    -- D-1. 급여 마감여부 확인.
    BEGIN
				SELECT A.CLOSE_YN
					INTO lv_close_yn
				FROM TCPN981 A
				WHERE 1=1
					AND A.ENTER_CD = P_ENTER_CD
          AND A.PAY_ACTION_CD = P_PAY_ACTION_CD;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            lv_close_yn := null;
        WHEN OTHERS THEN
            P_SQLCODE := TO_CHAR(SQLCODE);
            P_SQLERRM := 'PAY_ACTION_CD:'||P_PAY_ACTION_CD||', 급여 마감여부 조회 시 Error =>' || SQLERRM;
            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'D-1',P_SQLERRM, P_CHKID);
            RETURN;
    END;

    IF lv_close_yn = 'Y' THEN
        p_sqlcode   := 'D-1';
        p_sqlerrm   := '이미 마감된 급여코드입니다';
        RETURN;
    END IF;


    --------------------------------------------------------------------------------------------------------------
    -- D-3. 기존 생성내역건 삭제
		-- 해당 급여코드에 해당하는 인원은 다지우면 됨
		-- 해당 마감여부는 D-1에서 체크하기때문
    --------------------------------------------------------------------------------------------------------------
    -- 2024.05.31 추가: 마감취소 후, 다시 이자계산을 할 때, 마감 취소전 계산시 TBEN637 완납여부 'Y' 되었던 것 되돌리기
    BEGIN
        UPDATE TBEN637
            SET FIS_CHK = 'N'
            WHERE ENTER_CD = P_ENTER_CD
                AND APPL_SEQ IN (SELECT A.APPL_SEQ
                                 FROM TBEN637 A,
                                      TBEN639 B
                                 WHERE A.ENTER_CD = B.ENTER_CD
                                   AND A.SABUN = B.SABUN
                                   AND A.APPL_SEQ = B.AP_APPL_SEQ
                                   AND B.PAY_ACTION_CD = P_PAY_ACTION_CD
                                   AND A.FIS_CHK = 'Y'
                                 );
    EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        P_SQLCODE := TO_CHAR(SQLCODE);
        P_SQLERRM := 'PAY_ACTION_CD:'||P_PAY_ACTION_CD||', 신협대출생성내역 계산전 완납여부 원복시  Error =>' || SQLERRM;
        P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'D-3',P_SQLERRM, P_CHKID);
        RETURN;
    END;

    BEGIN
    	DELETE TBEN639 A
    	WHERE 1=1
	    	AND A.ENTER_CD 			= P_ENTER_CD
	    	AND A.PAY_ACTION_CD = P_PAY_ACTION_CD
	    ;
    EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        P_SQLCODE := TO_CHAR(SQLCODE);
        P_SQLERRM := 'PAY_ACTION_CD:'||P_PAY_ACTION_CD||', 신협대출생성내역 삭제  시 Error =>' || SQLERRM;
        P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'D-3',P_SQLERRM, P_CHKID);
        RETURN;
    END;

    ln_cnt := 0;

    --------------------------------------------------------------------------------------------------------------
    -- E. 대출신청서 기준으로 대출상환 정보 생성
    --------------------------------------------------------------------------------------------------------------
    -- E-1. 신협대출 생성필수 데이터 조회
    /*[C00001]00001:급여, 00002:상여		 , 00003:연월차*/
    /*[B50025]   01:급여, 	 02:급여+상여	,    03:상여*/
--         P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'DEBUG1',P_SQLERRM, P_CHKID);
    FOR C IN (
								SELECT A.*
                  FROM (SELECT A.*
                  					 -- 잔여금액은 최신꺼로
                             , NVL(( SELECT MAX(X.LOAN_REM_MON) KEEP(DENSE_RANK FIRST ORDER BY X.SEQ DESC)
                                       FROM TBEN639 X
                                      WHERE X.ENTER_CD 			= A.ENTER_CD
                                        AND X.AP_APPL_SEQ   = A.APPL_SEQ
                                        AND (X.PAY_RUN_TYPE  = '00001' OR X.PAY_RUN_TYPE IS NULL)
                                        AND X.CLOSE_YN = 'Y' ), -1) AS LOAN_REM_MON
                  					 -- 상여 제외 최신 적용시작일
                             , NVL(( SELECT MAX(X.APPLY_EDATE) KEEP(DENSE_RANK FIRST ORDER BY X.SEQ DESC)
                                       FROM TBEN639 X
                                      WHERE X.ENTER_CD 			= A.ENTER_CD
                                        AND X.AP_APPL_SEQ   = A.APPL_SEQ
                                        AND (X.PAY_RUN_TYPE  = '00001' OR X.PAY_RUN_TYPE IS NULL)
                                        AND X.CLOSE_YN = 'Y' ), -1) AS LAST_APPLY_EDATE
                  					 -- 상여 제외 최신 SEQ
                             , NVL(( SELECT MAX(X.SEQ) KEEP(DENSE_RANK FIRST ORDER BY X.SEQ DESC)
                                       FROM TBEN639 X
                                      WHERE X.ENTER_CD 			= A.ENTER_CD
                                        AND X.AP_APPL_SEQ   = A.APPL_SEQ
                                        AND (X.PAY_RUN_TYPE  = '00001' OR X.PAY_RUN_TYPE IS NULL)
                                        AND X.CLOSE_YN = 'Y' ), -1) AS LAST_SEQ
                          FROM TBEN637 A
                         WHERE A.ENTER_CD = P_ENTER_CD
                         	 /*AND  1 =  CASE WHEN P_PAY_RUN_TYPE = '00001' THEN
                         	 							 		CASE WHEN A.REP_TYPE IN('01','02') THEN 1 ELSE 0 END -- 급여(00001)[C00001] : 급여(01)[B50025]
                         									WHEN P_PAY_RUN_TYPE = '00002' THEN
                         										CASE WHEN A.REP_TYPE IN('02','03') THEN 1 ELSE 0 END -- 상여(00002)[C00001] : 급여(01) + 상여(02) 또는 상여(03) [B50025]
                         	 							END
                         	 							*/
                           AND EXISTS ( SELECT 1
                                          FROM THRI103 X
                                         WHERE X.ENTER_CD = A.ENTER_CD
                                           AND X.APPL_SEQ = A.APPL_SEQ
                                           AND X.APPL_STATUS_CD = '99' )						 -- 대출완료인건
                      ) A
                  WHERE A.FIS_CHK  != 'Y' -- 완납여부항목으로 판단
                    --상환구분이 '급여 01'일 때, 상여계산 00002 에서 제외 처리, HSLEE 2024.12.18
                    AND (
                    (1= case when P_PAY_RUN_TYPE = '00001' AND A.REP_TYPE IN ('01','02') THEN 1 ELSE 0 END) OR
                    (1= case when P_PAY_RUN_TYPE = '00002' AND A.REP_TYPE IN ('02','03') THEN 1 ELSE 0 END)
                    )
                  	AND A.LOAN_YMD <= lv_cpn201.PAYMENT_YMD -- 급여지급일 보단 이전에 승인나야함
                  	-- 23.12.06 추가 수정 요청사항 휴직자 빼라고 요청 옴
                    -- 24.04.17 추가 병가, 산재관련은 들어와야 함
                  	AND ( (F_COM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, lv_cpn201.PAYMENT_YMD) <> 'CA')
                            OR F_BEN_GET_IS_CA_YN(A.ENTER_CD, A.SABUN, lv_cpn201.PAYMENT_YMD, P_GUBUN) = 'Y'
                    )
             )
    LOOP
        P_SQLERRM := C.SABUN;
      lv_ben639 := NULL; -- 초기화하려는 값 (예: NULL 또는 다른 값)
     /*E-2. 상환정보 [최조 또는 마지막]*/
       IF C.LOAN_REM_MON = -1 THEN  -- 최초상환
            lv_ben639.REP_SEQ      := 1;															-- 상환회차 1회차부터
            lv_ben639.LOAN_STD_MON := C.LOAN_MON; 										-- 대출확정금
            lv_ben639.SEQ					 := lv_cpn201.PAYMENT_YMD||'0001';	-- 순번
           	lv_ben639.APPLY_SDATE  := C.LOAN_YMD; 										-- 대출시행일	처음이면 해당일
       ELSE
          --마지막 상환정보
          BEGIN
            SELECT A.*
              INTO lv_ben639
              FROM TBEN639 A
             WHERE A.ENTER_CD    = C.ENTER_CD
               AND A.AP_APPL_SEQ = C.APPL_SEQ
               AND A.SEQ  = (SELECT MAX(X.SEQ)
                               FROM TBEN639 X
                              WHERE X.ENTER_CD    = C.ENTER_CD
                                AND X.AP_APPL_SEQ = C.APPL_SEQ
                                AND X.CLOSE_YN    = 'Y'
                                -- and X.PAY_RUN_TYPE = '00001'  --2024.09.13 추가 : 상여는 안보도록
                                );

          EXCEPTION
              WHEN OTHERS THEN
                  ROLLBACK;
                  P_SQLCODE := TO_CHAR(SQLCODE);
                  P_SQLERRM := 'PAY_ACTION_CD:'||P_PAY_ACTION_CD||', SABUN:'||C.SABUN||', 마지막 상환내역 조회 시 Error =>' || SQLERRM;
                  P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'187',P_SQLERRM, P_CHKID);
                  RETURN;
          END;

          lv_ben639.REP_SEQ      := lv_ben639.REP_SEQ + 1;	 -- 상환회차 이전 + 1
          lv_ben639.LOAN_STD_MON := lv_ben639.LOAN_REM_MON;  -- 이자계산 기준급액 ( 전월 잔액 )

          -- 최근 적용일이 없으면 전 상환이 상여상환이였다는 말임
         	lv_ben639.APPLY_SDATE  := TO_CHAR(TO_DATE(NVL(lv_ben639.APPLY_EDATE, lv_ben639.SPARE_APPLY_EDATE), 'YYYYMMDD')+1, 'YYYYMMDD');

         	IF lv_cpn201.PAYMENT_YMD = lv_ben639.REP_YMD
         	THEN lv_ben639.SEQ  		 := lv_ben639.SEQ + 1;
         	ELSE lv_ben639.SEQ  		 := lv_cpn201.PAYMENT_YMD||'0001';
 			 		END IF;
       END IF;

 			 /* 변수 */
 			 lv_ben639.INT_RATE      := NVL(P_REQ_INT_RATE,C.INT_RATE); 				-- 이율 -- 화면파라미터로 컨트로  C.INT_RATE 사용 X
 			 lv_ben639.REP_YMD       := lv_cpn201.PAYMENT_YMD;	-- 상환일자 = 급여일자
             lv_ben639.PAY_ACTION_CD := P_PAY_ACTION_CD;  			-- 급여계산코드(TCPN201)
             lv_ben639.PAY_YM        := lv_cpn201.PAY_YM;  			-- 급여년월
             lv_ben639.PAY_RUN_TYPE  := P_PAY_RUN_TYPE;  				-- 급여구분

        -- 상환금액
 				IF P_PAY_RUN_TYPE 	 = '00001' THEN 		-- 급여
                    lv_ben639.REP_MON  := C.REP_MON;
                    lv_ben639.REPAY_TYPE    := '10';
                ELSIF P_PAY_RUN_TYPE = '00002' THEN 	 	-- 상여
                    lv_ben639.REP_MON  := C.REP_MON_BONUS;
                    lv_ben639.REPAY_TYPE    := '11';
                    -- lv_ben639.LOAN_REM_MON :=
 				END IF;

        IF lv_ben639.LOAN_STD_MON < lv_ben639.REP_MON THEN  -- 상환전 잔액이 월상환금 보다 작으면.
          lv_ben639.REP_MON :=  lv_ben639.LOAN_STD_MON;			-- 상환계산금액은 잔액으로 변경
        END IF;

 				/*
 					SDATE 가 지급일보다 클 경우
 					 - 중도상환 및 같은날 급여,상여 2번계산하는경우
 					 - 때문에 APPLY_SDTE, EDATE (적용일자) 수정 분기처리 필요
 					 	1. SDATE := 지급일
 					 	2. EDATE := 지급일(EDATE는 모든케이스가 급여지급일)
        IF lv_ben639.APPLY_SDATE >= lv_cpn201.PAYMENT_YMD THEN		-- 중도상환
 				*/
        IF lv_ben639.APPLY_EDATE = TO_CHAR(TO_DATE(lv_cpn201.PAYMENT_YMD, 'YYYYMMDD') - 1,'YYYYMMDD') THEN		-- 중도상환
            lv_ben639.APPLY_SDATE := TO_CHAR(TO_DATE(lv_cpn201.PAYMENT_YMD, 'YYYYMMDD') - 1,'YYYYMMDD');
            lv_ben639.APPLY_EDATE := lv_ben639.APPLY_SDATE;

        	lv_ben639.APPLY_DAY := 0;  -- 적용일수
        	lv_ben639.INT_MON   := 0;

        	IF C.LAST_APPLY_EDATE <> -1	THEN -- 마지막 상환날짜 존재(상여제외)
        		 IF C.LAST_APPLY_EDATE  <> lv_ben639.APPLY_EDATE THEN -- 마지막 상환날짜가(상여제외) 다를 때
	        		 lv_ben639.APPLY_DAY   := TO_DATE(lv_ben639.APPLY_EDATE, 'YYYYMMDD')  - (TO_DATE(C.LAST_APPLY_EDATE, 'YYYYMMDD') + 1) + 1;  -- 적용일수
	        		 lv_ben639.APPLY_SDATE := TO_CHAR(TO_DATE(C.LAST_APPLY_EDATE, 'YYYYMMDD') + 1,'YYYYMMDD');
        		 END IF;
        	ELSE
        		IF C.LOAN_REM_MON <> -1 THEN -- 마지막 상환날짜가(상여제외) 없는데 잔여내역이 있을때
        			IF P_PAY_RUN_TYPE = '00001' THEN -- 급여일때만
	        		 lv_ben639.APPLY_DAY   := TO_DATE(lv_ben639.APPLY_EDATE, 'YYYYMMDD')  - (TO_DATE(C.LOAN_YMD, 'YYYYMMDD') + 1) + 1;  -- 적용일수
	        		 lv_ben639.APPLY_SDATE := C.LOAN_YMD;
	        		-- ELSIF P_PAY_RUN_TYPE = '00001' THEN -- 상여일때는 X ===> 상여 상여 였다는이야기이기 떄문
        			END IF;
        		END IF;
       		END IF;
			  ELSE	-- 중도상환X
                --TP 예외처리, '25.01 까지, 이자 적용 종료일자 20일로 고정 
                IF P_ENTER_CD = 'TP' AND TO_DATE(lv_cpn201.PAYMENT_YMD, 'YYYYMMDD') < TO_DATE('20250201', 'YYYYMMDD') THEN
					lv_ben639.APPLY_EDATE := TO_CHAR(TO_DATE(lv_cpn201.PAYMENT_YMD, 'YYYYMMDD'), 'YYYYMM') || '20';
                ELSE
                    lv_ben639.APPLY_EDATE   := TO_CHAR(TO_DATE(lv_cpn201.PAYMENT_YMD,'YYYYMMDD') - 1, 'YYYYMMDD');  -- 적용기간 종료일 = 급여일자 - 1
                END IF;
 					-- 이자계산
                --TP, 김형종 15000646 및 '25.01 예외처리
                IF P_ENTER_CD = 'TP' AND TO_DATE(lv_cpn201.PAYMENT_YMD, 'YYYYMMDD') < TO_DATE('20250201', 'YYYYMMDD') THEN
                    lv_ben639.INT_MON := F_BEN_LOAN_INT_MON_EX(P_ENTER_CD, C.SABUN, lv_ben639.LOAN_STD_MON, lv_ben639.INT_RATE, lv_ben639.APPLY_SDATE, lv_ben639.APPLY_EDATE, P_GUBUN);
                ELSE
                    lv_ben639.INT_MON := F_BEN_LOAN_INT_MON(lv_ben639.LOAN_STD_MON, lv_ben639.INT_RATE, lv_ben639.APPLY_SDATE, lv_ben639.APPLY_EDATE, P_GUBUN);
                END IF;


       	END IF;

 				/* 예외처리
					 상여가 중간에 있을경우 이자계산을 따로해줘야 함 -- 같은날 나가는 항목인데 2번계산한다고함 이유는 없음 기존에 그렇게해서 2번돌린다고함;
					 급여 분리된거 하나때문에 너무 많은 경우세수가 생김 [급여 -> 상여], [상여 -> 급여], [상여 -> 중도상환 -> 급여] 등등
					 추가적으로 상환신청 후처리도 이자계산이 변경되야됨
					 마감된 건중, 가장 최근 급여상환보다(상여제외) 큰 이자계산된것들 합산
				*/
				IF P_PAY_RUN_TYPE = '00001' THEN -- 급여
					/* 급여상환 때 모두 합쳐서*/
					SELECT NVL(SUM(SPARE_INT_MON),0) + NVL(lv_ben639.INT_MON,0)
					INTO lv_ben639.INT_MON
						FROM TBEN639
					WHERE ENTER_CD = P_ENTER_CD
						--AND PAY_ACTION_CD = P_PAY_ACTION_CD
						AND SABUN         = C.SABUN
						AND AP_APPL_SEQ   = C.APPL_SEQ
						AND SEQ   > C.LAST_SEQ
						AND CLOSE_YN      = 'Y'
						;

        	IF C.LAST_APPLY_EDATE = -1	THEN -- 마지막 상활일자X(상여제외)
        		IF C.LOAN_REM_MON <> -1 THEN -- 마지막 상활일자X(상여제외) 잔여내역이 있을때
	        		 lv_ben639.APPLY_DAY   := TO_DATE(lv_ben639.APPLY_EDATE, 'YYYYMMDD')  - TO_DATE(C.LOAN_YMD, 'YYYYMMDD') + 1;  -- 적용일수
	        		 lv_ben639.APPLY_SDATE := C.LOAN_YMD;
	        	ELSE -- 잔여내역도 없을 때
							 lv_ben639.APPLY_DAY := TO_DATE(lv_ben639.APPLY_EDATE, 'YYYYMMDD') - TO_DATE(lv_ben639.APPLY_SDATE, 'YYYYMMDD') + 1;  -- 적용일수
        		END IF;
        	ELSE -- 마지막 상환일자O(상여제외)
        		lv_ben639.APPLY_SDATE := TO_CHAR(TO_DATE(C.LAST_APPLY_EDATE, 'YYYYMMDD')+ 1,'YYYYMMDD') ;

	       	  -- 이자계산 적용일수
	       	  IF lv_ben639.APPLY_SDATE > lv_ben639.APPLY_EDATE  -- 최종건이
	       	  THEN lv_ben639.APPLY_DAY := 0;
	       	  ELSE lv_ben639.APPLY_DAY := TO_DATE(lv_ben639.APPLY_EDATE, 'YYYYMMDD') - TO_DATE(lv_ben639.APPLY_SDATE, 'YYYYMMDD') + 1;  -- 적용일수
	       	  END IF;

       		END IF;

					/* 급여일 경우 초기화 */
					lv_ben639.SPARE_APPLY_SDATE := NULL;
					lv_ben639.SPARE_APPLY_EDATE := NULL;
					lv_ben639.SPARE_INT_MON 		:= NULL;

				ELSIF P_PAY_RUN_TYPE = '00002' THEN -- 상여
				  IF lv_ben639.APPLY_SDATE = lv_ben639.APPLY_EDATE THEN
				  	lv_ben639.SPARE_INT_MON := 0;
				  ELSE
						lv_ben639.SPARE_INT_MON := F_BEN_LOAN_INT_MON(lv_ben639.LOAN_STD_MON, lv_ben639.INT_RATE, lv_ben639.APPLY_SDATE, lv_ben639.APPLY_EDATE, P_GUBUN);
				  END IF;

					/* 변수초기화 */
					lv_ben639.SPARE_APPLY_SDATE := lv_ben639.APPLY_SDATE;
					lv_ben639.SPARE_APPLY_EDATE := lv_ben639.APPLY_EDATE;
					lv_ben639.APPLY_SDATE	:= NULL;
					lv_ben639.APPLY_EDATE := NULL;
					lv_ben639.INT_MON			:= 0;
					lv_ben639.APPLY_DAY := 0;
				END IF;
        -- 대출잔액
        lv_ben639.LOAN_REM_MON := lv_ben639.LOAN_STD_MON - lv_ben639.REP_MON;

		    BEGIN
		        INSERT INTO TBEN639 ( ENTER_CD, AP_APPL_SEQ, SABUN, LOAN_CD
		                            , REP_SEQ, REP_YMD, REPAY_TYPE
		                            , APPLY_SDATE, APPLY_EDATE, APPLY_DAY
		                            , LOAN_STD_MON, INT_RATE, REP_MON, INT_MON, LOAN_REM_MON
		                            , PAY_YM, CLOSE_YN, PAY_ACTION_CD, NOTE, CHKDATE, CHKID
		                            , SEQ, PAY_RUN_TYPE
		                            , SPARE_APPLY_SDATE, SPARE_APPLY_EDATE, SPARE_INT_MON)
---lv_cpn201.PAYMENT_YMD,  lv_ben639.REP_YMD
		           VALUES (   C.ENTER_CD, C.APPL_SEQ, C.SABUN, C.LOAN_CD
		                    , lv_ben639.REP_SEQ, lv_ben639.REP_YMD, lv_ben639.REPAY_TYPE
		                    , lv_ben639.APPLY_SDATE, lv_ben639.APPLY_EDATE, lv_ben639.APPLY_DAY
		                    , lv_ben639.LOAN_STD_MON, lv_ben639.INT_RATE, lv_ben639.REP_MON, lv_ben639.INT_MON, lv_ben639.LOAN_REM_MON
		                    , lv_ben639.PAY_YM, 'N', lv_ben639.PAY_ACTION_CD, lv_ben639.note , SYSDATE, P_CHKID
		                    , lv_ben639.SEQ, P_PAY_RUN_TYPE
		                    , lv_ben639.SPARE_APPLY_SDATE, lv_ben639.SPARE_APPLY_EDATE, lv_ben639.SPARE_INT_MON);
		        ln_cnt := ln_cnt + 1;
		    EXCEPTION
		        WHEN OTHERS THEN
		            ROLLBACK;
		            P_SQLCODE := TO_CHAR(SQLCODE);
		                P_SQLERRM := 'PAY_ACTION_CD:'||P_PAY_ACTION_CD||', SABUN:'||C.SABUN||', 상환내역 저장 시 Error =>' || SQLERRM;
		            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'458',P_SQLERRM, P_CHKID);
		            RETURN;
		    END;

				-- 잔여금액이 0이면 완납여부 UPDATE
				IF lv_ben639.LOAN_REM_MON = 0 THEN
					BEGIN
						UPDATE TBEN637
						SET FIS_CHK = 'Y'
						WHERE 1=1
						 AND ENTER_CD = C.ENTER_CD
						 AND APPL_SEQ = C.APPL_SEQ
						 AND SABUN    = C.SABUN;
			    EXCEPTION
			        WHEN OTHERS THEN
			            ROLLBACK;
			            P_SQLCODE := TO_CHAR(SQLCODE);
			                P_SQLERRM := 'PAY_ACTION_CD:'||P_PAY_ACTION_CD||', SABUN:'||C.SABUN||', 완납여부 Y UPDATE시 Error =>' || SQLERRM;
			            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm,'477',P_SQLERRM, P_CHKID);
			            RETURN;
			    END;
			   END IF;
    END LOOP;

    IF ln_cnt = 0 THEN
        p_sqlcode   := '0';
        p_sqlerrm   := '생성된 내역이 없습니다.';
        RETURN;
    END IF;

    p_sqlcode := ln_cnt;
    p_sqlerrm := '';

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_sqlcode   := TO_CHAR(sqlcode);
        p_sqlerrm   := sqlerrm;
        P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm, '295', sqlerrm, '');
        RETURN;
END;