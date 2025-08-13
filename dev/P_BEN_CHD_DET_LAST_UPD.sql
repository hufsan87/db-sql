create or replace PROCEDURE             "P_BEN_CHD_DET_LAST_UPD"(
      P_SQLCODE     OUT VARCHAR2,
      P_SQLERRM     OUT VARCHAR2,
      P_ENTER_CD    IN VARCHAR2,
      P_SABUN       IN VARCHAR2,
      P_APPL_SEQ    IN VARCHAR2,
      P_APPL_YMD    IN VARCHAR2,
      P_CHKID       IN VARCHAR2
) IS
/*  자녀보육비 승인 시,
*   신청자 또는 배우자의 기 신청자료의 '지급상태' 및 '종료년월' 업데이트하기
*/
    lv_enter_cd TBEN551.ENTER_CD%TYPE;
    lv_app_gb TBEN551.APP_GB%TYPE;
    lv_sabun TBEN551.SABUN%TYPE;
    lv_chd_name TBEN551.CHD_NAME%TYPE;
    lv_chd_birth TBEN551.CHD_BIRTH%TYPE;
    lv_part_sabun TBEN551.PART_SABUN%TYPE;

    ln_last_appl_seq NUMBER;
    lv_last_e_ym TBEN551.USE_E_YM%TYPE;
    lv_pay_amt TBEN551.PAY_AMT%TYPE;

		LV_BIZ_CD               TSYS903.BIZ_CD%TYPE := 'BEN';
    LV_OBJECT_NM            TSYS903.OBJECT_NM%TYPE := 'P_BEN_CHD_DET_LAST_UPD';
