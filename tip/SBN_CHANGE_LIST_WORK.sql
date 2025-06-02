--(2025.06.02)
--commit;
----rollback;
----update sbn_change_list set sbn_change_list.change_status_cd='';
--update sbn_change_list set sbn_change_list.change_status_cd='D' where  enter_cd='HG';
/*
update sbn_change_list set sbn_change_list.change_status_cd='D' where  enter_cd='KS' and sbn in (
'2001824',
'2000913',
'1902374',
'1902611',
'1903048',
'1950052',
'2050042',
'2050053',
'2100036');
*/
--
--select * from sbn_change_list where enter_cd='KS' and sbn_change_list.change_status_cd ='D';
--select * from sbn_change_list where sbn_change_list.change_status_cd ='D';
--update sbn_change_list set sbn_change_list.change_status_cd='Y' where enter_cd='KS' and sbn_change_list.change_status_cd is null;
--commit;
---------------------------------------------------------------------------------------------------
select * from sbn_change_list where sbn_change_list.change_status_cd='Y';
----------------------------------------------------------------------------------------------------

/*
[1] TRIGGER DISABLE
[2] 중복데이터 확인 & 백업 & 삭제
[3] 업데이트 문 : 1건, SBN_CHANGE_LIST.CHANGE_STATUS_CD = 'Y' 이용
[4] 업데이트 문 : 8건, SBN_CHANGE_LIST.CHANGE_STATUS_CD = 'Y' 이용
[5] COMMIT

*/
/*
(PRECOND)
  1) CHID 컬럼 제외
  
(TABLE)
SBN_CHANGE_LIST : 현재 및 변경 후 사번 대상자 테이블
SBN_CHANGE_EXCLUDE_TAB : DATA 0건으로 제외대상 테이블들
SBN_CHANGE_NEW_EXIST : 변경 후 사번으로 데이터가 있는 테이블들

(FUNCTION)
SKIP_SBN_TRGR 트리거에 삽입 해당 트리거 SKIP 하도록
SKIP_SBN_TRGR_NM 현재사번 기준, 트리거에 삽입하여, 해당 트리거에서 해당 사번 SKIP 하는지 확인용

(TRIGGER) - 9명 대상일때, 대상자에 따라 트리거 조회 해야 함.
TBEN593	TRG_BEN_593
TBEN593	TRG_HRI_103
TSYS305	TRG_TSYS305_PW_CHG
TSYS313	TRG_SYS_313
TTIM301	TRG_TIM_405
TTIM337	TRG_TIM_337
TTIM521	TRG_TIM_521
TTIM615	TRG_TIM615
TTIM616	TRG_TIM616
TTIM720	TRG_TTIM720_BF

*/
SELECT * FROM SBN_CHANGE_NEW_EXIST ;
SELECT * FROM USER_OBJECTS
WHERE OBJECT_NAME LIKE 'SKIP%';

select * from tab where tname like '%TRGR';
select * from sbn_change_exclude_tab;
select count(*) from sbn_change_exclude_tab;



--CHKID컬럼이 있는 TALBE 중, RECORD 0인 TABLE 목록 - 제외대상 추출용
--CREATE TABLE SBN_CHANGE_EXCLUDE_TAB(
--TAB_NAME VARCHAR2(30));

-- RECORD 0인 TABLE 목록 - 제외대상 추출용

--chg_sbn으로 데이터 있는 table
--create table sbn_change_new_exist(tab_name varchar2(30),sbn varchar2(13), chg_sbn varchar2(13));

--https://docs.google.com/spreadsheets/d/1ftz9dSxtRuqllAXbi2IfM2uIpc4xiHW8LwPAWI4smkg/edit?gid=11355697#gid=11355697
/*
6/2(월) 오전에
구사번 데이터 건 수 확인하기
데이터 클린징
9명에 대한 개발사이트, 업데이트 진행
*/

