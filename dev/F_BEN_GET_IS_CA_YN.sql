create or replace FUNCTION             "F_BEN_GET_IS_CA_YN" (
                     P_ENTER_CD        IN VARCHAR2, -- 회사코드
                     P_SABUN           IN VARCHAR2, -- 사원번호
                     P_DATE            IN VARCHAR2,  -- 기준일 
                     P_GUBUN           IN VARCHAR2 := NULL  -- 복리후생 업무구분
)
    RETURN VARCHAR2
IS

    -- Local Variables
    LV_STATUS_CD THRM151.STATUS_CD%TYPE; 
    LV_SDATE THRM151.SDATE%TYPE; 
    LV_CNT NUMBER;
BEGIN
   -- 휴직인 경우 151 SDATE가져옴
    BEGIN
			SELECT
				 A.STATUS_CD, A.SDATE
				 INTO LV_STATUS_CD, LV_SDATE
			FROM THRM151 A
			WHERE 1=1
				AND A.STATUS_CD = 'CA'
				AND A.ENTER_CD = P_ENTER_CD
				AND A.SABUN    = P_SABUN
				AND P_DATE BETWEEN A.SDATE AND A.EDATE
				;
    EXCEPTION
       WHEN NO_DATA_FOUND THEN
           RETURN 'N';
       WHEN OTHERS THEN
          RETURN 'N';
    END;
   
   -- 휴직 일 경우, 발령일이 같거나 작은것중 병가중 가장 큰것
   -- 왜냐하면 현상태가 휴직이기때문에 
   -- 한국공항(KS) 분리 24.10.16
    IF P_ENTER_CD = 'KS' THEN 
        BEGIN
            SELECT
            	COUNT(1)
            	INTO LV_CNT 
              FROM THRM191 X
             WHERE 1=1
               AND X.ENTER_CD = P_ENTER_CD
               AND X.SABUN    = P_SABUN
               AND X.ORD_YMD||X.APPLY_SEQ = (SELECT MAX( ZZ.ORD_YMD||ZZ.APPLY_SEQ)
                	                          FROM THRM191 ZZ
                	                         WHERE ZZ.ENTER_CD = X.ENTER_CD
                	                           AND ZZ.SABUN    = X.SABUN
                	                           AND ZZ.ORD_YMD  <= LV_SDATE
                	                           --AND F_COM_GET_STATUS_CD(ZZ.ENTER_CD, ZZ.SABUN, ZZ.ORD_YMD) = 'CA'
                                               AND F_COM_GET_STATUS_CD(ZZ.ENTER_CD, ZZ.SABUN, P_DATE) = 'CA'
                	                           AND ZZ.ORD_DETAIL_CD IN(SELECT ORD_DETAIL_CD FROM TSYS013 WHERE ENTER_CD = P_ENTER_CD AND ORD_TYPE_CD = 'LAT_UPL_KOR')
                	                         )
             -- 복리후생업무구분마다 사용휴직코드분리 24.10.16
               AND (
                    (P_GUBUN IS NULL AND X.ORD_DETAIL_CD IN ('LAT_UPL_KOR29', 'LAT_UPL_KOR30', 'LAT_UPL_KOR48', 'LAT_UPL_KOR49', 'LAT_UPL_KOR51', 'LAT_UPL_KOR09')) -- DEFAULT
                      OR (P_GUBUN = '55' AND X.ORD_DETAIL_CD IN ('LAT_UPL_KOR29', 'LAT_UPL_KOR30', 'LAT_UPL_KOR48', 'LAT_UPL_KOR49', 'LAT_UPL_KOR51')) --  자가보험
                      OR (P_GUBUN = 'SH' AND X.ORD_DETAIL_CD NOT IN ('LAT_UPL_KOR02','LAT_UPL_KOR08','LAT_UPL_KOR09','LAT_UPL_KOR10','LAT_UPL_KOR11','LAT_UPL_KOR12','LAT_UPL_KOR43','LAT_UPL_KOR50')) --  신협대출
                   )
            ;         
        EXCEPTION
           WHEN NO_DATA_FOUND THEN
               RETURN 'N';
           WHEN OTHERS THEN
              RETURN 'N';
        END;
     
     ELSE 
        BEGIN
            SELECT
                COUNT(1)
                INTO LV_CNT 
              FROM THRM191 X
             WHERE 1=1
               AND X.ENTER_CD = P_ENTER_CD
               AND X.SABUN    = P_SABUN
               AND X.ORD_YMD||X.APPLY_SEQ = (SELECT MAX( ZZ.ORD_YMD||ZZ.APPLY_SEQ)
                                              FROM THRM191 ZZ
                                             WHERE ZZ.ENTER_CD = X.ENTER_CD
                                               AND ZZ.SABUN    = X.SABUN
                                               AND ZZ.ORD_YMD  <= LV_SDATE
                                               --AND F_COM_GET_STATUS_CD(ZZ.ENTER_CD, ZZ.SABUN, ZZ.ORD_YMD) = 'CA'
                                               AND F_COM_GET_STATUS_CD(ZZ.ENTER_CD, ZZ.SABUN, P_DATE) = 'CA'
                                               AND ZZ.ORD_DETAIL_CD IN(SELECT ORD_DETAIL_CD FROM TSYS013 WHERE ENTER_CD = P_ENTER_CD AND ORD_TYPE_CD = 'LAT_UPL_KOR')
                                             )
             --AND X.ORD_DETAIL_CD IN ('LAT_UPL_KOR29','LAT_UPL_KOR30','LAT_UPL_KOR48') 
             --AND X.ORD_DETAIL_CD IN ('LAT_UPL_KOR29','LAT_UPL_KOR30','LAT_UPL_KOR48', 'LAT_UPL_KOR49') -- 24.04.15 산재추가
             --AND X.ORD_DETAIL_CD IN ('LAT_UPL_KOR29','LAT_UPL_KOR30','LAT_UPL_KOR48', 'LAT_UPL_KOR49', 'LAT_UPL_KOR51') -- 24.08.14 산재연장추가
             --AND X.ORD_DETAIL_CD IN ('LAT_UPL_KOR29','LAT_UPL_KOR30','LAT_UPL_KOR48', 'LAT_UPL_KOR49', 'LAT_UPL_KOR51','LAT_UPL_KOR09') -- 24.08.21 육아휴직추가 
               AND X.ORD_DETAIL_CD IN ('LAT_UPL_KOR29','LAT_UPL_KOR30','LAT_UPL_KOR48', 'LAT_UPL_KOR49', 'LAT_UPL_KOR51','LAT_UPL_KOR09','LAT_UPL_KOR11') -- 25.09.16 Voluntary추가 
             ;                
        EXCEPTION
           WHEN NO_DATA_FOUND THEN
               RETURN 'N';
           WHEN OTHERS THEN
              RETURN 'N';
        END;
     
     END IF;

	 IF LV_CNT = 0 THEN
	 	RETURN 'N';
	 ELSE 
	 	RETURN 'Y';
	 END IF; 
		
EXCEPTION
        WHEN OTHERS THEN
           RETURN 'N';
END;