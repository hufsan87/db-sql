package com.hr.common.interfaceIf.sys;

import java.io.FileReader;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.io.IOException;
import java.net.URLDecoder;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.GregorianCalendar;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.anyframe.util.DateUtil;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.ModelAndView;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hr.common.exception.HrException;
import com.hr.common.interfaceIf.olive.tim.IFTolivetimController;
import com.hr.common.interfaceIf.workday.ben.IFTbenController;
import com.hr.common.interfaceIf.workday.cpn.IFTcpnController;
import com.hr.common.interfaceIf.workday.hrm.IFThrmController;
import com.hr.common.interfaceIf.workday.org.IFTorgController;
import com.hr.common.interfaceIf.workday.sys.IFTsysController;
import com.hr.common.interfaceIf.workday.tim.IFTtimController;
import com.hr.common.language.LanguageUtil;
import com.hr.common.logger.Log;
import com.hr.common.other.OtherService;
import com.hr.common.popup.pwrSrchResultPopup.PwrSrchResultPopupService;
import com.hr.common.util.HttpUtils;
import com.hr.common.util.RSA;
import com.hr.common.util.StringUtil;
import com.hr.main.login.LoginService;

/**
 * Interface Controller 
 * 
 * @author 이름
 *
 */
@Controller
@RequestMapping("/InterfaceController.do")
public class InterfaceController {
	
	@Inject
	@Named("LoginService")
	private LoginService loginService;
	
	@Inject
	@Named("OtherService")
	private OtherService otherService;
	
	@Inject
	@Named("InterfaceService")
	public InterfaceService interfaceService;

	@Inject
	@Named("IFTorgController")
	public IFTorgController iFTorgController;
	
	@Inject
	@Named("IFThrmController")
	public IFThrmController iFThrmController;

	@Inject
	@Named("IFTbenController")
	public IFTbenController iFTbenController;
	
	@Inject
	@Named("IFTcpnController")
	public IFTcpnController iFTcpnController;
	
	@Inject
	@Named("IFTolivetimController")
	public IFTolivetimController iFTolivetimController;
	
	@Inject
	@Named("IFTtimController")
	public IFTtimController iFTtimController;
	
	@Inject
	@Named("IFTsysController")
	public IFTsysController iFTsysController;
	
	@Inject
	@Named("PwrSrchResultPopupService")
	private PwrSrchResultPopupService pwrSrchResultPopupService;

	@Inject
	@Named("HttpUtils")
	private HttpUtils httpUtils;
	

	@Value("#{opti['google.apigee.enter']}")			  		private String cEnterCd;			//인터페이스용 시스템 정보를 위한 코드
	@Value("#{opti['google.apigee.url']}") 				  		private String googleApigeeUrl;	//apigee uri
	@Value("#{opti['google.apigee.client.accessToken.path']}") 	private String accessTokenPath;	//apigee accessToken
	@Value("#{opti['google.apigee.client.id']}") 		  		private String apigeeClientId;	//apigee client_id
	@Value("#{opti['google.apigee.client.secret']}") 	  		private String apigeeClientSecret;//apigee client_secret
	@Value("#{opti['google.apigee.grant.type']}")         		private String apigeeGrantType;   //apigee grant_type
	
	@Value("#{opti['google.apigee.api.org105']}") 		private String apiOrg105;	    //조직정보 api
	@Value("#{opti['google.apigee.api.hrm100']}") 		private String apiHrm100;		//인사마스터 api
	@Value("#{opti['google.apigee.api.hrm112']}") 		private String apiHrm112;		//인사마스터(파견) api
	@Value("#{opti['google.apigee.api.hrm111']}") 		private String apiHrm111;		//가족사항 api
	@Value("#{opti['google.apigee.api.hrm192']}") 		private String apiHrm192;		//발령정보 api
	@Value("#{opti['google.apigee.api.hrm193']}") 		private String apiHrm193;		//휴직정보 api
	@Value("#{opti['google.apigee.api.hrm194']}") 		private String apiHrm194;		//복직정보 api
	@Value("#{opti['google.apigee.api.hrm195']}") 		private String apiHrm195;		//징계사항 api
	@Value("#{opti['google.apigee.api.hrm196']}") 		private String apiHrm196;		//수습사항 api
	@Value("#{opti['google.apigee.api.hrm197']}") 		private String apiHrm197;		//계약사항 api
	@Value("#{opti['google.apigee.api.hrm911']}") 		private String apiHrm911;		//개인사진 api
	@Value("#{opti['google.apigee.api.hrm911.list']}")	private String apiHrm911List;	//개인사진 Interface 대상자 api /2023.11.06 추가
	@Value("#{opti['google.apigee.api.cpn429']}") 		private String apiCpn429;		//수당발령 api
	@Value("#{opti['google.apigee.api.cpn493']}") 		private String apiCpn493;		//평가결과 api
	@Value("#{opti['google.apigee.api.ben592']}") 		private String apiBen592;		//생수불출내역 api
	@Value("#{opti['google.apigee.api.tim112']}") 		private String apiTim112;		//한국공항 부서근무조스케줄 api
	@Value("#{opti['google.apigee.api.tim301.etc']}")	private String apiTim301Etc;	//한진정보통신 출장,교육 api
	@Value("#{opti['google.apigee.api.tim331']}") 		private String apiTim331;		//한진정보통신 타각 api

    @Value("#{opti['google.apigee.api.tim331_kaltour']}") 		private String apiTim331_kaltour;		//한진관광 타각 api

	@Value("#{opti['google.apigee.api.data.type']}") 	private String dataType;		//응답데이타 type
	
	@Value("#{opti['olive.api.url']}") 					private String oliveUrl;		//olive url
	@Value("#{opti['olive.api.appId']}") 				private String oliveAppId;		//olive appId
	@Value("#{opti['olive.api.srchSeq']}") 				private String srchSeq;		    //olive 포인트 대상자 조건검색 번호
	
	//String  fileNm_THRM192 = "RT-INT-HR-002_Staffing_Transaction_Report";
	String  fileNm_TORG105 = "RT-INT-HR-006a_Full_Supervisory_Organization_Outbound";
	String  fileNm_THRM100 = "RT-INT-HR-001_Worker_Personal_Data";
	String  fileNm_THRM192 = "RT-INT-HR-002_All_Staffing_Transaction";
	String  fileNm_THRM193 = "RT-INT-HR-002b_All_LoA_Transaction";
	String  fileNm_THRM194 = "RT-INT-HR-002b_All_RFL_Transaction";
	String  fileNm_THRM195 = "RT-INT-HR-010_All_Disciplinary_Action_Outbound";
	String  fileNm_THRM196 = "RT-INT-HR-002d_All_Manage_Probation_Period";
	String  fileNm_THRM197 = "RT-INT-HR-002d_All_Employee_Contract_Outbound";
	String  fileNm_THRM911 = "RT-INT-HR-001a_Photo_Data";
	
	boolean dbProcCall = true; //DB 프로시져 실행여부
	
	private String accessToken  = null; //agigee accessToke
	private String expireSecond = null; //accessToken expire time(second)
	private String tokenType    = null; //accessToken token Type
	
	/**
	 * apigee accessToken 발행
	 * @param session
	 * @return
	 * @throws Exception
	 */
	private String getAccessToken(HttpSession session) throws Exception {
		
		Log.DebugStart();
		
		try {

			// 포맷변경 ( 년월일 시분초)
			SimpleDateFormat formatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss"); 
			Calendar todayCal = Calendar.getInstance();
			Date date = new Date();
			todayCal.setTime(date);
			
			//토큰 존재 여부 체크
			if(session.getAttribute("accessToken") != null) {
				accessToken = StringUtil.stringValueOf(session.getAttribute("accessToken"));
				tokenType 	= StringUtil.stringValueOf(session.getAttribute("tokenType"));
				//expire 시간 체크
				if(session.getAttribute("expired_date") != null) {
					
					Date expireDate = formatter.parse(session.getAttribute("expired_date").toString());
					Calendar expireCal = Calendar.getInstance();        
					expireCal.setTime(expireDate);     
					// 만료시간 이전이면 기존 accessToken 리턴
					if(todayCal.before(expireCal)) {
						return accessToken;
					}
				}
			}
			
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("grant_type", 	apigeeGrantType);
			paramMap.put("client_id", 	apigeeClientId);
			paramMap.put("client_secret", apigeeClientSecret);

			Log.Debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
			Log.Debug("accessTokenUrl  		: " + googleApigeeUrl+accessTokenPath);
			Log.Debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
			
			ResponseEntity<Map> responseEntity = httpUtils.getRestTemplateMap(googleApigeeUrl+accessTokenPath, paramMap);	
			
			if(responseEntity.getStatusCodeValue() == 200) {
				accessToken 		= responseEntity.getBody()!=null?responseEntity.getBody().get("access_token").toString():"";
				tokenType 			= responseEntity.getBody()!=null?responseEntity.getBody().get("token_type").toString():"";
				int expireSecond   	= Integer.parseInt(responseEntity.getBody()!=null?responseEntity.getBody().get("expires_in").toString():"0");
				
				// 만료시간 더하기
				todayCal.add(Calendar.MINUTE, (expireSecond/60));
				//todayCal.add(Calendar.MINUTE, (60/60));
				session.setAttribute("expired_date", formatter.format(todayCal.getTime()));			
				session.setAttribute("accessToken" , accessToken);				
				session.setAttribute("tokenType"   , tokenType);				
			}
			
		}catch(Exception e){
			Log.Error("Error : "+e.toString());
			
			throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}	
		
		Log.DebugEnd();
		
		return accessToken;
	}
	
	
	/**
	 * web 브라우져에서 호출 or 스케쥴 시 api 건별 호출
	 * @param session
	 * @param request
	 * @param paramMap
	 * @return
	 * @throws Exception
	 */
	@RequestMapping(params = "cmd=apigee-call", method={ RequestMethod.GET, RequestMethod.POST })
	public ModelAndView  apigeeCall(HttpSession session, HttpServletRequest request,
			@RequestParam Map<String, Object> paramMap) throws Exception {
		
		Log.DebugStart();
		
		ModelAndView mv = new ModelAndView();
		mv.setViewName("jsonView");
		mv.addObject("Result", "OK");

		try {
			////////////////////////////////////
			//accessToken 처리
			////////////////////////////////////
			getAccessToken(session);
			
			String ssnEnterCd 	= StringUtil.stringValueOf(session.getAttribute("ssnEnterCd"));
			String ssnSabun 	= StringUtil.stringValueOf(session.getAttribute("ssnSabun"));
			
			//세션 사번이 없으면 세션을 강제로 생성
			if (ssnSabun.length() == 0) {
				
				//Interceptor 처리용 세션 강제 매핑
				paramMap.put("loginEnterCd", cEnterCd);
		  		Map<String,String> SystemOptMap = (Map<String, String>) loginService.systemOption(paramMap);

		  		setSystemOptionsToSession(SystemOptMap, session);
		  		
				ssnEnterCd 	= cEnterCd;
				ssnSabun 	= "scheduler";
				
				// ehr token 및 RSA 처리
				setEHRToken(session, request);
			}
			
			Log.Debug("============================================================");
			Log.Debug("=== ssnSabun : " +ssnSabun);
			Log.Debug("=== ssnEnterCd : " +ssnEnterCd);
			Log.Debug("============================================================");
			
			
			boolean get 	= request.getMethod().equals("GET");
			boolean post 	= request.getMethod().equals("POST");
			
			SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd");
			Date now 		= new Date();
			Calendar cal = new GregorianCalendar(Locale.KOREA);
			cal.setTime(now);
			String today 	= format.format(cal.getTime());
			//하루 전 
			cal.add(Calendar.DATE, -1);
			String yesterday 	= format.format(cal.getTime());
			
			//요청회사
			String reqEnterCd 	= null;
			if(paramMap.get("enter-cd") 	!= null) reqEnterCd 	= paramMap.get("enter-cd").toString();
			//요청작업
			String jobId 	= null;
			if(paramMap.get("job-id") 	!= null) jobId 			= paramMap.get("job-id").toString();
			//요청시작일자
			String fromDate 	= null;
			if(paramMap.get("fromDate") 	!= null) { 
				fromDate 		= paramMap.get("fromDate").toString();
			}else {
				fromDate = yesterday;
			}
			//요청종료일자
			String toDate 	= null;
			if(paramMap.get("toDate") 	!= null) { 
				toDate 		= paramMap.get("toDate").toString();
			}else {
				toDate = today;
			}
			
			//대상자
			String sabun 	= null;
			if(paramMap.get("sabun") 	!= null) sabun 			= paramMap.get("sabun").toString();
	
			String paramStr = "";
	
			Log.Debug("XXXXXXXXXXXXXXXX cmd=apigee-call XXXXXXXXXXXXXXXXX");
			Log.Debug("get  		: " + get);
			Log.Debug("post 		: " + post);
			Log.Debug("paramMap 	: " + paramMap);
			Log.Debug("enter-cd     : " + reqEnterCd);
			Log.Debug("job-id 	    : " + jobId);
			Log.Debug("fromDate 	: " + fromDate);
			Log.Debug("toDate 	    : " + toDate);
			Log.Debug("sabun 	    : " + sabun);
			Log.Debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
			///////////////////////////////////////////////////////////////////////////////		
			
			if(jobId != null) {
				
				//조직정보
				if(jobId.equals("INT_TORG105")) {					

					paramStr = "";
					paramStr = "Company_ID="+reqEnterCd;
					runInterfaceTORG105(paramStr, reqEnterCd, ssnSabun, request );					
					
				//인사정보	
				}else if(jobId.equals("INT_THRM100")) {

					paramStr = "";
					paramStr = paramStr+"Company_ID="+reqEnterCd;

					if(sabun != null) {
						paramStr = paramStr+"&Employee_ID="+sabun;
					}else {
						if(StringUtil.null2Blank(paramMap.get("webFlag")).equals("Y")) { //WEB 브라우져에서 호출되고
							fromDate = DateUtil.addDays(fromDate,1); toDate = DateUtil.addDays(toDate,1); //workday PST 오차에 따른
						}
						paramStr = paramStr+"&Start_Updated="+fromDate;
						paramStr = paramStr+"&End_Updated="+toDate;
					}

					runInterfaceTHRM100(paramStr, reqEnterCd, ssnSabun, request);					
	
				//인사정보(파견)	
				}else if(jobId.equals("INT_THRM112")) {

					paramStr = "";
					paramStr = paramStr+"Company_ID="+reqEnterCd;
					paramStr = paramStr+"&Effective_Date="+fromDate;
					if(sabun != null) {
						paramStr = paramStr+"&Employee_ID="+sabun;
					}
					runInterfaceTHRM112(paramStr, reqEnterCd, ssnSabun, request);					
					
				//가족사항	
				}else if(jobId.equals("INT_THRM111")) {
					if(StringUtil.null2Blank(paramMap.get("webFlag")).equals("Y")) { //WEB 브라우져에서 호출되고
						fromDate = DateUtil.addDays(fromDate,1); toDate = DateUtil.addDays(toDate,1); //workday PST 오차에 따른
					}
					runInterfaceTHRM111(paramStr, reqEnterCd, fromDate, toDate, sabun, ssnSabun, request);
					
				//발령정보	
				}else if(jobId.equals("INT_THRM192")) {
					if(StringUtil.null2Blank(paramMap.get("webFlag")).equals("Y")) { //WEB 브라우져에서 호출되고
						fromDate = DateUtil.addDays(fromDate,1); toDate = DateUtil.addDays(toDate,1); //workday PST 오차에 따른
					}
					runInterfaceTHRM192(reqEnterCd, fromDate, toDate, sabun, ssnSabun, request);
					
				//휴직정보	
				}else if(jobId.equals("INT_THRM193")) {
					if(StringUtil.null2Blank(paramMap.get("webFlag")).equals("Y")) { //WEB 브라우져에서 호출되고
						fromDate = DateUtil.addDays(fromDate,1); toDate = DateUtil.addDays(toDate,1); //workday PST 오차에 따른
					}
					runInterfaceTHRM193(-1, reqEnterCd, fromDate, toDate, sabun, ssnSabun, request);
					
				//복직정보	
				}else if(jobId.equals("INT_THRM194")) {
					if(StringUtil.null2Blank(paramMap.get("webFlag")).equals("Y")) { //WEB 브라우져에서 호출되고
						fromDate = DateUtil.addDays(fromDate,1); toDate = DateUtil.addDays(toDate,1); //workday PST 오차에 따른
					}
					runInterfaceTHRM194(-1, reqEnterCd, fromDate, toDate, sabun, ssnSabun, request);
					
				//징계	
				}else if(jobId.equals("INT_THRM195")) {
					if(StringUtil.null2Blank(paramMap.get("webFlag")).equals("Y")) { //WEB 브라우져에서 호출되고
						fromDate = DateUtil.addDays(fromDate,1); toDate = DateUtil.addDays(toDate,1); //workday PST 오차에 따른
					}
					runInterfaceTHRM195(-1, reqEnterCd, fromDate, toDate, sabun, ssnSabun, request);
					
				//수습	
				}else if(jobId.equals("INT_THRM196")) {
					if(StringUtil.null2Blank(paramMap.get("webFlag")).equals("Y")) { //WEB 브라우져에서 호출되고
						fromDate = DateUtil.addDays(fromDate,1); toDate = DateUtil.addDays(toDate,1); //workday PST 오차에 따른
					}
					runInterfaceTHRM196("", reqEnterCd, fromDate, toDate, sabun, ssnSabun, request);
					
				//계약
				}else if(jobId.equals("INT_THRM197")) {
					if(StringUtil.null2Blank(paramMap.get("webFlag")).equals("Y")) { //WEB 브라우져에서 호출되고
						fromDate = DateUtil.addDays(fromDate,1); toDate = DateUtil.addDays(toDate,1); //workday PST 오차에 따른
					}
					runInterfaceTHRM197("", reqEnterCd, fromDate, toDate, sabun, ssnSabun, request);
					
				//개인사진	인터페이스 대상자
				}else if(jobId.equals("INT_THRM911_LIST")) {
					paramStr = "";
					
					paramStr = paramStr+"Company_ID="+reqEnterCd;
					if(sabun != null) {
						paramStr = paramStr+"&Employee_ID="+sabun;
					}
					
					if(StringUtil.null2Blank(paramMap.get("webFlag")).equals("Y")) { //WEB 브라우져에서 호출되고
						fromDate = DateUtil.addDays(fromDate,1); toDate = DateUtil.addDays(toDate,1); //workday PST 오차에 따른
					}
					
					paramStr = paramStr+"&Completed_Date_On_or_After="+fromDate;
					paramStr = paramStr+"&Completed_Date_On_or_Before="+toDate;
					
					runInterfaceTHRM911List(paramStr, reqEnterCd, ssnSabun, request);
					
				//수당발령	
				}else if(jobId.equals("INT_TCPN429")) {
					paramStr = "";
					
					paramStr = paramStr+"Company_ID="+reqEnterCd;
					if(sabun != null) {
						paramStr = paramStr+"&Employee_ID="+sabun;
					}
					
					runInterfaceTCPN429(paramStr, reqEnterCd, ssnSabun, request);
					
				//생수불출내역	
				}else if(jobId.equals("INT_TBEN592")) {
					paramStr = "";
					
					//paramStr = paramStr+"Company_ID="+enterCd;
					paramStr = paramStr+"p_yymm="+toDate.replaceAll("-", "");
					if(sabun != null) {
						paramStr = paramStr+"&p_empno="+sabun;
					}
					runInterfaceTBEN592(paramStr, reqEnterCd, ssnSabun, request);
			
				//한국공항 조업
				}else if(jobId.equals("INT_TTIM112")) {
					paramStr = "";
					
					//paramStr = paramStr+"Company_ID="+enterCd;
					//paramStr = paramStr+"p_workDate="+fromDate.replaceAll("-", "");
					paramStr = paramStr+"p_fromDate="+fromDate.replaceAll("-", "").substring(0,6)+"01"; //해당월 1일부터 호출
					paramStr = paramStr+"&p_toDate="+DateUtil.addDays(fromDate,30).replaceAll("-", "");
					
					runInterfaceTTIM112(paramStr, reqEnterCd, ssnSabun, request);
					
				//한진정보통신 출장교육
				}else if(jobId.equals("INT_TTIM301_ETC")) {
					paramStr = "";

//					String startDate = LocalDate.now().minusDays(5).format(DateTimeFormatter.ofPattern("yyyyMMdd"));
//					paramStr = paramStr+"chkStartDate="+startDate;

                    String startDate = LocalDate.now(ZoneId.of("Asia/Seoul")).minusDays(5)
                            .format(DateTimeFormatter.ofPattern("yyyyMMdd", Locale.US));  // 명시적으로 Locale 지정
                    paramStr = paramStr + "chkStartDate=" + startDate;
					//paramStr = paramStr+"Company_ID="+enterCd;
                    //paramStr = paramStr+"chkStartDate="+fromDate.replaceAll("-", "");

					paramStr = paramStr+"&chkEndDate="+toDate.replaceAll("-", "");
					if(sabun != null) {
						paramStr = paramStr+"&sabun="+sabun;
					}
					runInterfaceTTIM301Etc(paramStr, reqEnterCd, ssnSabun, request);
				
				//한진정보통신 타각
				}else if(jobId.equals("INT_TTIM331")) {
					paramStr = "";
					
					//paramStr = paramStr+"Company_ID="+enterCd;
					paramStr = paramStr+"bb13Date="+toDate.replaceAll("-", "");
					if(sabun != null) {
						paramStr = paramStr+"&bb13Sbn="+sabun;
					}
					runInterfaceTTIM331(paramStr, reqEnterCd, ssnSabun, request);
				} //JJH
				else if(jobId.equals("INT_TTIM331_HT")) {
					paramStr = "";

					//paramStr = paramStr+"Company_ID="+enterCd;
					paramStr = paramStr+"attdate="+toDate.replaceAll("-", "");
					if(sabun != null) {
						paramStr = paramStr+"&empnum="+sabun;
					}
					runInterfaceTTIM331_kaltour(paramStr, reqEnterCd, ssnSabun, request);
				}
			
			    /////////////////////////////////////////////////// 삭제 ////////////////////////////////////////////
				//조직정보 PJ Migration용 	
				if(jobId.equals("INT_TORG105_MIG")) {
					try{ runInterfaceTORG105_MIG("Company_ID=HG", "HG", "mig", fileNm_TORG105+"-HG");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTORG105_MIG("Company_ID=HX", "HX", "mig", fileNm_TORG105+"-HX");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTORG105_MIG("Company_ID=KS", "KS", "mig", fileNm_TORG105+"-KS");     }catch(HrException e){ Log.Error(e.toString());}
				}
				
				//발령정보 PJ Migration용 	
				if(jobId.equals("INT_THRM100_MIG")) {
					try{ runInterfaceTHRM100_MIG("Company_ID=HG", "HG", "mig", fileNm_THRM100+"-HG");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM100_MIG("Company_ID=HX", "HX", "mig", fileNm_THRM100+"-HX");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM100_MIG("Company_ID=KS", "KS", "mig", fileNm_THRM100+"-KS");     }catch(HrException e){ Log.Error(e.toString());}
					//try{ runInterfaceTHRM100_MIG("Company_ID=KS", "KS", "mig", "RT-INT-HR-001_Worker_Personal_Data.json_KS_20231115140000");     }catch(HrException e){ Log.Error(e.toString());}
				}
				
				//발령정보 PJ Migration용 	
				if(jobId.equals("INT_THRM192_MIG")) {
					try{ runInterfaceTHRM192_MIG("Company_ID=HG", "HG", "mig", fileNm_THRM192+"-HG");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM192_MIG("Company_ID=HX", "HX", "mig", fileNm_THRM192+"-HX");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM192_MIG("Company_ID=KS", "KS", "mig", fileNm_THRM192+"-KS");     }catch(HrException e){ Log.Error(e.toString());}
				}
				
				//휴복직정보(휴직) PJ Migration용 	
				if(jobId.equals("INT_THRM193_MIG")) {
					try{ runInterfaceTHRM193_MIG(1, "Company_ID=HG", "HG", "mig", fileNm_THRM193+"-HG");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM193_MIG(2, "Company_ID=HX", "HX", "mig", fileNm_THRM193+"-HX");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM193_MIG(3, "Company_ID=KS", "KS", "mig", fileNm_THRM193+"-KS");     }catch(HrException e){ Log.Error(e.toString());}
				}
				//휴복직정보(복직) PJ Migration용 	
				if(jobId.equals("INT_THRM194_MIG")) {
					try{ runInterfaceTHRM194_MIG(1, "Company_ID=HG", "HG", "mig", fileNm_THRM194+"-HG");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM194_MIG(2, "Company_ID=HX", "HX", "mig", fileNm_THRM194+"-HX");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM194_MIG(3, "Company_ID=KS", "KS", "mig", fileNm_THRM194+"-KS");     }catch(HrException e){ Log.Error(e.toString());}
				}
				//징계 Migration용 	
				if(jobId.equals("INT_THRM195_MIG")) {
					try{ runInterfaceTHRM195_MIG(1, "Company_ID=HG", "HG", "mig", fileNm_THRM195+"-HG");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM195_MIG(2, "Company_ID=HX", "HX", "mig", fileNm_THRM195+"-HX");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM195_MIG(3, "Company_ID=KS", "KS", "mig", fileNm_THRM195+"-KS");     }catch(HrException e){ Log.Error(e.toString());}
				}
				//수습 Migration용 	
				if(jobId.equals("INT_THRM196_MIG")) {
					try{ runInterfaceTHRM196_MIG(1, "Company_ID=HG", "HG", "mig", fileNm_THRM196+"-HG");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM196_MIG(2, "Company_ID=HX", "HX", "mig", fileNm_THRM196+"-HX");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM196_MIG(3, "Company_ID=KS", "KS", "mig", fileNm_THRM196+"-KS");     }catch(HrException e){ Log.Error(e.toString());}
				}
				//계약 Migration용 	
				if(jobId.equals("INT_THRM197_MIG")) {
					try{ runInterfaceTHRM197_MIG(1, "Company_ID=HG", "HG", "mig", fileNm_THRM197+"-HG");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM197_MIG(2, "Company_ID=HX", "HX", "mig", fileNm_THRM197+"-HX");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM197_MIG(3, "Company_ID=KS", "KS", "mig", fileNm_THRM197+"-KS");     }catch(HrException e){ Log.Error(e.toString());}
				}
				//개인사진 PJ Migration용 	
				if(jobId.equals("INT_THRM911_MIG")) {
					try{ runInterfaceTHRM911MIG("Company_ID=HG", "HG", "mig", fileNm_THRM911+"-HG");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM911MIG("Company_ID=HX", "HX", "mig", fileNm_THRM911+"-HX");     }catch(HrException e){ Log.Error(e.toString());}
					try{ runInterfaceTHRM911MIG("Company_ID=KS", "KS", "mig", fileNm_THRM911+"-KS");     }catch(HrException e){ Log.Error(e.toString());}
				}
	            /////////////////////////////////////////////////// 삭제 ////////////////////////////////////////////
			}

		}catch(Exception e){
			Log.Error("============================================================");
			Log.Error(e.toString());
			Log.Error("============================================================");
			mv.addObject("Result", "Error");
			mv.addObject("error", e.toString());
		}
		
		Log.DebugEnd();
		return mv;
	}
	
