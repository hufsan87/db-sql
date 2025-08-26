create or replace FUNCTION "F_BEN_SCH_DET_CHECK2" (
      P_ENTER_CD          IN VARCHAR2
    , P_APPL_SEQ          IN VARCHAR2
    , P_SABUN             IN VARCHAR2
    , P_SCH_TYPE_CD       IN VARCHAR2
    , P_SCH_SUP_TYPE_CD   IN VARCHAR2
    , P_FAM_NM            IN VARCHAR2
    , P_FAM_YMD           IN VARCHAR2
    , P_SCH_YEAR          IN VARCHAR2
    , P_DIV_CD            IN VARCHAR2 -- 분기/학기
    , P_APPL_MON          IN NUMBER -- 신청금액
    , P_ATD_AMT           IN NUMBER -- 등록금
    , P_SCH_LOC_CD        IN VARCHAR2 -- 국내외구분
    , P_REVERSE_YN        IN VARCHAR2 --역학기 신청 여부
    , P_YEAR_LONG         IN VARCHAR2 -- 수업년한/허용학기 산정용
  ) RETURN VARCHAR2
IS
    lv_biz_cd              TSYS903.BIZ_CD%TYPE := 'BEN';
    lv_object_nm           TSYS903.OBJECT_NM%TYPE := 'F_BEN_SCH_DET_CHECK2';
    P_SQLERRM VARCHAR2(1000) := '';
/********************************************************************************/
/*    학자금신청 기준 체크        */
/********************************************************************************/
    lv_ben750 TBEN750%ROWTYPE;  -- 학자금신청 기준관리
    ln_cnt    NUMBER;
    lv_result VARCHAR2(1000);

    -- 임원인 경우, 학자금신청 6개월 근속 제외(HX only)
    lv_immonYn VARCHAR2(10) := 'N';
	lv_jikgub_cd THRM151.JIKGUB_CD%TYPE;
    
	-- KS, 고교 신청금액 제한
	-- 재학생 : 674,550원, 신입생 : 695,700원요 (한도)
	lv_sch_10_new NUMBER := 695700;
	lv_sch_10_old NUMBER := 674550;
    
    --허용학기
    ln_year_long NUMBER := P_YEAR_LONG / 0.5;
