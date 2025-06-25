CREATE OR REPLACE FUNCTION F_BEN_SPE_EDU_CHECK(
	P_ENTER_CD 	IN VARCHAR2,
	P_APPL_SEQ 	IN VARCHAR2,
	P_SABUN 	IN VARCHAR2,
	P_FAM_NM	IN VARCHAR2,
	P_FAM_YMD	IN VARCHAR2,
	P_APP_YEAR	IN VARCHAR2,
	P_DIV_CD	IN VARCHAR2,
	P_APPL_MON1	IN NUMBER,
	P_APPL_MON2	IN NUMBER,
	P_APPL_MON3	IN NUMBER,
	P_APPL_MON	IN NUMBER
) RETURN VARCHAR2
IS
    lv_biz_cd              TSYS903.BIZ_CD%TYPE := 'BEN';
    lv_object_nm           TSYS903.OBJECT_NM%TYPE := 'F_BEN_SPE_EDU_CHECK';
    P_SQLERRM VARCHAR2(1000) := '';
/********************************************************************************/
/*    특수교육비 신청 기준 체크        */
/********************************************************************************/
    lv_ben770 TBEN770%ROWTYPE;  -- 특수교육비신청 기준관리
    ln_cnt    NUMBER;
    lv_result VARCHAR2(1000);

    -- 임원인 경우, 특수교육비신청 6개월 근속 제외(HX only)
    lv_immonYn VARCHAR2(10) := 'N';
    lv_jikgub_cd THRM151.JIKGUB_CD%TYPE;

    lv_from_date_m1       VARCHAR2(8);
    lv_to_date_m1         VARCHAR2(8);
    lv_from_date_m2       VARCHAR2(8);
    lv_to_date_m2         VARCHAR2(8);
    lv_from_date_m3       VARCHAR2(8);
    lv_to_date_m3         VARCHAR2(8);

    ln_work_days_m1       NUMBER;
    ln_work_days_m2       NUMBER;
    ln_work_days_m3       NUMBER;
    
    rtStr_json VARCHAR2(1000); --단순 오류 리턴이 아니라, 로직터리를 위한 파싱용 문자열 생성 용(예 : 근무일수가 15일 미만인 월 리턴 => 'ShortWorkDay'||1월,2월)
    rtStrM1 VARCHAR2(10) := '';
    rtStrM2 VARCHAR2(10) := '';
    rtStrM3 VARCHAR2(10) := '';
    rtStrFlag1 BOOLEAN := FALSE;
    rtStrFlag2 BOOLEAN := FALSE;
    rtStrFlag3 BOOLEAN := FALSE;
BEGIN
    lv_result := 'OK';

    ------------------------------
    -- 1. 근속기간 6개월 이상 신청 가능
    ------------------------------