	/**
	 * WEB 브라우져 로그에서 apigee api Recall
	 * @param session
	 * @param request
	 * @param paramMap
	 * @return
	 * @throws Exception
	 */
	@RequestMapping(params = "cmd=apigee-re-call", method={ RequestMethod.GET, RequestMethod.POST })
	public ModelAndView  apigeeReCall(HttpSession session, HttpServletRequest request,
			@RequestParam Map<String, Object> paramMap) throws Exception {
		
		Log.DebugStart();
		
		ModelAndView mv = new ModelAndView();
		mv.setViewName("jsonView");
		mv.addObject("Result", "OK");
		
		try {
			////////////////////////////////////
			//accessToken 처리
			////////////////////////////////////
			getAccessToken(session);
			
			String ssnEnterCd 	= StringUtil.stringValueOf(session.getAttribute("ssnEnterCd"));
			String ssnSabun 	= StringUtil.stringValueOf(session.getAttribute("ssnSabun"));
			
			//세션 사번이 없으면 세션을 강제로 생성
			if (ssnSabun.length() == 0) {
				
				//Interceptor 처리용 세션 강제 매핑
				paramMap.put("loginEnterCd", cEnterCd);
				Map<String,String> SystemOptMap = (Map<String, String>) loginService.systemOption(paramMap);
				setSystemOptionsToSession(SystemOptMap, session);
				
				ssnEnterCd 	= cEnterCd;
				ssnSabun 	= "scheduler";
				
				// ehr token 및 RSA 처리
				setEHRToken(session, request);
			}
			
			Log.Debug("============================================================");
			Log.Debug("=== ssnSabun : " +ssnSabun);
			Log.Debug("=== ssnEnterCd : " +ssnEnterCd);
			Log.Debug("============================================================");
			
			
			//요청작업
			String jobId 	= null;
			if(paramMap.get("job-id") 	!= null) jobId 			= paramMap.get("job-id").toString();
			//요청 파라메터 
			String paramStr 	= "";
			//요청회사
			String reqEnterCd 	= null;
			if(paramMap.get("paramStr") 	!= null) {
				//paramStr 			= paramMap.get("paramStr").toString();
				paramStr 			= URLDecoder.decode((String)paramMap.get("paramStr"), "UTF-8");;
				paramStr            = paramStr.substring(paramStr.indexOf("?")+1);
				//회사코드 찾기
				reqEnterCd 			= getParamEnterCd(paramStr);
			}
			
			Log.Debug("XXXXXXXXXXXXXXXX cmd=apigee-re-call XXXXXXXXXXXXXXXXX");
			Log.Debug("paramMap 	: " + paramMap);
			Log.Debug("enter-cd     : " + reqEnterCd);
			Log.Debug("jobId 	    : " + jobId);
			Log.Debug("paramStr 	: " + paramStr);
			Log.Debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
			///////////////////////////////////////////////////////////////////////////////		
			
			if(jobId != null) {
				
				//조직정보
				if(jobId.equals("INT_TORG105")) {					
					runInterfaceTORG105(paramStr, reqEnterCd, ssnSabun, request );
					
				//인사정보	
				}else if(jobId.equals("INT_THRM100")) {
					runInterfaceTHRM100(paramStr, reqEnterCd, ssnSabun, request);					
					
				//인사정보(파견)	
				}else if(jobId.equals("INT_THRM112")) {
					runInterfaceTHRM112(paramStr, reqEnterCd, ssnSabun, request);					
					
				//가족사항	
				}else if(jobId.equals("INT_THRM111")) {
					runInterfaceTHRM111(paramStr, reqEnterCd, "", "", "", ssnSabun, request);
					
				//발령정보	
				}else if(jobId.equals("INT_THRM192")) {
					int intfSeq 	= -1;
					if(paramMap.get("intf-seq") 	!= null) intfSeq 			= Integer.parseInt(paramMap.get("job-id").toString());
					runInterfaceTHRM192_RE(paramStr, intfSeq, reqEnterCd, "", "", "", ssnSabun, request);
					
				//휴직정보	
				}else if(jobId.equals("INT_THRM193")) {
					int intfSeq 	= -1;
					if(paramMap.get("intf-seq") 	!= null) intfSeq 			= Integer.parseInt(paramMap.get("job-id").toString());
					runInterfaceTHRM193_RE(paramStr, intfSeq, reqEnterCd, "", "", "", ssnSabun, request);
					
				//복직정보	
				}else if(jobId.equals("INT_THRM194")) {
					int intfSeq 	= -1;
					if(paramMap.get("intf-seq") 	!= null) intfSeq 			= Integer.parseInt(paramMap.get("job-id").toString());
					runInterfaceTHRM194_RE(paramStr, -1, reqEnterCd, "", "", "", ssnSabun, request);
					
				//징계	
				}else if(jobId.equals("INT_THRM195")) {
					int intfSeq 	= -1;
					if(paramMap.get("intf-seq") 	!= null) intfSeq 			= Integer.parseInt(paramMap.get("job-id").toString());
					runInterfaceTHRM195_RE(paramStr, -1, reqEnterCd, "", "", "", ssnSabun, request);
					
				//수습	
				}else if(jobId.equals("INT_THRM196")) {
					runInterfaceTHRM196(paramStr, reqEnterCd, "", "", "", ssnSabun, request);
					
				//계약
				}else if(jobId.equals("INT_THRM197")) {
					runInterfaceTHRM197(paramStr, reqEnterCd, "", "", "", ssnSabun, request);
					
				//개인사진	인터페이스
				}else if(jobId.equals("INT_THRM911")) {
					runInterfaceTHRM911_RE(paramStr, reqEnterCd, ssnSabun, request);
					
					//개인사진	인터페이스 대상자
				}else if(jobId.equals("INT_THRM911_LIST")) {
					runInterfaceTHRM911List(paramStr, reqEnterCd, ssnSabun, request);
					
				//수당발령	
				}else if(jobId.equals("INT_TCPN429")) {
					runInterfaceTCPN429(paramStr, reqEnterCd, ssnSabun, request);
					
				//생수불출내역	
				}else if(jobId.equals("INT_TBEN592")) {
					runInterfaceTBEN592(paramStr, reqEnterCd, ssnSabun, request);
					
				//한국공항 조업
				}else if(jobId.equals("INT_TTIM112")) {
					runInterfaceTTIM112(paramStr, reqEnterCd, ssnSabun, request);
					
				//한진정보통신 출장교육
				}else if(jobId.equals("INT_TTIM301_ETC")) {
					runInterfaceTTIM301Etc(paramStr, reqEnterCd, ssnSabun, request);
					
				//한진정보통신 타각
				}else if(jobId.equals("INT_TTIM331")) {
					runInterfaceTTIM331(paramStr, reqEnterCd, ssnSabun, request);
				}
				else if(jobId.equals("INT_TTIM331_HT")) {
					runInterfaceTTIM331_kaltour(paramStr, reqEnterCd, ssnSabun, request);
				}
			}
			
		}catch(Exception e){
			Log.Error("============================================================");
			Log.Error(e.toString());
			Log.Error("============================================================");
			mv.addObject("Result", "Error");
			mv.addObject("error", e.toString());
		}
		
		Log.DebugEnd();
		return mv;
	}
	
	
	/**
	 * 한진정보통신 출장 교육 호출
	 * @param session
	 * @param request
	 * @param paramMap
	 * @return
	 * @throws Exception
	 */
	@RequestMapping(params = "cmd=get-apigee-tim301-etc", method={ RequestMethod.GET, RequestMethod.POST })
	public ModelAndView  apigeeCallTim301Etc(HttpSession session, HttpServletRequest request,
			@RequestParam Map<String, Object> paramMap) throws Exception {
		
		Log.DebugStart();
		
		ModelAndView mv = new ModelAndView();
		mv.setViewName("jsonView");
		mv.addObject("Result", "OK");
		
		try {
			////////////////////////////////////
			//accessToken 처리
			////////////////////////////////////
			getAccessToken(session);
			
			//String ssnEnterCd 	= StringUtil.stringValueOf(session.getAttribute("ssnEnterCd"));
			String ssnEnterCd 	= "HX";
			String ssnSabun 	= StringUtil.stringValueOf(session.getAttribute("ssnSabun"));

			//세션 사번이 없으면 세션을 강제로 생성
			if (ssnSabun.length() == 0) {
				
				//Interceptor 처리용 세션 강제 매핑
				paramMap.put("loginEnterCd", cEnterCd);
		  		Map<String,String> SystemOptMap = (Map<String, String>) loginService.systemOption(paramMap);

		  		setSystemOptionsToSession(SystemOptMap, session);
		  		
				ssnEnterCd 	= cEnterCd;
				ssnSabun 	= "scheduler";
				
				// ehr token 및 RSA 처리
				setEHRToken(session, request);
			}

			// ehr token 및 RSA 처리
			setEHRToken(session, request);
			
//			SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd");
//			Date now 		= new Date();
//			Calendar cal = new GregorianCalendar(Locale.KOREA);
//			cal.setTime(now);
//			String today 	= format.format(cal.getTime());
			
			//요청회사
			String enterCd 	= null;
			enterCd 		= ssnEnterCd;
			
			String paramStr = "";
			// 오늘 날짜
			LocalDate today = LocalDate.now();
			DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyyMMdd");

			// 5일 전 날짜 계산
			String startDate = today.minusDays(5).format(formatter);

			// 오늘 날짜를 포맷
			String endDate = today.format(formatter);


			paramStr = paramStr+"chkStartDate="+startDate;
			paramStr = paramStr+"&chkEndDate="+endDate;
			
			runInterfaceTTIM301Etc(paramStr, "HX", ssnSabun, request);
			
		}catch(Exception e){
			Log.Error("============================================================");
			Log.Error(e.toString());
			Log.Error("============================================================");
			mv.addObject("Result", "Error");
			mv.addObject("error", e.toString());
		}
		
		Log.DebugEnd();
		return mv;
	}
	
