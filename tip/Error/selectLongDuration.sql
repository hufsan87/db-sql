SELECT
    s.sid,
    s.serial#,
    s.event,         -- 현재 세션이 대기 중인 이벤트
    s.wait_class,    -- 대기 이벤트의 분류 (e.g., Application, User I/O, Concurrency)
    s.seconds_in_wait, -- 현재 이벤트에서 대기한 시간 (초)
    s.state,         -- 대기 상태 (e.g., WAITING, WAITED UNTIL SQL*NET message from client)
    s.p1text, s.p1, s.p2text, s.p2, s.p3text, s.p3 -- 대기 이벤트 관련 추가 정보
FROM v$session s
WHERE s.sid = 3826;

--3826	42183	resmgr:cpu quantum	Scheduler	642	WAITED SHORT TIME	consumer group id	3	PDB id	20294	plan index	0

SET LONG 2000000000 -- 긴 텍스트 출력을 위해 설정 (SQL*Plus/SQL Developer에서 필요)
SET PAGESIZE 50000 -- 페이지 사이즈 설정 (SQL*Plus/SQL Developer에서 필요)

SELECT
    s.sid,
    s.serial#,
    s.username,
    s.status,              -- 세션 상태 (ACTIVE, INACTIVE, KILLED 등)
    s.program,             -- 세션을 시작한 프로그램
    s.module,              -- 세션을 시작한 모듈
    s.action,              -- 세션의 현재 액션
    s.client_info,         -- 클라이언트 정보
    s.osuser,              -- 운영체제 사용자
    s.machine,             -- 클라이언트 머신명
    s.sql_id,              -- 현재 실행 중인 SQL의 ID
    s.sql_child_number,    -- SQL의 Child Number (SQL_ID가 같더라도 실행 계획이 다를 수 있음)
    q.sql_text,            -- SQL 텍스트 (길이에 제한이 있을 수 있음)
    q.sql_fulltext,        -- 전체 SQL 텍스트 (CLOB 타입)
    TRUNC(q.elapsed_time / 1000000) AS elapsed_time_sec, -- 총 경과 시간 (초)
    TRUNC(q.cpu_time / 1000000) AS cpu_time_sec,         -- CPU 시간 (초)
    q.disk_reads,          -- 디스크 읽기 횟수
    q.buffer_gets,         -- 논리적 읽기 횟수 (메모리 캐시에서)
    q.executions,          -- 해당 SQL이 실행된 총 횟수
    q.rows_processed,      -- 처리된 총 행 수
    TO_CHAR(q.last_active_time, 'YYYY-MM-DD HH24:MI:SS') AS last_active_time -- 마지막으로 활동한 시간
FROM
    v$session s
JOIN
    v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number
WHERE
    s.status = 'ACTIVE'       -- 활성 상태인 세션만 조회
AND
    s.username IS NOT NULL    -- 시스템 세션 제외
AND
    s.sql_id IS NOT NULL      -- SQL이 실행 중인 세션만
ORDER BY
    elapsed_time_sec DESC;    -- 경과 시간이 긴 순서로 정렬