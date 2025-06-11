-- KS, 3명 추가 FINAL, 연말정산 ENTER_CD LIKE 적용 (예 : 'KS_23') TYEA993
/*
Trigger		                        DEV                     PRD	
SKIP_SBN_TRGR_NM (SKIP_SBN_TRGR)	SBN_CHANGE_EXCLUDE_TAB	SBN_CHANGE_EXCLUDE_TAB	제외 테이블
		                            SBN_CHANGE_LIST	        SBN_CHANGE_LIST	사번 변경 대상자
		                            SBN_CHANGE_LIST_BK	    SBN_CHANGE_LIST_BK	변경완료
                                    SBN_CHANGE_LOG	        SBN_CHANGE_LOG	사번변경 업데이트 결과 로그
                                    SBN_CHANGE_NEW_EXIST		
                                    SBN_CHANGE_TABLES_CHG_SBN		
                                    SBN_CHANGE_TRIGGERS		
*/
DECLARE
    v_sql varchar2(4000);
    v_sql2 varchar2(4000);
    v_sql3 varchar2(4000);
    v_count number;
    v_count2 number;
    v_count3 number;
    v_sabun varchar2(10) := '2000913';
    v_new_sabun varchar2(10) := '1801991';
    v_rowcount number;
    
  CURSOR C2 IS
    SELECT SBN, CHG_SBN
    FROM SBN_CHANGE_LIST
    WHERE 1=1
      AND ENTER_CD='KS'
      AND CHANGE_STATUS_CD='Y'
    ORDER BY SBN
    --FETCH FIRST 1 ROWS ONLY
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
                 'TBEN551_BACK_240104',
                 'THRM111_BE'
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
            --v_sql2 := 'select count(*) cnt from user_triggers where table_name = '''||c1_rec.tname||''' AND TRIGGERING_EVENT LIKE ''%UPDATE%'' ';
            --execute immediate v_sql2 into v_count2;
            --if v_count2 > 0 then
                --dbms_output.put_line('select table_name, trigger_name from user_triggers where table_name='''||c1_rec.tname||''' union');
                --INSERT INTO SBN_CHANGE_TRIGGERS(trgr_tab) values (c1_rec.tname);
            --end if;


------------------------------------------------------------------------------------------------------
        --dbms_output.put_line('select count(*) cnt  from '|| c1_rec.tname|| ' where enter_cd=''KS'' AND '||C1_REC.cname||'=''test128''; ' );
-- CHKID가 있는 TABLE의 RECORD 건수 확인용
        --v_sql := 'select count(*) cnt  from '|| c1_rec.tname|| ' where enter_cd=''KS'' ' ;
-- TABLE의 RECORD 건수 확인용
--        v_sql := 'select count(*) cnt  from '|| c1_rec.tname|| ' where enter_cd=''KS'' ' ;
        
--[0,1,2-1] 구 사번 데이터 확인 (실 업데이트용)
        v_sql := 'select count(*) cnt  from '|| c1_rec.tname|| ' where enter_cd LIKE ''KS%'' AND '||C1_REC.cname||'='''||C2_REC.SBN||''' ' ;
--[2-2] 신 사번 데이터 확인 (충돌 확인, 백업)
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
            --INSERT INTO sbn_change_tables_chg_sbn VALUES(C1_REC.TNAME, C1_REC.CNAME);
            --dbms_output.put_line('select '''||c1_rec.tname||''','''||c1_rec.cname||''','''||C2_REC.SBN||''', '''||C2_REC.CHG_SBN||''', COUNT(*) CNT from '||c1_rec.tname||' where enter_cd=''KS'' and '||c1_rec.cname||'='''||C2_REC.CHG_SBN||''' union ');
--[2-3] UPDATE문 생성            
            --DBMS_OUTPUT.PUT_LINE('UPDATE '||c1_rec.tname||' SET '||c1_rec.cname||'='''||C2_REC.CHG_SBN||''' WHERE ENTER_CD=''KS'' AND '||c1_rec.cname||'='''||C2_REC.SBN||''';');
            
            

            --[[[실제 update]]]
            v_sql3 := 'UPDATE '||c1_rec.tname||' SET '||c1_rec.cname||'='''||C2_REC.CHG_SBN||''' WHERE ENTER_CD LIKE ''KS%'' AND '||c1_rec.cname||'='''||C2_REC.SBN||''' ';
            execute immediate v_sql3;
            if SQL%ROWCOUNT > 0 then
              v_rowcount := SQL%ROWCOUNT;
              --DBMS_OUTPUT.PUT_LINE('UPDATED DONE '||c1_rec.tname||','||C2_REC.SBN||',=>'||C2_REC.CHG_SBN||','||SQL%ROWCOUNT||')');
              INSERT INTO SBN_CHANGE_LOG(RESULT_LOG, CHKDATE) VALUES ('UPDATED '||c1_rec.tname||' : '||C2_REC.SBN||' -> '||C2_REC.CHG_SBN||' (cnt='||v_rowcount||')', SYSDATE);
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