	/**
	 * 한진정보통신 타각 호출
	 * @param session
	 * @param request
	 * @param paramMap
	 * @return
	 * @throws Exception
	 */
	@RequestMapping(params = "cmd=get-apigee-tim331", method={ RequestMethod.GET, RequestMethod.POST })
	public ModelAndView  apigeeCallTim331(HttpSession session, HttpServletRequest request,
			@RequestParam Map<String, Object> paramMap) throws Exception {
		
		Log.DebugStart();
		
		ModelAndView mv = new ModelAndView();
		mv.setViewName("jsonView");
		mv.addObject("Result", "OK");
		
		try {
			////////////////////////////////////
			//accessToken 처리
			////////////////////////////////////
			getAccessToken(session);
			
			//String ssnEnterCd 	= StringUtil.stringValueOf(session.getAttribute("ssnEnterCd"));
			String ssnEnterCd 	= "HX";
			String ssnSabun 	= StringUtil.stringValueOf(session.getAttribute("ssnSabun"));

			//세션 사번이 없으면 세션을 강제로 생성
			if (ssnSabun.length() == 0) {
				
				//Interceptor 처리용 세션 강제 매핑
				paramMap.put("loginEnterCd", cEnterCd);
		  		Map<String,String> SystemOptMap = (Map<String, String>) loginService.systemOption(paramMap);

		  		setSystemOptionsToSession(SystemOptMap, session);
		  		
				ssnEnterCd 	= cEnterCd;
				ssnSabun 	= "scheduler";
				
				// ehr token 및 RSA 처리
				setEHRToken(session, request);
			}

			// ehr token 및 RSA 처리
			setEHRToken(session, request);
			
			SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd");
			Date now 		= new Date();
			Calendar cal = new GregorianCalendar(Locale.KOREA);
			cal.setTime(now);
			String today 	= format.format(cal.getTime());
			//하루 전 
			cal.add(Calendar.DATE, -1);
			String yesterday 	= format.format(cal.getTime());
			
			//요청회사
			String enterCd 	= null;
			enterCd 		= ssnEnterCd;
			
			//한진정보통신 타각
			try{ runInterfaceTTIM331("bb13Date="+today.replaceAll("-", ""), "HX", ssnSabun, request);     }catch(HrException e){ Log.Error(e.toString());}
			
		}catch(Exception e){
			Log.Error("============================================================");
			Log.Error(e.toString());
			Log.Error("============================================================");
			mv.addObject("Result", "Error");
			mv.addObject("error", e.toString());
		}
		
		Log.DebugEnd();
		return mv;
	}

    /**
     * 한진정보통신 타각 호출
     * @param session
     * @param request
     * @param paramMap
     * @return
     * @throws Exception
     */
    @RequestMapping(params = "cmd=get-apigee-tim331_kaltour", method={ RequestMethod.GET, RequestMethod.POST })
    public ModelAndView  apigeeCallTim331_kaltour(HttpSession session, HttpServletRequest request,
                                          @RequestParam Map<String, Object> paramMap) throws Exception {

        Log.DebugStart();

        ModelAndView mv = new ModelAndView();
        mv.setViewName("jsonView");
        mv.addObject("Result", "OK");

        try {
            ////////////////////////////////////
            //accessToken 처리
            ////////////////////////////////////
            getAccessToken(session);

            //String ssnEnterCd 	= StringUtil.stringValueOf(session.getAttribute("ssnEnterCd"));
            String ssnEnterCd 	= "HT";
            String ssnSabun 	= StringUtil.stringValueOf(session.getAttribute("ssnSabun"));

            //세션 사번이 없으면 세션을 강제로 생성
            if (ssnSabun.length() == 0) {

                //Interceptor 처리용 세션 강제 매핑
                paramMap.put("loginEnterCd", cEnterCd);
                Map<String,String> SystemOptMap = (Map<String, String>) loginService.systemOption(paramMap);

                setSystemOptionsToSession(SystemOptMap, session);

                //ssnEnterCd 	= cEnterCd;
                ssnEnterCd 	= "HT";
                ssnSabun 	= "scheduler";

                // ehr token 및 RSA 처리
                setEHRToken(session, request);
            }

            System.out.println("==================================================");
            System.out.println("============= apigeeCallTim331_kaltour Start ===========");
            System.out.println("");


            // ehr token 및 RSA 처리
            setEHRToken(session, request);

            SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd");
            Date now 		= new Date();
            Calendar cal = new GregorianCalendar(Locale.KOREA);
            cal.setTime(now);
            String today 	= format.format(cal.getTime());
            //하루 전
            cal.add(Calendar.DATE, -1);
            String yesterday 	= format.format(cal.getTime());

            //요청회사
            String enterCd 	= null;
            enterCd 		= ssnEnterCd;

            //한진관광 타각
            try{
                runInterfaceTTIM331_kaltour("attdate="+today.replaceAll("-", ""), "HT", ssnSabun, request);
            }catch(HrException e){ Log.Error(e.toString());}



        }catch(Exception e){
            Log.Error("============================================================");
            Log.Error(e.toString());
            Log.Error("============================================================");
            mv.addObject("Result", "Error");
            mv.addObject("error", e.toString());
        }

        Log.DebugEnd();
        return mv;
    }


