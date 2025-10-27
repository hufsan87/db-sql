select b.use_seq,a.*
from tben592 a, tben593 b
where a.enter_cd='HT'
and a.enter_cd=b.enter_cd
and a.sabun = '2241002'
and a.sabun=b.sabun
and a.deli_ym='202510'
and a.use_gb='02'
and a.use_gb=b.use_gb
and b.use_lt_cnt<>0
;










--TBEN592 만들기
-- USE_SEQ : SELECT TO_CHAR(SYSDATE,'YYYYMMDD')||LPAD(S_TBEN592.NEXTVAL,5,'0') INTO LV_USE_SEQ FROM DUAL;
SELECT '20250905'||LPAD(S_TBEN592.NEXTVAL,5,'0') FROM DUAL;

SELECT * fROM THRI103 WHERE APPL_SEQ='20250905000354';

COMMIT;

INSERT INTO TBEN592 VALUES(
'HT',
'2241002',
'202509',
'02',
'2025090500004',
'S',
'20250905',
'20250905000354',
1,
10400,
4200,
'202510',
'14685',
'경기도 부천시 소사구 부광로41번길 8-1 (괴안동)',
'안쪽빌라 202호',
'',
'용윤경',
'01041392619',
'',
'',
'',
'',
'',
SYSDATE,
'ADMIN'
);


insert into tben593 VALUES(
'HT',
'2241002',
'202509',
'02',
'2025090500004',
'03',
1,
SYSDATE,
'ADMIN',
'20250905000354',
'N',''
);

COMMIT;
DESC TBEN592;

select * from tben592
where enter_cd='HT' 
and RECV_gb='S';

select * from tben592 
where 
1=1
and enter_cd='HT'
and recv_gb='S';
--and sabun='2241002' 

update tben591
set use_amt=10400
where sabun='2241002' and bas_ym='202509';

commit;
--[한진관광] 단기택배, 급여작업
--현재(한정통,한진관광) : 단기택배 : 생수는 사용월에 일괄 과세(사용 무관), 택배 : 사용월(익월) 과세
--변경(한진관광) : 단기택배 : 생수 사용월을 택배월과 동일하게 과세

--[한진관광] 생성포인트 미사용 시, 소멸로직으로 처리 필요


--[1]
update tben591
set use_amt=0
where sabun='2241002' and bas_ym='202509'
and use_amt='10400';
--[2]
update tben592
set bas_ym='202510',use_ymd='202510'
where sabun='2241002' and bas_ym='202509' and use_ymd='20250905' and appl_seq='20250905000354';




select * from tben591 where sabun='2241002' order by bas_ym desc; --생수대상자(이월포인트, 생성포인트,지원금액 BEF_POINT,USE_POINT, USE_AMT)
select * from tben592 where sabun='2241002' order by bas_ym desc,chkdate desc; --신청서(직접수령/택배/모바일 USE_GB 01 02 03) [이용내역]
    SELECT DISTINCT USE_GB FROM TBEN592; --00 01 02 03
    SELECT * FROM TBEN592 WHERE USE_GB='00' ORDER BY BAS_YM DESC;-- 이관자료, 무시
    SELECT * fROM TBEN592 WHERE APPL_SEQ='20250908000651';
select * from tben593 where sabun='2241002' order by bas_ym desc; --신청서 상세(용량별) [이용내역]
    select * from tben593 where use_gb='02' order by chkdate desc;
select * from tben594 where sabun='2241002' order by appl_seq desc;--택배신청 (장기/단기 L/S) 
    select * from tben594 where recv_gb='S' ORDER BY CHKDATE DESC;
select * from tben595 where sabun='2241002' order by appl_seq desc; --택배신청 상세(용량별)
