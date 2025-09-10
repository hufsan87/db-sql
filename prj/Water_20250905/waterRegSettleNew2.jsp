<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="org.anyframe.util.DateUtil" %>
<%@ include file="/WEB-INF/jsp/common/include/taglibs.jsp"%>
<!DOCTYPE html> <html class="hidden"><head> <title>생수내역</title>
 <%@ include file="/WEB-INF/jsp/common/include/meta.jsp"%><!-- Meta -->
 <%@ include file="/WEB-INF/jsp/common/include/jqueryScript.jsp"%>
 <%@ include file="/WEB-INF/jsp/common/include/ibSheetScript.jsp"%>

 <script type="text/javascript">
  let gPRow = ""	 , pGubun = ""	 , titleList ="" 	 , curAdminYn = "${ssnAdminYn}"
   , grpCds			 , codeLists		 , lstDay
   , typingTimer
  ;

  $(function() {
   lstDay = getLastDay("${curSysYyyyMMdd}");
   setSearchForm();		 // 조회조건 세팅
   setSheetForm();			 // sheet 세팅
   doSearch();
  });

  function doSearch(){
   doAction2("Search");
  }

  function setSearchForm(){
   //기준일자 날짜형식, 날짜선택 시
   $("#searchCalcDAY").datepicker2({
    onReturn:function(){
     doSearch();
    }
   });

   $("#searchSabunName, #searchCalcDAY").on("keypress", function(event) {
    if( event.keyCode == 13) {
     doSearch();
    }
   });

   $('#searchIsCancYn').click(function() {
    if($(this).prop('checked')) {
     $('#searchIsCancYn').not(this).prop('checked', false);
    }
   });


   $("#searchIsCancYn").on("change", function(e) {
    doSearch("Search");
   });

   $("#searchCalcDAY").val(lstDay);
  }


  function updateSettleData(){
   let param;
   if($("#spBarCd").text){
    param = "&barCd=" + $("#spBarCd").text();
    data = ajaxCall("${ctx}/GetDataList.do?cmd=getBarCdChk", param, false).DATA[0];

    if(data.cnt1 > 0){
     alert("이미 정산등록된 내역입니다. 확인하여 주십시오.");
     return false;
    }

    if(data.cnt3 > 0) alert("해당 바코드 내역은 사용취소되었습니다.");
    updateBarData(param); //저장

   } else{
    alert("조회된 바코드정보가 없습니다.")
   }
  }

  function setBarData(param){
   barData = ajaxCall("${ctx}/GetDataList.do?cmd=getBarDataNew", param, false).DATA[0];
   if(barData){
    // $("#spCalcYmd").text(barData.calDay);
    // $("#spBarCd").text(barData.barCd);
    // $("#spAppNm").text(barData.name);
    // $("#spUseYmd").text(barData.useYmd);
    // $("#spUseLtCnt").text(barData.waterList);
    // $("#note1").text(barData.note1);


    $("#box1").text(barData.box1);
    $("#box2").text(barData.box2);
    $("#box3").text(barData.box3);
    return true;
   } else{
    alert("잘못된 바코드정보 입니다.");
    return false;
   }
  }

  function setSheetForm(){
   // 어차피 내역이라 옛날것도 보여야하기때문에 정산일 기준으로 매번 가져올 필요없음
   titleList =  ajaxCall("${ctx}/GetDataList.do?cmd=getWaterComboTitleList", '', false);
   init_sheet1();
   sheetInit();
  }

  function updateBarData(param){
   param += "&calDay=" + $("#calcYmd").val()
    + "&note1="+ $("#note1").val();
   result = ajaxCall("${ctx}/WaterRegSettle.do?cmd=saveWaterRegSettle", param, false).Result;
   if (result.Cnt > 0) {
    alert(result.Message);
    setBarData(param);
    doSearch();
   } else
    alert(result.Message);
  }

  function getLastDay(prYmd){
   let year, month, lstMnthDayDate, lstDay
   year =  prYmd.substr(0,4);
   month = prYmd.substr(4,2);
   lstMnthDayDate = new Date(year, Number(month), 0); // 말일자 Date 객체
   lstDay         = lstMnthDayDate.getDate(); // 말일

   return year.concat("-").concat(month).concat("-").concat(lstDay)
  }

  //Sheet 초기화
  function init_sheet1(){
   if (titleList != null && titleList.DATA != null){
    sheet1.Reset();

    let v=0;
    let initdata2 = {};
    initdata2.Cfg = {SearchMode:smLazyLoad,Page:22,MergeSheet:msHeaderOnly,FrozenCol:0, FrozenColRight:0};
    initdata2.HeaderMode = {Sort:1,ColMove:1,ColResize:1,HeaderCheck:0};

    initdata2.Cols = [];
    initdata2.Cols[v++] = {Header:"No|No",   		Type:"${sNoTy}",  Hidden:0,  Width:"${sNoWdt}", 					Align:"Center", ColMerge:0, SaveName:"sNo" };
    initdata2.Cols[v++] = {Header:"정산일자|정산일자",	Type:"Date",			Hidden:0,  Width:60,   Align:"Center",  SaveName:"calDay",  	KeyField:0,  Format:"Ymd",PointCount:0, UpdateEdit:0, InsertEdit:0 };
    initdata2.Cols[v++] = {Header:"바코드|바코드",		Type:"Text",			Hidden:0,  Width:90,   Align:"Center",  SaveName:"barCd",   	KeyField:0,  Format:"",   Edit:0 };
    initdata2.Cols[v++] = {Header:"신청자|사번",		Type:"Text",			Hidden:0,  Width:60,   Align:"Center",  SaveName:"sabun",   	KeyField:0,  Format:"",   Edit:0 };
    initdata2.Cols[v++] = {Header:"신청자|성명",		Type:"Text",			Hidden:0,  Width:60,   Align:"Center",  SaveName:"name",    	KeyField:0,  Format:"",   UpdateEdit:0,   InsertEdit:0};
    initdata2.Cols[v++] = {Header:"사용일자|사용일자",	Type:"Date",			Hidden:0,  Width:60,   Align:"Center",  SaveName:"useYmd",  	KeyField:0,  Format:"Ymd",PointCount:0, UpdateEdit:0, InsertEdit:0 };

    headerStartCnt = v; // 사용수량 항목 가변생성
    for(let i = 0 ; i<titleList.DATA.length; i++) {
     initdata2.Cols[v++] = {Header:"사용수량"+"|"+titleList.DATA[i].codeNm, Type:"Text",  Hidden:0, Width:60, Align:"Center", SaveName:"useLtCd" + titleList.DATA[i].saveName, Format:"", Edit:0};
     initdata2.Cols[v++] = {Header:"사용수량"+"|"+titleList.DATA[i].codeNm, Type:"AutoSum",  Hidden:1, Width:60, Align:"Center", SaveName:"autoSum"+titleList.DATA[i].saveName, Format:"", UpdateEdit:0, InsertEdit:0, CalcLogic:"|useLtCd" + titleList.DATA[i].saveName +"|"};
    }

    initdata2.Cols[v++] = {Header:"취소일자|취소일자",		Type:"html",  Hidden:0, Width:60,    Align:"Center",   SaveName:"cancYmd",		KeyField:0,  Format:"Ymd",Edit:0};
    initdata2.Cols[v++] = {Header:"비고|비고",				Type:"Text",  Hidden:0, Width:90,    Align:"Left",   SaveName:"note1",			KeyField:0,  Format:"",   Edit:0};

    IBS_InitSheet(sheet1, initdata2);sheet1.SetEditable(1);sheet1.SetVisible(true);sheet1.SetCountPosition(4);
    sheet1.SetDataAlternateBackColor(sheet1.GetDataBackColor()); //짝수번째 데이터 행의 기본 배경색

    $(window).smartresize(sheetResize);
   }
  }

  //sheet1 Action
  function doAction2(sAction) {
   let sXml
   switch (sAction) {
    case "Search":
     // 시트초기화
     sheet1.ShowProcessDlg("Search");
     setTimeout(function(){
      init_sheet1();
      sXml = sheet1.GetSearchData("${ctx}/WaterRegSettle.do?cmd=getWaterRegSettleList", $("#sheetForm").serialize() );
      sXml = replaceAll(sXml,"cancYmdFontColor", "cancYmd#FontColor");
      sheet1.LoadSearchData(sXml );
     }, 100);
     break;
    case "Down2Excel":
     downcol = makeHiddenSkipCol(sheet1);
     param  = {DownCols:downcol,SheetDesign:1,Merge:1,ExcelFontSize:"9",ExcelRowHeight:"20"};
     sheet1.Down2Excel(param);
     break;
   }
  }

  function setSheetAutoSum(){
   let lastRow = sheet1.GetDataLastRow() + 1, titleSaveNm;
   for(let j = 0; j<titleList.DATA.length; j++) { //useLtCd,codeNm
    titleSaveNm = titleList.DATA[j].saveName
    sheet1.SetCellValue(lastRow, ("useLtCd".concat(titleSaveNm)), sheet1.GetCellValue(lastRow, ("autoSum".concat(titleSaveNm))))
   }
  }

  //---------------------------------------------------------------------------------------------------------------
  // sheet Event
  //---------------------------------------------------------------------------------------------------------------

  // 조회 후 에러 메시지
  function sheet1_OnSearchEnd(Code, Msg, StCode, StMsg) {
   try {
    if (Msg != "") alert(Msg);
    setSheetAutoSum();
    sheetResize();
   } catch (ex) {
    alert("OnSearchEnd Event Error : " + ex);
   }
  }

  // 오토썸 변경시 동작
  function sheet1_OnChangeSum(Code, Msg, StCode, StMsg) {
   setSheetAutoSum();
  }
 </script>
 <style>

 </style>
