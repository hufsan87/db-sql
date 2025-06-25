create or replace FUNCTION "F_BEN_APP_CHECK" (
      P_ENTER_CD          IN VARCHAR2
    , P_SABUN             IN VARCHAR2
	, P_APPL_CD           IN VARCHAR2
  ) RETURN VARCHAR2
IS
/*****************************************************************************/
/*    신청 조건 체크                                                           */
/*    학자금           : 103                                                  */
/*    자녀보육비        : 113                                                  */
/*    장기근속여행포상비 : 116                                                  */
/*****************************************************************************/
    ln_work_ym    NUMBER := 0;    --근속개월
    lv_status_nm    VARCHAR2(50); --근무상태 (재직,휴직,퇴사)
    ln_sabun NUMBER := 0; -- 장기근속, 대상자 여부 확인용
    
    -- 임원인 경우, 학자금신청 6개월 근속 제외(HX only)
    lv_immonYn VARCHAR2(10) := 'N';
	lv_jikgub_cd THRM151.JIKGUB_CD%TYPE;

    lv_result    VARCHAR2(1000) := 'OK';
BEGIN
    BEGIN
        ------------------------------------------------------------------------
        -- 근속기간 6개월 이상 신청 가능 : 학자금
        -- 휴직상태 신청 불가	: 학자금(103), 자녀보육비(113), 장기근속여행비(116), 특수교육비(102)
        ------------------------------------------------------------------------
        BEGIN
            SELECT TRUNC(F_COM_GET_WORK_YM(P_ENTER_CD, P_SABUN, TO_CHAR(SYSDATE, 'YYYYMMDD'))) AS WORK_YM,
            F_COM_GET_STATUS_NM(P_ENTER_CD, P_SABUN, TO_CHAR(SYSDATE, 'YYYYMMDD')) AS STATUS_CD
              INTO ln_work_ym, lv_status_nm
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS THEN
                RETURN '근속개월 및 재직상태 체크 시 오류가 발생했습니다.';
        END;
        
        /*
        IF lv_status_nm is null THEN
            RETURN '재직정보가 없습니다.';
        ELSIF lv_status_nm <> '재직' AND P_APPL_CD <> '113' THEN -- 재직/휴직/정직/퇴직
            -- RETURN '휴직자는 복직 후 신청 가능합니다';
            RETURN '재직자만 신청 가능합니다.';
        END IF;
        */
        
        IF ln_work_ym is null THEN
            RETURN '근무기간 정보가 없습니다.';
        ELSIF (P_APPL_CD = '103') AND ln_work_ym < 6 AND P_ENTER_CD <> 'KS' THEN -- 자녀학자금
            lv_jikgub_cd := F_COM_GET_JIKGUB_CD(P_ENTER_CD, P_SABUN, TO_CHAR(SYSDATE,'YYYYMMDD'));
            lv_immonYn := F_COM_GET_GRCODE_MAP_VAL(P_ENTER_CD, 'A01','H20010', lv_jikgub_cd, TO_CHAR(SYSDATE,'YYYYMMDD'));
            IF P_ENTER_CD <> 'HX' OR lv_immonYn <> 'Y' THEN
                RETURN '6개월 이상 근무자만 신청 가능합니다.';
            END IF;
        END IF;

        ------------------------------------------------------------------------
        -- 장기근속여행비 대상자 체크
        ------------------------------------------------------------------------
        IF P_APPL_CD = '116' THEN
            BEGIN
                SELECT count(1) into ln_sabun
                FROM TBEN562
                WHERE ENTER_CD = P_ENTER_CD
                AND PAY_GB = '01' -- 여행비
                --AND BAS_YY >= TO_CHAR(SYSDATE,'yyyy') -- 그냥 대상자에 있으면 모두 가능
                AND SABUN  = P_SABUN;

                IF ln_sabun = 0 THEN
                    RETURN '장기근속여행 대상자 생성내역이 없습니다. 담당자에게 문의바랍니다';
                END IF;

                /*SELECT count(1) into ln_sabun
                FROM TBEN562
                WHERE ENTER_CD = P_ENTER_CD
                AND PAY_GB = '01' -- 여행비
                --AND BAS_YY >= TO_CHAR(SYSDATE,'yyyy')
                AND SABUN = P_SABUN
                AND EXP_YN = 'Y';

							  IF ln_sabun <> 0 THEN
										RETURN '장기근속여행 제외 대상자입니다. 담당자에게 문의바랍니다';
                END IF;*/
            EXCEPTION
                WHEN OTHERS THEN
                    RETURN '장기근속 여행 대상자 조회 시 오류가 발생했습니다.'||SQLERRM;
            END;
        END IF;

        ------------------------------------------------------------------------
        -- 특수교육비 대상자 체크 102
        ------------------------------------------------------------------------
        IF P_APPL_CD = '102' THEN
            --재직상태 체크
            IF F_COM_GET_STATUS_CD(P_ENTER_CD, P_SABUN, TO_CHAR(SYSDATE, 'YYYYMMDD')) != 'AA' THEN --(참고) CA, EA 휴지, 정직
                RETURN '재직자만 신청할 수 있습니다.';
            END IF;
        END IF;
    END;

    RETURN lv_result;
END;