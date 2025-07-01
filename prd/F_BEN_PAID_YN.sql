create or replace FUNCTION "F_BEN_PAID_YN" (
      P_ENTER_CD      IN VARCHAR2
    , P_SABUN         IN VARCHAR2
    , P_PAY_YM        IN VARCHAR2
    , P_ELEMENT_CD    IN VARCHAR2
) RETURN VARCHAR2
IS
BEGIN
/*****************************************************************************/
/*    급여공제 여부 체크 (TCPN217, 급여미공제내역)                               */
/*    항목코드 ELEMENT_CD, 경조금  : D160                                      */
/*                                                                           */
/*****************************************************************************/
    FOR rec IN (
        SELECT 1
        FROM TCPN217
        WHERE ENTER_CD = P_ENTER_CD
          AND SABUN = P_SABUN
          AND SUBSTR(PAY_ACTION_CD, 1, 6) = REPLACE(P_PAY_YM,'-','')
          AND ELEMENT_CD = P_ELEMENT_CD
          AND DED_MON = CHK_MON -- 공제금액=공제잔여금액=>미공제 여부
    ) LOOP
        RETURN 'N'; -- 미공제
    END LOOP;

    RETURN 'Y'; -- 공제
END;