    /**
	 * 평가결과 호출
	 * @param session
	 * @param request
	 * @param paramMap
	 * @return
	 * @throws Exception
	 */
	@RequestMapping(params = "cmd=apigee-call-cpn493", method={ RequestMethod.GET, RequestMethod.POST })
	public ModelAndView  apigeeCallCpn493(HttpSession session, HttpServletRequest request,
			@RequestParam Map<String, Object> paramMap) throws Exception {
		
		Log.DebugStart();
		
		ModelAndView mv = new ModelAndView();
		mv.setViewName("jsonView");
		mv.addObject("Result", "OK");
		
		try {
			////////////////////////////////////
			//accessToken 처리
			////////////////////////////////////
			getAccessToken(session);
			
			String ssnEnterCd 	= StringUtil.stringValueOf(session.getAttribute("ssnEnterCd"));
			String ssnSabun 	= StringUtil.stringValueOf(session.getAttribute("ssnSabun"));
			
			//세션 사번이 없으면 오류 리턴
			if (ssnSabun.length() == 0 ) {
				mv.setViewName("jsonView");
				mv.addObject("Result", "Error");
				mv.addObject("error", "session is null");
				return mv;
			}
			
			//조회년도 없으면 오류 리턴
			if (paramMap.get("searchAppraisalYy") 	== null ) {
				mv.setViewName("jsonView");
				mv.addObject("Result", "Error");
				mv.addObject("error", "searchAppraisalYy is null");
				return mv;
			}
			
			// ehr token 및 RSA 처리
			setEHRToken(session, request);
			
			SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd");
			Date now 		= new Date();
			Calendar cal = new GregorianCalendar(Locale.KOREA);
			cal.setTime(now);
			String today 	= format.format(cal.getTime());
			//1년전 기준일
			cal.add(Calendar.DATE, -365);
			String previousYearDate 	= format.format(cal.getTime());

			/////////////////////////////////////
			// Completed or Corrected or Rescinded
			/////////////////////////////////////
			//String CompletedBaseDate = "2023-09-01"; //2023.11.29 유재윤상무, 임영일프로 요청 (1년 전으로 기준설정)
			String CompletedBaseDate = previousYearDate;
			
			
			//요청회사
			String enterCd 	= null;
			enterCd 		= ssnEnterCd;
			
			String year 	= "1900";
			String paramStr	= "";
			if(paramMap.get("searchAppraisalYy") 	!= null) { 
				year 		= paramMap.get("searchAppraisalYy").toString();
			}
			String sabun 	= null;
			
			paramStr = paramStr+"Company_ID="+enterCd;
			if(paramMap.get("searchSabun") 	!= null) sabun 			= paramStr = paramStr+"&Employee_ID="+paramMap.get("searchSabun").toString();;
			
			//1. workday key field
			paramStr = paramStr+"&Review_Year="+year;
			paramStr = paramStr+"&Completed_Date_On_or_After_for_All="+CompletedBaseDate;
			paramStr = paramStr+"&Completed_Date_On_or_Before_for_All="+today;
			
			///////////////////////////////////////////////////////////////////////////////
			//전달받은 파라메터도 전달 
			Log.Debug("XXXXXXXXXXXXXXXX cmd=cmd=apigee-call-cpn493 XXXXXXXXXXXXXXXXX");
			Log.Debug("paramMap 	: " + paramMap);
			Log.Debug("enterCd 	    : " + enterCd);
			Log.Debug("sabun 	    : " + sabun);
			Log.Debug("paramStr 	    : " + paramStr);
			Log.Debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
			///////////////////////////////////////////////////////////////////////////////		
			
			//평가결과	
			runInterfaceTCPN493(paramStr, ssnEnterCd, ssnSabun, year, request);
			
		}catch(Exception e){
			Log.Error("============================================================");
			Log.Error(e.toString());
			Log.Error("============================================================");
			mv.addObject("Result", "Error");
			mv.addObject("error", e.toString());
		}
		
		Log.DebugEnd();
		return mv;
	}
	
	
	/**
	 * 스케쥴러에 따른 apigee interface 실행
	 * @param session
	 * @param request
	 * @param paramMap
	 * @return
	 * @throws Exception
	 */
	@RequestMapping(params = "cmd=get-interface-apigee", method={ RequestMethod.GET, RequestMethod.POST })
	public ModelAndView  putInterfaceApigee(HttpSession session, HttpServletRequest request,
			@RequestParam Map<String, Object> paramMap) throws Exception {
		
		Log.DebugStart();
		
		ModelAndView mv = new ModelAndView();
		mv.setViewName("jsonView");
		mv.addObject("Result", "OK");

		try {
			////////////////////////////////////
			//accessToken 처리
			////////////////////////////////////
			getAccessToken(session);
			
			String ssnEnterCd 	= StringUtil.stringValueOf(session.getAttribute("ssnEnterCd"));
			String ssnSabun 	= StringUtil.stringValueOf(session.getAttribute("ssnSabun"));
			
			//세션 사번이 없으면 세션을 강제로 생성
			if (ssnSabun.length() == 0) {
				
				//Interceptor 처리용 세션 강제 매핑
				paramMap.put("loginEnterCd", cEnterCd);
		  		Map<String,String> SystemOptMap = (Map<String, String>) loginService.systemOption(paramMap);
				
		  		setSystemOptionsToSession(SystemOptMap, session);
		  		
				ssnEnterCd 	= cEnterCd;
				ssnSabun 	= "scheduler";
				
				// ehr token 및 RSA 처리
				setEHRToken(session, request);

			}
			
			Log.Debug("============================================================");
			Log.Debug("=== ssnSabun : " +ssnSabun);
			Log.Debug("=== ssnEnterCd : " +ssnEnterCd);
			Log.Debug("============================================================");
			
			///////////////////////////////////////////////////////////////////////////////		
			//call runInterfaceAll 
			///////////////////////////////////////////////////////////////////////////////
			
			Log.Debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
			Log.Debug("call runInterfaceAll");
			Log.Debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");

			runInterfaceAll(ssnEnterCd, ssnSabun, request);

		}catch(Exception e){
			Log.Error("============================================================");
			Log.Error(e.toString());
			Log.Error("============================================================");
			mv.addObject("Result", "Error");
			mv.addObject("error", e.toString());
		}
		
		Log.DebugEnd();
		return mv;
	}	
	
	
	/**
	 * Olive 식권 포인트 interface 실행
	 * @param session
	 * @param request
	 * @param paramMap
	 * @return
	 * @throws Exception
	 */
	@RequestMapping(params = "cmd=put-interface-olive", method={ RequestMethod.GET, RequestMethod.POST })
	public ModelAndView  putInterfaceOlive(HttpSession session, HttpServletRequest request,
			@RequestParam Map<String, Object> paramMap) throws Exception {
		
		Log.DebugStart();
		
		ModelAndView mv = new ModelAndView();
		mv.setViewName("jsonView");
		mv.addObject("Result", "OK");
		
		//호출 api
	    String apiNm = "charge/point";

		try {
			
			String ssnEnterCd 	= StringUtil.stringValueOf(session.getAttribute("ssnEnterCd"));
			String ssnSabun 	= StringUtil.stringValueOf(session.getAttribute("ssnSabun"));
			
			//세션 사번이 없으면 세션을 강제로 생성
			if (ssnSabun.length() == 0) {
				
				//Interceptor 처리용 세션 강제 매핑
				paramMap.put("loginEnterCd", cEnterCd);
		  		Map<String,String> SystemOptMap = (Map<String, String>) loginService.systemOption(paramMap);

		  		setSystemOptionsToSession(SystemOptMap, session);
		  		
				ssnEnterCd 	= cEnterCd;
				ssnSabun 	= "scheduler";
				
				// ehr token 및 RSA 처리
				setEHRToken(session, request);

			}
			
			SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd");
			Date now 		= new Date();
			Calendar cal = new GregorianCalendar(Locale.KOREA);
			cal.setTime(now);
			//하루 전 
			//cal.add(Calendar.DATE, -1);
			String today 	= format.format(cal.getTime());
			
			paramMap.put("ssnEnterCd", 		ssnEnterCd);    //회사코드
			paramMap.put("ssnSabun", 		ssnSabun);      //사번
			paramMap.put("ssnSearchType", 	"A");           //조건검색구분
			paramMap.put("ssnGrpCd", 		"10");          //권한
			paramMap.put("ssnBaseDate", 	today);         //신청일자
			paramMap.put("srchSeq",			srchSeq);       //조건검색 번호
			paramMap.put("array",			"");            //정렬 파라메터
			
			String queryStr 	= null;
			List<HashMap<String, Object>> targetList = new ArrayList<>();
			List<HashMap<String, Object>> saveList = new ArrayList<>();
			Map query = pwrSrchResultPopupService.getPwrSrchResultPopupQueryMap2(paramMap);
			paramMap.put("seqId", "ETC");
			Map<?, ?> sequenceMap = (Map) otherService.getSequence(paramMap);
		    String reqSeq = sequenceMap != null ? StringUtil.null2Blank(sequenceMap.get("getSeq")): "";
		    
		    try{
			    query = pwrSrchResultPopupService.getPwrSrchResultPopupQueryMap(paramMap);
			    queryStr = (query != null) ? StringUtil.null2Blank(query.get("query")) : "";

				if (!queryStr.isEmpty() && queryStr.contains(":dfIdvSabun")) {
			        queryStr = queryStr.replace(":dfIdvSabun", ssnSabun);
			    }
			    
				paramMap.put("query", queryStr);
				
				///////////////////////////////////////////////////
				//대상자 조회
				///////////////////////////////////////////////////
				targetList = iFTolivetimController.getFoodPointList(paramMap);
				String targetSabun = "";
				String targetName = "";
				
				for(Map<String, Object> targetListMap  : targetList) {
					
					// olive 전달용 String 생성
					if(targetSabun.equals("")) {
						targetSabun = targetListMap.get("sabun").toString();
					}else {
						targetSabun = targetSabun + ", "+targetListMap.get("sabun").toString();						
					}
					if(targetName.equals("")) {
						targetName = targetListMap.get("sabun").toString();
					}else {
						targetName = targetName + ", "+targetListMap.get("name").toString();						
					}
										
					try{
						
						JSONObject jsonObj 	= null; 
						Map<String, Object> parameter = new HashMap();
						
						parameter.put("appId"    , oliveAppId);
						parameter.put("empNo"    , targetListMap.get("sabun").toString());

					}catch(Exception e){
						Log.Error(e.toString());
						targetListMap.put("resultCode", 	"ERROR");
						targetListMap.put("message", 	e.toString());
					}
					
					targetListMap.put("reqSeq", 	reqSeq);
					targetListMap.put("reqYmd", 	today);
					targetListMap.put("chkId", 		ssnSabun);
					
					///////////////////////////////////////////////////
					//포인트 충전 결과 처리
					///////////////////////////////////////////////////
					int cnt = iFTolivetimController.saveFoodPoint(targetListMap);

				}
				
				Map<String, Object> targetMap = new HashMap();
				try{
					
					JSONObject jsonObj 	= null; 
					Map<String, Object> parameter = new HashMap();
					
					parameter.put("appId"    , oliveAppId);
					parameter.put("empNo"    , targetSabun);
					
					jsonObj = httpUtils.getRestTemplateJson(oliveUrl+"/"+apiNm, parameter, request);
					String jsonStr = jsonObj.toJSONString().replaceAll("'", "CHR(39)");

					Map<String, Object> tmpMap = new ObjectMapper().readValue(jsonStr, Map.class);
					tmpMap.forEach((k, v) -> targetMap.putIfAbsent(k, v));

				}catch(HrException e){
					Log.Error(e.toString());
					targetMap.put("resultCode", 	"ERROR");
					targetMap.put("message", 	e.toString());
				}
				
				targetMap.put("enterCd", 	ssnEnterCd);
				targetMap.put("sabun", 		targetSabun);
				targetMap.put("name", 		targetName);
				targetMap.put("reqSeq", 	reqSeq);
				targetMap.put("reqYmd", 	today);
				targetMap.put("chkId", 		ssnSabun);
				
				///////////////////////////////////////////////////
				//포인트 충전 결과 처리
				///////////////////////////////////////////////////
				int cnt = iFTolivetimController.saveFoodPointList(targetMap);
				
			}catch(HrException e){
				mv.addObject("Result", "조회에 실패하였습니다.");
			}
			
			Log.Debug("============================================================");
			Log.Debug("=== ssnSabun : " +ssnSabun);
			Log.Debug("=== ssnEnterCd : " +ssnEnterCd);
			Log.Debug("============================================================");

		}catch(Exception e){
			Log.Error("============================================================");
			Log.Error(e.toString());
			Log.Error("============================================================");
			mv.addObject("Result", "Error");
			mv.addObject("error", e.toString());
		}
		
		Log.DebugEnd();
		return mv;
	}
	
	
	/**
	 * 전체 API 호출
	 */
	private void runInterfaceAll(String ssnEnterCd, String ssnSabun, HttpServletRequest request) throws Exception{

		//전체 Interface
		SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd");
		Date now 		= new Date();
		Calendar cal = new GregorianCalendar(Locale.KOREA);
		cal.setTime(now);
		String today 	= format.format(cal.getTime());
		//하루 전
		cal.add(Calendar.DATE, -1);
		String yesterday 	= format.format(cal.getTime());

		Log.Debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
		Log.Debug("yesterday  	: " + yesterday);
		Log.Debug("today  		: " + today);
		Log.Debug("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");

		String paramStr = "";

		//2023.11.06 호출 순서변경 요청	
		//한진칼
		//인사마스터
		paramStr = "";
		paramStr = paramStr+"&Start_Updated="+yesterday;
		paramStr = paramStr+"&End_Updated="+today;
		try{ runInterfaceTHRM100("Company_ID=HG"+paramStr, "HG", ssnSabun, request);    }catch(HrException e){ Log.Error(e.toString());}
		//가족사항
		try{ runInterfaceTHRM111("", "HG", yesterday, today, null, ssnSabun, request);  }catch(HrException e){ Log.Error(e.toString());}
		//발령,휴/복직,징계
		// THRM193,THRM194, THRM195 동시 호출됨
		try{ runInterfaceTHRM192("HG", yesterday, today, null, ssnSabun, request);     	}catch(HrException e){ Log.Error(e.toString());}
		//수습
		try{ runInterfaceTHRM196("", "HG", yesterday, today, null, ssnSabun, request);  }catch(HrException e){ Log.Error(e.toString());}
		//계약
		try{ runInterfaceTHRM197("", "HG", yesterday, today, null, ssnSabun, request);  }catch(HrException e){ Log.Error(e.toString());}
		//조직
		try{ runInterfaceTORG105("Company_ID=HG", "HG", ssnSabun, request);      		}catch(HrException e){ Log.Error(e.toString());}
		//파견인사마스터
		paramStr = "";
		paramStr = paramStr+"&Effective_Date="+yesterday;
		try{ runInterfaceTHRM112("Company_ID=HG"+paramStr, "HG", ssnSabun, request);    }catch(HrException e){ Log.Error(e.toString());}
		//사진
		paramStr = "";
		paramStr = paramStr+"&Completed_Date_On_or_After="+yesterday;
		paramStr = paramStr+"&Completed_Date_On_or_Before="+today;
		try{ runInterfaceTHRM911List("Company_ID=HG"+paramStr, "HG", ssnSabun, request); }catch(HrException e){ Log.Error(e.toString());}

		
		
		//한진정보통신
		//인사마스터
		paramStr = "";
		paramStr = paramStr+"&Start_Updated="+yesterday;
		paramStr = paramStr+"&End_Updated="+today;
		try{ runInterfaceTHRM100("Company_ID=HX"+paramStr, "HX", ssnSabun, request);      }catch(HrException e){ Log.Error(e.toString());}
		//가족사항
		try{ runInterfaceTHRM111("", "HX", yesterday, today, null, ssnSabun, request);    }catch(HrException e){ Log.Error(e.toString());}
		//발령,휴/복직,징계
		// THRM193, THRM194, THRM195 동시 호출됨
		try{ runInterfaceTHRM192("HX", yesterday, today, null, ssnSabun, request);        }catch(HrException e){ Log.Error(e.toString());}
		//수습
		try{ runInterfaceTHRM196("", "HX", yesterday, today, null, ssnSabun, request);    }catch(HrException e){ Log.Error(e.toString());}
		//계약
		try{ runInterfaceTHRM197("", "HX", yesterday, today, null, ssnSabun, request);    }catch(HrException e){ Log.Error(e.toString());}
		//조직
		try{ runInterfaceTORG105("Company_ID=HX", "HX", ssnSabun, request );     		  }catch(HrException e){ Log.Error(e.toString());}
		//파견인사마스터
		paramStr = "";
		paramStr = paramStr+"&Effective_Date="+yesterday;
		try{ runInterfaceTHRM112("Company_ID=HX"+paramStr, "HX", ssnSabun, request);       }catch(HrException e){ Log.Error(e.toString());}
		//사진
		paramStr = "";
		paramStr = paramStr+"&Completed_Date_On_or_After="+yesterday;
		paramStr = paramStr+"&Completed_Date_On_or_Before="+today;
		try{ runInterfaceTHRM911List("Company_ID=HX"+paramStr, "HX", ssnSabun, request);   }catch(HrException e){ Log.Error(e.toString());}
		//한진정보통신 타각
		//try{ runInterfaceTTIM331("bb13Date="+today.replaceAll("-", ""), "HX", ssnSabun, request);     }catch(HrException e){ Log.Error(e.toString());}

		
		//한국공항
		//인사마스터
		paramStr = "";
		paramStr = paramStr+"&Start_Updated="+yesterday;
		paramStr = paramStr+"&End_Updated="+today;
		try{ runInterfaceTHRM100("Company_ID=KS"+paramStr, "KS", ssnSabun, request);     	}catch(HrException e){ Log.Error(e.toString());}
		//가족사항
		try{ runInterfaceTHRM111("", "KS", yesterday, today, null, ssnSabun, request);     	}catch(HrException e){ Log.Error(e.toString());}
		//발령,휴/복직,징계
		// THRM193,THRM194, THRM195 동시 호출됨
		try{ runInterfaceTHRM192("KS", yesterday, today, null, ssnSabun, request);     		}catch(HrException e){ Log.Error(e.toString());}
		//수습
		try{ runInterfaceTHRM196("", "KS", yesterday, today, null, ssnSabun, request);        }catch(HrException e){ Log.Error(e.toString());}
		//계약
		try{ runInterfaceTHRM197("", "KS", yesterday, today, null, ssnSabun, request);        }catch(HrException e){ Log.Error(e.toString());}
		//조직
		try{ runInterfaceTORG105("Company_ID=KS", "KS", ssnSabun, request );     			}catch(HrException e){ Log.Error(e.toString());}
		//파견인사마스터
		paramStr = "";
		paramStr = paramStr+"&Effective_Date="+yesterday;
		try{ runInterfaceTHRM112("Company_ID=KS"+paramStr, "KS", ssnSabun, request);     	}catch(HrException e){ Log.Error(e.toString());}
		//사진
		paramStr = "";
		paramStr = paramStr+"&Completed_Date_On_or_After="+yesterday;
		paramStr = paramStr+"&Completed_Date_On_or_Before="+today;
		try{ runInterfaceTHRM911List("Company_ID=KS"+paramStr, "KS", ssnSabun, request);    }catch(HrException e){ Log.Error(e.toString());}
		//수당발령
		paramStr = "";
		try{ runInterfaceTCPN429("Company_ID=KS"+paramStr, "KS", ssnSabun, request);     	}catch(HrException e){ Log.Error(e.toString());}
		//생수불출 내역
		try{ runInterfaceTBEN592("p_yymm="+today.replaceAll("-", ""), "KS", ssnSabun, request);     		}catch(HrException e){ Log.Error(e.toString());}
		//통합조업 스케쥴
		paramStr = "";
		paramStr = paramStr+"p_fromDate="+today.replaceAll("-", "").substring(0,6)+"01"; //해당월 1일부터 호출;
		paramStr = paramStr+"&p_toDate="+DateUtil.addDays(today,30).replaceAll("-", "");
		
		try{ runInterfaceTTIM112(paramStr, "KS", ssnSabun, request);     					}catch(HrException e){ Log.Error(e.toString());}

	}
	
