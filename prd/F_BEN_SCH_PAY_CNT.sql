create or replace FUNCTION             F_BEN_SCH_PAY_CNT (
	 P_ENTER_CD				IN VARCHAR2
	, P_SABUN					IN VARCHAR2
	, P_SCH_LOC_CD			IN VARCHAR2
	, P_SCH_TYPE_CD			IN VARCHAR2
	, P_SCH_SUP_TYPE_CD	IN VARCHAR2
	, P_FAM_NM				IN VARCHAR2
	, P_FAM_YMD				IN VARCHAR2
  ) RETURN VARCHAR2
IS
/********************************************************************************/
/*    학자금승인 지원횟수 조회        */
/********************************************************************************/
    lv_result VARCHAR2(1000);

BEGIN

	BEGIN
        --국내 및 국외 신청/승인 건이 있는 자녀에 대하여 지원 회수 오류 fix 2025.03.07, 기존 쿼리에 sum/max로 합산하여 리턴
        SELECT SUM(CNT) || '/' || MAX(TO_NUMBER(APPL_CNT))
        INTO lv_result
        FROM (
            SELECT COUNT(B.ENTER_CD) AS CNT, F_BEN_LMT_APPL(A.ENTER_CD,A.SCH_TYPE_CD, A.SCH_SUP_TYPE_CD, A.SCH_LOC_CD, '1') AS APPL_CNT
              FROM TBEN751 A
              LEFT JOIN THRI103 B
                ON A.ENTER_CD = B.ENTER_CD 
               AND A.APPL_SEQ = B.APPL_SEQ 
               AND B.APPL_STATUS_CD = '99'
             WHERE A.ENTER_CD = P_ENTER_CD 
               AND A.SABUN = P_SABUN 
               AND A.SCH_TYPE_CD = P_SCH_TYPE_CD 
               AND A.SCH_SUP_TYPE_CD = P_SCH_SUP_TYPE_CD 
               AND A.FAM_NM = P_FAM_NM 
               AND A.FAM_YMD = P_FAM_YMD
             --  AND NVL(A.PAY_AMT,LEAST(A.APPL_MON,F_BEN_LMT_APPL(A.ENTER_CD,A.SCH_TYPE_CD, A.SCH_SUP_TYPE_CD, '2'))) > 0-- 240215 추가 (지급금액 0인 경우 지급횟수 체크 x)
             --  AND NVL(A.PAY_AMT,0) >0 --240304 추가 (지급금액 0인 경우 지급횟수 체크 x)
               AND (
                (A.ENTER_CD = 'KS' AND NVL(A.PAY_AMT, 0) >= 0) -- KS, 0이상으로 변경 250905
                OR (A.ENTER_CD <> 'KS' AND NVL(A.PAY_AMT, 0) > 0)
               )
             GROUP BY F_BEN_LMT_APPL(A.ENTER_CD,A.SCH_TYPE_CD, A.SCH_SUP_TYPE_CD, A.SCH_LOC_CD, '1')
        );
	EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN '0';
		WHEN OTHERS THEN
			RETURN '지원횟수 체크 시 오류가 발생했습니다. ('||UTL_CALL_STACK.error_msg (1)||')';
	END;

	RETURN lv_result;
END;