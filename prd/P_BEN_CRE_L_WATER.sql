create or replace PROCEDURE P_BEN_CRE_L_WATER(
	                      p_sqlcode           OUT VARCHAR2,     -- Error Code
                          p_sqlerrm           OUT VARCHAR2,     -- Error Messages
                          p_enter_cd          IN  VARCHAR2,     -- 회사코드
                          p_search_ym         IN  VARCHAR2,     -- 해당년월
                          p_sabun             IN  VARCHAR2      -- 입력자
)
IS

--  Local Variables
    LV_BIZ_CD             TSYS903.BIZ_CD%TYPE := 'BEN';
    LV_OBJECT_NM          TSYS903.OBJECT_NM%TYPE := 'P_BEN_CRE_L_WATER';
    --LV_USE_SEQ						 TBEN592.USE_SEQ%TYPE;

BEGIN
    p_sqlcode  := NULL;
    p_sqlerrm  := NULL;

    -- 일련번호
    --SELECT  TO_CHAR(SYSDATE,'YYYYMMDD')||LPAD(S_TBEN592.NEXTVAL,5,'0') INTO LV_USE_SEQ FROM DUAL;

	  -- 기존 대상자 정보 삭제
   	/*
   	  추후 에러로인해 생성을 못했을 경우를 대비해
   	  담당자가 수기로 땡겨오기위해 지우는 과정 진행
   	*/

    DELETE FROM TBEN593 B
    WHERE 1=1
	AND EXISTS (
		  SELECT 1
		  FROM TBEN592 A
		  WHERE 1=1
 		  -- A
				AND A.ENTER_CD = P_ENTER_CD
				AND A.BAS_YM  = P_SEARCH_YM
				AND A.RECV_GB = 'L' -- 장기
			-- B
				AND A.ENTER_CD = B.ENTER_CD
				AND A.BAS_YM	 = B.BAS_YM
				AND A.USE_SEQ = B.USE_SEQ
				AND A.SABUN   = B.SABUN
				AND A.USE_GB  = B.USE_GB
				AND A.CHKID = 'PROC'
	);

    DELETE FROM TBEN592 A
	WHERE 1=1
		AND A.ENTER_CD = P_ENTER_CD
		AND A.BAS_YM  = P_SEARCH_YM
		AND A.RECV_GB = 'L' -- 장기
		AND A.CHKID = 'PROC'
   	;

   BEGIN
					/* 생수기본 내역 */
				  INSERT INTO TBEN592
					SELECT
						 A.ENTER_CD
						 , B.SABUN
						 , P_SEARCH_YM  AS BAS_YM
						 , '02'	 							AS USE_GB  -- 유형(택배)
						 , TO_CHAR(SYSDATE,'YYYYMMDD')||LPAD(S_TBEN592.NEXTVAL,5,'0') AS USE_SEQ -- 일련번호			///////////////////////
						 , B.RECV_GB			    AS RECV_GB -- 단기건
						 , p_search_ym||'01' 		AS USE_YMD -- 사용일자는 승인날짜로
						,  A.APPL_SEQ 				AS APPL_SEQ
						 , B.USE_POINT				AS USE_POINT
						 , F_BEN_USE_AMT(A.ENTER_CD, A.APPL_SEQ) AS USE_AMT
						 , B.DELI_AMT 				AS DELI_AMT
						 , P_SEARCH_YM				AS DELI_YM -- 장기건은 월 1일 생성
						 , B.POST_NO         		 AS POST_NO
						 , B.ADDR_NM 			    AS ADDR_NM
						 , B.ADDR_DET_NM 			AS ADDR_DET_NM
						 , ''						AS UP_SEQ		-- 내역 업로드시 사용하는 거기 때문에 필요없음
						 , B.RECV_NAME  			AS RECV_NAME
						 , B.PHONE_NO 				AS PHON_NM
						 , '' AS CAL_DAY
						 , '' AS BAR_CD
						 , '' AS CANC_YMD
						 , '' AS CANC_POINT
						 , '' 	 					AS NOTE1
						 , SYSDATE 					AS CHKDATE
						 , P_SABUN						AS CHKID
					FROM THRI103 A, TBEN594 B
						WHERE 1=1
						-- A
						AND A.ENTER_CD = P_ENTER_CD
						AND A.APPL_STATUS_CD = '99'
						-- B
						AND A.ENTER_CD  = B.ENTER_CD
						AND A.APPL_SEQ  = B.APPL_SEQ
						AND B.RECV_GB   = 'L' -- 단기건
						AND (B.USE_SDATE <= p_search_ym AND p_search_ym < NVL(B.USE_EDATE,'299912'))
						AND F_COM_GET_STATUS_CD(A.ENTER_CD, B.SABUN, p_search_ym||'01') NOT LIKE( 'RA%')
					;			
			
   EXCEPTION
     WHEN OTHERS THEN
        ROLLBACK;
        p_sqlcode := TO_CHAR(sqlcode);
        p_sqlerrm := '복리후생 TBEN592 -> ' || sqlerrm;
        P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
        RETURN;
   END;


	 BEGIN
		/* 생수종류 내역 */
		-- 다음주에와서 생성된 내역가지고 몸체생성로직 만들기
		-- TBEN593 + TBEN594 + THRI103 [APPL_SEQ]
		INSERT INTO TBEN593
		SELECT
			A.ENTER_CD
			, A.SABUN
			, p_search_ym			 	AS BAS_YM
		 	, '02'			 				AS USE_GB  -- 유형(택배)
		 	, A.USE_SEQ			  	AS USE_SEQ
		 	, B.USE_LT_CD  			AS USE_LT_CD
		 	, B.USE_LT_CNT 			AS USE_LT_CNT
			, SYSDATE 	   			AS CHKDATE
			, P_SABUN						AS CHKID
			, A.APPL_SEQ				AS APPL_SEQ
			, 'N' , NULL
		FROM TBEN592 A, TBEN595 B
		WHERE 1=1
			-- A
			AND A.ENTER_CD = P_ENTER_CD
			AND A.BAS_YM   = p_search_ym
			-- B
			AND A.ENTER_CD  = B.ENTER_CD
			AND A.APPL_SEQ  = B.APPL_SEQ
			--
			AND F_COM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, p_search_ym||'01') NOT LIKE( 'RA%')
	  ;
   EXCEPTION
     WHEN OTHERS THEN
        ROLLBACK;
        p_sqlcode := TO_CHAR(sqlcode);
        p_sqlerrm := '복리후생 TBEN593 -> ' || sqlerrm;
        P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
        RETURN;
   END;
   
    /* 20240308 한진정보통신
     * 퇴직자에 대한 생수정기택배신청 종료 처리 
    */
    IF p_enter_cd = 'HX' THEN
        BEGIN
            UPDATE TBEN594 A
               SET A.USE_EDATE  = TO_CHAR(ADD_MONTHS(TO_DATE(p_search_ym, 'YYYYMM'), -1), 'YYYYMM')
                 , A.USE_STS   = 'F' -- 종료
                 , A.CHKDATE = SYSDATE
                 , A.CHKID = P_SABUN
             WHERE A.ENTER_CD = P_ENTER_CD
               AND A.APPL_SEQ IN (SELECT APPL_SEQ
                                    FROM THRI103 SUB1
                                   WHERE SUB1.ENTER_CD = A.ENTER_CD
                                     AND SUB1.APPL_SEQ = A.APPL_SEQ
                                     AND SUB1.APPL_STATUS_CD = '99' --결재완료
                                 )
               AND A.USE_STS = 'M' --유지
               AND A.RECV_GB   = 'L' -- 단기건
               AND (A.USE_SDATE <= p_search_ym AND p_search_ym < NVL(A.USE_EDATE,'299912'))
               AND F_COM_GET_STATUS_CD(A.ENTER_CD, A.SABUN, p_search_ym||'01') LIKE( 'RA%')
            ;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                p_sqlcode := TO_CHAR(sqlcode);
                p_sqlerrm := '복리후생 TBEN594 -> ' || sqlerrm;
                P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'7',P_SQLERRM, 'PROCEDURE');
                RETURN;
        END;
    END IF;

	 ------------------------
	 COMMIT;
	 ------------------------
EXCEPTION
 WHEN OTHERS THEN
    ROLLBACK;
    p_sqlcode := TO_CHAR(sqlcode);
    p_sqlerrm := '복리후생 정기건 배치에러 -> ' || sqlerrm;
    P_COM_SET_LOG(P_ENTER_CD, LV_BIZ_CD, LV_OBJECT_NM,'1',P_SQLERRM, 'PROCEDURE');
    RETURN;
END P_BEN_CRE_L_WATER;