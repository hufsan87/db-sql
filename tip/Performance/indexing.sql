--index 활용도 확인
SELECT
    obj.OBJECT_NAME AS INDEX_NAME,
    stat.STATISTIC_NAME,
    stat.VALUE
FROM
    V$SEGMENT_STATISTICS stat
JOIN
    ALL_OBJECTS obj ON stat.OBJ# = obj.OBJECT_ID -- 여기서 stat.OBJ# 와 obj.OBJECT_ID를 조인
                        AND stat.OWNER = obj.OWNER -- OWNER 조건 추가 (중요)
WHERE
    obj.OBJECT_TYPE = 'INDEX'
    AND obj.OBJECT_NAME = 'IX_TTIM131_OPTIMIZED'
    AND stat.STATISTIC_NAME IN ('logical reads', 'physical reads', 'db block gets', 'consistent gets', 'segment scans')
ORDER BY
    stat.STATISTIC_NAME;

--INDEX 확인
SELECT
    idx.INDEX_NAME,
    idx.INDEX_TYPE,
    idx.TABLE_NAME,
    col.COLUMN_NAME,
    col.COLUMN_POSITION,
    idx.UNIQUENESS
FROM
    ALL_INDEXES idx
JOIN
    ALL_IND_COLUMNS col ON idx.OWNER = col.INDEX_OWNER
                        AND idx.INDEX_NAME = col.INDEX_NAME
                        AND idx.TABLE_NAME = col.TABLE_NAME
WHERE
    idx.TABLE_NAME = 'TTIM131'
    -- AND idx.OWNER = 'YOUR_SCHEMA_NAME' -- 특정 스키마에 한정하려면 주석 해제
ORDER BY
    idx.INDEX_NAME,
    col.COLUMN_POSITION;