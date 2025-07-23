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