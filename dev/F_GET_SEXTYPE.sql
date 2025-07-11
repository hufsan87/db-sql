CREATE OR REPLACE FUNCTION F_GET_SEXTYPE (P_ENTER_CD IN VARCHAR2, P_FAMRES IN VARCHAR2) 
RETURN VARCHAR2 IS
    lv_hint VARCHAR2(1) := '';
	lv_sextype VARCHAR2(100) := '';
BEGIN
    BEGIN
        IF P_ENTER_CD IS NULL OR P_FAMRES IS NULL THEN RETURN ''; END IF;
        
        SELECT SUBSTR(NVL(CRYPTIT.DECRYPT(P_FAMRES, P_ENTER_CD),'0'),7,1) INTO lv_hint FROM DUAL;
        
        IF lv_hint IS NOT NULL THEN
            SELECT
            CASE lv_hint
                WHEN '1' THEN '1' --남성
                WHEN '3' THEN '1' --남성
                WHEN '2' THEN '2' --여성
                WHEN '4' THEN '2' --여성
                WHEN '5' THEN '1' --외국인 남성
                WHEN '7' THEN '1' --외국인 남성
                WHEN '6' THEN '2' --외국인 여성
                WHEN '8' THEN '2' --외국인 여성
                ELSE ''
            END INTO lv_sextype
            FROM DUAL;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
       RETURN sqlerrm;
    END;

    RETURN lv_sextype;
END;