</head>
<body class="bodywrap">
<div class="wrapper">
 <form name="sheetForm" id="sheetForm" method="post">
  <input type="hidden" id="tben593Data" name="tben593Data" />
  <div class="sheet_search outer">
   <table>
    <tr>
     <td>
      <span>정산일</span>
      <input type="text" id="searchCalcDAY" name="searchCalcDAY" class="date2" value="" />
     </td>
     <td>
      <span>사번/성명</span>
      <input type="text" id="searchSabunName" name="searchSabunName" class="text" style="ime-mode:active;" />
     </td>
     <td>
      <span>취소내역만 조회</span>
      <input class="searchChkBox" type="checkbox" id="searchIsCancYn" name="searchIsCancYn" value="Y">
     </td>
     <td>
      <a href="javascript:doSearch()" class="button">조회</a>
     </td>
    </tr>
   </table>
  </div>
 </form>
 <table class="sheet_main">
  <colgroup>
   <col width="29%" />
   <col width="1%" />
   <col width="70%" />
  </colgroup>
  <tr>
   <td class="valignT">
    <div class="top">
     <div class="inner" >
      <div class="sheet_title">
       <ul>
        <li id="txt" class="txt">정산현황</li>
       </ul>
      </div>

     </div>
     <div class="inner" >
      <div class="sheet_title">
       <ul>
        <li id="txt" class="txt">정산등록내역</li>
        <li class="btn">
         <span><a href="javascript:doAction2('Down2Excel')"   class="basic authR" >다운로드</a></span>
        </li>
       </ul>
      </div>
     </div>
     <script type="text/javascript">createIBSheet("sheet1", "100%", "100%"); </script>
    </div>
   </td>
   <td></td>
   <td >

     <div class="inner" >
      <div class="sheet_title">
       <ul>
        <li id="txt" class="txt">정산현황</li>
       </ul>
      </div>

     </div>
     <div class="inner" >
      <div class="sheet_title">
       <ul>
        <li id="txt" class="txt">정산등록내역</li>
        <li class="btn">
         <span><a href="javascript:doAction2('Down2Excel')"   class="basic authR" >다운로드</a></span>
        </li>
       </ul>
      </div>
     </div>
    

   </td>
  </tr>
 </table>
</div>
</body>
</html>