/*
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
*/
    --재직상태 체크
    IF F_COM_GET_STATUS_CD(P_ENTER_CD, P_SABUN, TO_CHAR(SYSDATE, 'YYYYMMDD')) != 'AA' THEN --(참고) CA, EA 휴지, 정직
        RETURN '재직자에 한하여 신청 가능합니다.';
    END IF;

    --분기, 각 해당월에 대한 근무일수 < 15, 신청금액 > 0  체크
    CASE P_DIV_CD
    WHEN '1' THEN -- 1분기 (1월, 2월, 3월)
            lv_from_date_m1 := P_APP_YEAR || '0101';
            lv_to_date_m1 := P_APP_YEAR || '01' || TO_CHAR(LAST_DAY(TO_DATE(P_APP_YEAR || '01', 'YYYYMM')), 'DD');
            lv_from_date_m2 := P_APP_YEAR || '0201';
            lv_to_date_m2 := P_APP_YEAR || '02' || TO_CHAR(LAST_DAY(TO_DATE(P_APP_YEAR || '02', 'YYYYMM')), 'DD');
            lv_from_date_m3 := P_APP_YEAR || '0301';
            lv_to_date_m3 := P_APP_YEAR || '03' || TO_CHAR(LAST_DAY(TO_DATE(P_APP_YEAR || '03', 'YYYYMM')), 'DD');
    WHEN '2' THEN -- 2분기 (4월, 5월, 6월)
            lv_from_date_m1 := P_APP_YEAR || '0401';
            lv_to_date_m1 := P_APP_YEAR || '04' || TO_CHAR(LAST_DAY(TO_DATE(P_APP_YEAR || '04', 'YYYYMM')), 'DD');
            lv_from_date_m2 := P_APP_YEAR || '0501';
            lv_to_date_m2 := P_APP_YEAR || '05' || TO_CHAR(LAST_DAY(TO_DATE(P_APP_YEAR || '05', 'YYYYMM')), 'DD');
            lv_from_date_m3 := P_APP_YEAR || '0601';
            lv_to_date_m3 := P_APP_YEAR || '06' || TO_CHAR(LAST_DAY(TO_DATE(P_APP_YEAR || '06', 'YYYYMM')), 'DD');
    WHEN '3' THEN -- 3분기 (7월, 8월, 9월)
            lv_from_date_m1 := P_APP_YEAR || '0701';
            lv_to_date_m1 := P_APP_YEAR || '07' || TO_CHAR(LAST_DAY(TO_DATE(P_APP_YEAR || '07', 'YYYYMM')), 'DD');
            lv_from_date_m2 := P_APP_YEAR || '0801';
            lv_to_date_m2 := P_APP_YEAR || '08' || TO_CHAR(LAST_DAY(TO_DATE(P_APP_YEAR || '08', 'YYYYMM')), 'DD');
            lv_from_date_m3 := P_APP_YEAR || '0901';
            lv_to_date_m3 := P_APP_YEAR || '09' || TO_CHAR(LAST_DAY(TO_DATE(P_APP_YEAR || '09', 'YYYYMM')), 'DD');
    WHEN '4' THEN -- 4분기 (10월, 11월, 12월)
            lv_from_date_m1 := P_APP_YEAR || '1001';
            lv_to_date_m1 := P_APP_YEAR || '10' || TO_CHAR(LAST_DAY(TO_DATE(P_APP_YEAR || '10', 'YYYYMM')), 'DD');
            lv_from_date_m2 := P_APP_YEAR || '1101';
            lv_to_date_m2 := P_APP_YEAR || '11' || TO_CHAR(LAST_DAY(TO_DATE(P_APP_YEAR || '11', 'YYYYMM')), 'DD');
            lv_from_date_m3 := P_APP_YEAR || '1201';
            lv_to_date_m3 := P_APP_YEAR || '12' || TO_CHAR(LAST_DAY(TO_DATE(P_APP_YEAR || '12', 'YYYYMM')), 'DD');
    ELSE
            RETURN '유효하지 않은 분기입니다: ' || P_DIV_CD;
    END CASE;

    ln_work_days_m1 := F_CPN_WKP_CNT(P_ENTER_CD, P_SABUN, lv_from_date_m1, lv_to_date_m1);
    ln_work_days_m2 := F_CPN_WKP_CNT(P_ENTER_CD, P_SABUN, lv_from_date_m2, lv_to_date_m2);
    ln_work_days_m3 := F_CPN_WKP_CNT(P_ENTER_CD, P_SABUN, lv_from_date_m3, lv_to_date_m3);

    --for test
        --ln_work_days_m1 := 14;
        --ln_work_days_m3 := 14;

    IF ln_work_days_m1 < 15 AND P_APPL_MON1 > 0 THEN rtStrM1 := SUBSTR(lv_from_date_m1, 5, 2)||'월'; rtStrFlag1 := TRUE;  END IF;
    IF ln_work_days_m2 < 15 AND P_APPL_MON2 > 0 THEN rtStrM2 := SUBSTR(lv_from_date_m2, 5, 2)||'월'; rtStrFlag2 := TRUE;  END IF;
    IF ln_work_days_m3 < 15 AND P_APPL_MON3 > 0 THEN rtStrM3 := SUBSTR(lv_from_date_m3, 5, 2)||'월'; rtStrFlag3 := TRUE;  END IF;

    IF rtStrFlag1 THEN  IF SUBSTR(rtStrM1,1,1) ='0' THEN rtStrM1 := SUBSTR(rtStrM1,2,1)||'월 '; END IF; END IF;
    IF rtStrFlag2 THEN  IF SUBSTR(rtStrM2,1,1) ='0' THEN rtStrM2 := SUBSTR(rtStrM2,2,1)||'월 '; END IF; END IF;
    IF rtStrFlag3 THEN  IF SUBSTR(rtStrM3,1,1) ='0' THEN rtStrM3 := SUBSTR(rtStrM3,2,1)||'월 '; END IF; END IF;


    IF rtStrFlag1 OR rtStrFlag2 OR rtStrFlag3 THEN RETURN  rtStrM1||rtStrM2||rtStrM3||' 신청금액을 0원으로 변경 후 신청하여 주십시오.(근무일수 15일 이상 필요)'; END IF;

    --    rtStr_json := '{"title" : "'||lv_object_nm||'", "m1":"'||rtStrM1||'", "m2":"'||rtStrM2||'", "m3":"'||rtStrM3||'"}';
    --    RETURN rtStr_json;
    

    --신청금액 0 체크
    IF P_APPL_MON = 0 THEN RETURN '신청금액이 없습니다.'; END IF;


    ------------------------------------------------------------------------------------------------------------------------
    -- 2. 부부직원 신청건 체크
    ------------------------------------------------------------------------------------------------------------------------
	ln_cnt := 0;
	BEGIN
		SELECT COUNT(1) AS CNT
        INTO ln_cnt
        FROM TBEN771 A
        WHERE ENTER_CD 	= P_ENTER_CD
            AND APP_YEAR= P_APP_YEAR
            AND DIV_CD	= P_DIV_CD
            AND FAM_NM 	= P_FAM_NM
            AND FAM_YMD = P_FAM_YMD
            AND SABUN 	= (
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
    -- 3. 기신청건 체크
    ------------------------------------------------------------------------------------------------------------------------
	ln_cnt := 0;
	BEGIN
		SELECT COUNT(1) AS CNT
		  INTO ln_cnt
		  FROM TBEN771 A
		 WHERE A.ENTER_CD   	= P_ENTER_CD
		   AND A.APPL_SEQ   	<> P_APPL_SEQ
		   AND A.SABUN   		= P_SABUN
           AND REPLACE(A.FAM_NM,' ','') = REPLACE(P_FAM_NM,' ','')
			  AND A.FAM_YMD 	= P_FAM_YMD
           AND A.APP_YEAR 	= P_APP_YEAR
			  AND A.DIV_CD 	= P_DIV_CD
		   AND EXISTS ( SELECT 1 FROM THRI103 X
						 WHERE X.ENTER_CD = A.ENTER_CD
						   AND X.APPL_SEQ = A.APPL_SEQ
						   AND X.APPL_STATUS_CD IN ('21','31','99') ); -- 신청중인 대상도 체크
	EXCEPTION
		WHEN OTHERS THEN
			RETURN '기 신청건 체크 시 오류가 발생했습니다.';
	END;

	IF ln_cnt > 0 THEN
		RETURN '동일한 신청 건이 있어 신청 할 수 없습니다.('||P_FAM_NM||', '||P_APP_YEAR||'년'||REPLACE(P_DIV_CD,'0','')||'분기)';
	END IF;
    
    ------------------------------------------------------------------------------------------------------------------------
    -- 4.지급한도 체크, 월&분기
    ------------------------------------------------------------------------------------------------------------------------
    -- 특수교육비신청 기준정보 가져오기
    BEGIN
        SELECT *
            INTO lv_ben770
            FROM TBEN770
            WHERE ENTER_CD        = P_ENTER_CD
            AND TO_CHAR(SYSDATE, 'YYYYMMDD') BETWEEN SDATE AND NVL( EDATE, '99991231' );

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN '특수교육비 기준정보가 없습니다.';
        WHEN OTHERS THEN
            RETURN '특수교육비 기준정보 조회 시 오류가 발생했습니다.';
    END;


	IF  P_APPL_MON1 > lv_ben770.MAX_M_AMT OR
        P_APPL_MON2 > lv_ben770.MAX_M_AMT OR
        P_APPL_MON3 > lv_ben770.MAX_M_AMT 
	THEN
		RETURN '특수교육비 지원금은 월간 '|| FUNC_COMMA(lv_ben770.MAX_M_AMT, 0 )||'원까지 가능합니다.';
	END IF;
	
	IF P_APPL_MON > lv_ben770.MAX_Q_AMT
	THEN
		RETURN '특수교육비 지원금은 분기 '|| FUNC_COMMA(lv_ben770.MAX_Q_AMT, 0 )||'원까지 가능합니다.';
	END IF;

   ------------------------------------------------------------------------------------------------------------------------
   -- 4.지원대상 나이 체크, 기준나이 일할계산없이, 우선 년도단위로 처리
   ------------------------------------------------------------------------------------------------------------------------
	IF TO_NUMBER(P_APP_YEAR) - TO_NUMBER(SUBSTR(P_FAM_YMD, 1, 4)) > TO_NUMBER(lv_ben770.AGE_LMT) THEN
		RETURN '특수교육비 대상자 나이는 18세(만)까지 신청 가능합니다.';
	END IF;
	 
	 
	 
	--END OF CHECK
	
   RETURN lv_result;
END;