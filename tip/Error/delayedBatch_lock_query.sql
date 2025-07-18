--7/18 09:00
-- 제공된 SQL 쿼리는 TMSYS_06 테이블에 데이터를 삽입하는(INSERT) 작업입니다. 데이터베이스에서 INSERT 작업이 수행될 때는 데이터의 일관성을 유지하기 위해 해당 
-- 테이블에 잠금(LOCK)이 발생합니다. 이 잠금은 작업이 완료되거나 COMMIT될 때 해제됩니다.
-- 이 쿼리는 TSYS007, TSYS005, THRM151, TTIM017, TTIM051, TTIM120_V, V_TTIM821, 
-- TTIM014, TTIM309와 같은 다른 여러 테이블에서도 데이터를 읽습니다. 데이터를 읽는 테이블에는 일반적으로 공유 잠금(Shared Lock, 읽기 잠금)이 발생하며, 
-- 이는 다른 세션이 동시에 데이터를 읽을 수 있도록 허용하지만 데이터를 변경하지는 못하게 합니다.
-- 따라서 TMSYS_06 테이블에는 INSERT 작업 동안 배타적 잠금(Exclusive Lock, 쓰기 잠금)이 발생하며, 읽기 작업을 수행하는 다른 테이블에는 공유 잠금이 발생합니다.

