<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ include file="/WEB-INF/jsp/common/include/taglibs.jsp"%>
<%@ page import="org.anyframe.util.DateUtil" %>
<!DOCTYPE html> <html class="hidden"><head> <title>개인별주근무현황</title>
 <%@ include file="/WEB-INF/jsp/common/include/meta.jsp"%><%@ include file="/WEB-INF/jsp/common/include/jqueryScript.jsp"%>
 <%@ include file="/WEB-INF/jsp/common/include/ibSheetScript.jsp"%>


 <style type="text/css">
     html, body { margin: 0; padding: 0; height: 100%; overflow: hidden; }
     .filter-area { padding: 10px; background-color: #f0f0f0; border-bottom: 1px solid #ddd; }

     .ibsheet_grid_cell_text { text-align: center; }
     /* IBSheet 셀 배경색은 SetCellBackColor 함수로 직접 적용됩니다. */
 </style>
</head>
<body class="bodywrap">
<div class="wrapper">
 <form name="sheet1Form" id="sheet1Form" method="post">
  <input type="hidden" id="oldSearchYm" name="oldSearchYm" />
  <input type="hidden" id="oldSearchOrgCd" name="oldSearchOrgCd" />
  <input type="hidden" id="multiManageCd" name="multiManageCd" value="" />
  <div class="sheet_search outer">
   <table>
    <tr>
     <td>
      <span>기준년월</span>
      <input type="text" id="searchYm" name="searchYm" class="date2 required" value="${curSysYyyyMMHyphen}" readonly/>
     </td>
     <td>
      <span>소속</span>
      <select id="searchOrgCd" name="searchOrgCd"></select>
     </td>
     <td>
      <span>사원구분</span>
      <select id="manageCd" name="manageCd" multiple=""> </select>
     </td>
     <td>
      <span>직급</span>
      <select id="multiJikgubCd" name="multiJikgubCd" multiple></select>
      <input type="hidden" id="searchJikgubCd" name="searchJikgubCd" value=""/>
     </td>
     <td>
      <a href="javascript:doAction1('Search')" class="button">조회</a>
     </td>
    </tr>
   </table>
  </div>
 </form>
 <div class="inner">
  <div class="sheet_title">
   <ul>
    <li class="txt">부서별월근태현황</li>
    <li class="btn">
     <a href="javascript:doAction1('Down2Excel');" class="basic authR">다운로드</a>
    </li>
   </ul>
  </div>
 </div>



 <script type="text/javascript"> createIBSheet("sheet1", "100%", "100%", "${ssnLocaleCd}"); </script>

 <script type="text/javascript">
  var sheet1; // 전역 IBSheet 객체 선언 (createIBSheet에 의해 할당될 이름)
  var gPRow = "";
  var pGubun = "";
  var titleList; // 기존 titleList 변수는 유지하나, 시간대별 컬럼 정의에는 사용되지 않음

  $(function() {
   $("#searchYm").datepicker2({
    ymonly: true,
    onReturn: function() {
     $("#searchOrgCd").val($("#oldSearchOrgCd").val());
     setOrgCombo();
     init_sheet1(); // 시트 구조 재구성 및 초기 데이터 로드
    }
   });

   $("#searchWorkType, #searchOrgCd").bind("change", function(e) {
    //doAction1("Search");
   });

   // 공통코드 조회 (기존 로직 유지)
   var grpCds = "'H20010','H10050'";
   var codeLists = convCodes(ajaxCall("${ctx}/CommonCode.do?cmd=commonCodeLists&useYn=Y", "grpCd=" + grpCds, false).codeList, "");
   $("#multiJikgubCd").html(codeLists["H20010"][2]);
   $("#searchWorkType").html("<option value=''>전체</option>" + codeLists["H10050"][2]);

   var manageCd = convCode(codeList("${ctx}/CommonCode.do?cmd=commonCodeList&useYn=Y", "H10030"), "");
   $("#manageCd").html(manageCd[2]);
   $("#manageCd").select2({ placeholder: " 전체"});

   $("#multiJikgubCd").select2({
    placeholder: "전체",
    maximumSelectionSize: 100
   });
   $("#multiJikgubCd").bind("change", function(e) {
    $("#searchJikgubCd").val(($("#multiJikgubCd").val() == null ? "" : getMultiSelect($("#multiJikgubCd").val())));
    //doAction1("Search");
   });

   setOrgCombo();
   init_sheet1(); // 페이지 로드 시 시트 초기화 시작
  });

  function setOrgCombo(){
   var orgCd = convCode(ajaxCall("${ctx}/OrgMonthWorkSta.do?cmd=getOrgMonthWorkStaOrgList", "searchYmd=" + $("#searchYm").val(), false).DATA, "전체");
   $("#searchOrgCd").html(orgCd[2]);
  }

  // Sheet 초기화 및 컬럼 정의
  function init_sheet1(){
   // 기존 init_sheet1()의 if 조건 제거: 항상 최신 컬럼 구조로 초기화
   // if( $("#oldSearchYm").val() == $("#searchYm").val() ) return;

   if (sheet1) { // 시트가 이미 생성되어 있다면 리셋
    sheet1.Reset();
   }

   // 월별 일별 근태 현황 헤더의 첫 번째 부분 (예: [2025년 07월] 일별 근태 현황)
   var str = "[ " +($("#searchYm").val()).substring(0,4)+"년 " + ($("#searchYm").val()).substring(5,7)+"월 ] 일별 근태 현황|";
   var initdata1 = {};
   // FrozenCol을 6으로 조정 (No, 세부내역, 본부, 부서, 사번, 성명)
   initdata1.Cfg = {SearchMode:2,Page:22,MergeSheet:5,FrozenCol:6,FrozenColRight:0,HeaderMerge:1};
   initdata1.HeaderMode = {Sort:1,ColMove:1,ColResize:1,HeaderCheck:1};

   initdata1.Cols = [];
   var v = 0 ;
   initdata1.Cols[v++] = {Header:"No|No", Type:"${sNoTy}", Hidden:Number("${sNoHdn}"), Width:"${sNoWdt}", Align:"Center", ColMerge:0, SaveName:"sNo", Sort:0 };
   initdata1.Cols[v++] = {Header:"세부\n내역|세부\n내역", Type:"Image", Hidden:0, Width:45, Align:"Center", ColMerge:0, SaveName:"detail", Edit:0, Sort:0, Cursor:"Pointer" };
   initdata1.Cols[v++] = {Header:"본부|본부", Type:"Text", Hidden:1, Width:120, Align:"Left", ColMerge:0, SaveName:"pOrgNm", KeyField:0, Edit:0};
   initdata1.Cols[v++] = {Header:"부서|부서", Type:"Text", Hidden:0, Width:120, Align:"Left", ColMerge:0, SaveName:"orgNm", KeyField:0, Edit:0};
   if("${ssnEnterCd}" == "KS"){
    initdata1.Cols[v++] = {Header:"근무조|근무조", Type:"Text", Hidden:0, Width:80, Align:"Left", ColMerge:0, SaveName:"workOrgCd", KeyField:0, Edit:0};
   }
   initdata1.Cols[v++] = {Header:"사번|사번", Type:"Text", Hidden:("${ssnEnterCd}" === "KS"? 0 : 1), Width:70, Align:"Center", ColMerge:0, SaveName:"sabun", KeyField:0, Edit:0};
   initdata1.Cols[v++] = {Header:"성명|성명", Type:"Text", Hidden:0, Width:70, Align:"Center", ColMerge:0, SaveName:"name", KeyField:0, UpdateEdit:0, InsertEdit:1};
   initdata1.Cols[v++] = {Header:"직급|직급", Type:"Text", Hidden:Number("${jgHdn}"), Width:60, Align:"Center", ColMerge:0, SaveName:"jikgubNm", KeyField:0, Edit:0};

   initdata1.Cols[v++] = {Header:"입사일자|입사일자", Type:"Date", Hidden:1, Width:80, Align:"Center", ColMerge:0, SaveName:"empYmd", KeyField:0, Format:"Ymd", Edit:0};
   initdata1.Cols[v++] = {Header:"입사일자|입사일자", Type:"Text", Hidden:1, Width:80, Align:"Center", ColMerge:0, SaveName:"ym", KeyField:0, Format:"", Edit:0};

   // --- 시간대별 근무 현황 컬럼 (0시 ~ 23시 30분, 총 48개 컬럼) ---
   var hourWidth = 25; // 30분 단위 컬럼의 너비

   for (var i = 0; i < 24; i++) {
    // 0분 단위 컬럼
    initdata1.Cols[v++] = {
     Header: (i + "시") + "|00분", // 상단 헤더: "0시", 하단 헤더: "00분"
     Type: "Text",
     Width: hourWidth,
     Align: "Center",
     ColMerge: 0,
     SaveName: "Hour_" + i + "_0",
     Edit: 0
    };

    // 30분 단위 컬럼
    initdata1.Cols[v++] = {
     Header: "|30분", // 상단 헤더: 비워둠 (이전 컬럼과 병합), 하단 헤더: "30분"
     Type: "Text",
     Width: hourWidth,
     Align: "Center",
     ColMerge: 0,
     SaveName: "Hour_" + i + "_30",
     Edit: 0
    };
   }

   // --- 기존의 총계 컬럼들 (수정된 헤더 형태 적용) ---
   initdata1.Cols[v++] = {Header:"근무\n일수|근무\n일수", Type:"AutoSum", Hidden:("${ssnEnterCd}" === "KS"? 0 : 1), Width:60, Align:"Center", ColMerge:0, SaveName:"cntDays", Sort:0 };
   initdata1.Cols[v++] = {Header:"년/\n월차계|년/\n월차계", Type:"AutoSum", Hidden:0, Width:60, Align:"Center", ColMerge:0, SaveName:"cnt5", KeyField:0, Edit:0};
   // 공휴/대휴 헤더 수정
   if("${ssnEnterCd}" == "KS"){
    initdata1.Cols[v++] = {Header:"공휴|공휴", Type:"AutoSum", Hidden:0, Width:60, Align:"Center", ColMerge:0, SaveName:"cnt6", KeyField:0, Edit:0};
   } else {
    initdata1.Cols[v++] = {Header:"대휴|대휴", Type:"AutoSum", Hidden:"${ssnEnterCd}" != "HG" ? 0 : 1, Width:60, Align:"Center", ColMerge:0, SaveName:"cnt6", KeyField:0, Edit:0};
   }

   if("${ssnEnterCd}" == "KS"){
    initdata1.Cols[v++] = {Header:"주휴|주휴", Type:"AutoSum", Hidden:0, Width:60, Align:"Center", ColMerge:0, SaveName:"cnt7", KeyField:0, Edit:0};
    initdata1.Cols[v++] = {Header:"무휴|무휴", Type:"AutoSum", Hidden:0, Width:60, Align:"Center", ColMerge:0, SaveName:"cnt8", KeyField:0, Edit:0};
   }
   // 발령현황 헤더 수정 (상위 헤더는 한 번만, 하위 헤더는 각 컬럼에)
   initdata1.Cols[v++] = {Header:"발령현황|육아휴직", Type:"AutoSum", Hidden:0, Width:80, Align:"Center", ColMerge:0, SaveName:'lat1', KeyField:0, Format:"", PointCount:0, UpdateEdit:0, InsertEdit:0};
   initdata1.Cols[v++] = {Header:"|가족돌봄", Type:"AutoSum", Hidden:0, Width:80, Align:"Center", ColMerge:0, SaveName:'lat2', KeyField:0, Format:"", PointCount:0, UpdateEdit:0, InsertEdit:0};
   initdata1.Cols[v++] = {Header:"|병가", Type:"AutoSum", Hidden:0, Width:80, Align:"Center", ColMerge:0, SaveName:'lat3', KeyField:0, Format:"", PointCount:0, UpdateEdit:0, InsertEdit:0};
   initdata1.Cols[v++] = {Header:"|산재", Type:"AutoSum", Hidden:0, Width:80, Align:"Center", ColMerge:0, SaveName:'lat4', KeyField:0, Format:"", PointCount:0, UpdateEdit:0, InsertEdit:0};
   initdata1.Cols[v++] = {Header:"|휴직", Type:"AutoSum", Hidden:0, Width:80, Align:"Center", ColMerge:0, SaveName:'lat6', KeyField:0, Format:"", PointCount:0, UpdateEdit:0, InsertEdit:0};
   initdata1.Cols[v++] = {Header:"|정직", Type:"AutoSum", Hidden:0, Width:80, Align:"Center", ColMerge:0, SaveName:'lat5', KeyField:0, Format:"", PointCount:0, UpdateEdit:0, InsertEdit:0};

   // 근무시간 헤더 수정
   initdata1.Cols[v++] = {Header:"근무시간|시작시간", Type:"text", Hidden:0, Width:80, Align:"Center", ColMerge:0, SaveName:'worktimeFrom', KeyField:0, Format:"", PointCount:0, UpdateEdit:0, InsertEdit:0};
   initdata1.Cols[v++] = {Header:"|종료시간", Type:"text", Hidden:0, Width:80, Align:"Center", ColMerge:0, SaveName:'worktimeTo', KeyField:0, Format:"", PointCount:0, UpdateEdit:0, InsertEdit:0};
   initdata1.Cols[v++] = {Header:"|휴게시작시간", Type:"text", Hidden:0, Width:80, Align:"Center", ColMerge:0, SaveName:'leavetimeFrom', KeyField:0, Format:"", PointCount:0, UpdateEdit:0, InsertEdit:0};
   initdata1.Cols[v++] = {Header:"|휴게종료시간", Type:"text", Hidden:0, Width:80, Align:"Center", ColMerge:0, SaveName:'leavetimeTo', KeyField:0, Format:"", PointCount:0, UpdateEdit:0, InsertEdit:0};


   // IBSheet 객체 생성 (createIBSheet에 의해 전역 변수 sheet1이 이미 할당되었음을 가정)
   if (window["sheet1"]) {
    sheet1 = window["sheet1"]; // 전역 sheet1 변수에 할당 (확실하게)
    IBS_InitSheet(sheet1, initdata1); // initdata1으로 시트 초기화
    sheet1.SetEditable("${editable}");
    sheet1.SetVisible(true);
    sheet1.SetCountPosition(4);
    sheet1.SetImageList(0,"${ctx}/common/images/icon/icon_info.png");
    sheet1.SetEditableColorDiff(0); //편집불가 배경색 적용안함
   } else {
    console.error("IBSheet 'sheet1' 객체가 아직 생성되지 않았습니다.");
   }

   // 기존 titleList 관련 셀 폰트 색상 설정은 이제 시간대별 컬럼에 적용되지 않으므로 제거하거나 주석 처리합니다.
   // if (titleList != null && titleList.DATA != null) {
   //     for(var i = 0 ; i<titleList.DATA.length; i++) {
   //         var map = titleList.DATA[i];
   //         sheet1.SetCellFontColor( 1, map.saveName, map.fontColor );
   //     }
   // }

   $(window).smartresize(sheetResize);
   sheetInit();

   // 시트가 DOM에 완전히 렌더링될 시간을 주기 위해 setTimeout 사용
   setTimeout(function() {
    doAction1("Search"); // 시트 준비 후 데이터 로드 시작
   }, 100); // 100ms 지연 (필요시 조정)
  }

  // Sheet1 Action
  function doAction1(sAction) {
   if (!sheet1) { // sheet1 객체가 유효한지 다시 확인
    console.error("sheet1 객체가 아직 준비되지 않아 doAction1을 실행할 수 없습니다.");
    return;
   }

   switch (sAction) {
    case "Search":
     $("#multiManageCd").val(getMultiSelect($("#manageCd").val()));
     $("#oldSearchYm").val($("#searchYm").val());
     $("#oldSearchOrgCd").val($("#searchOrgCd").val());

     var data = getSampleTimeData(); // 시간대별 샘플 데이터 가져오기
     sheet1.LoadSearchData(data); // IBSheet에 데이터 로드

     break;
    case "Down2Excel":
     var downcol = makeHiddenSkipCol(sheet1);
     var param  = {DownCols:downcol,SheetDesign:1,Merge:1,ExcelFontSize:"9",ExcelRowHeight:"20"};
     sheet1.Down2Excel(param);
     break;
   }
  }

  // 데이터를 로드하고 시트에 표시하는 함수 (시간대별 처리 추가)
  function loadSheetData() {
   for (var i = sheet1.HeaderRows(); i < sheet1.HeaderRows() + sheet1.RowCount(); i++) {
    var row = sheet1.GetRowData(i);
    var rowIdx = i;

    // 모든 30분 단위 시간 컬럼의 셀 초기화 (텍스트 및 배경색)
    for (var h = 0; h < 24; h++) {
     sheet1.SetCellValue(rowIdx, 'Hour_' + h + '_0', ''); // 0분 단위
     sheet1.SetCellBackColor(rowIdx, 'Hour_' + h + '_0', '#ffffff'); // 기본 배경색
     sheet1.SetCellValue(rowIdx, 'Hour_' + h + '_30', ''); // 30분 단위
     sheet1.SetCellBackColor(rowIdx, 'Hour_' + h + '_30', '#ffffff'); // 기본 배경색
    }

    // 시간을 컬럼 SaveName으로 변환하는 헬퍼 함수
    // 예: 9.5 -> 'Hour_9_30'
    function getTimeSaveName(timeValue) {
     if (timeValue === null || timeValue === '') return null;
     var hour = Math.floor(timeValue);
     var minutePart = (timeValue % 1 === 0) ? '0' : '30';
     return 'Hour_' + hour + '_' + minutePart;
    }

    // 1. 근무 시간 블록 배경색 설정
    if (row.worktimeFrom !== '' && row.worktimeTo !== '') {
     var workStartMin = parseFloat(row.worktimeFrom) * 60; // 시작 시간을 분으로 (소수점 처리)
     var workEndMin = parseFloat(row.worktimeTo) * 60;     // 종료 시간을 분으로 (소수점 처리)

     for (var m = workStartMin; m <= workEndMin; m += 30) { // 30분 단위로 순회
      var hour = Math.floor(m / 60);
      var minutePart = (m % 60 === 0) ? '0' : '30';
      sheet1.SetCellBackColor(rowIdx, 'Hour_' + hour + '_' + minutePart, '#ADD8E6'); // 연한 파란색
     }
    }

    // 2. 휴게 시간 (연차) 블록 배경색 및 텍스트 설정 (셀 병합 포함)
    if (row.leavetimeFrom !== '' && row.leavetimeTo !== '') {
     var leaveStartMin = parseFloat(row.leavetimeFrom) * 60;
     var leaveEndMin = parseFloat(row.leavetimeTo) * 60;

     var leaveStartColSaveName = getTimeSaveName(parseFloat(row.leavetimeFrom));
     var leaveEndColSaveName = getTimeSaveName(parseFloat(row.leavetimeTo) - 0.5); // 종료 시간 30분 전까지 병합

     var leaveStartColIdx = sheet1.SaveNameCol(leaveStartColSaveName);
     var leaveEndColIdx = sheet1.SaveNameCol(leaveEndColSaveName);

     if (leaveStartColIdx !== -1 && leaveEndColIdx !== -1 && leaveStartColIdx <= leaveEndColIdx) {
      // 해당 범위의 셀들 배경색 설정 (30분 단위로)
      for (var m = leaveStartMin; m < leaveEndMin; m += 30) {
       var hour = Math.floor(m / 60);
       var minutePart = (m % 60 === 0) ? '0' : '30';
       sheet1.SetCellBackColor(rowIdx, 'Hour_' + hour + '_' + minutePart, '#0EB4FC'); // 하늘색 (연차 색상)
      }

      // 셀 병합: SetMergeCell(Row, Col, RowSpan, ColSpan)
      sheet1.SetMergeCell(rowIdx, leaveStartColIdx, 1, (leaveEndColIdx - leaveStartColIdx + 1));

      // 병합된 셀에 "연차" 텍스트 설정 (시작 셀에만 설정)
      sheet1.SetCellValue(rowIdx, leaveStartColIdx, '연차');
      sheet1.SetCellAlign(rowIdx, leaveStartColIdx, "Center"); // 중앙 정렬
     }
    }

    // 3. 대휴 시간 블록 배경색 및 텍스트 설정 (셀 병합 포함)
    if (row.AltleavetimeFrom !== undefined && row.AltleavetimeTo !== undefined && row.AltleavetimeFrom !== null && row.AltleavetimeTo !== null && row.AltleavetimeFrom !== '' && row.AltleavetimeTo !== '') {
     var altLeaveStartMin = parseFloat(row.AltleavetimeFrom) * 60;
     var altLeaveEndMin = parseFloat(row.AltleavetimeTo) * 60;

     var altLeaveStartColSaveName = getTimeSaveName(parseFloat(row.AltleavetimeFrom));
     var altLeaveEndColSaveName = getTimeSaveName(parseFloat(row.AltleavetimeTo) - 0.5);

     var altLeaveStartColIdx = sheet1.SaveName2Col(altLeaveStartColSaveName);
     var altLeaveEndColIdx = sheet1.SaveName2Col(altLeaveEndColSaveName);

     if (altLeaveStartColIdx !== -1 && altLeaveEndColIdx !== -1 && altLeaveStartColIdx <= altLeaveEndColIdx) {
      for (var m = altLeaveStartMin; m < altLeaveEndMin; m += 30) {
       var hour = Math.floor(m / 60);
       var minutePart = (m % 60 === 0) ? '0' : '30';
       sheet1.SetCellBackColor(rowIdx, 'Hour_' + hour + '_' + minutePart, '#FFFF00'); // 노란색
      }
      sheet1.SetMergeCell(rowIdx, altLeaveStartColIdx, 1, (altLeaveEndColIdx - altLeaveStartColIdx + 1));
      sheet1.SetCellValue(rowIdx, altLeaveStartColIdx, '대휴');
      sheet1.SetCellAlign(rowIdx, altLeaveStartColIdx, "Center");
     }
    }
   }
  }

  // 시간대별 샘플 데이터 (30분 단위 포함)
  function getSampleTimeData() {
   return '{"Message":"", "DATA":[{ "sabun": "09400801", "name": "윤석식", "orgNm": "영업본부통신", "jikgubNm": "1급", "worktimeFrom": "8.5", "worktimeTo": "17.5", "leavetimeFrom": "12.5", "leavetimeTo": "17.0", "AltleavetimeFrom": "0.5", "AltleavetimeTo": "2.0",  "cnt5": "0", "cnt6": "0", "lat1": "0", "lat2": "0", "lat3": "0", "lat4": "0", "lat5": "0", "lat6": "0"   }]}' ;
  }

  //---------------------------------------------------------------------------------------------------------------
  // sheet1 Event
  //---------------------------------------------------------------------------------------------------------------

  // 조회 후 에러 메시지
  function sheet1_OnSearchEnd(Code, Msg, StCode, StMsg) {

   loadSheetData();

   try {
    if (Msg != "") {
     alert(Msg);
    }

    // 기존 한국공항 로직 (필요시 시간대별 색상 로직과 통합)
    if("${ssnEnterCd}" == "KS") {
     if (titleList != null && titleList.DATA != null) {
      for(var i = 0 ; i<titleList.DATA.length; i++) {
       var map = titleList.DATA[i];
       for(var j = sheet1.HeaderRows(); j <= sheet1.LastRow() - 1; j++){
        // 이 부분은 30분 단위 컬럼 SaveName에 맞게 수정해야 하거나 제거해야 합니다.
        // if(sheet1.GetCellValue(j, map.saveName) == "무휴"){
        //  sheet1.SetCellFontColor( j, map.saveName, "#0000FF" );
        // }else if(sheet1.GetCellValue(j, map.saveName) == "주휴"){
        //  sheet1.SetCellFontColor( j, map.saveName, "#ff0000" );
        // }else{
        //  sheet1.SetCellFontColor( j, map.saveName, "#000000" );
        // }
       }
      }
     }
    }

    sheetResize();
   } catch (ex) {
    alert("OnSearchEnd Event Error : " + ex);
   }
  }

  // 셀 클릭시 발생
  function sheet1_OnClick(Row, Col, Value, CellX, CellY, CellW, CellH) {
   try {
    if( Row < sheet1.HeaderRows() ) return;

    if( sheet1.ColSaveName(Col) == "detail" ) {

     gPRow = Row;
     pGubun = "OrgMonthWorkStaPop";

     sheet1.SetCellValue(Row, "ym", $("#searchYm").val());

     OrgMonthWorkStaPopup(Row);
    }
   }
   catch (ex) {
    alert("OnClick Event Error : " + ex);
   }
  }

  function OrgMonthWorkStaPopup(Row) {
   if (!isPopup()) {
    return;
   }
   gPRow = Row;
   pGubun = "OrgMonthWorkStaPop";
   var url = "${ctx}/OrgMonthWorkSta.do?cmd=viewOrgMonthWorkStaPop&authPg=R";

   parent.$.modalLink.open(url, {
    title:"개인별 월근태현황",
    method:"POST",
    width:850,
    height:650,
    data: {
     targetSheet: "sheet1",
     // 팝업으로 넘겨줄 데이터
     ym: $("#searchYm").val(),
     sabun: sheet1.GetCellValue(Row, "sabun"),
     name: sheet1.GetCellValue(Row, "name"),
     orgNm: sheet1.GetCellValue(Row, "orgNm"),
     jikgubNm: sheet1.GetCellValue(Row, "jikgubNm")
    }
   });
  }
 </script>
</div>
</body>
</html>