	/** 
	 * 조직정보 API 호출
	 * @param parameter
	 * @throws Exception
	 */
	private void runInterfaceTORG105(String paramStr, String chkEnterCd, String chkid, HttpServletRequest request) throws Exception {

		Log.DebugStart();
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterface ===");
			Log.Debug("============================================================");
	
			String intfCd 		= "INT_TORG105";
			String intfNm 		= "조직정보";
			String uri 			= apiOrg105;
			
			//Apigee 도입 시 수정 필요
			///////////////////////////////////////////////////////////////////////////////
			//String apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
			String apiUri = googleApigeeUrl + uri + "?" + paramStr;
			Log.Debug("============================================================");
			Log.Debug("=== change apiUri ===");
			Log.Debug(apiUri);
			Log.Debug("============================================================");		
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		apiUri);
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	chkEnterCd);
			//intfSdate 추가 처리
			//paramMap.put("intfSdate", intfSdate);
	
			paramMap.put("intfCallFlag",	"Completed");
			paramMap.put("paramStr", 	paramStr);
			int intfSeq = saveInterfaceJSON(paramMap, request);
			
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFTorgController.pumpIntfTorg105(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFTorgController.pkgIntfTorg101(paramMap);
					iFTorgController.pkgIntfTorg103(paramMap);
					iFTorgController.pkgIntfTorg105Init(paramMap);
					iFTorgController.pkgIntfTorg105(paramMap);
				}
			}
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}

		Log.DebugEnd();
	}

	
	/**
	 * 인사마스터 API 호출
	 * @param paramStr   파라메터 String
	 * @param chkEnterCd 
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTHRM100(String paramStr, String enterCd, String chkid, HttpServletRequest request) throws Exception {

		Log.DebugStart();
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterface ===");
			Log.Debug("============================================================");
	
			String intfCd 		= "INT_THRM100";
			String intfNm 		= "인사마스터";
			String uri 			= apiHrm100;
			Map<String, Object> paramMap = new HashMap();
			int intfSeq 		= -1;

			//workday 데이타 조회
			//String apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
			String apiUri = googleApigeeUrl + uri + "?" + paramStr;
			Log.Debug("============================================================");
			Log.Debug("=== change apiUri ===");
			Log.Debug(apiUri);
			Log.Debug("============================================================");		
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			paramMap.put("apiUri", 		apiUri);
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);

			intfSeq = getInterfaceSequence(null, paramMap);

			paramMap.put("intfSeq",  	intfSeq);			
			
	
			paramMap.put("intfCallFlag",	"Completed");
			paramMap.put("paramStr", 	paramStr);
	
			intfSeq = saveInterfaceJSON(paramMap, request);
	
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFThrmController.pumpIntfThrm100(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFThrmController.pkgIntfThrm100(paramMap);
				}
			}
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
	
		Log.DebugEnd();
	}
	
	
	/**
	 * 인사마스터(파견)  API 호출
	 * @param paramStr   파라메터 String
	 * @param chkEnterCd 
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTHRM112(String paramStr, String enterCd, String chkid, HttpServletRequest request) throws Exception {
		
		Log.DebugStart();
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterface ===");
			Log.Debug("============================================================");
			
			String intfCd 		= "INT_THRM112";
			String intfNm 		= "인사마스터(파견)";
			String uri 			= apiHrm112;
			
			//workday 데이타 조회
			//String apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
			String apiUri = googleApigeeUrl + uri + "?" + paramStr;
			Log.Debug("============================================================");
			Log.Debug("=== change apiUri ===");
			Log.Debug(apiUri);
			Log.Debug("============================================================");		
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		apiUri);
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);
			//intfSdate 추가 처리
			//paramMap.put("intfSdate", intfSdate);
			
			paramMap.put("intfCallFlag",	"Completed");
			paramMap.put("paramStr", 	paramStr);
	
			int intfSeq = saveInterfaceJSON(paramMap, request);
	
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFThrmController.pumpIntfThrm112(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFThrmController.pkgIntfThrm112(paramMap);
				}
			}
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}

		Log.DebugEnd();
	}
	
	
	/**
	 * 가족사항  API 호출
	 * @param enterCd
	 * @param fromDate 조회시작일자
	 * @param toDate 조회종료일자
	 * @param sabun
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTHRM111(String paramStr, String enterCd, String fromDate, String toDate, String sabun, String chkid, HttpServletRequest request) throws Exception {
		
		Log.DebugStart();
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterfaceTHRM111 ===");
			Log.Debug("============================================================");
			
			String intfCd 		= "INT_THRM111";
			String intfNm 		= "가족사항";
			String uri 			= apiHrm111;
			Map<String, Object> paramMap = new HashMap();
			int intfSeq 		= -1;

			//workday데이타(INT_TSYS986) interface 테이블에 저장
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);

			intfSeq = getInterfaceSequence(null, paramMap);
		
			paramMap.put("intfSeq",  	intfSeq);

	
			//Completed, Corrected, Rescinded 호출
			intfSeq = callCCR(paramStr, uri, enterCd, fromDate, toDate, sabun, paramMap, request);	
			
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFThrmController.pumpIntfThrm111(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFThrmController.pkgIntfThrm111(paramMap);
				}
			}
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}

		Log.DebugEnd();
	}
	

	////////////////////////////////////////////////////////////////////
	//////////////////////// 재호출 부분 시작 ///////////////////////////////
	////////////////////////////////////////////////////////////////////
	/**
	 * 발령정보  API 호출
	 * @param paramStr   파라메터 String
	 * @param chkEnterCd 
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTHRM192_RE(String paramStr, int intfSeq, String enterCd, String fromDate, String toDate, String sabun, String chkid, HttpServletRequest request) throws Exception {
		Log.DebugStart();

		Log.Debug("============================================================");
		Log.Debug("=== runInterfaceTHRM192 ===");
		Log.Debug("============================================================");

		String intfCd 		= "INT_THRM192";
		String intfNm 		= "개인발령사항";
		String uri 			= apiHrm192;
		Map<String, Object> paramMap = new HashMap();

		//workday데이타(INT_TSYS986) interface 테이블에 저장
		paramMap.put("intfCd", 		intfCd);
		paramMap.put("intfSdate",	"");
		paramMap.put("intfNm", 		intfNm);
		paramMap.put("chkid", 		chkid);
		paramMap.put("chkEnterCd", 	enterCd);

		paramMap.put("intfSeq",  	intfSeq);

		//Completed, Corrected, Rescinded 호출
		try{ intfSeq = callCCR(paramStr, uri, enterCd, fromDate, toDate, sabun, paramMap, request);     }catch(HrException e){ Log.Error(e.toString());}

		if(intfSeq > -1) {


			Log.Debug("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
			Log.Debug("=== paramMap : "+paramMap);
			Log.Debug("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
			Log.Debug("============================================================");
			Log.Debug("============================================================");


			//workday데이타 건별로 인터페이스 테이블 저장
			try{ iFThrmController.pumpIntfThrm192(paramMap);     }catch(HrException e){ Log.Error(e.toString());}

			if(dbProcCall) {
				//인터페이스 테이블 실 테이블에 저장 처리
				try{ iFThrmController.pkgIntfThrm192(paramMap);     }catch(HrException e){ Log.Error(e.toString());}
				//인터페이스 개인발령취합
				try{ iFThrmController.pkgIntfThrm191(paramMap);     }catch(HrException e){ Log.Error(e.toString());}
				//개인발령사항, 휴복직정보 중 처리해야할 것이 있으면 수행
				try{ iFThrmController.pkgIntfThrm151(paramMap);     }catch(HrException e){ Log.Error(e.toString());}
			}

		}

		Log.Debug("============================================================");
		Log.Debug("intfSeq : "+intfSeq);
		Log.Debug("============================================================");

		Log.DebugEnd();
	}
	
	/**
	 * 휴복직사항(휴직)  API 호출
     * @param pSeq   인터페이스 순번
     * @param enterCd   회사코드
     * @param fromDate 조회시작일자
     * @param toDate 조회종료일자
     * @param sabun 사번
     * @param chkid 처리자
	 * @throws Exception
	 */
	private int runInterfaceTHRM193_RE(String paramStr, int intfSeq, String enterCd, String fromDate, String toDate, String sabun ,String chkid, HttpServletRequest request) throws Exception {
		Log.DebugStart();
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterface ===");
			Log.Debug("============================================================");
	
			String intfCd 		= "INT_THRM193";
			String intfNm 		= "휴직사항";
			String uri 			= apiHrm193;
			Map<String, Object> paramMap = new HashMap();

			//workday데이타(INT_TSYS986) interface 테이블에 저장
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);

			//Completed, Corrected, Rescinded 호출
			intfSeq = callCCR(paramStr, uri, enterCd, fromDate, toDate, sabun, paramMap, request);	
	
			if(intfSeq > -1) {
				paramMap.put("intfSeq",  	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFThrmController.pumpIntfThrm193(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFThrmController.pkgIntfThrm193(paramMap);
					//인터페이스 개인발령취합
					try{ iFThrmController.pkgIntfThrm191(paramMap);     }catch(HrException e){ Log.Error(e.toString());}
					//개인발령사항, 휴복직정보 중 처리해야할 것이 있으면 수행
					try{ iFThrmController.pkgIntfThrm151(paramMap);     }catch(HrException e){ Log.Error(e.toString());}
				}
			}
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
			
		Log.DebugEnd();
		
		return intfSeq;
	}
	
	/**
     * 휴복직사항(복직)  API 호출
     * @param pSeq   인터페이스 순번
     * @param enterCd   회사코드
     * @param fromDate 조회시작일자
     * @param toDate 조회종료일자
     * @param sabun 사번
     * @param chkid 처리자
     * @throws Exception
     */
    private int runInterfaceTHRM194_RE(String paramStr, int intfSeq, String enterCd, String fromDate, String toDate, String sabun, String chkid, HttpServletRequest request) throws Exception {
        Log.DebugStart();
        try {
	        Log.Debug("============================================================");
	        Log.Debug("=== runInterface ===");
	        Log.Debug("============================================================");
	
	        String intfCd       = "INT_THRM194";
	        String intfNm       = "복직사항";
	        String uri          = apiHrm194;
			Map<String, Object> paramMap = new HashMap();

			//workday데이타(INT_TSYS986) interface 테이블에 저장
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);

			//Completed, Corrected, Rescinded 호출
			intfSeq = callCCR(paramStr, uri, enterCd, fromDate, toDate, sabun, paramMap, request);	
	        
	        if(intfSeq > -1) {
	        	paramMap.put("intfSeq",  	intfSeq);
	            //workday데이타 건별로 인터페이스 테이블 저장
	            iFThrmController.pumpIntfThrm194(paramMap);
	            //인터페이스 테이블 실 테이블에 저장 처리
	            if(dbProcCall) {
	            	iFThrmController.pkgIntfThrm194(paramMap);
					//인터페이스 개인발령취합
					try{ iFThrmController.pkgIntfThrm191(paramMap);     }catch(HrException e){ Log.Error(e.toString());}
					//개인발령사항, 휴복직정보 중 처리해야할 것이 있으면 수행
					try{ iFThrmController.pkgIntfThrm151(paramMap);     }catch(HrException e){ Log.Error(e.toString());}
	            }
	        }
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
        
        Log.DebugEnd();
        
        return intfSeq;
    }
    
    /**
     * 징계사항  API 호출
     * @param pSeq   인터페이스 순번
     * @param enterCd   회사코드
     * @param fromDate 조회시작일자
     * @param toDate 조회종료일자
     * @param sabun 사번
     * @param chkid 처리자
     * @throws Exception
     */
    private int runInterfaceTHRM195_RE(String paramStr, int intfSeq, String enterCd, String fromDate, String toDate, String sabun, String chkid, HttpServletRequest request) throws Exception {
    	Log.DebugStart();
    	try {
	    	Log.Debug("============================================================");
	    	Log.Debug("=== runInterface ===");
	    	Log.Debug("============================================================");
	    	
	    	String intfCd       = "INT_THRM195";
	    	String intfNm       = "징계사항";
	    	String uri          = apiHrm195;
	    	Map<String, Object> paramMap = new HashMap();

			//workday데이타(INT_TSYS986) interface 테이블에 저장
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);

			//Completed, Corrected, Rescinded 호출
			intfSeq = callCCR(paramStr, uri, enterCd, fromDate, toDate, sabun, paramMap, request);	
	    	
	    	if(intfSeq > -1) {
	    		paramMap.put("intfSeq",  	intfSeq);
	    		//workday데이타 건별로 인터페이스 테이블 저장
	    		iFThrmController.pumpIntfThrm195(paramMap);
	    		//인터페이스 테이블 실 테이블에 저장 처리
	    		if(dbProcCall) {
	    			iFThrmController.pkgIntfThrm195(paramMap);
					//인터페이스 개인발령취합
					try{ iFThrmController.pkgIntfThrm191(paramMap);     }catch(HrException e){ Log.Error(e.toString());}
					//개인발령사항, 휴복직정보 중 처리해야할 것이 있으면 수행
					try{ iFThrmController.pkgIntfThrm151(paramMap);     }catch(HrException e){ Log.Error(e.toString());}
	    		}
	    	}
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}

    	Log.DebugEnd();
    	
    	return intfSeq;
    }
    
	/**
	 * 개인사진  API 호출
	 * @param paramStr   파라메터 String
	 * @param chkEnterCd 
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTHRM911_RE(String paramStr, String enterCd, String chkid, HttpServletRequest request) throws Exception {
		
		Log.DebugStart();
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterface ===");
			Log.Debug("============================================================");
			
			String intfCd 		= "INT_THRM911";
			String intfNm 		= "개인사진";
			String uri 			= apiHrm911;
			
			//workday 데이타 조회
			String apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
			Log.Debug("============================================================");
			Log.Debug("=== change apiUri ===");
			Log.Debug(apiUri);
			Log.Debug("============================================================");		
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		apiUri);
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);
			//intfSdate 추가 처리
			//paramMap.put("intfSdate", intfSdate);
			
			paramMap.put("intfCallFlag",	"Completed");
			paramMap.put("paramStr", 	paramStr);
	
			int intfSeq = saveInterfaceJSON(paramMap, request);
	
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFThrmController.pumpIntfThrm911(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFThrmController.pkgIntfThrm911(paramMap);
				}
			}
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}

		Log.DebugEnd();
	}

    ////////////////////////////////////////////////////////////////
	//////////////////////// 재호출 끝 ///////////////////////////////
    //////////////////////////////////////////////////////////////
	
	
	/**
	 * 발령정보  API 호출
	 * @param paramStr   파라메터 String
	 * @param chkEnterCd 
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTHRM192(String enterCd, String fromDate, String toDate, String sabun, String chkid, HttpServletRequest request) throws Exception {
		Log.DebugStart();
		
		Log.Debug("============================================================");
		Log.Debug("=== runInterfaceTHRM192 ===");
		Log.Debug("============================================================");
		
		String intfCd 		= "INT_THRM192";
		String intfNm 		= "개인발령사항";
		String uri 			= apiHrm192;
		Map<String, Object> paramMap = new HashMap();
		int intfSeq 		= -1;
		
		//workday데이타(INT_TSYS986) interface 테이블에 저장
		paramMap.put("intfCd", 		intfCd);
		paramMap.put("intfSdate",	"");
		paramMap.put("intfNm", 		intfNm);
		paramMap.put("chkid", 		chkid);
		paramMap.put("chkEnterCd", 	enterCd);
		
		intfSeq = getInterfaceSequence(null, paramMap);
		
		paramMap.put("intfSeq",  	intfSeq);
			
		//Completed, Corrected, Rescinded 호출
		try{ intfSeq = callCCR("", uri, enterCd, fromDate, toDate, sabun, paramMap, request);     }catch(HrException e){ Log.Error(e.toString());}
		
		if(intfSeq > -1) {
			
			
			Log.Debug("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
			Log.Debug("=== paramMap : "+paramMap);
			Log.Debug("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
			Log.Debug("============================================================");
			Log.Debug("============================================================");
			
			
			//workday데이타 건별로 인터페이스 테이블 저장
			try{ iFThrmController.pumpIntfThrm192(paramMap);     }catch(HrException e){ Log.Error(e.toString());}
			
			//인터페이스 테이블 실 테이블에 저장 처리
			//////////////////////////////////////////////////
			//휴복직이력(휴직) api 처리 후 인터페이스 테이블 실 테이블 저장
			try{ runInterfaceTHRM193(intfSeq, enterCd, fromDate, toDate, sabun , chkid, request);     }catch(HrException e){ Log.Error(e.toString());}
			//휴복직이력(복직) api 처리 후 인터페이스 테이블 실 테이블 저장
			try{ runInterfaceTHRM194(intfSeq, enterCd, fromDate, toDate, sabun , chkid, request);     }catch(HrException e){ Log.Error(e.toString());}
			//징계사항 api 처리 후 인터페이스 테이블 실 테이블 저장
			try{ runInterfaceTHRM195(intfSeq, enterCd, fromDate, toDate, sabun , chkid, request);     }catch(HrException e){ Log.Error(e.toString());}
			//////////////////////////////////////////////////
			
			if(dbProcCall) {
				//인터페이스 테이블 실 테이블에 저장 처리
				try{ iFThrmController.pkgIntfThrm192(paramMap);     }catch(HrException e){ Log.Error(e.toString());}
				//인터페이스 개인발령취합
				try{ iFThrmController.pkgIntfThrm191(paramMap);     }catch(HrException e){ Log.Error(e.toString());}
				//개인발령사항, 휴복직정보 중 처리해야할 것이 있으면 수행
				try{ iFThrmController.pkgIntfThrm151(paramMap);     }catch(HrException e){ Log.Error(e.toString());}
			}
			
		}
		
		Log.Debug("============================================================");
		Log.Debug("intfSeq : "+intfSeq);
		Log.Debug("============================================================");
		
		Log.DebugEnd();
	}
	
	
	
	/**
	 * 휴복직사항(휴직)  API 호출
	 * @param pSeq   인터페이스 순번
	 * @param enterCd   회사코드
	 * @param fromDate 조회시작일자
	 * @param toDate 조회종료일자
	 * @param sabun 사번
	 * @param chkid 처리자
	 * @throws Exception
	 */
	private int runInterfaceTHRM193(int pSeq, String enterCd, String fromDate, String toDate, String sabun ,String chkid, HttpServletRequest request) throws Exception {
		Log.DebugStart();
		int intfSeq = -1;
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterface ===");
			Log.Debug("============================================================");
			
			String intfCd 		= "INT_THRM193";
			String intfNm 		= "휴직사항";
			String uri 			= apiHrm193;
			Map<String, Object> paramMap = new HashMap();
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);
			
			intfSeq = getInterfaceSequence(pSeq, paramMap);
			
			paramMap.put("intfSeq",  	intfSeq);
			
			//Completed, Corrected, Rescinded 호출
			intfSeq = callCCR("", uri, enterCd, fromDate, toDate, sabun, paramMap, request);	
			
			if(intfSeq > -1) {
				//workday데이타 건별로 인터페이스 테이블 저장
				iFThrmController.pumpIntfThrm193(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFThrmController.pkgIntfThrm193(paramMap);
				}
			}
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
			throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
		
		Log.DebugEnd();
		
		return intfSeq;
	}

 
    /**
     * 휴복직사항(복직)  API 호출
     * @param pSeq   인터페이스 순번
     * @param enterCd   회사코드
     * @param fromDate 조회시작일자
     * @param toDate 조회종료일자
     * @param sabun 사번
     * @param chkid 처리자
     * @throws Exception
     */
    private int runInterfaceTHRM194(int pSeq, String enterCd, String fromDate, String toDate, String sabun, String chkid, HttpServletRequest request) throws Exception {
        Log.DebugStart();
        int intfSeq = -1;
        try {
	        Log.Debug("============================================================");
	        Log.Debug("=== runInterface ===");
	        Log.Debug("============================================================");
	
	        String intfCd       = "INT_THRM194";
	        String intfNm       = "복직사항";
	        String uri          = apiHrm194;
			Map<String, Object> paramMap = new HashMap();

			//workday데이타(INT_TSYS986) interface 테이블에 저장
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);

			intfSeq = getInterfaceSequence(pSeq, paramMap);
			
			paramMap.put("intfSeq",  	intfSeq);

	
			//Completed, Corrected, Rescinded 호출
			intfSeq = callCCR("", uri, enterCd, fromDate, toDate, sabun, paramMap, request);	
	        
	        if(intfSeq > -1) {
	            //workday데이타 건별로 인터페이스 테이블 저장
	            iFThrmController.pumpIntfThrm194(paramMap);
	            //인터페이스 테이블 실 테이블에 저장 처리
	            if(dbProcCall) {
	            	iFThrmController.pkgIntfThrm194(paramMap);
	            }
	        }
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
        
        Log.DebugEnd();
        
        return intfSeq;
    }
	
	
    /**
     * 징계사항  API 호출
     * @param pSeq   인터페이스 순번
     * @param enterCd   회사코드
     * @param fromDate 조회시작일자
     * @param toDate 조회종료일자
     * @param sabun 사번
     * @param chkid 처리자
     * @throws Exception
     */
    private int runInterfaceTHRM195(int pSeq, String enterCd, String fromDate, String toDate, String sabun, String chkid, HttpServletRequest request) throws Exception {
    	Log.DebugStart();
    	int intfSeq =  -1;
    	try {
	    	Log.Debug("============================================================");
	    	Log.Debug("=== runInterface ===");
	    	Log.Debug("============================================================");
	    	
	    	String intfCd       = "INT_THRM195";
	    	String intfNm       = "징계사항";
	    	String uri          = apiHrm195;
	    	Map<String, Object> paramMap = new HashMap();

			//workday데이타(INT_TSYS986) interface 테이블에 저장
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);

			intfSeq = getInterfaceSequence(pSeq, paramMap);
			
			paramMap.put("intfSeq",  	intfSeq);
	
			//Completed, Corrected, Rescinded 호출
			intfSeq = callCCR("", uri, enterCd, fromDate, toDate, sabun, paramMap, request);	
	    	
	    	if(intfSeq > -1) {
	    		//workday데이타 건별로 인터페이스 테이블 저장
	    		iFThrmController.pumpIntfThrm195(paramMap);
	    		//인터페이스 테이블 실 테이블에 저장 처리
	    		if(dbProcCall) {
	    			iFThrmController.pkgIntfThrm195(paramMap);
	    		}
	    	}
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}

    	Log.DebugEnd();
    	
    	return intfSeq;
    }
    
    
    /**
     * 수습사항  API 호출
     * @param pSeq   인터페이스 순번
     * @param enterCd   회사코드
     * @param fromDate 조회시작일자
     * @param toDate 조회종료일자
     * @param sabun 사번
     * @param chkid 처리자
     * @throws Exception
     */
    private int runInterfaceTHRM196(String paramStr, String enterCd, String fromDate, String toDate, String sabun, String chkid, HttpServletRequest request) throws Exception {
    	Log.DebugStart();
    	int intfSeq = -1;
    	try {
	    	Log.Debug("============================================================");
	    	Log.Debug("=== runInterface ===");
	    	Log.Debug("============================================================");
	    	
	    	String intfCd       = "INT_THRM196";
	    	String intfNm       = "수습사항";
	    	String uri          = apiHrm196;
	    	Map<String, Object> paramMap = new HashMap();

			//workday데이타(INT_TSYS986) interface 테이블에 저장
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);

			//Completed, Corrected, Rescinded 호출
			intfSeq = callCCR(paramStr, uri, enterCd, fromDate, toDate, sabun, paramMap, request);	
	    	
	    	if(intfSeq > -1) {
	    		paramMap.put("intfSeq",  	intfSeq);
	    		//workday데이타 건별로 인터페이스 테이블 저장
	    		iFThrmController.pumpIntfThrm196(paramMap);
	    		//인터페이스 테이블 실 테이블에 저장 처리
	    		if(dbProcCall) {
	    			iFThrmController.pkgIntfThrm196(paramMap);
	    		}
	    	}
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
			throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
	
    	Log.DebugEnd();
    	
    	return intfSeq;
    }
    
    
    /**
     * 계약사항  API 호출
     * @param pSeq   인터페이스 순번
     * @param enterCd   회사코드
     * @param fromDate 조회시작일자
     * @param toDate 조회종료일자
     * @param sabun 사번
     * @param chkid 처리자
     * @throws Exception
     */
    private int runInterfaceTHRM197(String paramStr, String enterCd, String fromDate, String toDate, String sabun, String chkid, HttpServletRequest request) throws Exception {
    	Log.DebugStart();
    	int intfSeq = -1;
    	try {
	    	Log.Debug("============================================================");
	    	Log.Debug("=== runInterface ===");
	    	Log.Debug("============================================================");
	    	
	    	String intfCd       = "INT_THRM197";
	    	String intfNm       = "계약사항";
	    	String uri          = apiHrm197;
	    	Map<String, Object> paramMap = new HashMap();

			//workday데이타(INT_TSYS986) interface 테이블에 저장
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);
	
			//Completed, Corrected, Rescinded 호출
			intfSeq = callCCR(paramStr, uri, enterCd, fromDate, toDate, sabun, paramMap, request);	
	    	
	    	if(intfSeq > -1) {
	    		paramMap.put("intfSeq",  	intfSeq);
	    		//workday데이타 건별로 인터페이스 테이블 저장
	    		iFThrmController.pumpIntfThrm197(paramMap);
	    		//인터페이스 테이블 실 테이블에 저장 처리
	    		if(dbProcCall) {
	    			iFThrmController.pkgIntfThrm197(paramMap);
	    		}
	    	}
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}

    	Log.DebugEnd();
    	
    	return intfSeq;
    }
    
    
	/**
	 * 개인사진  API 호출
	 * @param oIntfSeq   대상리스트 intSeq  
	 * @param paramStr   파라메터 String
	 * @param chkEnterCd 
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTHRM911(int oIntfSeq, String Employee_ID, String paramStr, String enterCd, String chkid, HttpServletRequest request) throws Exception {
		
		Log.DebugStart();
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterfaceTHRM911 ===");
			Log.Debug("============================================================");
			
			String intfCd 		= "INT_THRM911";
			String intfNm 		= "개인사진";
			String uri 			= apiHrm911;
			
			//workday 데이타 조회
			//String apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
			String apiUri = googleApigeeUrl + uri + "?" + paramStr;
			Log.Debug("============================================================");
			Log.Debug("=== change apiUri ===");
			Log.Debug(apiUri);
			Log.Debug("============================================================");		
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		apiUri);
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);
			//intfSdate 추가 처리
			//paramMap.put("intfSdate", intfSdate);
			
			paramMap.put("intfCallFlag","Completed");
			paramMap.put("paramStr", 	paramStr);
			
			int intfSeq = saveInterfaceJSON(paramMap, request);
			
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				paramMap.put("oIntfSeq", 	oIntfSeq); //대상자 리스트 Seq
				
				//workday데이타 건별로 인터페이스 테이블 저장
				iFThrmController.pumpIntfThrm911(paramMap);
			}
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}

		Log.DebugEnd();
	}


	/**
	 * 개인사진 CLOB update 실행
	 * @param intfSeq
	 * @param enterCd
	 * @param chkid
	 * @param request
	 * @param targetList
	 * @throws Exception
	 */
	private void updatePhotoCLOB(int intfSeq, String paramStr, String enterCd, String chkid, HttpServletRequest request, List<?> targetList ) throws Exception {
		
		if( targetList.size() > 0 ){
			for(int i=0 ; i < targetList.size() ; i++){
				try {
					
					HashMap<String, Object> paramMap  	= (HashMap<String, Object>)targetList.get(i);
					String Company_ID 					= (String)paramMap.get("Company_ID");
					String Employee_ID 					= (String)paramMap.get("EEID");
					
					//String tmpParamStr = paramStr+"&Employee_ID=" + Employee_ID;
					String tmpParamStr = "Company_ID=" + Company_ID+"&Employee_ID=" + Employee_ID;
		
					runInterfaceTHRM911(intfSeq, Employee_ID, tmpParamStr, enterCd, chkid, request);
					
					
					
				} catch(HrException e){
					Log.Error("Error : "+e.toString());
				}
				
			}
		}
	}
	
		
	/**
	 * 개인사진 리스트 API 호출
	 * @param paramStr   파라메터 String
	 * @param chkEnterCd 
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTHRM911List(String paramStr, String enterCd, String chkid, HttpServletRequest request) throws Exception {
		
		Log.DebugStart();
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterfaceTHRM911Target ===");
			Log.Debug("============================================================");
			
			String intfCd 		= "INT_THRM911_LIST";
			String intfNm 		= "개인사진대상자";
			String uri 			= apiHrm911List;
			
			//workday 데이타 조회
			//String apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
			String apiUri = googleApigeeUrl + uri + "?" + paramStr;
			Log.Debug("============================================================");
			Log.Debug("=== change apiUri ===");
			Log.Debug(apiUri);
			Log.Debug("============================================================");		
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		apiUri);
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);
			//intfSdate 추가 처리
			//paramMap.put("intfSdate", intfSdate);
			
			paramMap.put("intfCallFlag",	"Completed");
			paramMap.put("paramStr", 	paramStr);
			
			int intfSeq = saveInterfaceJSON(paramMap, request);
			
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				List<?> targetList = iFThrmController.pumpIntfThrm911_LIST(paramMap);
				////////////////////////////////////////////////////////
				//사진 CLOB update
				////////////////////////////////////////////////////////
                if( targetList != null && (targetList.size() > 0) ) {
                    updatePhotoCLOB(intfSeq, paramStr, enterCd, chkid, request, targetList);

                    //인터페이스 테이블 실 테이블에 저장 처리
                    if (dbProcCall) {
                        iFThrmController.pkgIntfThrm911_LIST(paramMap);
                    }
                }
			} 
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
			throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
		
		Log.DebugEnd();
	}
	
	
	/**
	 * 수당발령  API 호출
	 * @param paramStr   파라메터 String
	 * @param chkEnterCd 
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTCPN429(String paramStr, String enterCd, String chkid, HttpServletRequest request) throws Exception {
		
		Log.DebugStart();
		
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterface ===");
			Log.Debug("============================================================");
			
			String intfCd 		= "INT_TCPN429";
			String intfNm 		= "개인별수당";
			String uri 			= apiCpn429;
			
			//workday 데이타 조회
			//String apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
			String apiUri = googleApigeeUrl + uri + "?" + paramStr;
			Log.Debug("============================================================");
			Log.Debug("=== change apiUri ===");
			Log.Debug(apiUri);
			Log.Debug("============================================================");		
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		apiUri);
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);
			//intfSdate 추가 처리
			//paramMap.put("intfSdate", intfSdate);
			
			paramMap.put("intfCallFlag",	"Completed");
			paramMap.put("paramStr", 	paramStr);
	
			int intfSeq = saveInterfaceJSON(paramMap, request);
	
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFTcpnController.pumpIntfTcpn429(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFTcpnController.pkgIntfTcpn429(paramMap);
				}
			}
		}catch(Exception e){
			Log.Error(e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
		
		Log.DebugEnd();
	}
	
	/**
	 * 평가결과  API 호출
	 * @param enterCd
	 * @param fromDate 조회시작일자
	 * @param toDate 조회종료일자
	 * @param sabun
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTCPN493(String paramStr, String enterCd, String chkid, String year, HttpServletRequest request) throws Exception {
		
		Log.DebugStart();
		
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterface ===");
			Log.Debug("============================================================");
			
			String intfCd 		= "INT_TCPN493";
			String intfNm 		= "평가결과";
			String uri 			= apiCpn493;
			
			//workday 데이타 조회
			//String apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
			String apiUri = googleApigeeUrl + uri + "?" + paramStr;
			Log.Debug("============================================================");
			Log.Debug("=== change apiUri ===");
			Log.Debug(apiUri);
			Log.Debug("============================================================");		
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		apiUri);
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);
			//intfSdate 추가 처리
			//paramMap.put("intfSdate", intfSdate);
			
			paramMap.put("intfCallFlag",	"Completed");
			paramMap.put("paramStr", 	paramStr);
			
			int intfSeq = saveInterfaceJSON(paramMap, request);
			
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFTcpnController.pumpIntfTcpn493(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					//삭제 처리용 년도 설정
					paramMap.put("appraisalYy", year);
					
					iFTcpnController.pkgIntfTcpn493(paramMap);
				}
			}
		}catch(Exception e){
			Log.Error(e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
		
		Log.DebugEnd();
	}
	
	
	/**
	 * 생수불출내역  API 호출
	 * @param enterCd
	 * @param fromDate 조회시작일자
	 * @param toDate 조회종료일자
	 * @param sabun
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTBEN592(String paramStr, String enterCd, String chkid, HttpServletRequest request) throws Exception {
		
		Log.DebugStart();
		
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterfaceTBEN592  ===");
			Log.Debug("============================================================");
			
			String intfCd 		= "INT_TBEN592";
			String intfNm 		= "생수불출내역";
			String uri 			= apiBen592;
			//workday 데이타 조회
			//String apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
			String apiUri = googleApigeeUrl + uri + "?" + paramStr;
			Log.Debug("============================================================");
			Log.Debug("=== change apiUri ===");
			Log.Debug(apiUri);
			Log.Debug("============================================================");		
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		apiUri);
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);
			//intfSdate 추가 처리
			//paramMap.put("intfSdate", intfSdate);
			
			paramMap.put("intfCallFlag",	"Completed");
			paramMap.put("paramStr", 	paramStr);
	
			int intfSeq = saveInterfaceJSON(paramMap, request);	
			
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFTbenController.pumpIntfTben592(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFTbenController.pkgIntfTben592(paramMap);
				}
			}
		}catch(Exception e){
			Log.Error(e.toString());
			
			throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
		
		Log.DebugEnd();
	}
	
	
	
	/**
	 * 한국공항 부서근무조스케줄  API 호출
	 * @param enterCd
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTTIM112(String paramStr, String enterCd, String chkid, HttpServletRequest request) throws Exception {
		
		Log.DebugStart();
		
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterfaceTTIM112  ===");
			Log.Debug("============================================================");
			
			String intfCd 		= "INT_TTIM112";
			String intfNm 		= "한국공항 부서근무조스케줄";
			String uri 			= apiTim112;
			//workday 데이타 조회
			//String apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
			String apiUri = googleApigeeUrl + uri + "?" + paramStr;
			Log.Debug("============================================================");
			Log.Debug("=== change apiUri ===");
			Log.Debug(apiUri);
			Log.Debug("============================================================");		
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		apiUri);
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);
			//intfSdate 추가 처리
			//paramMap.put("intfSdate", intfSdate);
			
			paramMap.put("intfCallFlag",	"Completed");
			paramMap.put("paramStr", 	paramStr);
			
			int intfSeq = saveInterfaceJSON(paramMap, request);	
			
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFTtimController.pumpIntfTtim112(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFTtimController.pkgIntfTtim112(paramMap);
				}
			}
		}catch(Exception e){
			Log.Error(e.toString());
			
			throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
		
		Log.DebugEnd();
	}
	
	/**
	 * 한진정보통신 출장,교육  API 호출
	 * @param enterCd
	 * @param fromDate 조회시작일자
	 * @param toDate 조회종료일자
	 * @param sabun
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTTIM301Etc(String paramStr, String enterCd, String chkid, HttpServletRequest request) throws Exception {
		
		Log.DebugStart();
		
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterfaceTTIM301Etc  ===");
			Log.Debug("============================================================");
			
			String intfCd 		= "INT_TTIM301_ETC";
			String intfNm 		= "한진정보통신 출장 교육";
			String uri 			= apiTim301Etc;
			//workday 데이타 조회
			//String apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
			String apiUri = googleApigeeUrl + uri + "?" + paramStr;
			Log.Debug("============================================================");
			Log.Debug("=== change apiUri ===");
			Log.Debug(apiUri);
			Log.Debug("============================================================");		
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		apiUri);
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);
			//intfSdate 추가 처리
			//paramMap.put("intfSdate", intfSdate);
			
			paramMap.put("intfCallFlag",	"Completed");
			paramMap.put("paramStr", 	paramStr);
			
			int intfSeq = saveInterfaceJSON(paramMap, request);	
			
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFTtimController.pumpIntfTtim301Etc(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFTtimController.pkgIntfTtim301Etc(paramMap);
				}
			}
		}catch(Exception e){
			Log.Error(e.toString());
			
			throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
		
		Log.DebugEnd();
	}
	
	/**
	 * 한진정보통신 타각  API 호출
	 * @param enterCd
	 * @param fromDate 조회시작일자
	 * @param toDate 조회종료일자
	 * @param sabun
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTTIM331(String paramStr, String enterCd, String chkid, HttpServletRequest request) throws Exception {
		
		Log.DebugStart();
		
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterfaceTTIM331  ===");
			Log.Debug("============================================================");
			
			String intfCd 		= "INT_TTIM331";
			String intfNm 		= "한진정보통신 타각";
			String uri 			= apiTim331;
			//workday 데이타 조회
			//String apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
			String apiUri = googleApigeeUrl + uri + "?" + paramStr;
			Log.Debug("============================================================");
			Log.Debug("=== change apiUri ===");
			Log.Debug(apiUri);
			Log.Debug("============================================================");		
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		apiUri);
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			paramMap.put("chkEnterCd", 	enterCd);
			//intfSdate 추가 처리
			//paramMap.put("intfSdate", intfSdate);
			
			paramMap.put("intfCallFlag",	"Completed");
			paramMap.put("paramStr", 	paramStr);
			
			int intfSeq = saveInterfaceJSON(paramMap, request);	
			
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFTtimController.pumpIntfTtim331(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFTtimController.pkgIntfTtim331(paramMap);
				}
			}
		}catch(Exception e){
			Log.Error(e.toString());
			
			throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
		
		Log.DebugEnd();
	}

    /**
     * 한진관광 타각  API 호출
     * @param enterCd
     * @param fromDate 조회시작일자
     * @param toDate 조회종료일자
     * @param sabun
     * @param chkid
     * @throws Exception
     */
    private void runInterfaceTTIM331_kaltour(String paramStr, String enterCd, String chkid, HttpServletRequest request) throws Exception {

        Log.DebugStart();

        try {
            Log.Debug("============================================================");
            Log.Debug("=== runInterfaceTTIM331_kaltour  ===");
            Log.Debug("============================================================");

            String intfCd 		= "INT_TTIM331_HT";
            String intfNm 		= "한진관광 타각";
            String uri 			= apiTim331_kaltour;
            //workday 데이타 조회
            //String apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
            String apiUri = googleApigeeUrl + uri + "?" + paramStr;
            Log.Debug("============================================================");
            Log.Debug("=== change apiUri ===");
            Log.Debug(apiUri);
            Log.Debug("============================================================");

            //workday데이타(INT_TSYS986) interface 테이블에 저장
            Map<String, Object> paramMap = new HashMap();
            paramMap.put("apiUri", 		apiUri);
            paramMap.put("intfCd", 		intfCd);
            paramMap.put("intfSdate",	"");
            paramMap.put("intfNm", 		intfNm);
            paramMap.put("chkid", 		chkid);
            paramMap.put("chkEnterCd", 	enterCd);
            //intfSdate 추가 처리
            //paramMap.put("intfSdate", intfSdate);

            paramMap.put("intfCallFlag",	"Completed");
            paramMap.put("paramStr", 	paramStr);

            int intfSeq = saveInterfaceJSON(paramMap, request);

            if(intfSeq > -1) {
                paramMap.put("intfSeq", 	intfSeq);
                //workday데이타 건별로 인터페이스 테이블 저장
                iFTtimController.pumpIntfTtim331(paramMap);
                //인터페이스 테이블 실 테이블에 저장 처리
                if(dbProcCall) {
                    iFTtimController.pkgIntfTtim331(paramMap);
                }
            }
        }catch(Exception e){
            Log.Error(e.toString());

            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
        }

        Log.DebugEnd();
    }

	/**
	 * interface 데이타 임시테이블(INT_TSYS986) 저장
	 * @param apiUri        interface 호출 api
	 * @param intfCd	interface코드
	 * @param intfNm   interface명
	 * @return
	 */
	private int saveInterfaceJSON(Map<String, Object> paramMap, HttpServletRequest request) throws Exception  {
		
		Log.DebugStart();
		
		Log.Debug("============================================================");
		Log.Debug("=== saveInterfaceJSON ===");
		Log.Debug("============================================================");
		
		int intfSeq         = -1;
		JSONObject jsonObj 	= null;
		
		//인터페이스 정보(INT_TSYS986 임시테이블 저장용)
		Map<String, Object> dataMap = new HashMap<String, Object>();
		dataMap.put("intfCd", paramMap.get("intfCd"));
		dataMap.put("intfNm", paramMap.get("intfNm"));
		
		try {
			//Api 호출 결과 받아오기
			jsonObj			= httpUtils.apigeeRestApiCC(paramMap, accessToken, tokenType, request);

            System.out.println("");
            System.out.println("");
            System.out.println("jsonObj : ");
            System.out.println(jsonObj);
            System.out.println("");
            System.out.println("");

			//RestTemplate 결과가 null이면

			if(jsonObj == null) {
				Log.Error("interface data is null.");
				return -1;
			}else {
			    intfSeq = getInterfaceSequence(null, paramMap);

				paramMap.put("intfSeq",  	intfSeq);			
				
				//인터페이스 임시테이블에 저장(INT_TSYS986)
				dataMap.put("intfSeq", 		intfSeq);
				dataMap.put("jsonData", 	jsonObj.toString());
				dataMap.put("jsonDataLen", 	jsonObj.toString().length() - 19);
				dataMap.put("jsonDataByte", jsonObj.toString().getBytes().length - 19);

				dataMap.put("intfCallFlag", paramMap.get("intfCallFlag"));
				dataMap.put("paramStr", 	paramMap.get("paramStr"));
				dataMap.put("chkEnterCd", 	paramMap.get("chkEnterCd"));
				dataMap.put("sabun", 		paramMap.get("chkid"));
				interfaceService.saveINT_TSYS986(dataMap);
			}


			
		} catch(HrException e){
			intfSeq         = -1;
			Log.Error(e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
		
		
		Log.DebugEnd();
		
		return intfSeq;
	}
	
	/**
	 * Completed, Corrected, Rescinded 전체 호출
	 * @param uri
	 * @param enterCd
	 * @param fromDate
	 * @param toDate
	 * @param sabun
	 * @param paramMap
	 * @return
	 * @throws Exception
	 */
	private int callCCR(String paramStr, String uri, String enterCd, String fromDate, String toDate, String sabun,  Map<String, Object> paramMap, HttpServletRequest request) throws Exception  {
		int intfSeq 		= -1;
		String apiUri 	= "";
		try {
			
			if(paramStr == null || paramStr.equals("")) {
				/////////////////////////////////////
				// 1.Completed or Corrected or Rescinded
				/////////////////////////////////////
				paramStr = getParamStr("Completed", enterCd, fromDate, toDate, sabun );
			}
			
			//apiUri = googleApigeeUrl + uri + "?" + dataType + "&" + paramStr;
			apiUri = googleApigeeUrl + uri + "?" + paramStr;

			paramMap.put("intfCallFlag",	"Completed");
			paramMap.put("apiUri", 		apiUri);
			paramMap.put("paramStr", 	paramStr);
			
			intfSeq = saveInterfaceJSON(paramMap, request);
			
			Log.Debug("============================================================");
			Log.Debug("=== callCCR change apiUri ===");
			Log.Debug(apiUri);
			Log.Debug("============================================================");		
			
		} catch(HrException e){
		  
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
		return intfSeq;			
	}
	
	/**
	 * Completed, Corrected, Rescinded 파라메터 만들기
	 * @param callOption
	 * @param enterCd
	 * @param fromDate
	 * @param toDate
	 * @param sabun
	 * @return
	 */
	private String getParamStr(String callOption, String enterCd, String fromDate, String toDate,  String sabun) throws Exception  {
		
		String paramStr = "";

		SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd");
		Date now 		= new Date();
		Calendar cal = new GregorianCalendar(Locale.KOREA);
		cal.setTime(now);
		String today 	= format.format(cal.getTime());
		//1년전 기준일
		cal.add(Calendar.DATE, -365);
		String previousYearDate 	= format.format(cal.getTime());

		/////////////////////////////////////
		// Completed or Corrected or Rescinded
		/////////////////////////////////////
		//String CompletedBaseDate = "2023-09-01"; //2023.11.29 유재윤상무, 임영일프로 요청 (1년 전으로 기준설정)
		String CompletedBaseDate = previousYearDate;
		
		paramStr = "Company_ID="+enterCd;

		//1. workday key field
		paramStr = paramStr+"&Completed_Date_On_or_After_for_All="+CompletedBaseDate;
		//paramStr = paramStr+"&Completed_Date_On_or_After_for_All="+fromDate;
		paramStr = paramStr+"&Completed_Date_On_or_Before_for_All="+toDate;

		//2. Completed
		paramStr = paramStr+"&Completed_Date_On_or_After="+fromDate;
		paramStr = paramStr+"&Completed_Date_On_or_Before="+toDate;

		//3. Corrected
		paramStr = paramStr+"&Corrected_on_or_after="+fromDate;
		paramStr = paramStr+"&Corrected_on_or_before="+toDate;

		//4. Rescinded
		paramStr = paramStr+"&Rescinded_on_or_after="+fromDate;
		paramStr = paramStr+"&Rescinded_on_or_before="+toDate;

		if(sabun != null) {
			paramStr = "Company_ID="+enterCd;
			paramStr = paramStr+"&Completed_Date_On_or_After_for_All="+CompletedBaseDate;
			paramStr = paramStr+"&Completed_Date_On_or_Before_for_All="+toDate;

			paramStr = paramStr+"&Employee_ID="+sabun;
		}


//			/////////////////////////////////////
//			// 1.Completed
//			/////////////////////////////////////
//			if(callOption.equals("Completed")) {
//				paramStr = paramStr+"Company_ID="+enterCd;
//
//				if(sabun != null) {
//					paramStr = paramStr+"&Employee_ID="+sabun;
//				}else {
//					paramStr = paramStr+"&Completed_Date_On_or_After="+date;
//					paramStr = paramStr+"&Completed_Date_On_or_Before="+date;
//				}
//
//			/////////////////////////////////////
//			//2.Corrected
//			/////////////////////////////////////
//			}else if(callOption.equals("Corrected")) {
//				paramStr = paramStr+"Company_ID="+enterCd;
//
//				if(sabun != null) {
//					paramStr = paramStr+"&Employee_ID="+sabun;
//				}else {
//					paramStr = paramStr+"&Completed_Date_On_or_After="+preYear;
//					paramStr = paramStr+"&Completed_Date_On_or_Before="+date;
//					paramStr = paramStr+"&Corrected_on_or_after="+date;
//					paramStr = paramStr+"&Corrected_on_or_before="+date;
//				}
//			/////////////////////////////////////
//			//3.Rescinded
//			/////////////////////////////////////
//			}else if(callOption.equals("Rescinded")) {
//				paramStr = paramStr+"Company_ID="+enterCd;
//
//				if(sabun != null) {
//					paramStr = paramStr+"&Employee_ID="+sabun;
//				}else {
//					paramStr = paramStr+"&Completed_Date_On_or_After="+preYear;
//					paramStr = paramStr+"&Completed_Date_On_or_Before="+date;
//					paramStr = paramStr+"&Rescinded_on_or_after="+date;
//					paramStr = paramStr+"&Rescinded_on_or_before="+date;
//				}
//			}
		return paramStr;
	}
	
	/**
	 * 매출내역 조회(사용 일시별)
	 * @param session
	 * @param request
	 * @param paramMap
	 * @return
	 * @throws Exception
	 */
	@RequestMapping(params = "cmd=getFoodCouponList1", method={ RequestMethod.GET, RequestMethod.POST })
	public ModelAndView  getFoodCouponList1(HttpSession session, HttpServletRequest request,
			@RequestParam Map<String, Object> paramMap) throws Exception {
		
		Log.DebugStart();

		//호출 api
		String apiNm = "sales/date";
		
		JSONObject jsonObj 	= null;
		JSONArray resultJsonArray = new JSONArray();
		
		String Message = "";
		
		try{
			
			Map<String, Object> parameter = new HashMap();
			parameter.put("appId"    	, oliveAppId);
			parameter.put("startDate"   , paramMap.get("startDate").toString());
			parameter.put("endDate"    	, paramMap.get("endDate").toString());
			
			jsonObj = httpUtils.getRestTemplateJson(oliveUrl+"/"+apiNm, parameter, request);
			String jsonStr = jsonObj.toJSONString().replaceAll("'", "CHR(39)");
			
			JSONParser jsonParser = new JSONParser();
			jsonObj = (JSONObject) jsonParser.parse(jsonStr);

			if(jsonObj.get("response") != null) {
				JSONObject resJsonObj = (JSONObject) jsonObj.get("response");
				resultJsonArray = (JSONArray) resJsonObj.get("salesList"); 	
			}
	    	
		}catch(HrException e){
			Message=LanguageUtil.getMessage("msg.alertSearchFail2", null, "조회에 실패하였습니다.");
		}
		ModelAndView mv = new ModelAndView();
		
		mv.setViewName("jsonView");
		mv.addObject("DATA", resultJsonArray);
		mv.addObject("Message", Message);

		Log.DebugEnd();
		return mv;
	}
    
	
	/**
	 * 매출내역 조회(직원별)
	 * @param session
	 * @param request
	 * @param paramMap
	 * @return
	 * @throws Exception
	 */
	@RequestMapping(params = "cmd=getFoodCouponList2", method={ RequestMethod.GET, RequestMethod.POST })
	public ModelAndView  getFoodCouponList2(HttpSession session, HttpServletRequest request,
			@RequestParam Map<String, Object> paramMap) throws Exception {
		
		Log.DebugStart();
		
		//호출 api
		String apiNm = "sales/employee";
		
		JSONObject jsonObj 	= null;
		JSONArray resultJsonArray = new JSONArray();
		
		String Message = "";
		
		try{
			
			Map<String, Object> parameter = new HashMap();
			parameter.put("appId"    	, oliveAppId);
			parameter.put("startDate"   , paramMap.get("startDate").toString());
			parameter.put("endDate"    	, paramMap.get("endDate").toString());
			
			jsonObj = httpUtils.getRestTemplateJson(oliveUrl+"/"+apiNm, parameter, request);
			String jsonStr = jsonObj.toJSONString().replaceAll("'", "CHR(39)");
			
			JSONParser jsonParser = new JSONParser();
			jsonObj = (JSONObject) jsonParser.parse(jsonStr);

			if(jsonObj.get("response") != null) {
				JSONObject resJsonObj = (JSONObject) jsonObj.get("response");
				resultJsonArray = (JSONArray) resJsonObj.get("salesList"); 	
			}
			
		}catch(HrException e){
			Message=LanguageUtil.getMessage("msg.alertSearchFail2", null, "조회에 실패하였습니다.");
		}
		ModelAndView mv = new ModelAndView();
		
		mv.setViewName("jsonView");
		mv.addObject("DATA", resultJsonArray);
		mv.addObject("Message", Message);
		
		Log.DebugEnd();
		return mv;
	}
	
	
	/** 
	 * 조직정보 Migration 실행
	 * @param parameter
	 * @throws Exception
	 */
	private void runInterfaceTORG105_MIG(String paramStr, String chkEnterCd, String chkid, String fileNm) throws Exception {

		Log.DebugStart();
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterface ===");
			Log.Debug("============================================================");
	
			String intfCd 		= "INT_TORG105";
			String intfNm 		= "조직정보_MIG";
			String uri 			= apiOrg105;
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		"");
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			
	        paramMap.put("paramStr",    paramStr);
	        paramMap.put("chkEnterCd",  chkEnterCd);
	        paramMap.put("fileNm",      fileNm);
	
			//조직사항 api 처리
			paramMap.put("intfCallFlag",	"Migration");
			paramMap.put("paramStr", 	paramStr);
	        
			int intfSeq = saveInterfaceJSON_MIG(paramMap);
	        
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFTorgController.pumpIntfTorg105(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFTorgController.pkgIntfTorg101(paramMap);
					iFTorgController.pkgIntfTorg103(paramMap);
					iFTorgController.pkgIntfTorg105Init(paramMap);
					iFTorgController.pkgIntfTorg105(paramMap);
				}
			}
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}

		Log.DebugEnd();
	}
	
	
	/**
	 * 발령정보 Migration 실행
	 * @param paramStr   파라메터 String
	 * @param chkEnterCd 
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTHRM100_MIG(String paramStr, String chkEnterCd, String chkid, String fileNm) throws Exception {
		Log.DebugStart();
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterface ===");
			Log.Debug("============================================================");
	
			String intfCd 		= "INT_THRM100";
			String intfNm 		= "인사마스터_MIG";
			String uri 			= apiHrm100;
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		"");
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			
	        paramMap.put("paramStr",    paramStr);
	        paramMap.put("chkEnterCd",  chkEnterCd);
	        paramMap.put("fileNm",      fileNm);
			
			//개인발령사항 api 처리
			paramMap.put("intfCallFlag",	"Migration");
			paramMap.put("paramStr", 	paramStr);
	
			int intfSeq = saveInterfaceJSON_MIG(paramMap);
	
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFThrmController.pumpIntfThrm100_MIG(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFThrmController.pkgIntfThrm100(paramMap);
				}
			}
			
			Log.Debug("============================================================");
			Log.Debug("intfSeq : "+intfSeq);
			Log.Debug("============================================================");

		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}

		Log.DebugEnd();
	}
	
	
	/**
	 * 발령정보 Migration 실행
	 * @param paramStr   파라메터 String
	 * @param chkEnterCd 
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTHRM192_MIG(String paramStr, String chkEnterCd, String chkid, String fileNm) throws Exception {
		Log.DebugStart();
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterface ===");
			Log.Debug("============================================================");
			
			String intfCd 		= "INT_THRM192";
			String intfNm 		= "개인발령사항_MIG";
			String uri 			= apiHrm192;
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		"");
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			
			paramMap.put("paramStr",    paramStr);
			paramMap.put("chkEnterCd",  chkEnterCd);
			paramMap.put("fileNm",      fileNm);
			
			//개인발령사항 api 처리
			paramMap.put("intfCallFlag",	"Migration");
			int intfSeq = saveInterfaceJSON_MIG(paramMap);
			
			if(intfSeq > -1) {
				paramMap.put("intfSeq", 	intfSeq);
				//workday데이타 건별로 인터페이스 테이블 저장
				iFThrmController.pumpIntfThrm192_MIG(paramMap);
				
				//인터페이스 테이블 실 테이블에 저장 처리
//				//////////////////////////////////////////////////
//				//휴복직이력(휴직) api 처리 후 인터페이스 테이블 실 테이블 저장
//				runInterfaceTHRM193_MIG(intfSeq, paramStr, chkEnterCd, chkid, fileNm_THRM193+"-"+chkEnterCd);
//				//휴복직이력(복직) api 처리 후 인터페이스 테이블 실 테이블 저장
//				runInterfaceTHRM194_MIG(intfSeq, paramStr, chkEnterCd, chkid, fileNm_THRM194+"-"+chkEnterCd);
//				//징계 api 처리 후 인터페이스 테이블 실 테이블 저장
//				runInterfaceTHRM195_MIG(intfSeq, paramStr, chkEnterCd, chkid, fileNm_THRM195+"-"+chkEnterCd);
//				//수습 api 처리 후 인터페이스 테이블 실 테이블 저장
//				runInterfaceTHRM196_MIG(intfSeq, paramStr, chkEnterCd, chkid, fileNm_THRM196+"-"+chkEnterCd);
//				//계약 api 처리 후 인터페이스 테이블 실 테이블 저장
//				runInterfaceTHRM197_MIG(intfSeq, paramStr, chkEnterCd, chkid, fileNm_THRM197+"-"+chkEnterCd);
//				//////////////////////////////////////////////////			
				
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					//iFThrmController.pkgIntfThrm192(paramMap);
					iFThrmController.pkgIntfThrm191_MIG(paramMap);
					iFThrmController.pkgIntfThrm151(paramMap);
				}
			}
			
			Log.Debug("============================================================");
			Log.Debug("intfSeq : "+intfSeq);
			Log.Debug("============================================================");
			
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
			throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
		
		Log.DebugEnd();
	}
	
	
	

	/**
	 * 
	 * @param paramMap
	 * @return
	 */
	private int saveInterfaceJSON_MIG(Map<String, Object> paramMap) throws Exception {
		
		Log.DebugStart();
		
		Log.Debug("============================================================");
		Log.Debug("=== saveInterfaceJSONMig ===");
		Log.Debug("============================================================");
		
		int intfSeq         = -1;
		
		//인터페이스 정보(INT_TSYS986 임시테이블 저장용)
		Map<String, Object> dataMap = new HashMap<String, Object>();
		dataMap.put("intfCd", paramMap.get("intfCd"));
		dataMap.put("intfNm", paramMap.get("intfNm"));
		
		try {
		    /*
			JSONParser parser = new JSONParser();
			FileReader reader = new FileReader("C:\\Project\\EHR_APP\\hg-ehr\\WebContent\\json\\"+paramMap.get("fileNm").toString()+".json");
			JSONObject jsonObject = (JSONObject) parser.parse(reader);
			*/

		    JSONParser parser = new JSONParser();
		    JSONObject jsonObject;

		    try (FileReader reader = new FileReader("C:\\Project\\EHR_APP\\hg-ehr\\WebContent\\json\\" + paramMap.get("fileNm").toString() + ".json")) {
		        jsonObject = (JSONObject) parser.parse(reader);
		    } catch (IOException | ParseException e) {
		        throw new RuntimeException("Error while reading or parsing JSON", e);
		    }

			
			//RestTemplate 결과가 null이면 
			if(jsonObject == null) {
				Log.Error("interface data is null.");
				return -1;
			}else {
				//인터페이스 순서 가져오기
			    /*
				if(paramMap.get("intfSeq") != null && Integer.parseInt(paramMap.get("intfSeq").toString()) > -1) {
					intfSeq = Integer.parseInt(paramMap.get("intfSeq").toString());
				}else {
					Map<String, Object> rMap = (Map<String, Object>) interfaceService.getINT_TSYS986Seq(dataMap);
					intfSeq = Integer.parseInt(rMap.get("intfSeq").toString());					
				}
				*/
			    intfSeq = getInterfaceSequence(null, paramMap);

				//인터페이스 임시테이블에 저장(INT_TSYS986)
				dataMap.put("intfSeq", 		intfSeq);
				dataMap.put("jsonData", 	jsonObject.toString());
				dataMap.put("jsonDataLen", 	jsonObject.toString().length() - 19);
				dataMap.put("jsonDataByte", jsonObject.toString().getBytes().length - 19);
				
                dataMap.put("paramStr",      paramMap.get("paramStr").toString());
                dataMap.put("chkEnterCd",    paramMap.get("chkEnterCd").toString());
                dataMap.put("intfCallFlag",  paramMap.get("intfCallFlag").toString());
                
				dataMap.put("sabun", 		paramMap.get("chkid"));
				interfaceService.saveINT_TSYS986(dataMap);
			}
			
		} catch(HrException e){
			intfSeq         = -1;
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}

		Log.DebugEnd();
		
		return intfSeq;
	}
	
	
	/**
	 * 휴복직정보(휴직) Migration 실행
	 * @param intfSeq   인터페이스 순번
	 * @param paramStr   파라메터 String
	 * @param chkEnterCd 
	 * @param chkid
	 * @throws Exception
	 */
	private void runInterfaceTHRM193_MIG(int intfSeq, String paramStr, String chkEnterCd, String chkid, String fileNm) throws Exception {
		Log.DebugStart();
		
		try {
			Log.Debug("============================================================");
			Log.Debug("=== runInterface ===");
			Log.Debug("============================================================");
	
			String intfCd 		= "INT_THRM193";
			String intfNm 		= "휴직사항_MIG";
			String uri 			= apiHrm193;
			
			//workday데이타(INT_TSYS986) interface 테이블에 저장
			Map<String, Object> paramMap = new HashMap();
			paramMap.put("apiUri", 		"");
			paramMap.put("intfCd", 		intfCd);
			paramMap.put("intfSdate",	"");
			paramMap.put("intfNm", 		intfNm);
			paramMap.put("chkid", 		chkid);
			
	        paramMap.put("paramStr",    paramStr);
	        paramMap.put("chkEnterCd",  chkEnterCd);
	        paramMap.put("fileNm",      fileNm);
			
			//intfSdate 추가 처리
			//paramMap.put("intfSdate", intfSdate);
	
			//개인발령사항 api 처리
	        paramMap.put("intfSeq", 	intfSeq);
			paramMap.put("intfCallFlag",	"Migration");
			intfSeq = saveInterfaceJSON_MIG(paramMap);
			
			if(intfSeq > -1) {
				//workday데이타 건별로 인터페이스 테이블 저장
				iFThrmController.pumpIntfThrm193_MIG(paramMap);
				//인터페이스 테이블 실 테이블에 저장 처리
				if(dbProcCall) {
					iFThrmController.pkgIntfThrm193(paramMap);
				}
			}
			
			Log.Debug("============================================================");
			Log.Debug("intfSeq : "+intfSeq);
			Log.Debug("============================================================");

		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
	
		Log.DebugEnd();
	}
	

    /**
     * 휴복직정보(복직) Migration 실행
     * @param intfSeq   인터페이스 순번
     * @param paramStr   파라메터 String
     * @param chkEnterCd 
     * @param chkid
     * @throws Exception
     */
    private void runInterfaceTHRM194_MIG(int intfSeq, String paramStr, String chkEnterCd, String chkid, String fileNm) throws Exception {
        Log.DebugStart();
        
        try {
	        Log.Debug("============================================================");
	        Log.Debug("=== runInterface ===");
	        Log.Debug("============================================================");
	
	        String intfCd       = "INT_THRM194";
	        String intfNm       = "복직사항_MIG";
	        String uri          = apiHrm194;
	        
	        //workday데이타(INT_TSYS986) interface 테이블에 저장
	        Map<String, Object> paramMap = new HashMap();
	        paramMap.put("apiUri",      "");
	        paramMap.put("intfCd",      intfCd);
	        paramMap.put("intfSdate",   "");
	        paramMap.put("intfNm",      intfNm);
	        paramMap.put("chkid",       chkid);
	        
	        paramMap.put("paramStr",    paramStr);
	        paramMap.put("chkEnterCd",  chkEnterCd);
	        paramMap.put("fileNm",      fileNm);
	        
	        //intfSdate 추가 처리
	        //paramMap.put("intfSdate", intfSdate);
	
	        //개인발령사항 api 처리
	        paramMap.put("intfSeq",     intfSeq);
			paramMap.put("intfCallFlag",	"Migration");
	        intfSeq = saveInterfaceJSON_MIG(paramMap);
	        
	        if(intfSeq > -1) {
	            //workday데이타 건별로 인터페이스 테이블 저장
	            iFThrmController.pumpIntfThrm194_MIG(paramMap);
	            //인터페이스 테이블 실 테이블에 저장 처리
	            if(dbProcCall) {
	            	iFThrmController.pkgIntfThrm194(paramMap);
	            }
	        }
	        
	        Log.Debug("============================================================");
	        Log.Debug("intfSeq : "+intfSeq);
	        Log.Debug("============================================================");

        } catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}
	        
        Log.DebugEnd();
    }
    
    
    /**
     * 징계 Migration 실행
     * @param intfSeq   인터페이스 순번
     * @param paramStr   파라메터 String
     * @param chkEnterCd 
     * @param chkid
     * @throws Exception
     */
    private void runInterfaceTHRM195_MIG(int intfSeq, String paramStr, String chkEnterCd, String chkid, String fileNm) throws Exception {
    	Log.DebugStart();
    	
    	try {
    		Log.Debug("============================================================");
    		Log.Debug("=== runInterface ===");
    		Log.Debug("============================================================");
    		
    		String intfCd       = "INT_THRM195";
    		String intfNm       = "징계사항_MIG";
    		String uri          = apiHrm195;
    		
    		//workday데이타(INT_TSYS986) interface 테이블에 저장
    		Map<String, Object> paramMap = new HashMap();
    		paramMap.put("apiUri",      "");
    		paramMap.put("intfCd",      intfCd);
    		paramMap.put("intfSdate",   "");
    		paramMap.put("intfNm",      intfNm);
    		paramMap.put("chkid",       chkid);
    		
    		paramMap.put("paramStr",    paramStr);
    		paramMap.put("chkEnterCd",  chkEnterCd);
    		paramMap.put("fileNm",      fileNm);
    		
    		//intfSdate 추가 처리
    		//paramMap.put("intfSdate", intfSdate);
    		
    		//개인발령사항 api 처리
    		paramMap.put("intfSeq",     intfSeq);
    		paramMap.put("intfCallFlag",	"Migration");
    		intfSeq = saveInterfaceJSON_MIG(paramMap);
    		
    		if(intfSeq > -1) {
    			//workday데이타 건별로 인터페이스 테이블 저장
    			iFThrmController.pumpIntfThrm195_MIG(paramMap);
    			//인터페이스 테이블 실 테이블에 저장 처리
    			if(dbProcCall) {
    				iFThrmController.pkgIntfThrm195(paramMap);
    			}
    		}
    		
    		Log.Debug("============================================================");
    		Log.Debug("intfSeq : "+intfSeq);
    		Log.Debug("============================================================");
    		
    	} catch(HrException e){
    		Log.Error("Error : "+e.toString());
    		
    		throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
    	}
    	
    	Log.DebugEnd();
    }
    
    
    /**
     * 수습 Migration 실행
     * @param intfSeq   인터페이스 순번
     * @param paramStr   파라메터 String
     * @param chkEnterCd 
     * @param chkid
     * @throws Exception
     */
    private void runInterfaceTHRM196_MIG(int intfSeq, String paramStr, String chkEnterCd, String chkid, String fileNm) throws Exception {
    	Log.DebugStart();
    	
    	try {
    		Log.Debug("============================================================");
    		Log.Debug("=== runInterface ===");
    		Log.Debug("============================================================");
    		
    		String intfCd       = "INT_THRM196";
    		String intfNm       = "수습사항_MIG";
    		String uri          = apiHrm196;
    		
    		//workday데이타(INT_TSYS986) interface 테이블에 저장
    		Map<String, Object> paramMap = new HashMap();
    		paramMap.put("apiUri",      "");
    		paramMap.put("intfCd",      intfCd);
    		paramMap.put("intfSdate",   "");
    		paramMap.put("intfNm",      intfNm);
    		paramMap.put("chkid",       chkid);
    		
    		paramMap.put("paramStr",    paramStr);
    		paramMap.put("chkEnterCd",  chkEnterCd);
    		paramMap.put("fileNm",      fileNm);
    		
    		//intfSdate 추가 처리
    		//paramMap.put("intfSdate", intfSdate);
    		
    		//개인발령사항 api 처리
    		paramMap.put("intfSeq",     intfSeq);
    		paramMap.put("intfCallFlag",	"Migration");
    		intfSeq = saveInterfaceJSON_MIG(paramMap);
    		
    		if(intfSeq > -1) {
    			//workday데이타 건별로 인터페이스 테이블 저장
    			iFThrmController.pumpIntfThrm196_MIG(paramMap);
    			//인터페이스 테이블 실 테이블에 저장 처리
    			if(dbProcCall) {
    				iFThrmController.pkgIntfThrm196(paramMap);
    			}
    		}
    		
    		Log.Debug("============================================================");
    		Log.Debug("intfSeq : "+intfSeq);
    		Log.Debug("============================================================");
    		
    	} catch(HrException e){
    		Log.Error("Error : "+e.toString());
    		
    		throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
    	}
    	
    	Log.DebugEnd();
    }
    
	
    /**
     * 계약 Migration 실행
     * @param intfSeq   인터페이스 순번
     * @param paramStr   파라메터 String
     * @param chkEnterCd 
     * @param chkid
     * @throws Exception
     */
    private void runInterfaceTHRM197_MIG(int intfSeq, String paramStr, String chkEnterCd, String chkid, String fileNm) throws Exception {
    	Log.DebugStart();
    	
    	try {
    		Log.Debug("============================================================");
    		Log.Debug("=== runInterface ===");
    		Log.Debug("============================================================");
    		
    		String intfCd       = "INT_THRM197";
    		String intfNm       = "계약사항_MIG";
    		String uri          = apiHrm197;
    		
    		//workday데이타(INT_TSYS986) interface 테이블에 저장
    		Map<String, Object> paramMap = new HashMap();
    		paramMap.put("apiUri",      "");
    		paramMap.put("intfCd",      intfCd);
    		paramMap.put("intfSdate",   "");
    		paramMap.put("intfNm",      intfNm);
    		paramMap.put("chkid",       chkid);
    		
    		paramMap.put("paramStr",    paramStr);
    		paramMap.put("chkEnterCd",  chkEnterCd);
    		paramMap.put("fileNm",      fileNm);
    		
    		//intfSdate 추가 처리
    		//paramMap.put("intfSdate", intfSdate);
    		
    		//개인발령사항 api 처리
    		paramMap.put("intfSeq",     intfSeq);
    		paramMap.put("intfCallFlag",	"Migration");
    		intfSeq = saveInterfaceJSON_MIG(paramMap);
    		
    		if(intfSeq > -1) {
    			//workday데이타 건별로 인터페이스 테이블 저장
    			iFThrmController.pumpIntfThrm197_MIG(paramMap);
    			//인터페이스 테이블 실 테이블에 저장 처리
    			if(dbProcCall) {
    				iFThrmController.pkgIntfThrm197(paramMap);
    			}
    		}
    		
    		Log.Debug("============================================================");
    		Log.Debug("intfSeq : "+intfSeq);
    		Log.Debug("============================================================");
    		
    	} catch(HrException e){
    		Log.Error("Error : "+e.toString());
    		
    		throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
    	}
    	
    	Log.DebugEnd();
    }
    
    
    /**
     * 사진정보 Migration 실행
     * @param paramStr   파라메터 String
     * @param chkEnterCd 
     * @param chkid
     * @throws Exception
     */
    private void runInterfaceTHRM911MIG(String paramStr, String chkEnterCd, String chkid, String fileNm) throws Exception {
    	Log.DebugStart();
    	
    	try {
	    	Log.Debug("============================================================");
	    	Log.Debug("=== runInterface ===");
	    	Log.Debug("============================================================");
	    	
	    	String intfCd       = "INT_THRM911";
	    	String intfNm       = "사진정보_MIG";
	    	String uri          = apiHrm911;
	    	
	    	//workday데이타(INT_TSYS986) interface 테이블에 저장
	    	Map<String, Object> paramMap = new HashMap();
	    	paramMap.put("apiUri",      "");
	    	paramMap.put("intfCd",      intfCd);
	    	paramMap.put("intfSdate",   "");
	    	paramMap.put("intfNm",      intfNm);
	    	paramMap.put("chkid",       chkid);
	    	
	    	paramMap.put("paramStr",    paramStr);
	    	paramMap.put("chkEnterCd",  chkEnterCd);
	    	paramMap.put("fileNm",      fileNm);
	    	
	        //////////////////////////////////////////////////
	    	paramMap.put("intfCallFlag",	"Migration");
			int intfSeq = saveInterfaceJSON_MIG(paramMap);
	
	    	if(intfSeq > -1) {
	    		paramMap.put("intfSeq",     intfSeq);
	    		//workday데이타 건별로 인터페이스 테이블 저장
	    		iFThrmController.pumpIntfThrm911_MIG(paramMap);
	    		//인터페이스 테이블 실 테이블에 저장 처리
	    		if(dbProcCall) {
	    			iFThrmController.pkgIntfThrm911(paramMap);
	    		}
	    	}
	    	//인터페이스 테이블 실 테이블에 저장 처리
	    	//////////////////////////////////////////////////
	    	
	    	Log.Debug("============================================================");
	    	Log.Debug("intfSeq : "+intfSeq);
	    	Log.Debug("============================================================");
		} catch(HrException e){
			Log.Error("Error : "+e.toString());
			
            throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
		}

    	Log.DebugEnd(); 
    }

    //NULL_RETURN 방지
	private int getInterfaceSequence(Integer pSeqValue, Map<String, Object> parameters) {
		if (pSeqValue != null && pSeqValue > -1) {
			return pSeqValue;
		}

		int intfSeqFromMap = StringUtil.null2Int(parameters != null ? parameters.get("intfSeq") : null, -1);
		if (intfSeqFromMap > -1) {
			return intfSeqFromMap;
		}

		try {
			Map<String, Object> rMap = (Map<String, Object>) interfaceService.getINT_TSYS986Seq(parameters);
			return (rMap !=null) ? StringUtil.null2Int(rMap.get("intfSeq"), -1): -1;
		} catch(HrException e) {
			Log.Error(e.getMessage());
		} catch(Exception e) {
			throw new RuntimeException(e);
		}

		return -1;
	}


	public void setSystemOptionsToSession(Map<String, String> SystemOptMap, HttpSession session) {
        if (SystemOptMap == null || session == null) {
            return;  // or throw an appropriate exception
        }
        
        Log.Debug("┌────────────────── Create System Option Start ─────────────────");
        
        for (Map.Entry<String, String> entry : SystemOptMap.entrySet()) {
            String key = entry.getKey();
            String value = entry.getValue();
            Log.Debug("│ " + key + ":" + value);
            session.setAttribute(key, value);
        }

        session.setAttribute("ssnLocaleCd", "ko_KR");
        Log.Debug("└────────────────── Create System Option End ────────────────────");
    }

	
	private void setEHRToken(HttpSession session, HttpServletRequest request)  throws Exception {
		//eHR accessToken 생성 
        String hrToken = UUID.randomUUID().toString();
        session.setAttribute("ssnHrToken", hrToken);
        
		RSA rsa = RSA.getEncKey();
	    if (rsa == null) {
	        Log.Debug("RSA key generation failed.");
	       
	    } else {
    		request.getSession().setAttribute("RSAModulus", rsa.getPublicKeyModulus());
    		request.getSession().setAttribute("RSAExponent", rsa.getPublicKeyExponent());
    		request.getSession().setAttribute("_RSA_WEB_Key_", rsa.getPrivateKey());
	    }
	}
	
	/**
	 * parameter 내 회사코드 가져오기
	 * @param paramStr
	 * @return
	 */
	private String getParamEnterCd(String paramStr) {
		
		String indexStr = "Company_ID=";
		int idxLength = indexStr.length();
		
		// "Company_ID=" 다음에 나오는 2자리의 시작 인덱스 찾기
        int startIndex = paramStr.indexOf("Company_ID=");
        
        if (startIndex == -1 || paramStr.isEmpty()) {
            return "";
        }

        // "Company_ID=" 다음에 나오는 2자리 가져오기
        return paramStr.substring(startIndex + idxLength, startIndex + idxLength + 2);
	}
}
