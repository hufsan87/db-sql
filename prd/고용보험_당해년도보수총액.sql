SELECT (                       
        SELECT B.CURR_TOT_MON AS MON
          FROM TCPN811 A, TCPN841 B, THRM100 C
         WHERE A.ENTER_CD = @@회사코드@@
           AND A.SABUN = @@사번@@
           AND A.ADJUST_TYPE = '3'
           AND A.ENTER_CD = B.ENTER_CD
           AND A.WORK_YY = B.WORK_YY
           AND A.ADJUST_TYPE = B.ADJUST_TYPE
           AND A.SABUN = B.SABUN
           AND A.ENTER_CD = C.ENTER_CD
           AND A.SABUN = C.SABUN
           AND SUBSTR(NVL(RET_YMD, '29991231'),0,4) = A.WORK_YY
        UNION ALL
        SELECT SUM(NVL(A.DATA_1,0)+NVL(A.DATA_2,0)+NVL(A.DATA_3,0)+NVL(A.DATA_4,0)+NVL(A.DATA_5,0)+NVL(A.DATA_6,0)) AS MON
          FROM TYEA003 A, THRM100 B
         WHERE A.ENTER_CD = B.ENTER_CD
           AND A.SABUN = B.SABUN
           AND A.ENTER_CD = @@회사코드@@
           AND A.WORK_YY = SUBSTR(NVL(B.RET_YMD, '29991231'),0,4)
           AND A.SABUN = @@사번@@
           AND A.ADJUST_TYPE = '3'
     ) FROM DUAL