BEGIN
		P_SQLCODE := NULL;
		P_SQLERRM := NULL;

    --[신규][변경][중단](신청자료)
		BEGIN
		  -- 한진정보, 한진칼은 만나이 기준, (TP,HT 추가 2025.08.13)
			IF P_ENTER_CD IN ('HX','HG','TP','HT') THEN
		    SELECT A.ENTER_CD,	 A.APP_GB,		A.SABUN,		A.CHD_NAME,		A.CHD_BIRTH, 	B.PAY_AMT
		      INTO lv_enter_cd	,lv_app_gb,		lv_sabun,		lv_chd_name,	lv_chd_birth, lv_pay_amt
		      FROM TBEN551 A, TBEN550 B
		     WHERE A.ENTER_CD=P_ENTER_CD
		       AND A.APPL_SEQ = P_APPL_SEQ
		       AND B.ENTER_CD = A.ENTER_CD
		       AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN B.SDATE 		AND NVL(B.EDATE,'99991231')
		       --AND SUBSTR(P_APPL_YMD,1,6)			  BETWEEN B.SDATE 	  AND B.EDATE
		       AND A.CHD_YY_CNT = B.CHD_YY_CNT
		       ;
			ELSE
			-- 한국공항은 기준에 태어날 년월 기준
		    SELECT A.ENTER_CD,	 A.APP_GB,		A.SABUN,		A.CHD_NAME,		A.CHD_BIRTH, 	B.PAY_AMT
		      INTO lv_enter_cd	,lv_app_gb,		lv_sabun,		lv_chd_name,	lv_chd_birth, lv_pay_amt
		      FROM TBEN551 A, TBEN550 B
		     WHERE A.ENTER_CD=P_ENTER_CD
		       AND A.APPL_SEQ = P_APPL_SEQ
		       AND B.ENTER_CD = A.ENTER_CD
		       --AND TO_CHAR(SYSDATE,'YYYYMMDD') BETWEEN B.SDATE 		AND NVL(B.EDATE,'99991231')
		       -- 분기점
		       AND SUBSTR(A.CHD_BIRTH,1,6) BETWEEN B.CHD_YY_SYM AND B.CHD_YY_EYM
		       ;
	     END IF;
    EXCEPTION
    WHEN OTHERS THEN
       P_SQLERRM := '자녀보육비 신청정보 조회 시 에러발생 ' || SQLERRM;
       P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'113',P_SQLERRM, P_SABUN);
    END;

    lv_part_sabun := F_BEN_GET_COUPLE_SABUN(P_ENTER_CD, P_SABUN, SYSDATE);
    lv_last_e_ym  := F_BEN_CHD_GET_EYM(P_ENTER_CD, P_APPL_SEQ, P_APPL_YMD, lv_app_gb, P_SABUN, lv_chd_name, lv_chd_birth);

    --[신규][변경]
    IF lv_app_gb != '3' THEN
 			BEGIN
            
            IF P_ENTER_CD='KS' THEN
                UPDATE TBEN551
                SET PAY_STS = 'P', -- 지급
                        PAY_AMT = lv_pay_amt,
                    USE_S_YM =
                    /* 시작년월 : 신청일자 15일이전까지 당월부터 지급 
                    (2025.08.13 시작년월 처리관련 승인화면과 동일 로직 적용 요청
                    <=20일 : 익월, >20일 : 익익월
                    */
                            CASE
                                WHEN EXTRACT(DAY FROM TO_DATE(REPLACE(P_APPL_YMD,'-',''), 'YYYYMMDD')) <= 20
                                THEN TO_CHAR(ADD_MONTHS(TO_DATE(REPLACE(P_APPL_YMD,'-',''), 'YYYYMMDD'), 1), 'YYYYMM')
                                ELSE TO_CHAR(ADD_MONTHS(TO_DATE(REPLACE(P_APPL_YMD,'-',''), 'YYYYMMDD'), 2), 'YYYYMM')
                            END, --신청월
                    --USE_E_YM = lv_last_e_ym, -- 신규:기준테이블, 변경:기 신청 종료년월
                    PART_SABUN = lv_part_sabun, -- 배우자 사번
                      PAY_ST_CNT = CASE WHEN lv_app_gb = '1' THEN months_between(to_date(
                                            CASE WHEN  SUBSTR(REPLACE(P_APPL_YMD,'-',''), 7) <= 15
                                                                    THEN SUBSTR(REPLACE(P_APPL_YMD,'-',''), 1,6)
                                                                    ELSE TO_CHAR(ADD_MONTHS(TO_DATE(P_APPL_YMD, 'YYYYMMDD'), 1), 'YYYYMM')
                                                                    END -- 신청월
                      ,'yyyymm'),to_date(substr(chd_birth,1,6),'yyyymm')) ELSE 0 END,
                    CHKDATE = SYSDATE,
                    CHKID = P_CHKID
                WHERE ENTER_CD = P_ENTER_CD AND APPL_SEQ = P_APPL_SEQ;
            ELSE -- HG,HX,TP,HT
                UPDATE TBEN551
                SET PAY_STS = 'P', -- 지급
                        PAY_AMT = lv_pay_amt,
                    USE_S_YM =
                    /* 시작년월 : 신청일자 15일이전까지 당월부터 지급 */
                                CASE WHEN  SUBSTR(REPLACE(P_APPL_YMD,'-',''), 7) <= 15
                                THEN SUBSTR(REPLACE(P_APPL_YMD,'-',''), 1,6)
                                ELSE TO_CHAR(ADD_MONTHS(TO_DATE(P_APPL_YMD, 'YYYYMMDD'), 1), 'YYYYMM')
                                END, -- 신청월
                    --USE_E_YM = lv_last_e_ym, -- 신규:기준테이블, 변경:기 신청 종료년월
                    PART_SABUN = lv_part_sabun, -- 배우자 사번
                      PAY_ST_CNT = CASE WHEN lv_app_gb = '1' THEN months_between(to_date(
                                            CASE WHEN  SUBSTR(REPLACE(P_APPL_YMD,'-',''), 7) <= 15
                                                                    THEN SUBSTR(REPLACE(P_APPL_YMD,'-',''), 1,6)
                                                                    ELSE TO_CHAR(ADD_MONTHS(TO_DATE(P_APPL_YMD, 'YYYYMMDD'), 1), 'YYYYMM')
                                                                    END -- 신청월
                      ,'yyyymm'),to_date(substr(chd_birth,1,6),'yyyymm')) ELSE 0 END,
                    CHKDATE = SYSDATE,
                    CHKID = P_CHKID
                WHERE ENTER_CD = P_ENTER_CD AND APPL_SEQ = P_APPL_SEQ;
            END IF;
	    EXCEPTION
	    WHEN OTHERS THEN
	       P_SQLERRM := '자녀보육비 신규,변경 변경 시 에러발생 ' || SQLERRM;
	       P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'113-1',P_SQLERRM, P_SABUN);
	    END;
    ELSIF lv_app_gb = '3' THEN
    	-- [중단]
    	BEGIN
        UPDATE TBEN551
        SET PAY_STS = 'F', -- 중단
            USE_S_YM = SUBSTR(TO_CHAR(ADD_MONTHS(TO_DATE(REPLACE(P_APPL_YMD,'-',''),'YYYYMMDD'),1),'YYYYMMDD'), 1,6), --신청월 익월
            USE_E_YM = SUBSTR(TO_CHAR(ADD_MONTHS(TO_DATE(REPLACE(P_APPL_YMD,'-',''),'YYYYMMDD'),1),'YYYYMMDD'), 1,6), --신청월 익월
            PART_SABUN = lv_part_sabun,
            CHKDATE = SYSDATE,
            CHKID = P_CHKID
        WHERE ENTER_CD = P_ENTER_CD AND APPL_SEQ = P_APPL_SEQ;
	    EXCEPTION
	    WHEN OTHERS THEN
	       P_SQLERRM := '자녀보육비 중단 시 에러발생 ' || SQLERRM;
	       P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'113-2',P_SQLERRM, P_SABUN);
	    END;
    END IF;

    --[변경][중단] (기 신청자료)
    ln_last_appl_seq := F_BEN_CHD_GET_LAST_SEQ(lv_enter_cd, P_APPL_SEQ, lv_app_gb,lv_sabun,lv_chd_name,lv_chd_birth);
