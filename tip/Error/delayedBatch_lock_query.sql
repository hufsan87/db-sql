--7/18 09:00
-- 제공된 SQL 쿼리는 TMSYS_06 테이블에 데이터를 삽입하는(INSERT) 작업입니다. 데이터베이스에서 INSERT 작업이 수행될 때는 데이터의 일관성을 유지하기 위해 해당 
-- 테이블에 잠금(LOCK)이 발생합니다. 이 잠금은 작업이 완료되거나 COMMIT될 때 해제됩니다.
-- 이 쿼리는 TSYS007, TSYS005, THRM151, TTIM017, TTIM051, TTIM120_V, V_TTIM821, 
-- TTIM014, TTIM309와 같은 다른 여러 테이블에서도 데이터를 읽습니다. 데이터를 읽는 테이블에는 일반적으로 공유 잠금(Shared Lock, 읽기 잠금)이 발생하며, 
-- 이는 다른 세션이 동시에 데이터를 읽을 수 있도록 허용하지만 데이터를 변경하지는 못하게 합니다.
-- 따라서 TMSYS_06 테이블에는 INSERT 작업 동안 배타적 잠금(Exclusive Lock, 쓰기 잠금)이 발생하며, 읽기 작업을 수행하는 다른 테이블에는 공유 잠금이 발생합니다.

  INSERT INTO TMSYS_06 (
    ENTER_CD, SABUN, YMD, WORK_SHM, BF_WORK_TIME1, BF_WORK_TIME2, BF_WORK_TIME3
  )
   WITH 
	BASE_ENTER AS (
		SELECT ENTER_CD
			, NOTE1
			, NOTE2
			, NOTE3
		  FROM TSYS005
		WHERE GRCODE_CD = 'M00001'
		  AND USE_YN = 'Y'
	),
	-- 근무시간 정보 CTE
	WORK_TIME AS (
	    SELECT S2.ENTER_CD, S1.WORKDAY_STD, S2.TIME_CD, S2.STIME_CD,
	           S2.HALF_HOLIDAY1, S2.HALF_HOLIDAY2,
	           S2.WORK_SHM AS WORK_SHM2,
	           S2.WORK_EHM AS WORK_EHM2
	    FROM TTIM017 S1
	    JOIN BASE_ENTER BE
	      ON BE.ENTER_CD = S1.ENTER_CD
	    LEFT JOIN TTIM051 S2 ON S1.ENTER_CD = S2.ENTER_CD
	                        AND S1.TIME_CD = S2.TIME_CD
	),
	-- 근태 정보 CTE
	WORK_STATUS AS (
	    SELECT V.ENTER_CD
	    		, V.SABUN
	    		, V.YMD
	    		, V.WORK_YN
	    		, V.SHM
	    		, V.EHM
	    		, V.STIME_CD
	    		, V.TIME_CD
	            , F_TIM_GET_DAY_GNT_CD(V.ENTER_CD, V.SABUN, V.YMD) AS GNT_CD 
	    FROM TTIM120_V V
	    JOIN BASE_ENTER BE ON BE.ENTER_CD = V.ENTER_CD
	    JOIN THRM151 E
	      ON V.ENTER_CD = E.ENTER_CD
	     AND V.SABUN = E.SABUN
	     AND E.STATUS_CD = 'AA'
	     AND E.WORK_TYPE != 'JCG_JLJ_07'
	     AND V.YMD BETWEEN E.SDATE AND E.EDATE
	    WHERE V.YMD = TO_CHAR(SYSDATE, 'YYYYMMDD')
	      AND NOT EXISTS (
	            SELECT 1
	            FROM TTIM309 E
	            WHERE V.ENTER_CD = E.ENTER_CD
	            AND V.SABUN = E.SABUN
	            AND V.YMD BETWEEN E.SDATE AND NVL(E.EDATE,'29991231')
	            AND E.FIX_ST_TIME_YN = 'Y'
	            AND E.FIX_ED_TIME_YN = 'Y'
	        )
	),
	-- 메인 데이터 처리
	MAIN_DATA AS (
	  SELECT ENTER_CD
	  		, SABUN
	  		, YMD
	  		, CASE 
		  		WHEN GNT_CD = '88' THEN WORK_SHM 
	            WHEN GNT_CD IS NOT NULL AND GNT_CD NOT IN ('15','16','135','136') THEN '-' --근태코드 처리
	            WHEN ENTER_CD = 'KS' AND GNT_CD IN ('G2','V01') THEN '-'
	            WHEN TIME_CD IS NULL THEN '-'
	            WHEN WORK_YN = 'N' THEN
						                CASE 
						                    WHEN REQUEST_USE_TYPE = 'AM' THEN HALF_HOLIDAY1 
						                    ELSE WORK_SHM
						                END
	            WHEN WORK_YN = 'Y' AND SHM IS NOT NULL AND EHM IS NOT NULL THEN SHM
	            ELSE '-'
	        END AS WORK_SHM
	    FROM (
		    SELECT 
		        A.ENTER_CD,
		        A.SABUN,
		        A.YMD,
		        A.GNT_CD,
		        A.TIME_CD,
		        A.WORK_YN,
		        A.SHM,
		        A.EHM,
		        D.HALF_HOLIDAY1,
		        R.REQUEST_USE_TYPE,
		        CASE
			        WHEN E.ENTER_CD IS NOT NULL 
			        THEN TO_CHAR(TO_DATE(D.WORK_SHM2, 'HH24MI') + NVL(E.DECRE_SM, 0) / 1440, 'HH24MI')
			        ELSE NVL(A.SHM, D.WORK_SHM2)
			        END AS WORK_SHM
		    FROM WORK_STATUS A
		    JOIN TTIM014 R ON A.ENTER_CD = R.ENTER_CD
		                       AND A.GNT_CD = R.GNT_CD
	        LEFT JOIN WORK_TIME D ON A.ENTER_CD = D.ENTER_CD 
							     AND A.TIME_CD = D.TIME_CD 
							     AND A.STIME_CD = D.STIME_CD
		    LEFT JOIN V_TTIM821 E ON A.ENTER_CD = E.ENTER_CD 
		                         AND A.SABUN = E.SABUN 
		                         AND A.YMD = E.YMD
	    )
	),
	RESULT_DATA AS (
		SELECT 
		        T.ENTER_CD, 
		        T.SABUN, 
		        T.YMD,
		        T.WORK_SHM,
		  --      BE.NOTE1,
		 --       BE.NOTE2,
		  --      BE.NOTE3,
		        CASE WHEN BE.NOTE1 IS NOT NULL
		            THEN TO_CHAR((TO_DATE(T.WORK_SHM,'HH24MI') - TO_NUMBER(NVL(BE.NOTE1,'0')/1440)), 'HH24MI')
		            ELSE NULL
		            END AS BF_WORK_TIME1 ,
		        CASE WHEN BE.NOTE2 IS NOT NULL
		          	THEN TO_CHAR((TO_DATE(T.WORK_SHM,'HH24MI') - TO_NUMBER(NVL(BE.NOTE2,'0')/1440)), 'HH24MI')
		          	ELSE NULL
		          	END AS BF_WORK_TIME2 ,
		        CASE WHEN BE.NOTE3 IS NOT NULL
		          	THEN TO_CHAR((TO_DATE(T.WORK_SHM,'HH24MI') - TO_NUMBER(NVL(BE.NOTE3,'0')/1440)), 'HH24MI')
		          	ELSE NULL
		          	END AS BF_WORK_TIME3
		    FROM MAIN_DATA T
		    JOIN BASE_ENTER BE ON T.ENTER_CD = BE.ENTER_CD
		      AND (T.WORK_SHM IS NOT NULL AND T.WORK_SHM != '-')
		      )
	    SELECT 
		    ENTER_CD,
		    SABUN,
		    YMD,
		    WORK_SHM,
		    BF_WORK_TIME1,
		    BF_WORK_TIME2,
		    BF_WORK_TIME3
		FROM RESULT_DATA
  
  COMMIT;