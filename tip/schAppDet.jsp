<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ include file="/WEB-INF/jsp/common/include/taglibs.jsp"%>
<%@ include file="/WEB-INF/jsp/common/include/applCommon.jsp"%>
<%@ page import="org.anyframe.util.DateUtil" %>
<!DOCTYPE html> <html class="hidden"><head> <title>학자금신청/승인 세부내역</title>
<%@ include file="/WEB-INF/jsp/common/include/meta.jsp"%><!-- Meta -->
<%@ include file="/WEB-INF/jsp/common/include/jqueryScript.jsp"%>
<%@ include file="/WEB-INF/jsp/common/include/ibSheetScript.jsp"%>

<script type="text/javascript">
let searchApplSeq    = "${searchApplSeq}"	  , adminYn          = "${adminYn}"	, authPg           = "${authPg}"
	, searchApplSabun  = "${searchApplSabun}"	, searchApplInSabun= "${searchApplInSabun}"	, searchApplYmd    = "${searchApplYmd}"
	, applStatusCd     = ""	, applYn           = ""	, pGubun           = ""	, gPRow            = ""	, adminRecevYn     = "N" //수신자 여부
	, user	, schStdData       = null
	, grpCds	,codeLists // 공통코드
 , ssnEnterCd = "${ssnEnterCd}"
	;

 // 23.11.28 오픈 후 대대적 수정
 $(function() {
	pgInit();	// Page Init
	setCmCombo(); // 기본 콤보(조건안타고 무조건 불러와도 됨)

  // 신청, 임시저장
  if(authPg == "A"){ //2023.11.09
	 $("#searchSchNameList1").on("keyup", function(event) {if(event.keyCode === 13)	selectMatchingItem();});

   $("#schEntYm").datepicker2({ymonly:true}); //입학년월
   $(".ui-datepicker-trigger").hide();

   $("#appYear").val("${curSysYear}");  //신청년도 고정
   setSchPointRqd();

   $("#intAmt, #atdAmt, #stdAmt, #meritAmt").on("blur", function(e){setApplMon();}); // 신청금액 제어 이벤트

   // 전학기학점 제어 이벤트,학자금유형 콤보 선택 이벤트
   $("#schTypeCd, #schYear, #divCd, #schPoint").on("change", function(e) {
    setSchPointRqd();
    if(this.id=="schTypeCd"){
     setSchDeptRqd($(this).val());
     const schTypeCdObj = $("#schTypeCd option:selected");
     if($("#schTypeCd").val() === "20")	$("#schSupTypeCd").html("<option value=''> </option>");
     else	setSchSupTypeCdCombo($(this).val(), "",schTypeCdObj.attr("note2") === "Y"?"Y":"N",  $("#schLocCd").val());

     /* 초기화 */
     $("#schDeptList1").html("<option value=''> </option>");
     $("#schFieldCd1").html("<option value=''> </option>");
     $("#schYear").html("<option value=''> </option>");
     $("#schFieldCd").val("");
     $("#schField").val("");
     $("#intAmt").prop("disabled", true);
     $("#intAmt").val("");
     /* 초기화 */

     $("#schUnivGb").text("학과");
     toggleSelectInput();
     if(schTypeCdObj.attr("note2") === "Y"){ //대학일 경우
      setSchNameCombo(); //대학 콤보 리스트
      $("#schUnivGb").text("학과/전공계열");
      $("#stdAmt").prop("disabled", false); //대학 학생회비 입력
     }else if(schTypeCdObj.attr("note2") !== "Y"){
      $("#stdAmt").prop("disabled", true); //고교 학생회비 입력불가
      $("#stdAmt").val("");

      setApplMon();
      $("#schSupTypeCd").val("10");
      $("#schSupTypeCd").change();
     }

     // 가족 콤보 목록 조회
     let param = "&searchApplSabun="+searchApplSabun + "&schTypeCd="+$("#schTypeCd").val() + "&schSupTypeCd="+$("#schSupTypeCd").val() + "&useYn=Y"
     	, famList = convCodeCols(ajaxCall("${ctx}/CommonCode.do?cmd=getCommonNSCodeList", "queryId=getSchAppDetFamList"+param, false).codeList
                 , "famNm,famYmd,admissionDate"
                 , " ");
     $("#famResNo").html(famList[2]);

     //clear
     $("#famNm").val("");
     $("#famYmd").html("");
     $("#birYmd").html("");
    } else if(this.id=="schYear" || this.id=="divCd"){
     //전문대 1.5,2.5,3.5...년제의 마지막 학년에 1학기만 표출 '25.03.14
     if(this.id=="schYear" && $("#schTypeCd").val() == "30"){
      let schYear = $(this).prop('selectedIndex'); //2, 3, 4
      let yearLongTmp = $("#schSupTypeCd").val(); //15, 25 (35는 제외, 4년제)
      //yearLongTmp =
      if(typeof yearLongTmp != "undefined" && yearLongTmp != null && yearLongTmp != ""
       && typeof schYear != "undefined" && schYear != null && schYear != ""
       && Number(schYear) != 4 && yearLongTmp.charAt(1) == "5" && Number(schYear) == Number(yearLongTmp.charAt(0)) + 1){
        $("#divCd").val("01"); //1학기만 셋팅
        $("#divCd option").not(":selected").remove();
      }else{
       setDivCdCombo($("#schTypeCd").val(), "Y");
      }
     }

    	if($("#schYear").val() == 1  && $("#divCd").val() == "01"){
      $(".ui-datepicker-trigger").show();
      $("#schEntYm").addClass('date2','bbit-dp-input');
      $("#schEntYm").prop("disabled",false);
      $("#intAmt").prop("disabled", false);
    	} else {
      $("#schEntYm").val("");
      $(".ui-datepicker-trigger").hide();
      $("#schEntYm").removeClass('date2','bbit-dp-input');
      $("#schEntYm").prop("disabled",true);
      $("#intAmt").prop("disabled", true);
    		$("#intAmt").val("");
    	}
    }
   });

   $("#schLocCd").on("change", function(e) {toggleSelectInput();});

   $("#famResNo").on("change", function(e){
    $("#famNm").val($(this).val());
   });

   // 대학 콤보 선택 이벤트
   $("select[id=schNameList1]").on("change", function(e) {
	   $("#schFieldCd1").html("<option value=''> </option>");
    $("#schYear").html("<option value=''> </option>");
	   if($("#schTypeCd").val() === "20") $("#schSupTypeCd").html("<option value=''> </option>");
     setSchDeptCombo($(this).val());
     $("#schCd").val($(this).val());
     $("#schName").val($(this).find(":selected").text());

    setSchSupTypeCdCombo($("#schTypeCd").val(), "","Y", $("#schLocCd").val());
   });

   $("input[id=schNameList2]").on("change", function(e) {
    $("#schCd").val("");
    $("#schName").val($(this).val());
   });

   // 대학별 학과 콤보 선택 이벤트
   $("select[id=schDeptList1]").on("change", function(e) {
    $("#schDeptCd").val($(this).val());
    $("#schDept").val($(this).find(":selected").text());

    setSchFieldCdCombo($("#schNameList1").val(), $(this).val());
    setSchYearCombo($("#schSupTypeCd").val());

    //전문대, value2(수업연한)에 값이 있을 때, 학과에 따른 세부구분(수업연한 표기) 설정 '25.03.14
    let yearLong = $(this).find("option").eq($(this).prop('selectedIndex')).attr("value2");
    if($("#schTypeCd").val() == "30" && yearLong != "null"){
     setSchSupTypeCdCombo($("#schTypeCd").val(), "","Y", $("#schLocCd").val());
     $("#schSupTypeCd").val(getYearLongToCd(yearLong));
     $("#schSupTypeCd option").not(":selected").remove();
     $("#schSupTypeCd").change();
    }

   });

   $("input[id=schDeptList2]").on("change", function(e) {
    $("#schDeptCd").val("");
    $("#schDept").val($(this).val());
   });

   // 대학별 전공 콤보 선택 이벤트
   $("select[id=schFieldCd1]").on("change", function(e) {
	   if($("#schTypeCd").val() =="20"){
		   setSchSupTypeCdCombo($("#schTypeCd").val(),$(this).val(),"Y", $("#schLocCd").val());
	    $("#schSupTypeCd").val($(this).val());
	    $("#schSupTypeCd").change();
	   }

    $("#schFieldCd").val($(this).val());
    $("#schField").val($(this).find(":selected").text());
   });

   $("input[id=schFieldCd2]").on("change", function(e) {
    $("#schFieldCd").val("");
    $("#schField").val($(this).val());
   });

   // 전학기학점 2.0미만 신청 불가 메세지
   $("#schPoint").on("change", function(e) {
    if(parseInt($(this).val()) < 2){
     alert("전학기 학점 2.0이상만 신청가능합니다");
     $(this).focus();
    }
   });

   // 학자금 세부구분 콤보 선택 이벤트
   $("#schSupTypeCd").change(function() {setSchYearCombo($("#schSupTypeCd").val());});

   // 대상자 선택 이벤트
   $("#famResNo").change(function() {
    const obj = $("#famResNo option:selected");
    $("#famNm").val(obj.attr("famNm"));
    $("#famYmd").val(obj.attr("famYmd"));
    $("#schEntYm").val(obj.attr("admissionDate"));

    //생년월일/성별 표시
    $("#birYmd").html(formatDate(obj.attr("famYmd"),"-"));
   });

   // 성적장학금수혜여부 콤보 선택 이벤트
   $("#meritYn").on("change", function(e) {
      if($(this).val() == "Y") {
       $("#meritAmt").removeClass("transparent").prop("readonly", false);
      } else {
       $("#meritAmt").prop('readonly', true);
       $("#meritAmt").val("");
       setApplMon(); // 신청금액 재계산
      }
   });

   // 성적장학금수혜여부 콤보 선택 이벤트
   $("#meritAmt").on("click", function(e) {
    if($("#meritYn").val() == "Y") {
     alert("성적우수장학금만 신청가능 합니다. (교내장학금 限)");
    }
   });
  } else if (authPg == "R") {
	  setSchNameCombo();
	  setSchYearCombo();
  }
  doAction("Search");
 });

 function pgInit(){
	  parent.iframeOnLoad();
	  //----------------------------------------------------------------
	  $("#searchApplSeq").val(searchApplSeq);
	  $("#searchApplSabun").val(searchApplSabun);
	  $("#searchApplYmd").val(searchApplYmd);
	  $('#applMon').mask('000,000,000,000,000', { reverse : true });
	  $('#intAmt').mask('000,000,000,000,000', { reverse : true });
	  $('#atdAmt').mask('000,000,000,000,000', { reverse : true });
	  $('#stdAmt').mask('000,000,000,000,000', { reverse : true });
      $('#meritAmt').mask('000,000,000,000,000', { reverse : true });

	  applStatusCd = parent.$("#applStatusCd").val();
	  applYn = parent.$("#applYn").val(); // 현 결재자와 세션사번이 같은지 여부

	  if(applStatusCd == "") applStatusCd = "11";

	  if( ( adminYn == "Y" ) || ( applStatusCd == "31"  && applYn == "Y" ) ){ //담당자거나 수신결재자이면
	   if( applStatusCd == "31") { //수신처리중일 때만 지급정보 수정 가능
	    $("#payMon").removeClass("transparent").prop("readonly", false);
	    $("#payYm").removeClass("transparent").prop("readonly", false);
	    $("#payMon").mask('000,000,000,000,000', { reverse : true });
	    $("#payYm").datepicker2({ymonly:true});
	   }

   	 adminRecevYn = "Y";
   	 parent.iframeOnLoad();
   }

  // 전학기학점 hidden, 등록금 실납입금액 표기 (HT only)
  if("${ssnEnterCd}" === "HT") $(".pointHidden").css("display", "none");

// 등록금 실납입금액 표기 (HT only)
  if("${ssnEnterCd}" === "HT"){
   $(".atdamtHidden").css("display", "inline");
  }else{
   $(".atdamtHidden").css("display", "none");
  }

 }

 function setCmCombo(){ //공통코드 한번에 조회
	  grpCds = "'B60050','S90005'";

	  //가족대상 콤보 및 경조기준정보 가져오기
	  let codeLists = convCodeCols(ajaxCall("${ctx}/CommonCode.do?cmd=getCommonNSCodeList", "queryId=getSchTypeCd", false).codeList, "note2", " ");
	  $("#schTypeCd").html(codeLists[2]); //학자금유형 콤보

      // 성적장학금수혜여부 콤보
      let newCodeLists = convCodes(ajaxCall("${ctx}/CommonCode.do?cmd=commonCodeLists","grpCd="+grpCds,false).codeList, "");
      $("#meritYn").html(newCodeLists["S90005"][2]);		// 여부
      $("#meritYn").val("N");
 }

 function selectMatchingItem() {
	 let schTypeCd = $("#schTypeCd option:selected");
	 if(schTypeCd.attr("note2") == "Y"){
	  let searchSchNmList = convCode(ajaxCall("${ctx}/CommonCode.do?cmd=getCommonNSCodeList&searchSchName="
			  											 + $("#searchSchNameList1").val().toLowerCase()
			  											 + "&searchSchCd=" + $("#schTypeCd").val()  + "&schLocCd=" + $("#schLocCd").val()
			  											 , "queryId=getSchList", false).codeList, " ");
	  $("#schNameList1").html(searchSchNmList[2]);
	 } else alert("학자금유형이 대학일 때만 사용가능합니다.");
 }

 function setSchPointRqd(){
	const obj = $("#schTypeCd option:selected");
  if(obj.attr("note2") === "Y"){ //전학기 학점 required 제어
   if(($("#schYear").val()==1 && parseInt($("#divCd").val())>1) ||
    ($("#schYear").val()>1)
   ){
    $("#schPoint").addClass("required");
    $("#schPoint").prop('disabled', false);
   }else{
    $("#schPoint").removeClass("required");
    $("#schPoint").prop('disabled', true);
   }
  }else{
   $("#schPoint").removeClass("required");
   $("#schPoint").prop('disabled', true);
   $("#schPoint").val("");
  }
 }

 function setSchDeptRqd(schTypeCd){
  if(schTypeCd=="10"){
   $("#schDeptList2").removeClass("required");
  }else{
   $("#schDeptList2").addClass("required");
  }
 }

 function setApplMon(){
  $("#applMon").val(
   Number($("#atdAmt").val().replace(/,/g, ''),10)
   + Number($("#intAmt").val().replace(/,/g, ''),10)
   + Number($("#stdAmt").val().replace(/,/g, ''),10)
   + ($("#meritAmt").val() !== undefined ? Number($("#meritAmt").val().replace(/,/g, ''),10) * (50/100) : 0) // 성적장학금 50%
  );
  $('#applMon').mask('000,000,000,000,000', { reverse : true });
  $("#intAmt_won").html( ( $("#intAmt").val() == "")?"":" 원"); // 입학금 원
  $("#atdAmt_won").html( ( $("#atdAmt").val() == "")?"":" 원"); // 등록금 원
  $("#stdAmt_won").html( ( $("#stdAmt").val() == "")?"":" 원"); // 학생회비 원
  $("#applMon_won").html( ( $("#applMon").val() == "")?"":" 원"); // 신청금액 원
  $("#meritAmt_won").html( ( $("#meritAmt").val() == "")?"":" 원"); // 성적장학금 원
 }

 function doAction(sAction) {
  switch (sAction) {
   case "Search":
    // 입력 폼 값 셋팅
    var data = ajaxCall( "${ctx}/SchAppDet.do?cmd=getSchAppDetMap", $("#searchForm").serialize(),false);

    if ( data != null && data.DATA != null ){
     $("#schTypeCd").val(data.DATA.schTypeCd);   // 학자금구분
     const schTypeCdObj = $("#schTypeCd option:selected");
     if(schTypeCdObj.attr("note2") === "Y")	$("#schUnivGb").text("학과/전공계열");

     if(authPg == "A") {
      // 지원구분콤보생성
      $("#schTypeCd").change();
      $("#schSupTypeCd").val(data.DATA.schSupTypeCd);
      // 대상자콤보 생성
      $("#schSupTypeCd").change();
      let selectedNm = $('#famResNo option:contains('+data.DATA.famNm+')').val();
      $('#famResNo').val(selectedNm);
      $("#famResNo").change();
      $("#schLocCd").val(data.DATA.schLocCd);  // 국내/국외
      $("#schLocCd").change();

      if(($("#schLocCd").val() === "0" || $("#schLocCd").val() === "1") && schTypeCdObj.attr("note2") === "Y"){ //국내
	      $("#schNameList1").val(data.DATA.schCd);  // 학교명
	      $("#schNameList1").change();

     	  setSchDeptCombo(data.DATA.schCd);
     	  $("#schDeptList1").val(data.DATA.schDeptCd);  // 학과
	      $("#schDeptList1").change();

     	  setSchFieldCdCombo(data.DATA.schCd, data.DATA.schDeptCd);
     	  $("#schFieldCd1").val(data.DATA.schFieldCd);  // 전공계열
	      $("#schFieldCd1").change();
      } else{
	      $("#schNameList2").val(data.DATA.schName);  // 학교명
	      $("#schNameList2").change();

	      $("#schDeptList2").val(data.DATA.schDept);  // 학과
	      $("#schDeptList2").change();

	      $("#schFieldCd2").val(data.DATA.schField);  // 전공계열
	      $("#schFieldCd2").change();
      }
     }else{
       setSchSupTypeCdCombo(data.DATA.schTypeCd,data.DATA.schSupTypeCd, schTypeCdObj.attr("note2") === "Y", data.DATA.schLocCd);
       $("#schSupTypeCd").val(data.DATA.schSupTypeCd);
       $("#famResNo").html("<option value='"+data.DATA.famResNo+"'>"+data.DATA.famNm+"</option>");
       $("#schLocCd").val(data.DATA.schLocCd);  // 국내/국외
	     $("#schNameList2").val(data.DATA.schName);  // 학교명
	     $("#schDeptList2").val(data.DATA.schDept);  // 학과
	     $("#schFieldCd2").val(data.DATA.schField);  // 전공계열
	     $("#schNameList2, #schDeptList2, #schFieldCd2").show();
	     $("#schNameList1, #schDeptList1, #schFieldCd1").hide();
     }
     $("#famNm").val(data.DATA.famNm);  // 가족명
     $("#famYmd").val(data.DATA.famYmd);  // 생년월일
     $("#birYmd").html(formatDate(data.DATA.famYmd,"-")); // 생년월일/성별
     $("#appYear").val(data.DATA.appYear); // 신청년도
     $("#divCd").val(data.DATA.divCd);   // 신청학기(분기)
     $("#schName").val(data.DATA.schName);  // 학교명
     $("#schDept").val(data.DATA.schDept);  // 학과명
     $("#schYear").val(data.DATA.schYear);  // 학년
     $("#schPoint").val(data.DATA.schPoint);  // 전학년 학점
     $("#schEntYm").val(formatDate(data.DATA.schEntYm,"-")); // 입학년월
     $("#applNote").val(data.DATA.applNote);  // 비고(신청)
     $("#meritYn").val(data.DATA.meritYn);  // 성적장학금수혜여부

     $("#intAmt").val(makeComma(data.DATA.intAmt)); // 입학금
     $("#intAmt_won").html( ( $("#intAmt").val() == "")?"":" 원"); // 입학금 원
     $("#atdAmt").val(makeComma(data.DATA.atdAmt)); // 등록금
     $("#atdAmt_won").html( ( $("#atdAmt").val() == "")?"":" 원"); // 등록금 원
     $("#stdAmt").val(makeComma(data.DATA.stdAmt)); // 학생회비
     $("#stdAmt_won").html( ( $("#stdAmt").val() == "")?"":" 원"); // 학생회비 원
     $("#applMon").val(makeComma(data.DATA.applMon)); // 신청금액
     $("#applMon_won").html( ( $("#applMon").val() == "")?"":" 원"); // 신청금액 원
     $("#meritAmt").val(makeComma(data.DATA.meritAmt)); // 성적장학금
     $("#meritAmt_won").html( ( $("#meritAmt").val() == "")?"":" 원"); // 성적장학금 원

     if( adminRecevYn == "Y" ){
      $("#payMon").val(makeComma(data.DATA.payMon));
      $("#payYm").val(formatDate(data.DATA.payYm, "-"));
     }

     if(authPg != "A") {
      convertReadModeForAppDet($("#searchForm"));
     }

    }
    break;
  }
 }

 //--------------------------------------------------------------------------------
 //  저장 시 필수 입력 및 조건 체크
 //--------------------------------------------------------------------------------
 function checkList(status) {
  var ch = true;
  // 화면의 개별 입력 부분 필수값 체크
  $(".required").each(function(index){
   let valid = true;
   if(($(this).val() == null || $(this).val() == "") && ($(this).css("display")!="none")){
    if($(this).attr("id")=="birYmd"){
     if($(this).html() != null || $(this).html() != ""){
      valid = true;
     }else{
      valid = false;
     }
    }else{
     valid = false;
    }
    if(!valid) {
     alert($(this).parent().prev().text() + "은(는) 필수값입니다.");
     $(this).focus();
     ch = false;
    }
   }

   return ch;
  });

  if( ch ){
   var params = "searchGubun=P&"+$("#searchForm").serialize();
   //학자금 체크
   var map = ajaxCall( "${ctx}/SchAppDet.do?cmd=getSchAppDupChk",params,false);
   if ( map != null && map.DATA != null ){
    if( map.DATA.msg != "OK" ){
     alert(replaceAll(map.DATA.msg,"/n","\n"));
     ch =  false;
     return false;
    }
   }
  }

  return ch;
 }


 //--------------------------------------------------------------------------------
 //  저장 시 필수 입력 및 조건 체크
 //--------------------------------------------------------------------------------
 function checkListAdmin(status) {
  var ch = true;

  if( $("#payMon").val() == "" ) return true;
  //년간한도 체크
  // var params = "searchGubun=A&searchApplSeq="+$("#searchApplSeq").val()
  //            + "&searchApplSabun="+$("#searchApplSabun").val()
  //            + "&schTypeCd="+$("#schTypeCd").val()
  //            + "&schSupTypeCd="+$("#schSupTypeCd").val()
  //            + "&famCd="+$("#famCd").val()
  //            + "&famYmd="+$("#famYmd").val()
  //            + "&famNm="+$("#famNm").val()
  //            + "&famResNo="+encodeURIComponent($("#famResNo").val())
  //            + "&appYear="+$("#appYear").val()
  //            + "&divCd="+$("#divCd").val()
  //            + "&applMon="+$("#applMon").val()
  //            + "&schLocCd="+$("#schLocCd").val();
  let $form = $("#searchForm");
  let $disabledElements = $form.find(":disabled").removeAttr("disabled");
  let params = "searchGubun=A&"+$("#searchForm").serialize();
  $disabledElements.attr("disabled", "disabled");
  let map = ajaxCall( "${ctx}/SchAppDet.do?cmd=getSchAppDupChk",params,false);

  if( map != null && map.DATA != null ){
   if( map.DATA.msg != "OK" ){
    ch =  false;
    alert(replaceAll(map.DATA.msg,"/n","\n"));
   }
  }else if(map.Message != null && map.Message != ""){
   ch = false;
   alert("결재 조건검사에 실패하였습니다.");
  }

  return ch;
 }
 //--------------------------------------------------------------------------------
 //  임시저장 및 신청 시 호출
 //--------------------------------------------------------------------------------
 function setValue(status) {

  //전송 전 잠근 계좌선택 풀기
  var returnValue = false;
  try {
  	if( adminRecevYn == "Y" ){ //관리자 수신담당자 경우 지급정보 저장
		  if( applStatusCd != "31") return true; //수신처리중이 아니면 저장 처리 하지 않음

		  //지급한도 체크
		  if (!checkListAdmin()) return false;
		  else returnValue = true;

    }else{
	    if ( authPg == "R" ) return true;
	    if ( !checkList()) return false;// 항목 체크 리스트

	    if( !$("#schPayYn").is(":checked") ) $("#schPayYnVal").val("N");
	    else $("#schPayYnVal").val("Y");
	    
	    //disabled false 처리
	    $("#intAmt").prop("disabled", false); //입학금
	    $("#stdAmt").prop("disabled", false); //학생회비

	    //disabled false 처리
	    $("#intAmt").prop("disabled", false); //입학금
	    $("#stdAmt").prop("disabled", false); //학생회비
	    
	    //저장
	    let data = ajaxCall("${ctx}/SchAppDet.do?cmd=saveSchAppDet", $("#searchForm").serialize(), false);
	    if(data.Result.Code < 1) {
	       alert(data.Result.Message);
				 returnValue = false;
	    }else{
				returnValue = true;
	    }

   	}

  } catch (ex){
   alert("Error!" + ex);
   returnValue = false;
  }

  makeGWhtml(); // 그룹웨어 html 세팅

  // console.log(gwHtml);
  // return false;


  return returnValue;
 }

