SELECT
    s.sid,                -- 세션 ID
    s.serial#,            -- 세션 일련번호
    s.username,           -- 락을 건 사용자
    s.osuser,             -- OS 사용자
    s.program,            -- 실행 프로그램
    o.owner AS object_owner, -- 오브젝트 소유자
    o.object_name,        -- 락이 걸린 테이블/오브젝트 이름
    lo.locked_mode,       -- 락 모드 (숫자 값)
    DECODE(lo.locked_mode,
           0, 'None',
           1, 'Null (NULL)',
           2, 'Row-S (SS)',         -- Row Share
           3, 'Row-X (SX)',         -- Row Exclusive
           4, 'Share (S)',          -- Share
           5, 'S/Row-X (SSX)',      -- Share Row Exclusive
           6, 'Exclusive (X)',      -- Exclusive
           'Unknown') AS locked_mode_desc, -- 락 모드 설명
    s.status,             -- 세션 상태 (ACTIVE, INACTIVE 등)
    s.logon_time          -- 세션 시작 시간
FROM
    v$locked_object lo
JOIN
    v$session s ON lo.session_id = s.sid
JOIN
    dba_objects o ON lo.object_id = o.object_id
WHERE
    o.object_type = 'TABLE' -- 테이블 락만 보고 싶을 경우
ORDER BY
    s.sid, o.object_name;
    
    
    
    SELECT
    s.sid,                -- 세션 ID
    s.serial#,            -- 세션 일련번호
    s.username,           -- 사용자
    s.osuser,             -- OS 사용자
    s.program,            -- 실행 프로그램
    s.status,             -- 세션 상태 (ACTIVE, INACTIVE)
    s.sql_id,             -- 현재 실행 중인 SQL ID
    s.prev_sql_id,        -- 직전에 실행된 SQL ID
    sq.sql_text,          -- 현재 실행 중인 SQL 텍스트
    sq.module,            -- SQL을 실행한 모듈
    sq.action,            -- SQL을 실행한 액션
    sq.last_active_time   -- SQL이 마지막으로 활성 상태였던 시간
FROM
    v$session s
LEFT JOIN
    v$sqlarea sq ON s.sql_id = sq.sql_id
WHERE
    s.sid IN (SELECT session_id FROM v$locked_object) -- 락을 걸고 있는 세션만 필터링
    AND s.status = 'ACTIVE' -- 현재 활성 상태인 세션 (쿼리 실행 중인)
    AND s.type = 'USER'     -- 사용자 세션만 (백그라운드 프로세스 제외)
ORDER BY
    s.sid;
    
    
SELECT
    s.sid,                -- 세션 ID
    s.serial#,            -- 세션 일련번호
    s.username,           -- 사용자
    s.osuser,             -- OS 사용자
    s.program,            -- 실행 프로그램
    s.status,             -- 세션 상태 (ACTIVE, INACTIVE)
    s.sql_id,             -- 현재 실행 중인 SQL ID
    s.prev_sql_id,        -- 직전에 실행된 SQL ID
    sq.sql_fulltext AS full_sql_text, -- 전체 SQL 텍스트 (여기서 변경됨)
    sq.module,            -- SQL을 실행한 모듈
    sq.action,            -- SQL을 실행한 액션
    sq.last_active_time   -- SQL이 마지막으로 활성 상태였던 시간
FROM
    v$session s
LEFT JOIN
    v$sql sq ON s.sql_id = sq.sql_id -- V$SQLAREA 대신 V$SQL 사용 (여기서 변경됨)
WHERE
    s.sid IN (SELECT session_id FROM v$locked_object) -- 락을 걸고 있는 세션만 필터링
    AND s.status = 'ACTIVE' -- 현재 활성 상태인 세션 (쿼리 실행 중인)
    AND s.type = 'USER'     -- 사용자 세션만 (백그라운드 프로세스 제외)
ORDER BY
    s.sid;