SET SERVEROUTPUT ON;
DECLARE
    v_sql varchar2(4000);
    v_sql2 varchar2(4000);
    v_sql3 varchar2(4000);
    v_count number;
    v_count2 number;
    v_count3 number;
    v_sabun varchar2(10) := '2000913';
    v_new_sabun varchar2(10) := '1801991';
    
  CURSOR C2 IS
    SELECT SBN, CHG_SBN
    FROM SBN_CHANGE_LIST
    WHERE 1=1
      AND ENTER_CD='KS'
      AND CHANGE_STATUS_CD='Y'
      --AND ROWNUM < 2
    ORDER BY SBN
      ;
      
   CURSOR C1 is
      WITH candidate_tables AS (
        SELECT DISTINCT
          utc.table_name
        FROM
          user_tables ut
        JOIN
          user_tab_columns utc
            ON utc.table_name = ut.table_name
        WHERE
          -- only VARCHAR2 columns
          utc.data_type = 'VARCHAR2'
          -- must also have an ENTER_CD column
          AND EXISTS (
            SELECT 1
            FROM user_tab_columns x
            WHERE x.table_name  = utc.table_name
              AND x.column_name = 'ENTER_CD'
          )
          -- table‐name filters
          AND utc.table_name NOT IN (select tab_name from sbn_change_exclude_tab)
          AND utc.table_name NOT LIKE 'CONV%'
          AND (
               (LENGTH(utc.table_name) = 7 AND
                utc.table_name NOT IN ('ZTST001','ZTST002','THRM001','THRM005') AND
                utc.table_name NOT LIKE 'TEIS%'
               )
            OR utc.table_name IN (
                 'INT_OLIVE', 'INT_OLIVE_LIST',
                 'INT_THRM151', 'INT_TTIM301_ETC',
                 'TBEN551_BACK_240104'
              )
          )
          -- some hint of “SABUN” in name or comments
          AND (
            utc.column_name LIKE '%SABUN%'
            OR EXISTS (
              SELECT 1
              FROM user_col_comments ucc
              WHERE ucc.table_name = utc.table_name
                AND (
                     ucc.column_name LIKE '%SABUN%'
                  OR ucc.comments    LIKE '%사번%'
                  OR ucc.comments    LIKE '%사원번호%'
                )
            )
          )
      )
      SELECT
          t.table_name AS tname,
          t.comments   AS tcmt,
          c.column_name AS cname,
          c.comments    AS ccmt
      FROM
          candidate_tables ct
        JOIN user_tab_comments   t
          ON t.table_name = ct.table_name
        JOIN user_col_comments   c
          ON c.table_name  = ct.table_name
         AND (
              c.column_name LIKE '%SABUN%'
           OR c.comments    LIKE '%사번%'
           OR c.comments    LIKE '%사원번호%'
         )
      ORDER BY
          t.table_name;

BEGIN
  FOR C2_REC IN C2 LOOP
    --DBMS_OUTPUT.PUT_LINE('SABUN : '||C2_REC.SBN||'=>'||C2_REC.CHG_SBN);
    FOR C1_REC IN C1 LOOP
    --[0]참고, SABUN 이외 테이블 및 컬럼명
            --IF c1_rec.cname != 'SABUN' THEN
                --DBMS_OUTPUT.PUT_LINE(c1_rec.tname||' - '||c1_rec.cname);
            --END IF;
            
--[1]TRIGGER 확인
/*            v_sql2 := 'select count(*) cnt from user_triggers where table_name = '''||c1_rec.tname||''' AND TRIGGERING_EVENT LIKE ''%UPDATE%'' ';
            execute immediate v_sql2 into v_count2;
            if v_count2 > 0 then
                dbms_output.put_line('select table_name, trigger_name from user_triggers where table_name='''||c1_rec.tname||''' union');
            end if;
*/

------------------------------------------------------------------------------------------------------
        --dbms_output.put_line('select count(*) cnt  from '|| c1_rec.tname|| ' where enter_cd=''KS'' AND '||C1_REC.cname||'=''test128''; ' );
-- CHKID가 있는 TABLE의 RECORD 건수 확인용
        --v_sql := 'select count(*) cnt  from '|| c1_rec.tname|| ' where enter_cd=''KS'' ' ;