////////////////////// GW 연동용 고정 변수//////////////////////////////////////
var gwTitleEtc 	= ""; //제목
var gwHtml 		= ""; //본문
////////////////////// GW 연동용 고정 변수//////////////////////////////////////
////////////////////// GW 연동용 HTML 작성(각 신청서별 수정) //////////////////////
function makeGWhtml(){
 // 경조휴가신청 :  공통에서 신청서 타이틀이 붙음
 //gwTitleEtc  = "[".concat($("#occCd option:selected").text()).concat("]").concat(etc02 + " (" + formatDate($("#occYmd").val(),"-") + ") ");
 gwTitleEtc = "- 자녀학자금신청제목테스트"
 //.concat(etc02 + " (" + formatDate(searchApplYmd,"-") + ") ");

 let userInfoOrgNm = window.parent.document.querySelector('.userInfoOrgNm');
 let userInfoName = window.parent.document.querySelector('.userInfoName');
 let userInfoApplYmd = window.parent.document.querySelector('.userInfoApplYmd');
 if(userInfoOrgNm && userInfoName && userInfoApplYmd) {
  let orgText = "-"+userInfoApplYmd.textContent.trim().substring(0,4) +"-"+ userInfoOrgNm.textContent.trim() +"-"+ userInfoName.textContent.trim();
  let cleanText = orgText.replace(/^['"]|['"]$/g, '');
  gwTitleEtc = cleanText;
 }

 gwHtml 		= "본문내용 테스트";

 if(authPg === "A" && "${ssnEnterCd}" === "KS") $("#gw_Ben_Appl_Info").css("display","block");
 //!etc01 &&
 // #TABLE CSS
 $("div").each(function() {
  if ($(this).css("display") === "none"|| $(this).prop("hidden")) {
   $(this).css("display","none");
  }
 });

 $("table, th, tr, td").each(function() {
  let tagName = this.tagName.toLowerCase();
  if ($(this).css("display") === "none" || $(this).prop("hidden")) {
   $(this).css("display","none");
  }
  if(tagName === "table" || tagName === "tr" ){
   $(this).css("border-collapse","collapse");
  }

  if(tagName === "td"){
   $(this).css("padding-left","10px");
   $(this).css("border","solid 1px #f2f2f2");
   $(this).css("border-spacing","0px");
   return;
  }
  if(tagName === "th"){
   $(this).css("border","solid 1px #f2f2f2");
   $(this).css("background-color","#fbfaf4");
   $(this).css("border-spacing","0px");
   return;
  }
 });

 // #INPUT
 $("input").each(function() {
  if($(this).val()){
   $(this).attr("value", $(this).val());
   $(this).css("border", 'none');
   $(this).css("background-color", "white");
  } else{
   $(this).css("display", "none");
  }

  if ($(this).is(":checked")) $(this).attr("checked", "checked");
  else $(this).removeAttr("checked");

  // disabled 필수
  $(this).attr("disabled","disabled");
 });

 // #IMG
 $("img").remove();

 // #TEXTAREA
 $("textarea").each(function() {
  $(this).text($(this).val());

  // disabled 필수
  $(this).attr("disabled","disabled");
  $(this).css("border", "none");
  $(this).css("background-color", "white");
 });

 $("select option").each(function() {
  $("select option").each(function(){$(this).prop("selected", $(this).is(":selected"));});
 });

 $("select").each(function() {
  if ($(this).css("display") !== "none" || !$(this).prop("hidden")) {
   $(this).removeAttr("style");
  }

  if(!$(this).val()) {
   $(this).css("display", "none");
  }

  let selectedText = $(this).find(':selected').text(); // 선택된 옵션의 텍스트 가져오기

  // 선택된 옵션의 텍스트가 존재하면
  if (selectedText.trim() !== "") {
   // 현재 select 요소의 HTML을 변경하여 span으로 대체
   let newSpan = $("<span>").text(selectedText);
   $(this).replaceWith(newSpan);
  }

  $(this).attr("disabled","disabled");
  $(this).css("border", "none");

 });


 $("checkbox").each(function() {
  if ($(this).is(":checked")) {
   $(this).attr("checked", "checked");
  } else {
   $(this).removeAttr("checked");
  }
 });

 $(".payInfo").css("display", "none");
 //
 gwHtml = $('#div_GW').html();
}
////////////////////// GW 연동용 HTML 작성(각 신청서별 수정) //////////////////////

 // 학자금지원세부구분 코드 콤보 셋팅
 function setSchSupTypeCdCombo(schTypeCd, schSupTypeCd, schGb, schLocCd) {
  let schSupTypeList = convCodeCols(ajaxCall("${ctx}/CommonCode.do?cmd=getCommonNSCodeList"
		  								, "queryId=getSchAppDetSupTypeList" + "&schTypeCd=" + schTypeCd+ "&schLocCd=" + schLocCd
		  																										+ "&useYn=Y"
		  																										+ ("${ssnEnterCd}" == "KS"? "&schSupTypeCd=" + schSupTypeCd : ""), false).codeList
		  								, "note1"
		  								, " ");//학자금지원구분(B60051)
  $("#schSupTypeCd").html(schSupTypeList[2]);

  setDivCdCombo(schTypeCd, schGb); // 학기
 }

 // 대학코드 콤보 셋팅
 function setSchNameCombo() {
  let schNameList = convCode(ajaxCall("${ctx}/CommonCode.do?cmd=getCommonNSCodeList&searchSchCd=" + $("#schTypeCd").val() + "&schLocCd=" + $("#schLocCd").val(), "queryId=getSchList", false).codeList, " ");
  $("#schNameList1").html(schNameList[2]);
 }

 // 대학별 학과코드 콤보 셋팅
 function setSchDeptCombo(schCd) {
  var param = "&schCd="+schCd;
  var schDeptList = convCodeMv(ajaxCall("${ctx}/CommonCode.do?cmd=getCommonNSCodeList", "queryId=getSchDeptList"+param, false).codeList, " ");
  $("#schDeptList1").html(schDeptList[2]);
 }

 // 대학별 전공계열명 콤보 셋팅
 function setSchFieldCdCombo(schCd, schDeptCd) {
  let param = "&schCd="+schCd + "&schDeptCd=" + schDeptCd
  	, schSchFieldCdList = convCode(ajaxCall("${ctx}/CommonCode.do?cmd=getCommonNSCodeList", "queryId=getSchFieldCdList"+param, false).codeList, "");
  $("#schFieldCd1").html(schSchFieldCdList[2]);
  $("#schFieldCd1").change();
 }

 // 학기 구분
 function setDivCdCombo(schCd, schGb) {
  let divCdLists =  convCode(ajaxCall("/CommonCode.do?cmd=getCommonNSCodeList"
		  											,"queryId=getCommonCodeList&grpCd=B60060&useYn=Y&note1=" + (schGb === "Y"? "Y":""), false).codeList, " ");
	$("#divCd").html(divCdLists[2]);
 }

 // 학년구분
 function setSchYearCombo(schSupTypeCd) {
  let param = "&grpCd=B20004&useYn=Y";
  const obj = $("#schSupTypeCd option:selected");
  const obj_schDeptList1 = $("#schDeptList1 option:selected");

  if(obj.attr("note1")){
   if(obj_schDeptList1.text().indexOf("간호")!=-1){ //대학&전문대, 간호학과 4학년 표출관련 추가
    param += "&note3=Y";
   }else if(obj.attr("note1") == "1") param += "&note1=Y"
   else if(obj.attr("note1") == "2") param += "&note2=Y"
   else if(obj.attr("note1") == "3") param += "&note3=Y"
   else if(obj.attr("note1") == "4") param += "&note4=Y"
  }
  let schYearLists =  convCode(ajaxCall("/CommonCode.do?cmd=getCommonNSCodeList" + param,"queryId=getCommonCodeList", false).codeList, " ");
  $("#schYear").html(schYearLists[2]);
 }

 // 국내 0 , 대학 20 인경우 대학 및 학과 콤보 처리
 function toggleSelectInput(){
  let locCd = $("#schLocCd").val()
  	, typeCd = $("#schTypeCd").val()
  	, schTypeObj = $("#schTypeCd option:selected")
  	;

  if((locCd=="0" || locCd=="1") && schTypeObj.attr("note2") == "Y"){
   if($("#schNameList1").css("display") =="none") {
    $(".schToggle").toggle();
    $(".schDeptToggle").toggle();
    $(".schFieldToggle").toggle();
   }

   selectMatchingItem();  // 국내외변경시 대학리스트 조회

  }else{
   if($("#schNameList1").css("display") !="none") {
    $(".schToggle").toggle();
    $(".schDeptToggle").toggle();
    $(".schFieldToggle").toggle();
   }
  }

  if(schTypeObj.attr("note2") !== "Y"){
		$("#schFieldCd2").hide();
		$("#schFieldCd2").val("");
  } else if(schTypeObj.attr("note2") == "Y" && (locCd=="0" || locCd=="1")){
		$("#schFieldCd2").hide();
		$("#schFieldCd2").val("");
  } else{
	  $("#schFieldCd2").show();
  }
 }


 function getYearLongToCd(yearLong) {
  switch(yearLong) {
   case '1.5':
    return 15;
   case '2':
    return 20;
   case '3':
    return 30;
   case '4':
    return 35;
   default:
    return null;
  }
 }
</script>

<style>

/*---- checkbox ----*/
input[type="checkbox"]  {
 display:inline-block; width:20px; height:20px; cursor:pointer; appearance:none;
  -moz-appearance:checkbox; -webkit-appearance:checkbox; margin-top:2px;background:none;
    border: 5px solid red;
}
label {
 vertical-align:-2px;padding-right:10px;
}

</style>
</head>
<body class="bodywrap">
<div class="wrapper">
 <form name="searchForm" id="searchForm" method="post">
  <input type="hidden" id="searchApplSabun" name="searchApplSabun" value=""/>
  <input type="hidden" id="searchApplName"  name="searchApplName"  value=""/>
  <input type="hidden" id="searchApplSeq"   name="searchApplSeq"   value=""/>
  <input type="hidden" id="searchApplYmd"   name="searchApplYmd"   value=""/>
  <input type="hidden" id="searchAuthPg"    name="searchAuthPg"    value=""/>
  <input type="hidden" id="searchSabun"     name="searchSabun"     value=""/>

  <input type="hidden" id="famNm"    		name="famNm"  value=""/>
  <input type="hidden" id="famYmd"   		name="famYmd" value=""/>
  <input type="hidden" id="schCd"   		name="schCd" value=""/>
  <input type="hidden" id="schName"   	name="schName" value=""/>
  <input type="hidden" id="schDeptCd"   name="schDeptCd" value=""/>
  <input type="hidden" id="schDept"   	name="schDept" value=""/>
  <input type="hidden" id="schFieldCd"  name="schFieldCd" value=""/>
  <input type="hidden" id="schField"   	name="schField" value=""/>

  <div id="div_GW">
  <div class="sheet_title">
   <ul>
    <li class="txt">신청내용</li>
   </ul>
  </div>

  <table class="table">
   <colgroup>
    <col style="width:120px"/>
    <col style="width:35%"/>
    <col style="width:120px" />
    <col />
   </colgroup>

   <tr>
    <th>학자금유형</th>
    <td colspan="3">
     <select id="schTypeCd" name="schTypeCd" class="${selectCss} ${required} " ${disabled}></select>
    </td>
   </tr>
   <tr>
    <th>대상자 명</th>
    <td>
     <select id="famResNo" name="famResNo" class="${selectCss} ${required} " ${disabled}></select>
    </td>
    <th>생년월일</th>
    <td>
     <div id="birYmd" class="${required}"></div>
    </td>
   </tr>
   <tr>
    <th>신청년도</th>
    <td>
     <input type="text" id="appYear" name="appYear" class="${textCss}  w40 ${required}" readonly maxlength="20"/>
    </td>
    <th>국내외</th>
    <td>
     <select id="schLocCd" name="schLocCd" class="${selectCss}" ${disabled} >
      <option value="0" selected>국내</option>
      <option value="1">국외</option>
     </select>
    </td>
   </tr>
   <tr>
    <th>학교명</th>
    <td colspan="3">
     <input type="text" id="searchSchNameList1" name="searchSchNameList1" class="${textCss} schToggle w200"/>
     <select id="schNameList1" name="schNameList1" class="${selectCss} ${required} schToggle"  ${disabled}></select>
     <input type="text" id="schNameList2" name="schNameList2" class="${textCss} ${required} w200 schToggle"  style="display:none"/>
    </td>
   </tr>
   <tr>
    <th id="schUnivGb">학과</th>
    <td>
     <select id="schDeptList1" name="schDeptList1" class="${selectCss} ${required} schDeptToggle" ${disabled}></select>
     <input type="text" id="schDeptList2" name="schDeptList2" class="${textCss} w150 ${required} schDeptToggle"  style="display:none"/>
     <select id="schFieldCd1" name="schFieldCd1" class="${selectCss} ${required} schFieldToggle" ${disabled}></select>
     <input type="text" id="schFieldCd2" name="schFieldCd2" class="${textCss} w150 ${required} schFieldToggle"  readOnly style="display:none"/>
    </td>
    <th>세부구분</th>
    <td>
     <select id="schSupTypeCd" name="schSupTypeCd" class="${selectCss} ${required} " ${disabled}></select>
    </td>
   <tr>
   <th>학년</th>
   <td>
    <select id="schYear" name="schYear" class="${selectCss} ${required}"></select>
   </td>
   <th>학기(분기)</th>
   <td>
    <select id="divCd" name="divCd" class="${selectCss} ${required}"></select>
   </td>
  </tr>
   <tr>
    <th>입학년월</th>
    <td>
     <input type="text" id="schEntYm" name="schEntYm" class="${dateCss} w80" readonly maxlength="10"/>
    </td>
    <th class="pointHidden">전학기 학점</th>
    <td class="pointHidden"><input type="text" id="schPoint" name="schPoint" class="pointHidden ${textCss} w100"  /></td>
   </tr>

   <tr>
    <th>입학금</th>
    <td>
     <input id="intAmt" name="intAmt" type="text" class="${textCss} w100 alignR" ${readonly}/><span id="intAmt_won"></span>
    </td>
    <th>등록금 <span class="atdamtHidden"> (실납입금액)</span></th>
    <td>
     <input id="atdAmt" name="atdAmt" type="text" class="${textCss} ${required} w100 alignR" ${readonly}/><span id="atdAmt_won"></span>
    </td>

   </tr>
   <tr>
    <th>학생회비${ssnEnterCd == "KS"?"(학교운영비)":""}</th>
    <td>
     <input id="stdAmt" name="stdAmt" type="text" class="${textCss}  w100 alignR" ${readonly}/><span id="stdAmt_won"></span>
    </td>
<c:if test="${ssnEnterCd == 'KS'}">
    <th>성적장학금수혜여부</th>
    <td>
     <select id="meritYn" name="meritYn" class="${selectCss} ${required}"></select>
    </td>
   </tr>
   <tr>
    <th>성적장학금</th>
    <td>
     <input id="meritAmt" name="meritAmt" type="text" class="${textCss} w100 alignR" readonly/><span id="meritAmt_won"></span>
    </td>
</c:if>
    <th>신청금액</th>
    <td>
     <input id="applMon" name="applMon" type="text" class="${textCss} w100 alignR" readonly/><span id="applMon_won"></span>
    </td>
   </tr>
   <tr>
    <th>비고</th>
    <td colspan="3">
     <input type="text" id="applNote" name="applNote" class="${textCss} w100p " ${readonly}/>
    </td>
   </tr>
   <tr>
    <td colspan="3" style="height:20px;border:solid 0px"></td>
   </tr>
   </table>
  </div>
 </form>
</div>

</body>
</html>
