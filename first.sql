select sysdate-1/12 from dual;



DECLARE
    tt varchar2(100):='test한글나라';
BEGIN
    dbms_output.put_line('hello world');

    dbms_output.put_line('tt : '||tt);

    dbms_output.put_line('tt111 : '||tt);

    dbms_output.put_line('tt222 : '||tt);

end;

select * from thrm100 where enter_cd='HX';