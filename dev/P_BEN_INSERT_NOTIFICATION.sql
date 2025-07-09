create or replace PROCEDURE P_BEN_INSERT_NOTIFICATION (
    p_sqlcode            OUT        VARCHAR2,
    p_sqlerrm            OUT        VARCHAR2,
    P_ENTER_CD           IN         VARCHAR2,
    P_SABUN              IN         VARCHAR2   -- 생성자
) IS
    lv_biz_cd        TSYS903.BIZ_CD%TYPE := 'BEN';
    lv_object_nm     TSYS903.OBJECT_NM%TYPE := 'P_BEN_INSERT_NOTIFICATION';

BEGIN
    p_sqlcode   := NULL;
    p_sqlerrm   := NULL;

		BEGIN
            MERGE INTO TSYS920 T
            USING (
                SELECT
                    P_ENTER_CD AS ENTER_CD,
                    P_SABUN AS SABUN,
                    (SELECT NVL(MAX(SEQ), 0) + 1 FROM TSYS920 WHERE ENTER_CD = P_ENTER_CD AND SABUN = P_SABUN) AS SEQ,
                    '노무수령거부' AS N_TITLE,
                    --'금일은 회사에 제출한 미사용 연차유급 휴가 사용 지정일로, 회사에 노무를 제공할 의무가 없으며, 회사에서는 귀하의 노무 수령을 거부함을 알려드립니다.' AS N_CONTENT,
                    '금일은 회사에 제출한 미사용 연차유급휴가 사용 지정일로, 회사에 노무를 제공할 의무가 없으며, 회사에서는 귀하의 노무 수령을 거부함을 알려드립니다.'  AS N_CONTENT,
                    TO_CHAR(SYSDATE, 'YYYYMMDD') AS SDATE,
                    TO_CHAR(SYSDATE, 'YYYYMMDD') AS EDATE,
                    'P_INSERT_NOTI' AS CHKID,
                    SYSDATE AS CHKDATE
                FROM DUAL
            ) S
            ON (
                    T.ENTER_CD = S.ENTER_CD
                AND T.SABUN = S.SABUN
                AND T.SDATE = S.SDATE
                AND T.N_TITLE = S.N_TITLE
            )
            WHEN NOT MATCHED THEN
                INSERT (ENTER_CD, SABUN, SEQ, N_TITLE, N_CONTENT, SDATE, EDATE, CHKID, CHKDATE)
                VALUES (S.ENTER_CD, S.SABUN, S.SEQ, S.N_TITLE, S.N_CONTENT, S.SDATE, S.EDATE, S.CHKID, S.CHKDATE);
		EXCEPTION
	    WHEN OTHERS THEN
		    ROLLBACK;
            p_sqlcode   := TO_CHAR(sqlcode);
            p_sqlerrm   := sqlerrm;
            P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm, '1', sqlerrm, '');
            RETURN;
		END;
  		--COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_sqlcode   := TO_CHAR(sqlcode);
        p_sqlerrm   := sqlerrm;
        P_COM_SET_LOG(P_ENTER_CD, lv_biz_cd, lv_object_nm, '2', sqlerrm, '');
        RETURN;
END;