BEGIN
    lv_result := 'OK';

    ------------------------------
    -- 근속기간 6개월 이상 신청 가능
    ------------------------------
    ln_cnt := 0;
    BEGIN
        SELECT TRUNC(F_COM_GET_WORK_YM(P_ENTER_CD, P_SABUN, TO_CHAR(SYSDATE, 'YYYYMMDD'))) AS CNT
          INTO ln_cnt
          FROM DUAL;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN '근속개월 체크 시 오류가 발생했습니다.';
    END;

    IF ln_cnt < 6 AND P_ENTER_CD != 'KS' THEN
        lv_jikgub_cd := F_COM_GET_JIKGUB_CD(P_ENTER_CD, P_SABUN, TO_CHAR(SYSDATE,'YYYYMMDD'));
        lv_immonYn := F_COM_GET_GRCODE_MAP_VAL(P_ENTER_CD, 'A01','H20010', lv_jikgub_cd, TO_CHAR(SYSDATE,'YYYYMMDD'));
        IF P_ENTER_CD <> 'HX' OR lv_immonYn <> 'Y' THEN
            RETURN '근속기간 6개월 미만인 경우 신청 할 수 없습니다.';
        END IF;
    END IF;

    ------------------------------------------------------------------------------------------------------------------------
    -- 1. 부부직원 신청건 체크
    ------------------------------------------------------------------------------------------------------------------------
	ln_cnt := 0;
	BEGIN
		SELECT COUNT(1) AS CNT
        INTO ln_cnt
        FROM TBEN751 A
        WHERE ENTER_CD=P_ENTER_CD
            --AND SCH_TYPE_CD=P_SCH_TYPE_CD
            AND (
                (P_SCH_TYPE_CD IN ('20','30') AND SCH_TYPE_CD IN ('20','30'))
                OR ((P_SCH_TYPE_CD NOT IN ('20','30') AND SCH_TYPE_CD = P_SCH_TYPE_CD))
            )
            --AND SCH_SUP_TYPE_CD=P_SCH_SUP_TYPE_CD
            AND SCH_YEAR=P_SCH_YEAR
            AND DIV_CD=P_DIV_CD
            AND FAM_NM = P_FAM_NM
            AND FAM_YMD = P_FAM_YMD
            AND SABUN = (
                SELECT SABUN
                FROM THRM100
                WHERE ENTER_CD=P_ENTER_CD AND
                    NAME||BIR_YMD = (
                        SELECT FAM_NM||FAM_YMD
                        FROM THRM111_BE
                        WHERE ENTER_CD=P_ENTER_CD
                            AND SABUN=P_SABUN
                            AND FAM_CD='RPR_00'
                            AND USE_YN='Y'
                    )
                )
            AND EXISTS(SELECT 1 FROM THRI103 X
                        WHERE X.ENTER_CD = A.ENTER_CD
                            AND X.APPL_SEQ = A.APPL_SEQ
                            AND X.APPL_STATUS_CD IN ('21','31','99') ); -- 신청중인 대상도 체크
	EXCEPTION
		WHEN OTHERS THEN
			RETURN '부부직원 신청건 체크 시 오류가 발생했습니다.';
	END;
	IF ln_cnt > 0 THEN
		RETURN '부부사원은 1인만 신청 가능합니다';
	END IF;

    ------------------------------------------------------------------------------------------------------------------------
    -- 0. 기신청건 체크
    ------------------------------------------------------------------------------------------------------------------------
	ln_cnt := 0;
	BEGIN
		SELECT COUNT(1) AS CNT
		  INTO ln_cnt
		  FROM TBEN751 A
		 WHERE A.ENTER_CD   	 = P_ENTER_CD
		   AND A.APPL_SEQ   	 <> P_APPL_SEQ
		   AND A.SABUN   		 = P_SABUN
           --AND A.SCH_TYPE_CD    = P_SCH_TYPE_CD
            AND (
                (P_SCH_TYPE_CD IN ('20','30') AND SCH_TYPE_CD IN ('20','30'))
                OR ((P_SCH_TYPE_CD NOT IN ('20','30') AND SCH_TYPE_CD = P_SCH_TYPE_CD))
            )
		   --AND A.SCH_SUP_TYPE_CD = P_SCH_SUP_TYPE_CD
           AND REPLACE(A.FAM_NM,' ','') = REPLACE(P_FAM_NM,' ','')
           AND A.SCH_YEAR||A.DIV_CD = P_SCH_YEAR||P_DIV_CD
		   AND EXISTS ( SELECT 1 FROM THRI103 X
						 WHERE X.ENTER_CD = A.ENTER_CD
						   AND X.APPL_SEQ = A.APPL_SEQ
						   AND X.APPL_STATUS_CD IN ('21','31','99') ); -- 신청중인 대상도 체크
	EXCEPTION
		WHEN OTHERS THEN
			RETURN '기 신청건 체크 시 오류가 발생했습니다.';
	END;

	IF ln_cnt > 0 THEN
		RETURN '동일한 신청 건이 있어 신청 할 수 없습니다.('||P_FAM_NM||', '||P_sch_year||'학년'||REPLACE(P_DIV_CD,'0','')||'학기)';
	END IF;

    ------------------------------------------------------------------------------------------------------------------------
    -- 0. 과거신청건 체크
    ------------------------------------------------------------------------------------------------------------------------
    IF P_REVERSE_YN IS NULL OR P_REVERSE_YN='' OR P_REVERSE_YN = 'N' THEN
    	ln_cnt := 0;
        BEGIN
            SELECT COUNT(1) AS CNT
              INTO ln_cnt
              FROM TBEN751 A
             WHERE A.ENTER_CD   	 = P_ENTER_CD
               AND A.APPL_SEQ   	 <> P_APPL_SEQ
               AND A.SABUN   		 = P_SABUN
               --AND A.SCH_TYPE_CD    = P_SCH_TYPE_CD
                AND (
                    (P_SCH_TYPE_CD IN ('20','30') AND SCH_TYPE_CD IN ('20','30'))
                    OR ((P_SCH_TYPE_CD NOT IN ('20','30') AND SCH_TYPE_CD = P_SCH_TYPE_CD))
                )
               -- AND A.SCH_SUP_TYPE_CD = P_SCH_SUP_TYPE_CD
               AND REPLACE(A.FAM_NM,' ','') = REPLACE(P_FAM_NM,' ','')
               AND A.SCH_YEAR||A.DIV_CD > P_SCH_YEAR||P_DIV_CD
               AND EXISTS ( SELECT 1 FROM THRI103 X
                             WHERE X.ENTER_CD = A.ENTER_CD
                               AND X.APPL_SEQ = A.APPL_SEQ
                               AND X.APPL_STATUS_CD IN ('21','31','99') ); -- 신청중인 대상도 체크
        EXCEPTION
            WHEN OTHERS THEN
                RETURN '과거 신청건 체크 시 오류가 발생했습니다.';
        END;
    
        IF ln_cnt > 0 THEN
            RETURN '과거 신청 건은 신청할 수 없습니다.';
        END IF;
    END IF;
    
    ------------------------------
    -- 학자금신청 기준정보 가져오기
    ------------------------------
    BEGIN
        SELECT *
          INTO lv_ben750
          FROM TBEN750
         WHERE ENTER_CD        = P_ENTER_CD
           AND SCH_TYPE_CD     = P_SCH_TYPE_CD
           AND SCH_SUP_TYPE_CD = P_SCH_SUP_TYPE_CD
           AND SCH_LOC_CD      = P_SCH_LOC_CD   --24.08.21 주석, 25.02.18 주석해제
           AND TO_CHAR(SYSDATE, 'YYYYMMDD') BETWEEN SDATE AND NVL( EDATE, '99991231' );

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN '학자금 기준정보가 없습니다.';
        WHEN OTHERS THEN
            RETURN '학자금 기준정보 조회 시 오류가 발생했습니다.';
    END;

    ------------------------------------------------------------------------------------------------------------------------
    -- 3.회당지급한도 체크
    ------------------------------------------------------------------------------------------------------------------------
	--KS, 고교 재학생 : 674,550원, 신입생 : 695,700원요 (한도)