--P_COM_SET_LOG(P_ENTER_CD, 'BEN', 'P_BEN_CHD_DET_LAST_UPD','113-2','TEST START : '||lv_app_gb||','||ln_last_appl_seq, P_SABUN);
    IF ln_last_appl_seq > 0 THEN
        IF lv_app_gb='2' THEN
--P_COM_SET_LOG(P_ENTER_CD, 'BEN', 'P_BEN_CHD_DET_LAST_UPD','113-3','TEST START : '||lv_app_gb||','||ln_last_appl_seq, P_SABUN);
            UPDATE TBEN551
            SET
                PAY_STS='F',
                USE_E_YM = TO_CHAR(ADD_MONTHS(TO_DATE(REPLACE(P_APPL_YMD,'-',''),'YYYYMMDD'), -1), 'YYYYMM'),
                CHKDATE = SYSDATE,
                CHKID = P_CHKID
            WHERE
                ENTER_CD = P_ENTER_CD
                AND APPL_SEQ = ln_last_appl_seq;
        ELSIF lv_app_gb='3' THEN
--P_COM_SET_LOG(P_ENTER_CD, 'BEN', 'P_BEN_CHD_DET_LAST_UPD','113-4','TEST START : '||lv_app_gb||','||ln_last_appl_seq, P_SABUN);
            UPDATE TBEN551
            SET
                PAY_STS='F',
                USE_E_YM = SUBSTR(TO_CHAR(ADD_MONTHS(TO_DATE(REPLACE(P_APPL_YMD,'-',''),'YYYYMMDD'),1),'YYYYMMDD'), 1,6), --신청월 익월
                CHKDATE = SYSDATE,
                CHKID = P_CHKID
            WHERE
                ENTER_CD = P_ENTER_CD
                AND APPL_SEQ = ln_last_appl_seq;
        END IF;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        P_COM_SET_LOG(P_ENTER_CD, 'BEN', 'P_BEN_CHD_DET_LAST_UPD','113-9',SQLERRM, P_SABUN);
END;