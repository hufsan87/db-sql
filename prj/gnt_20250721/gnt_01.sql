--[flow]
--근태코드 - 근무 (근태코드 X)
--        - 휴무 (근태코드 O)



---------------------------------------------------------------------
--HX	2000	20210010	20250620	10000	BASE	N	11010	1	B1	N	N	0930	1230		
--HX	20250620	20210010		0919	1230		25/07/21	20230030		N	N		N	10000				N
--92,94
--대체휴가(오후), 대체휴가(오후1H)
--42
select * 
from ttim120_v 
where 
    enter_cd='HX' 
    and sabun='20210010' 
    and ymd='20250620';
    
select * from TTIM335 where enter_cd='HX' and sabun='20210010' and ymd= '20250620';


SELECT F_TIM_GET_DAY_GNT_CD('HX','20210010','20250620') GNT_CD FROM DUAL;
SELECT F_TIM_GET_DAY_GNT_nm('HX','20210010','20250620') GNT_CD FROM DUAL;
SELECT F_TIM_GET_DAY_GNT_nm2('HX','20210010','20250620') GNT_CD FROM DUAL;


select * from ttim131_v where enter_cd='HX' and sabun='20210010' and sdate='20250620';

SELECT * fROM TTIM111_V  where enter_cd='HX' and sabun='20210010' ;

--근태코드
--GNT_CD, GNT_NM, REQUEST_USE_TYPE(D, AM/PM, H), D:8hr, AM/PM : 4hr, H : MAX_CNT OR MIN_CNT(동일, 단위:hr)
SELECT DISTINCT request_use_type FROM TTIM014 WHERE ENTER_CD='HX';
SELECT * FROM TTIM014 WHERE ENTER_CD='HX' AND request_use_type='H' AND MAX_CNT is null;

SELECT A.ENTER_CD
					     , A.GNT_CD
					     , A.GNT_NM
					     , A.GNT_GUBUN_CD
					     , A.REQUEST_USE_TYPE
					     , A.SEQ
					     , A.HOL_INCL_YN
					     , A.MAX_CNT
					     , A.BASE_CNT
					     , A.MAX_UNIT
					     , A.NOTE1
					     , A.NOTE2
					     , A.NOTE3
					     , A.LANGUAGE_CD
						 , F_COM_GET_LANGUAGE_MAPPING ('HX', 'ttim014', LANGUAGE_CD, '') AS LANGUAGE_NM
						 , A.STD_APPLY_HOUR
						 , A.WORK_CD
						 , A.VACATION_YN -- 발셍휴가사용여부
						 , A.APPL_YN     -- 근태신청여부
						 , A.CAL_APPL_YN     -- 달력신청여부
						 , A.SEARCH_SEQ  -- 신청대상자
						 , ( SELECT SUBSTR( B.SEARCH_DESC , LENGTH('[근태신청]')+1 ) 
						       FROM THRI201 B
						      WHERE B.ENTER_CD   = A.ENTER_CD
						        AND B.SEARCH_SEQ = A.SEARCH_SEQ
						        AND ROWNUM = 1
						    ) AS SEARCH_DESC
						 , DECODE(A.SEARCH_SEQ, NULL, 0, 1 ) AS SEARCH_DTL
						 , A.USE_STD_DATE_CD
						 , A.USE_SDATE_CD
						 , A.USE_EDATE_CD 
						 , A.APPL_LIMIT_DAY
						 , A.OCC_DIV_CNT
					  FROM TTIM014 A
					 WHERE A.ENTER_CD = 'HX'
					 ORDER BY A.SEQ;