-- TABLE의 RECORD 건수 확인용
--        v_sql := 'select count(*) cnt  from '|| c1_rec.tname|| ' where enter_cd=''KS'' ' ;
        
--[0,1,2-1] 구 사번 데이터 확인
        v_sql := 'select count(*) cnt  from '|| c1_rec.tname|| ' where enter_cd=''KS'' AND '||C1_REC.cname||'='''||C2_REC.SBN||''' ' ;
--[2-2] 신 사번 데이터 확인
        --v_sql := 'select count(*) cnt  from '|| c1_rec.tname|| ' where enter_cd=''KS'' AND '||C1_REC.cname||'='''||C2_REC.CHG_SBN||''' ' ;

        execute immediate  v_sql into v_count;
        
-- CHKID가 있는 TABLE의 RECORD 건수 확인용
--        if v_count=0 then
--          dbms_output.put_line(c1_rec.tname);
--          INSERT INTO SBN_CHANGE_EXCLUDE_TAB VALUES (c1_rec.tname);
--        end if;
        
        if v_count > 0 then
            --dbms_output.put_line('select '''||c1_rec.tname||''','''||c1_rec.cname||''','''||C2_REC.SBN||''', COUNT(*) CNT from '||c1_rec.tname||' where enter_cd=''KS'' and '||c1_rec.cname||'='''||C2_REC.CHG_SBN||''' union ');
            
            --FINAL
--[2] UPDATE문 생성
--[2-1] 구 사번
            --dbms_output.put_line('select '''||c1_rec.tname||''','''||c1_rec.cname||''','''||C2_REC.SBN||''', COUNT(*) CNT from '||c1_rec.tname||' where enter_cd=''KS'' and '||c1_rec.cname||'='''||C2_REC.SBN||''' union ');
--[2-2] 신 사번
            --dbms_output.put_line('select '''||c1_rec.tname||''','''||c1_rec.cname||''','''||C2_REC.CHG_SBN||''', COUNT(*) CNT from '||c1_rec.tname||' where enter_cd=''KS'' and '||c1_rec.cname||'='''||C2_REC.CHG_SBN||''' union ');
            --dbms_output.put_line('select '''||c1_rec.tname||''','''||c1_rec.cname||''','''||C2_REC.SBN||''', '''||C2_REC.CHG_SBN||''', COUNT(*) CNT from '||c1_rec.tname||' where enter_cd=''KS'' and '||c1_rec.cname||'='''||C2_REC.CHG_SBN||''' union ');
--[2-3] UPDATE문 생성            
            --DBMS_OUTPUT.PUT_LINE('UPDATE '||c1_rec.tname||' SET '||c1_rec.cname||'='''||C2_REC.CHG_SBN||''' WHERE ENTER_CD=''KS'' AND '||c1_rec.cname||'='''||C2_REC.SBN||''';');
            --[[[실제 update]]]
            v_sql3 := 'UPDATE '||c1_rec.tname||' SET '||c1_rec.cname||'='''||C2_REC.CHG_SBN||''' WHERE ENTER_CD=''KS'' AND '||c1_rec.cname||'='''||C2_REC.SBN||''' ';
            execute immediate v_sql3;
            if SQL%ROWCOUNT > 0 then
              DBMS_OUTPUT.PUT_LINE('UPDATED DONE '||c1_rec.tname||','||C2_REC.SBN||',=>'||C2_REC.CHG_SBN||','||SQL%ROWCOUNT||')');
            end if;
        end if;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

        
--        if v_count = 0  then
--        -- TABLE의 RECORD 건수 확인용
--            --dbms_output.put_line('select COUNT(*) CNT from '||c1_rec.tname||' where enter_cd=''KS'' union ');
--          dbms_output.put_line(c1_rec.tname);
--          INSERT INTO SBN_CHANGE_EXCLUDE_TAB VALUES (c1_rec.tname);
--           
--        end if;
    END LOOP;
  END LOOP;
END;