--	IF P_ENTER_CD = 'KS' AND P_SCH_TYPE_CD = '10' THEN
--		IF P_SCH_YEAR = '1' AND P_DIV_CD = '01' THEN
--			IF NVL(P_APPL_MON,0) > lv_sch_10_new THEN
--				RETURN '신입생 신청금액 한도 '||REPLACE(TO_CHAR(lv_sch_10_new,'9,999,999'),' ','')||'원을 초과하였습니다.';
--			END IF;
--		ELSE 
--            IF NVL(P_APPL_MON,0) > lv_sch_10_old THEN
--                RETURN '재학생 신청금액 한도 '||REPLACE(TO_CHAR(lv_sch_10_new,'9,999,999'),' ','')||'원을 초과하였습니다.';
--            END IF;
--        END IF;
--	END IF;
    
    IF P_ENTER_CD = 'HX' THEN
        IF P_ATD_AMT > NVL(lv_ben750.LMT_YEAR_MON, 0) THEN
            RETURN '등록금은 '|| FUNC_COMMA(lv_ben750.LMT_YEAR_MON, 0 )||'원을 넘길 수 없습니다.';
        END IF;
    ELSE
        IF P_ATD_AMT > NVL(lv_ben750.LMT_YEAR_MON, 0) THEN -- P_APPL_MON
            RETURN '등록금은 '|| FUNC_COMMA(lv_ben750.LMT_YEAR_MON, 0 )||'원을 넘길 수 없습니다.';
        END IF;
    END IF;

    ------------------------------------------------------------------------------------------------------------------------
    -- 4.지원한도횟수 체크
    ------------------------------------------------------------------------------------------------------------------------
    IF NVL(lv_ben750.LMT_APP_CNT, 0)  > 0 THEN
        ln_cnt := 0;
        BEGIN
            SELECT COUNT(1)
              INTO ln_cnt
              FROM TBEN751 A
             WHERE ENTER_CD        = P_ENTER_CD
               AND APPL_SEQ        <> P_APPL_SEQ -- 현재 신청서 제외
               AND SABUN           = P_SABUN
               AND SCH_TYPE_CD     = P_SCH_TYPE_CD
               AND SCH_SUP_TYPE_CD = P_SCH_SUP_TYPE_CD
               AND FAM_YMD      = P_FAM_YMD
               AND EXISTS ( SELECT 1 FROM THRI103 X
                             WHERE X.ENTER_CD = A.ENTER_CD
                               AND X.APPL_SEQ = A.APPL_SEQ
                               AND X.APPL_STATUS_CD IN ('21','31','99') ) -- 신청중인 대상도 체크
               ;

        EXCEPTION
            WHEN OTHERS THEN
                RETURN '지원한도횟수 체크 시 오류가 발생했습니다.';
        END;

        ln_cnt := ln_cnt + 1; -- 현재 신청건수 더함.

--        IF ln_cnt > NVL(lv_ben750.LMT_APP_CNT, 0) THEN
--            RETURN '지원가능횟수는 '|| lv_ben750.LMT_APP_CNT || '회이며 초과 신청 할 수 없습니다./n(기 지원횟수 : '|| (ln_cnt-1) ||'회)';
--        END IF;
        
        IF P_SCH_TYPE_CD IN ('20','30') AND P_SCH_LOC_CD = '0' AND P_YEAR_LONG IS NOT NULL AND P_YEAR_LONG > 0 THEN
            IF ln_cnt > NVL(ln_year_long,0) THEN
                RETURN '신청 학교/학과의 지원가능횟수는 '|| ln_year_long || '회이며/n초과 신청 할 수 없습니다. (기 지원횟수 : '|| (ln_cnt-1) ||'회)';
            END IF;
        ELSE
            IF ln_cnt > NVL(lv_ben750.LMT_APP_CNT, 0) THEN
                RETURN '신청 학교/학과의 지원가능횟수는 '|| lv_ben750.LMT_APP_CNT || '회이며/n초과 신청 할 수 없습니다. (기 지원횟수 : '|| (ln_cnt-1) ||'회)';
            END IF;
        END IF;
        
    END IF;

   RETURN lv_result;
END;