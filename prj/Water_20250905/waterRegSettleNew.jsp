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

  $("#barCdNew").on("input", function(event) {
   if($(this).val()){
    $(".fake\-input\-container").show();

    let param;
    param = "&barCd=" + $(this).val();

    clearTimeout(typingTimer); // 새 입력이 들어오면 이전 타이머를 제거합니다.
    typingTimer = setTimeout(function() {
      setTitle();
      setBarData(param);
    }, 1000);
   }else{
    $(".fake\-input\-container").hide();
    initBox();
    return;
   }
  });




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



 function setTitle(){
  let titleListNew =  ajaxCall("${ctx}/GetDataList.do?cmd=getWaterComboTitleList", '', false);
  if (titleListNew != null && titleListNew.DATA != null){
   $("#boxTitle1").text(titleList.DATA[0].codeNm);
   $("#boxTitle2").text(titleList.DATA[1].codeNm);
   $("#boxTitle3").text(titleList.DATA[2].codeNm);
  }
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

 function clearBox(){

 }

 function setSheetForm(){
  initBox();
		init_sheet1();
		sheetInit();
 }


 function initBox(){
  $(".fake\-input\-container").hide();
 }
 function updateBarData(param){
	 param += "&calDay=" + $("#searchCalcDAY").val()
	 			  + "&note1="+ "하치장불출";
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
  titleList =  ajaxCall("${ctx}/GetDataList.do?cmd=getWaterComboTitleList", '', false);
  if (titleList != null && titleList.DATA != null){
	  sheet1.Reset();

	  let v=0;
	  let initdata2 = {};
	  initdata2.Cfg = {SearchMode:smLazyLoad,Page:22,MergeSheet:msHeaderOnly,FrozenCol:0, FrozenColRight:0};
	  initdata2.HeaderMode = {Sort:1,ColMove:1,ColResize:1,HeaderCheck:0};

	  initdata2.Cols = [];
	  initdata2.Cols[v++] = {Header:"No|No",   		Type:"${sNoTy}",  Hidden:0,  Width:"${sNoWdt}", 					Align:"Center", ColMerge:0, SaveName:"sNo" };
   //initdata2.Cols[v++] = {Header:"No|No",   		Type:"Text",  Hidden:0,  Width:"${sNoWdt}", 					Align:"Center", ColMerge:0, SaveName:"rn" };
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
    init_sheet1();
    sXml = sheet1.GetSearchData("${ctx}/WaterRegSettle.do?cmd=getWaterRegSettleList", $("#sheetForm").serialize() );
    sXml = replaceAll(sXml,"cancYmdFontColor", "cancYmd#FontColor");
    sheet1.LoadSearchData(sXml );
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
    html, body {
        margin: 0;
        padding: 0;
        height: 100%;
    }

    .wrapper {
        height: 100%;
    }

    /* input처럼 보이게 할 부모 컨테이너 스타일 */
    .fake-input-container {
        border: 1px solid #ccc;
        border-radius: 4px;
        padding: 10px;
        background-color: #fff;

        /* Flexbox를 사용하여 내부 아이템들을 가로로 정렬 */
        display: flex;
        justify-content: space-around; /* 아이템들을 균등한 간격으로 배치 */
        align-items: center; /* 아이템들을 세로 중앙에 배치 */
    }

    /* 각 정보가 담길 박스 스타일 */
    .info-box {
        text-align: center;
    }

    /* 박스 안의 큰 숫자 스타일 */
    .info-box .value {
        font-size: 100px; /* 기존 24px * 3 = 72px */
        font-weight: bold;
        color: #333;
        line-height: 1; /* 텍스트 줄 간격 조정 */
    }

    /* 박스 안의 작은 글씨 스타일 */
    .info-box .label {
        font-size: 100px; /* 기존 16px * 3 = 48px */
        font-weight: bold;
        color: #555;
        line-height: 1; /* 텍스트 줄 간격 조정 */
        padding: 5px 0; /* 배경색이 잘 보이도록 상하 패딩 추가 */
    }

    /* "6 BOX" 부분의 배경색을 노란색으로 채우는 스타일 */
    .highlight-yellow {
        background-color: yellow;
        padding: 0 5px; /* 배경색이 텍스트 너비에 맞게 조절되도록 좌우 패딩 추가 */
        border-radius: 3px; /* 모서리를 약간 둥글게 */
    }

    .strong-border {
        border: 20px solid #000;
    }

    span.button {
        display: inline-block;
        vertical-align: middle;
        background-color: #0072bc;
        margin: 0 1px;
        color: #FFF;
        font-size: 12px;
        line-height: 12px;
        font-weight: bold;
        border-radius: 8px;
        padding: 9px 20px 10px;
        letter-spacing: 0;
        cursor : default;
    }
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
    <td><span class="button">바코드2</span> <input type="text" id="barCdNew" name="barCdNew" class="w100p strong-border" style="border: 2px solid #000;" /></td>
     <td>
      <a href="javascript:doSearch()" class="button">등록</a>
     </td>
    </tr>
   </table>
  </div>
 </form>


 <table border="1" class="sheet_main" style="width: 100%; height:80%; border-collapse: collapse; text-align: center;">
  <colgroup>
   <col width="29%" />
   <col width="1%" />
   <col width="70%" />
  </colgroup>
  <tr>
   <td  style="border: 1px solid black; padding: 8px; vertical-align: top;" class="valignT">
    <div class="top">
     <div class="inner">
      <ul>
       <li id="txt" class="">정산기준</li>
       <span><a href="javascript:doAction2('Down2Excel')"   class="basic authR" >다운로드</a></span>
      </ul>
     </div>
     <script type="text/javascript">createIBSheet("sheet1", "100%", "100%"); </script>
    </div>
   </td>
   <td  style="border: 1px solid black; padding: 8px; vertical-align: middle;">test</td>

   <td  style="border: 1px solid black; padding: 0;">
    <div style="display: flex; flex-direction: column; height: 100%;">
     <div style="height: 70%; border-bottom: 1px solid black; padding: 8px;">
      <div class="fake-input-container">
       <div id="info1" class="info-box">
        <div class="value"><span id="boxTitle1"/></div>
        <div class="label"><span id="box1" class="highlight-yellow"/></div>
       </div>
       <div  id="info2" class="info-box">
        <div class="value"><span id="boxTitle2"/></div>
        <div class="label"><span id="box2" class="highlight-yellow"/></div>
       </div>
       <div  id="info3" class="info-box">
        <div class="value"><span id="boxTitle3"/></div>
        <div class="label"><span id="box3" class="highlight-yellow"/></div>
       </div>
      </div>

     </div>
     <div style="height: 30%; padding: 8px;">
      tafasdf dddddddd
     </div>
    </div>
   </td>
  </tr>
 </table>
</div>
</body>
</html>