INSERT INTO TMSYS_06 (
  ENTER_CD, SABUN, YMD, WORK_SHM, BF_WORK_TIME1, 
  BF_WORK_TIME2, BF_WORK_TIME3
) WITH BASE_DATE AS (
  SELECT 
    SUN_DATE AS YMD 
  FROM 
    TSYS007 
  WHERE 
    SUN_DATE = TO_CHAR(SYSDATE, 'YYYYMMDD')
), 
BASE_ENTER AS (
  SELECT 
    ENTER_CD, 
    NOTE1, 
    NOTE2, 
    NOTE3 
  FROM 
    TSYS005 
  WHERE 
    GRCODE_CD = 'M00001' 
    AND USE_YN = 'Y'
), 
EMP_BASE AS (
  SELECT 
    A1.ENTER_CD, 
    A1.SABUN, 
    A2.YMD, 
    A1.STATUS_CD 
  FROM 
    THRM151 A1 
    JOIN BASE_DATE A2 ON 1 = 1 
  WHERE 
    EXISTS (
      SELECT 
        1 
      FROM 
        BASE_ENTER BE 
      WHERE 
        BE.ENTER_CD = A1.ENTER_CD
    ) 
    AND A2.YMD BETWEEN A1.SDATE 
    AND A1.EDATE 
    AND A1.WORK_TYPE != 'JCG_JLJ_07' 
    AND A1.STATUS_CD = 'AA'
), 
WORK_TIME AS (
  SELECT 
    S2.ENTER_CD, 
    S1.WORKDAY_STD, 
    S2.TIME_CD, 
    S2.STIME_CD, 
    S2.HALF_HOLIDAY1, 
    S2.HALF_HOLIDAY2, 
    S2.WORK_SHM AS WORK_SHM2, 
    S2.WORK_EHM AS WORK_EHM2 
  FROM 
    TTIM017 S1 
    LEFT JOIN TTIM051 S2 ON S1.ENTER_CD = S2.ENTER_CD 
    AND S1.TIME_CD = S2.TIME_CD
), 
WORK_STATUS AS (
  SELECT 
    ENTER_CD, 
    SABUN, 
    YMD, 
    WORK_YN, 
    SHM, 
    EHM, 
    STIME_CD, 
    TIME_CD 
  FROM 
    TTIM120_V V 
  WHERE 
    EXISTS (
      SELECT 
        1 
      FROM 
        BASE_ENTER BE 
      WHERE 
        BE.ENTER_CD = V.ENTER_CD
    ) 
    AND YMD = (
      SELECT 
        YMD 
      FROM 
        BASE_DATE
    )
), 
GNT_STATUS AS (
  SELECT 
    ENTER_CD, 
    SABUN, 
    YMD, 
    F_TIM_GET_DAY_GNT_CD(ENTER_CD, SABUN, YMD) AS GNT_CD 
  FROM 
    EMP_BASE
), 
MAIN_DATA AS (
  SELECT 
    ENTER_CD, 
    SABUN, 
    YMD, 
    CASE WHEN GNT_CD = '88' THEN WORK_SHM WHEN GNT_CD IS NOT NULL 
    AND GNT_CD NOT IN ('15', '16', '135', '136') THEN '-' WHEN ENTER_CD = 'KS' 
    AND GNT_CD IN ('G2', 'V01') THEN '-' WHEN TIME_CD IS NULL THEN '-' WHEN WORK_YN = 'N' THEN CASE WHEN REQUEST_USE_TYPE = 'AM' THEN HALF_HOLIDAY1 ELSE WORK_SHM END WHEN WORK_YN = 'Y' 
    AND SHM IS NOT NULL 
    AND EHM IS NOT NULL THEN SHM ELSE '-' END AS WORK_SHM 
  FROM 
    (
      SELECT 
        A.ENTER_CD, 
        A.SABUN, 
        A.YMD, 
        G.GNT_CD, 
        C.TIME_CD, 
        C.WORK_YN, 
        D.HALF_HOLIDAY1, 
        R.REQUEST_USE_TYPE, 
        C.SHM, 
        C.EHM, 
        CASE WHEN E.ENTER_CD IS NOT NULL THEN TO_CHAR(
          TO_DATE(D.WORK_SHM2, 'HH24MI') + NVL(E.DECRE_SM, 0) / 24 / 60, 
          'HH24MI'
        ) ELSE NVL(C.SHM, D.WORK_SHM2) END AS WORK_SHM 
      FROM 
        EMP_BASE A 
        JOIN WORK_STATUS C ON A.ENTER_CD = C.ENTER_CD 
        AND A.YMD = C.YMD 
        AND A.SABUN = C.SABUN 
        LEFT JOIN WORK_TIME D ON C.ENTER_CD = D.ENTER_CD 
        AND C.TIME_CD = D.TIME_CD 
        AND C.STIME_CD = D.STIME_CD 
        LEFT JOIN V_TTIM821 E ON A.ENTER_CD = E.ENTER_CD 
        AND A.SABUN = E.SABUN 
        AND A.YMD = E.YMD 
        LEFT JOIN GNT_STATUS G ON A.ENTER_CD = G.ENTER_CD 
        AND A.SABUN = G.SABUN 
        AND A.YMD = G.YMD 
        LEFT JOIN TTIM014 R ON A.ENTER_CD = R.ENTER_CD 
        AND G.GNT_CD = R.GNT_CD
    )
), 
RESULT_DATA AS (
  SELECT 
    T.ENTER_CD, 
    T.SABUN, 
    T.YMD, 
    T.WORK_SHM, 
    BE.NOTE1, 
    BE.NOTE2, 
    BE.NOTE3, 
    CASE WHEN BE.NOTE1 IS NOT NULL THEN TO_CHAR(
      (
        TO_DATE(T.WORK_SHM, 'HH24MI') - TO_NUMBER(
          NVL(BE.NOTE1, '0')/ 24 / 60
        )
      ), 
      'HH24MI'
    ) ELSE NULL END AS BF_WORK_TIME1, 
    CASE WHEN BE.NOTE2 IS NOT NULL THEN TO_CHAR(
      (
        TO_DATE(T.WORK_SHM, 'HH24MI') - TO_NUMBER(
          NVL(BE.NOTE2, '0')/ 24 / 60
        )
      ), 
      'HH24MI'
    ) ELSE NULL END AS BF_WORK_TIME2, 
    CASE WHEN BE.NOTE3 IS NOT NULL THEN TO_CHAR(
      (
        TO_DATE(T.WORK_SHM, 'HH24MI') - TO_NUMBER(
          NVL(BE.NOTE3, '0')/ 24 / 60
        )
      ), 
      'HH24MI'
    ) ELSE NULL END AS BF_WORK_TIME3 
  FROM 
    MAIN_DATA T 
    JOIN BASE_ENTER BE ON T.ENTER_CD = BE.ENTER_CD 
  WHERE 
    NOT EXISTS (
      SELECT 
        1 
      FROM 
        TTIM309 E 
      WHERE 
        T.ENTER_CD = E.ENTER_CD 
        AND T.SABUN = E.SABUN 
        AND (
          SELECT 
            YMD 
          FROM 
            BASE_DATE
        ) BETWEEN E.SDATE 
        AND NVL(E.EDATE, '29991231') 
        AND E.FIX_ST_TIME_YN = 'Y' 
        AND E.FIX_ED_TIME_YN = 'Y'
    ) 
    AND (
      T.WORK_SHM IS NOT NULL 
      AND T.WORK_SHM != '-'
    )
) 
SELECT 
  ENTER_CD, 
  SABUN, 
  YMD, 
  WORK_SHM, 
  BF_WORK_TIME1, 
  BF_WORK_TIME2, 
  BF_WORK_TIME3 
FROM 
  RESULT_DATA COMMIT
