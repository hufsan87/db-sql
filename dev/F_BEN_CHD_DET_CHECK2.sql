create or replace FUNCTION F_BEN_CHD_DET_CHECK2 (
      P_ENTER_CD	IN VARCHAR2
    , P_SABUN		IN VARCHAR2
    , P_APPL_CD		IN VARCHAR2
	, P_CHD_NAME	IN VARCHAR2
	, P_CHD_BIRTH	IN VARCHAR2
    , P_APP_GB		IN VARCHAR2
    , P_APPL_YMD    IN VARCHAR2
    , P_PAY_GB      IN VARCHAR2
    , P_CHD_SDATE   IN VARCHAR2
    , P_CHD_EDATE   IN VARCHAR2
    , P_APPL_SEQ    IN VARCHAR2 
  ) RETURN VARCHAR2
IS
	lv_tben550 TBEN550%ROWTYPE; -- 자녀보육비 기준
	ln_months NUMBER;
    ln_cnt    NUMBER;
	lv_couple_sabun VARCHAR2(13);
    lv_result VARCHAR2(1000) := 'OK';
    lv_emp_status VARCHAR2(20);
    lv_appl_ymd varchar2(8) := to_char(sysdate, 'yyyymmdd');

    lv_appl_seq NUMBER;
    ln_period_cnt NUMBER;
    
    lv_app_gb VARCHAR2(20);

