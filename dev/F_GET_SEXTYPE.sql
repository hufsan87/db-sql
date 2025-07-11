CREATE OR REPLACE FUNCTION F_GET_SEXTYPE (P_HINT IN VARCHAR2) 
RETURN VARCHAR2 IS
	lv_sextype VARCHAR2(100) := '';
BEGIN
    BEGIN
        SELECT
        CASE P_HINT
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
    EXCEPTION
        WHEN OTHERS THEN
       RETURN sqlerrm;
    END;

    RETURN lv_sextype;
END;