BEGIN
  lv_result := F_BEN_APP_CHECK(P_ENTER_CD, P_SABUN, P_APPL_CD);
  lv_couple_sabun := F_BEN_GET_COUPLE_SABUN(P_ENTER_CD, P_SABUN, '');
  lv_emp_status := F_COM_GET_STATUS_NM(P_ENTER_CD, lv_couple_sabun, TO_CHAR(SYSDATE, 'YYYYMMDD')); -- 재직상태, 재직/휴직/정직/퇴직

  ------------------------------------
  -- 1.재직상태 체크 : 재직자만 신청 가능
  ------------------------------------
  IF lv_result != 'OK' THEN
      RETURN lv_result;
  END IF;

	IF P_APP_GB='1' THEN --신규신청
		------------------------------------------------------------------------------------------------------------------------
		-- 2-1. 신규/기신청건 체크
		------------------------------------------------------------------------------------------------------------------------
		ln_cnt := 0;
		BEGIN
			SELECT COUNT(1) AS CNT, MAX(A.APPL_SEQ)
			  INTO ln_cnt, lv_appl_seq
			  FROM TBEN551 A
			 WHERE A.ENTER_CD	= P_ENTER_CD
			   AND A.SABUN		= P_SABUN
			   AND A.CHD_NAME     = P_CHD_NAME
			   AND A.CHD_BIRTH   = REPLACE(P_CHD_BIRTH, '-','')
               AND A.APPL_SEQ != P_APPL_SEQ
			   AND EXISTS ( SELECT 1
                            FROM THRI103 X
							 WHERE X.ENTER_CD = A.ENTER_CD
                               AND X.APPL_SABUN = A.SABUN
							   AND X.APPL_SEQ != P_APPL_SEQ
							   AND X.APPL_STATUS_CD IN ('21','31','99') ); -- 신청중인 대상도 체크
		EXCEPTION
			WHEN OTHERS THEN
				RETURN '기 신청건 체크 시 오류가 발생했습니다.';
		END;

		IF ln_cnt > 0 THEN
			-- 한국공항 신규일 경우 이전 신청내역 상관없이 신청 가능하도록 (어린이집 기간만 체크)
			IF P_ENTER_CD = 'KS' AND P_PAY_GB = '02' THEN
                --IF P_PAY_GB = '02' THEN -- 어린이집 기간 체크
                    SELECT APP_GB INTO lv_app_gb
                    FROM TBEN551
                    WHERE 
                        ENTER_CD = P_ENTER_CD
                        AND APPL_SEQ=lv_appl_seq ;
                    
                    IF lv_app_gb != '3' THEN  -- 이전 신청이 중단이면 제외
                        SELECT COUNT(*)
                        INTO ln_period_cnt
                        FROM TBEN551 A 
                        WHERE A.ENTER_CD = P_ENTER_CD
                        AND A.APPL_SEQ = lv_appl_seq
                        AND A.CHD_EDATE  >= P_CHD_SDATE;
                        
                        IF ln_period_cnt > 0 THEN
                           RETURN '해당 어린이집 계약기간에 이미 신청완료 또는 신청중인 내역이 있습니다.';
                        END IF;
                    END IF;
                --END IF;
			ELSE
				RETURN '이미 신청완료 또는 신청중인 내역이 있습니다.';
			END IF;
		END IF;
		------------------------------------------------------------------------------------------------------------------------
		-- 3-1. 신규/부부직원 신청건 체크
		------------------------------------------------------------------------------------------------------------------------
		ln_cnt := 0;
		BEGIN
			SELECT COUNT(1) AS CNT
			  INTO ln_cnt
			  FROM TBEN551 A
			 WHERE A.ENTER_CD	= P_ENTER_CD
			   AND A.SABUN		= lv_couple_sabun
			   AND A.CHD_NAME   = P_CHD_NAME
			   AND A.CHD_BIRTH  = REPLACE(P_CHD_BIRTH, '-','')
               AND A.APPL_SEQ != P_APPL_SEQ
			   AND EXISTS ( SELECT 1
                            FROM THRI103 X
							 WHERE X.ENTER_CD = A.ENTER_CD
                               AND X.APPL_SABUN = A.SABUN
							   AND A.APPL_SEQ != P_APPL_SEQ
							   AND X.APPL_STATUS_CD IN ('21','31','99') ); -- 신청중인 대상도 체크
		EXCEPTION
			WHEN OTHERS THEN
				RETURN '부부직원 신청건 체크 시 오류가 발생했습니다.';
		END;

		IF ln_cnt > 0 THEN
            RETURN '한 자녀에 대해 부부사원은 1인만 신청 가능합니다';
		END IF;
	ELSIF P_APP_GB='2' THEN --변경신청
		------------------------------------------------------------------------------------------------------------------------
		-- 2-2. 변경/기신청건 체크
		------------------------------------------------------------------------------------------------------------------------
		ln_cnt := 0;
    lv_appl_ymd := to_char(sysdate, 'yyyymmdd');
		BEGIN
            SELECT MAX(B.appl_ymd),count(b.appl_ymd) into lv_appl_ymd, ln_cnt
            FROM TBEN551 A
                LEFT JOIN THRI103 B
                    ON B.enter_cd = A.enter_cd
                    AND B.APPL_SABUN = A.SABUN
                    AND B.APPL_SEQ != P_APPL_SEQ
                    AND B.appl_status_cd = '99'
            WHERE A.enter_cd = P_ENTER_CD
                AND A.sabun		 = P_SABUN
                AND A.chd_name   = P_CHD_NAME
                AND A.chd_birth  = REPLACE(P_CHD_BIRTH, '-','')
                AND A.APP_GB !='3'; -- 중단 제외

		EXCEPTION
			WHEN OTHERS THEN
				RETURN '기 신청건 체크 시 오류가 발생했습니다.';
		END;

        IF ln_cnt > 0 THEN
            IF P_ENTER_CD = 'KS' THEN -- 한국공항만 본인 신청건 변경 가능
                IF lv_appl_ymd != null and substr(P_APPL_YMD,1,6) = substr(lv_appl_ymd,1,6) THEN
                    RETURN '당월 신청된 내역이 있습니다. 담당자 문의하여 취소 후 재 신청바랍니다.';
                ELSE
                    RETURN '기 신청한 내역을 변경하시겠습니까?';
                END IF;
            ELSE -- HX, HG
                RETURN '기 신청된 내역은 변경할 수 없습니다';
            END IF;
        END IF;
		------------------------------------------------------------------------------------------------------------------------
		-- 3-2. 변경/부부직원 신청건 체크
		------------------------------------------------------------------------------------------------------------------------
		ln_cnt := 0;
		BEGIN
            SELECT MAX(B.appl_ymd),count(b.appl_ymd) into lv_appl_ymd, ln_cnt
            FROM TBEN551 A
                LEFT JOIN THRI103 B
                    ON B.enter_cd = A.enter_cd
                    AND B.APPL_SABUN = A.SABUN
                    AND B.APPL_SEQ != P_APPL_SEQ
                    AND B.appl_status_cd = '99'
            WHERE A.enter_cd = P_ENTER_CD
                AND A.sabun		 = lv_couple_sabun
                AND A.chd_name   = P_CHD_NAME
                AND A.chd_birth  = REPLACE(P_CHD_BIRTH, '-','');
		EXCEPTION
			WHEN OTHERS THEN
				RETURN '부부직원 신청건 체크 시 오류가 발생했습니다.';
		END;

		-- P_COM_SET_LOG(P_ENTER_CD, 'BEN', 'F_BEN_CHD_DET_CHECK','113','TEST START : '||P_ENTER_CD||','||lv_couple_sabun||','||P_CHD_NAME||','||P_CHD_BIRTH||','||lv_appl_ymd||','||ln_cnt, P_SABUN);
    IF ln_cnt > 0 THEN
        IF lv_emp_status != '재직' OR lv_emp_status is null THEN
            IF P_ENTER_CD = 'KS' THEN
                IF lv_emp_status = '퇴직' THEN
                    IF lv_appl_ymd != null and substr(P_APPL_YMD,1,6) = substr(lv_appl_ymd,1,6) THEN
                        RETURN '당월 신청된 내역이 있습니다. 담당자 문의하여 취소 후 재 신청바랍니다.';
                    ELSE
                        RETURN '퇴직한 배우자가 기 신청한 자녀보육비 내역을 신청자로 변경하시겠습니까?';
                    END IF;
                ELSE
                    RETURN '부부사원은 1인만 신청 가능합니다.';
                END IF;
            ELSE -- HX, HG
                IF lv_appl_ymd != null and substr(P_APPL_YMD,1,6) = substr(lv_appl_ymd,1,6) THEN
                    RETURN '당월 신청된 내역이 있습니다. 담당자 문의하여 취소 후 재 신청바랍니다.';
                ELSE
                    RETURN '배우자가 기 신청한 자녀보육비 내역을 신청자로 변경하시겠습니까?';
                END IF;
            END IF;
        ELSIF lv_emp_status = '재직' THEN -- 재직
            IF P_ENTER_CD = 'KS' THEN
                RETURN '부부사원은 1인만 신청 가능합니다.';
            ELSE -- HX, HG
                RETURN '재직중인 배우자가 기 신청한 내역이 있습니다.';
            END IF;
        END IF;
    ELSE
        RETURN '기 신청된 내역이 없습니다.';
		END IF;
	END IF;

	------------------------------------------
  -- 4. 자녀보육비 신청 기준 체크 : 자녀 개월 수
  ------------------------------------------
	-- 자녀생년월일을 개월 수로 전환
  ln_months := TRUNC(MONTHS_BETWEEN(SYSDATE, TO_DATE(REPLACE(P_CHD_BIRTH,'-',''),'YYYYMMDD')));
  BEGIN
  	SELECT A.*
     INTO lv_tben550
     FROM TBEN550 A
    WHERE A.ENTER_CD        = P_ENTER_CD
      AND TO_CHAR(SYSDATE, 'YYYYMMDD') BETWEEN A.SDATE AND NVL( A.EDATE, '99991231' )
      AND 1 = CASE WHEN P_ENTER_CD = 'KS'
								THEN CASE WHEN SUBSTR(P_CHD_BIRTH,1,6) BETWEEN A.CHD_YY_SYM AND A.CHD_YY_EYM THEN 1 ELSE 0 END
								ELSE CASE WHEN A.CHD_YY_CNT = TRUNC(MONTHS_BETWEEN(SYSDATE, TO_DATE(P_CHD_BIRTH,'YYYYMMDD')) /12) THEN 1 ELSE 0 END
							END
			 ;
  EXCEPTION
      WHEN NO_DATA_FOUND THEN
          RETURN '해당하는 자녀보육비 기준정보가 없습니다.';
      WHEN OTHERS THEN
          RETURN '자녀보육비 기준정보 조회 시 오류가 발생했습니다.';
  END;
	RETURN lv_result;
END;