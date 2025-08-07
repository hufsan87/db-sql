package com.hr.common.util;

import com.hr.common.exception.HrException;
import com.hr.common.logger.Log;
import com.hr.common.scheduler.apigee.HttpClientPoolService;
import org.anyframe.query.QueryService;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.*;
import org.springframework.http.client.support.BasicAuthorizationInterceptor;
import org.springframework.http.converter.StringHttpMessageConverter;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import javax.annotation.PostConstruct;
import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;
import java.net.*;
import java.nio.charset.Charset;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.Map;

import static org.apache.commons.lang.StringEscapeUtils.escapeJavaScript;

/**
 * 공통 Http Util
 */
@Service("HttpUtils")
public class HttpUtils {

    @Inject
    @Named("myRestTemplate")
    private RestTemplate restTemplate;

    @Autowired
    private HttpClientPoolService httpClientPoolMonitoringService;  // Pooling RestTemplate 주입

	@Inject
	@Named("queryService")
	private QueryService queryService;
	
	/**
	 * Returns the Gitblit URL based on the request.
	 *
	 * @param request
	 * @return the host url
	 */
    public static String getGitblitURL(HttpServletRequest request) throws HrException {
        // Default values
        // SparrowSAST 누락된 널 값 참조
        String scheme = request==null?"":request.getScheme();
        int port = request==null?0:request.getServerPort();
        String context = request==null?"":request.getContextPath();
        String host = request==null?"":request.getServerName();

        // Determine reverse-proxy headers for scheme, port, context, and host
        String forwardedScheme = getHeaderValueOrFallback(request, "X-Forwarded-Proto", "X_Forwarded_Proto");
        String forwardedPort = getHeaderValueOrFallback(request, "X-Forwarded-Port", "X_Forwarded_Port");
        String forwardedContext = getHeaderValueOrFallback(request, "X-Forwarded-Context", "X_Forwarded_Context");
        String forwardedHost = getHeaderValueOrFallback(request, "X-Forwarded-Host", "X_Forwarded_Host");

        // Update values based on headers, if present
        if (forwardedScheme != null) {
            scheme = forwardedScheme;

            if ("https".equals(scheme) && port == 80) {
                port = 443;  // Handle proxy scenario
            }
        }

        if (forwardedPort != null) {
            try {
                port = Integer.parseInt(forwardedPort);
            } catch (NumberFormatException e) {
				throw new HrException(e.getMessage());
            }
        }

        if (forwardedContext != null) {
            context = forwardedContext;
        }

        if (forwardedHost != null) {
            host = forwardedHost;
        }

        // Trim trailing slash from context if present
        if (context.length() > 0 && context.charAt(context.length() - 1) == '/') {
            context = context.substring(1);
        }

        // Build the URL
        StringBuilder sb = new StringBuilder();
        sb.append(scheme).append("://").append(host);
        if (("http".equals(scheme) && port != 80) || ("https".equals(scheme) && port != 443)) {
            if (!host.endsWith(":" + port)) {
                sb.append(":").append(port);
            }
        }
        sb.append(context);
        return sb.toString();
    }

    private static String getHeaderValueOrFallback(HttpServletRequest request, String primary, String fallback) {
        String value = request.getHeader(primary);
        if (value == null) {
            value = request.getHeader(fallback);
        }
        return value;
    }

	public static String getBrowser(HttpServletRequest request) {
		String header = request.getHeader("User-Agent");
		if (header != null) {
			if (header.indexOf("Trident") > -1) {
				return "MSIE";
			} else if (header.indexOf("Chrome") > -1) {
				return "Chrome";
			} else if (header.indexOf("Opera") > -1) {
				return "Opera";
			} else if (header.indexOf("iPhone") > -1 && header.indexOf("Mobile") > -1) {
				return "iPhone";
			} else if (header.indexOf("Android") > -1 && header.indexOf("Mobile") > -1) {
				return "Android";
			}
		}
		return "Firefox";
	}

	public static String getEncodedFilename(String filename, String browser) throws Exception {
		String encodedFilename = null;
		if (browser.equals("MSIE")) {
			encodedFilename = URLEncoder.encode(filename, "UTF-8").replaceAll("\\+", "%20");
		} else if (browser.equals("Firefox")) {
			encodedFilename = "\"" + new String(filename.getBytes("UTF-8"), "8859_1") + "\"";
		} else if (browser.equals("Opera")) {
			encodedFilename = "\"" + new String(filename.getBytes("UTF-8"), "8859_1") + "\"";
		} else if (browser.equals("Chrome")) {
			StringBuffer sb = new StringBuffer();
			for (int i = 0; i < filename.length(); i++) {
				char c = filename.charAt(i);
				if (c > '~') {
					sb.append(URLEncoder.encode("" + c, "UTF-8"));
				} else {
					sb.append(c);
				}
			}
			encodedFilename = sb.toString();
		} else {
			throw new RuntimeException("Not supported browser");
		}
		return encodedFilename;
	}
	
	public static String getEncodedFilenameAddPrefix(String filename, String browser, String dispositionPrefix) throws Exception {
		String encodedFilename = getEncodedFilename(filename, browser);
		return dispositionPrefix + encodedFilename;
	}
	
	/**
	 * Apigee에서 Restfull Api 호출
	 * @return
	 */
	@SuppressWarnings("finally")
	public static JSONObject apigeeRestApi(String apiUrl, String name, String pwd) throws Exception {
	    Log.DebugStart();
	    try {
	        RestTemplate restTemplate = new RestTemplate();
	        restTemplate.getMessageConverters().add(0, new StringHttpMessageConverter(Charset.forName("UTF-8")));

	        Log.Debug("============================================================");
	        Log.Debug("=== apigee url === : " + apiUrl);
	        Log.Debug("============================================================");

	        if (!name.equals("") && !pwd.equals("")) {
	            restTemplate.getInterceptors().add(new BasicAuthorizationInterceptor(name, pwd));
	        }

	        ResponseEntity<String> responseEntity = restTemplate.getForEntity(apiUrl, String.class);
	        HttpStatus httpStatusCode = responseEntity.getStatusCode();

	        if (httpStatusCode != HttpStatus.OK) {
	            throw new HrException("API 호출이 실패했습니다. HTTP 상태 코드: " + httpStatusCode);
	        }

	        String jsonResponse = responseEntity.getBody();

	        // JSON 파싱 예외 처리 추가
	        JSONParser parser = new JSONParser();
	        JSONObject jsonObj = (JSONObject) parser.parse(jsonResponse);

	        Log.DebugEnd();
	        return jsonObj;
	    } catch (HrException e) {
	        Log.Error(e.toString());
	        throw new HrException("API 호출 중 오류가 발생했습니다.", e);
	    }
	}

	/**
	 * Apigee에서 Restfull Api 호출
	 * @return
	 */
    public synchronized JSONObject apigeeRestApiCC(
            Map<String, Object> paramMap,
            String accessToken,
            String tokenType,
            HttpServletRequest request) throws Exception {

        Log.DebugStart();

        JSONObject jsonObj = null;
        String apiUrl = paramMap.get("apiUri").toString();
        Map<String, Object> logParamMap = new HashMap<>();
        logParamMap.put("api", "apigeeRestApiCC");

        String requestIp = request.getRemoteHost();
        if (paramMap != null && "scheduler".equals(paramMap.get("chkid"))) {
            requestIp = getLocalIpAddress();
        }

        try {
            Log.Debug("============================================================");
            Log.Debug("=== apigee url === : " + apiUrl);
            Log.Debug("============================================================");

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
            if ("".equals(tokenType)) {
                tokenType = "Bearer";
            }
            headers.set("Authorization", tokenType + " " + accessToken);

            Log.Debug("============================================================");
            Log.Debug("accessToken : " + accessToken);
            Log.Debug("tokenType   : " + tokenType);
            Log.Debug("Authorization: " + tokenType + " " + accessToken);
            Log.Debug("============================================================");

            logParamMap.put("accessToken", accessToken);
            logParamMap.put("tokenType", tokenType);
            logParamMap.put("Authorization", tokenType + " " + accessToken);
            logParamMap.put("apiUrl", apiUrl);

            if (paramMap != null && paramMap.get("intfCd") != null) {
                logParamMap.put("intfCd", paramMap.get("intfCd").toString());
            }
            if (paramMap != null && paramMap.get("intfNm") != null) {
                logParamMap.put("intfNm", paramMap.get("intfNm").toString());
            }

            HttpEntity<String> entity = new HttpEntity<>(headers);

            httpClientPoolMonitoringService.logPoolStats("BEFORE"); //pool monitoring
            ResponseEntity<String> responseEntity =
                    restTemplate.exchange(apiUrl, org.springframework.http.HttpMethod.GET, entity, String.class);
            httpClientPoolMonitoringService.logPoolStats("AFTER"); //pool monitoring

            //jsonObj = responseEntity.getBody();

            String body = responseEntity.getBody();
            JSONParser parser = new JSONParser();

            try {
                jsonObj = (JSONObject) parser.parse(body);
            } catch(ParseException pe) {
                throw new HrException("JSON 파싱 에러: " + pe.getMessage(), pe);
            }

            HttpHeaders httpHeaders = responseEntity.getHeaders();
            HttpStatus httpStatusCode = responseEntity.getStatusCode();
            int httpStatusCodeValue = responseEntity.getStatusCodeValue();

            logParamMap.put("requestIp", requestIp);
            logParamMap.put("httpHeaders", httpHeaders);
            logParamMap.put("httpStatusCode", httpStatusCode);
            logParamMap.put("httpStatusCodeValue", httpStatusCodeValue);
            String detail = (jsonObj != null ? jsonObj.toString() : "");
            logParamMap.put("detailMsg", detail.length() > 2000 ? detail.substring(0, 2000) : detail);

        } catch (HttpServerErrorException ex) {
            Log.Error("===================== apigeeRestApiCC HttpServerErrorException Start =========================");
            Log.Error(ex.toString());
            System.out.println("Server error: " + ex.getMessage());
            System.out.println("Response Body: " + ex.getResponseBodyAsString());
            Log.Error("===================== apigeeRestApiCC HttpServerErrorException End =========================");

            logParamMap.put("requestIp", requestIp);
            logParamMap.put("httpHeaders", "");
            logParamMap.put("httpStatusCode", ex.getRawStatusCode());
            logParamMap.put("httpStatusCodeValue", ex.getStatusText());
            logParamMap.put("detailMsg", ex.toString());

            throw new HrException(ex.getMessage());

        } catch (RestClientException ex) {
            Log.Error("===================== apigeeRestApiCC RestClientException Start =========================");
            Log.Error(ex.toString());
            Log.Error("===================== apigeeRestApiCC RestClientException End =========================");

            logParamMap.put("requestIp", requestIp);
            logParamMap.put("httpHeaders", "");
            logParamMap.put("httpStatusCode", "Err");
            logParamMap.put("httpStatusCodeValue", ex.getMessage());
            logParamMap.put("detailMsg", ex.toString());

            throw new HrException(ex.getMessage());

        } catch (Exception ex) {
            Log.Error("===================== apigeeRestApiCC Error Start =========================");
            Log.Error(ex.toString());
            Log.Error("===================== apigeeRestApiCC Error End =========================");

            logParamMap.put("requestIp", requestIp);
            logParamMap.put("httpHeaders", "");
            logParamMap.put("httpStatusCode", "Err");
            logParamMap.put("httpStatusCodeValue", "");
            logParamMap.put("detailMsg", ex.toString());

            throw new HrException(ex.getMessage(), ex);

        } finally {
            Log.Debug("===================== apigeeRestApiCC finally Start =========================");
            queryService.execute("insertApigeeLogMgr", logParamMap);
            Log.Debug("===================== apigeeRestApiCC finally End =========================");
        }

        Log.DebugEnd();
        return jsonObj;
    }
	public synchronized JSONObject apigeeRestApiCC_backup(Map<String, Object> paramMap, String accessToken, String tokenType, HttpServletRequest request) throws Exception{
		
		Log.DebugStart();
		
		JSONObject jsonObj 	= null;
		String apiUrl = paramMap.get("apiUri").toString();
		Map<String, Object> logParamMap = new HashMap();
		logParamMap.put("api", "apigeeRestApiCC");
		String requestIp = request.getRemoteHost();

        if (paramMap!=null && paramMap.get("chkid")!=null && paramMap.get("chkid").equals("scheduler")){
            requestIp = getLocalIpAddress();
        }

		try {

			Log.Debug("============================================================");
			Log.Debug("=== apigee url === : "+apiUrl);
			Log.Debug("============================================================");

			//RestTemplate restTemplate = new RestTemplate();
			//restTemplate.getMessageConverters().add(0, new StringHttpMessageConverter(Charset.forName("UTF-8")));
			HttpHeaders headers = new HttpHeaders();
			headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
			if(tokenType.equals("")) tokenType = "Bearer";
			headers.set("Authorization", tokenType + " " + accessToken);
			
			Log.Debug("============================================================");
			Log.Debug("accessToken : " + accessToken);
			Log.Debug("tokenType   : " + tokenType);
			Log.Debug("Authorization   : " + tokenType + " " + accessToken);
			Log.Debug("============================================================");

			logParamMap.put("accessToken", accessToken);
			logParamMap.put("tokenType", tokenType);
			logParamMap.put("Authorization", tokenType + " " + accessToken);
			logParamMap.put("apiUrl", apiUrl);
			/*
			logParamMap.put("intfCd", paramMap.get("intfCd").toString());
			logParamMap.put("intfNm", paramMap.get("intfNm").toString());
			*/
            //SparrowSAST 누락된 널 값 검사 2025.04.28
			//if (paramMap.get("intfCd") != null) {
            if (paramMap != null && paramMap.get("intfCd") != null) {
			    logParamMap.put("intfCd", paramMap.get("intfCd").toString());
			}

			//if (paramMap.get("intfNm") != null) {
            if (paramMap != null && paramMap.get("intfNm") != null) {
			    logParamMap.put("intfNm", paramMap.get("intfNm").toString());
			}
			HttpEntity entity = new HttpEntity(headers);
            System.out.println("apigeeRestApiCC : 2");

            System.out.println("URL: " + apiUrl);
            System.out.println("Headers: " + entity.getHeaders());

			//jsonObj = restTemplate.exchange(apiUrl, HttpMethod.GET, entity, JSONObject.class).getBody();
			ResponseEntity<?> responseEntity = restTemplate.exchange(apiUrl, HttpMethod.GET, entity, JSONObject.class);

            System.out.println("apigeeRestApiCC : 3");
			jsonObj 				   			= (JSONObject)responseEntity.getBody();
			HttpHeaders httpHeaders				= responseEntity.getHeaders();
			HttpStatus httpStatusCode			= responseEntity.getStatusCode();
			int httpStatusCodeValue 			= responseEntity.getStatusCodeValue();

			logParamMap.put("requestIp", 			requestIp);
			logParamMap.put("httpHeaders", 			httpHeaders);
			logParamMap.put("httpStatusCode", 		httpStatusCode);
			logParamMap.put("httpStatusCodeValue", 	httpStatusCodeValue);
			logParamMap.put("detailMsg", 			jsonObj.toString().length()> 2000 ? jsonObj.toString().substring(0,2000) : jsonObj);
		}catch (HttpServerErrorException ex) {
			Log.Error("===================== apigeeRestApiCC HttpServerErrorException Start =========================");
			Log.Error(ex.toString());

            System.out.println("Server error: " + ex.getMessage());
            System.out.println("Response Body: " + ex.getResponseBodyAsString());

			Log.Error("===================== apigeeRestApiCC HttpServerErrorException Start =========================");
			logParamMap.put("requestIp", 		   requestIp);
			logParamMap.put("httpHeaders", 		   "");
			logParamMap.put("httpStatusCode", 	   ex.getRawStatusCode());
			logParamMap.put("httpStatusCodeValue", ex.getStatusText());
			logParamMap.put("detailMsg",           ex.toString());
			throw new HrException(ex.getMessage());			
		}catch (RestClientException ex) {
			Log.Error("===================== apigeeRestApiCC RestClientException Start =========================");
			Log.Error(ex.toString());
			Log.Error("===================== apigeeRestApiCC RestClientException Start =========================");
			logParamMap.put("requestIp", 		   requestIp);
			logParamMap.put("httpHeaders", 		   "");
			logParamMap.put("httpStatusCode", 	   "Err");
			logParamMap.put("httpStatusCodeValue", ex.getMessage());
			logParamMap.put("detailMsg",           ex.toString());
			throw new HrException(ex.getMessage());			
		}catch(Exception ex){
			Log.Error("===================== apigeeRestApiCC Error Start =========================");
			Log.Error(ex.toString());
			Log.Error("===================== apigeeRestApiCC Error Start =========================");
			logParamMap.put("requestIp", 			requestIp);
			logParamMap.put("httpHeaders", 		    "");
			logParamMap.put("httpStatusCode", 		"Err");
			logParamMap.put("httpStatusCodeValue",  "");
			logParamMap.put("detailMsg",            ex.toString());
			throw new HrException(ex.getMessage());
		}finally {
			Log.Debug("===================== apigeeRestApiCC finally Start =========================");
			queryService.execute("insertApigeeLogMgr", logParamMap);
			Log.Debug("===================== apigeeRestApiCC finally End =========================");
		}
		
		Log.DebugEnd();
		return jsonObj;
	}
	

	
	/**
	 * Restapi 호출 (accessToken용)
	 * @param url
	 * @param paramMap
	 * @return ResponseEntity<Map>
	 * @throws Exception
	 */
	public synchronized ResponseEntity<Map> getRestTemplateMap(String url, Map<String, Object> paramMap) throws Exception {
	    try {
            //Connection pool 주입으로 불필요
	        //RestTemplate restTemplate = new RestTemplate();
	        //restTemplate.getMessageConverters().add(0, new StringHttpMessageConverter(Charset.forName("UTF-8")));

	        HttpHeaders headers = new HttpHeaders();
	        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

	        // 파라미터 설정
	        MultiValueMap<String, String> parameters = new LinkedMultiValueMap<>();
	        paramMap.forEach((key, value) -> parameters.set(key, value.toString()));

	        HttpEntity<MultiValueMap<String, String>> tokenRequest = new HttpEntity<>(parameters, headers);

	        ResponseEntity<Map> responseEntity = this.restTemplate.exchange(
	            url,
	            HttpMethod.POST,
	            tokenRequest,
	            Map.class
	        );

	        return responseEntity;
	    } catch (RestClientException e) {
	        Log.Error("Error : " + e.getMessage());
	        throw new HrException("예외가 발생했습니다: " + e.getMessage(), e);
	    }
	}


	/**
	 * Restapi 호출
	 * @param url
	 * @param paramMap
	 * @return JSONObject
	 * @throws Exception
	 */
	//@SuppressWarnings("finally")
	public synchronized JSONObject getRestTemplateJson(String url, Map<String, Object> paramMap, HttpServletRequest request) throws Exception {
		
		Log.DebugStart();
		
		JSONObject jsonObj 	= null;
		Map<String, Object> logParamMap = new HashMap();
		logParamMap.put("api", "getRestTemplateJson");
		String requestIp = requestIp = request.getRemoteHost();
		
		try {

			Enumeration<NetworkInterface> n = NetworkInterface.getNetworkInterfaces();
            for (; n.hasMoreElements();)
            {
                NetworkInterface e = n.nextElement();
                Enumeration<InetAddress> a = e.getInetAddresses();
                for (; a.hasMoreElements();)
                {
                    InetAddress addr = a.nextElement();
                    requestIp = addr.getHostAddress().toString();
                }
            }

            //Connection pool 주입으로 불필요
            //RestTemplate restTemplate = new RestTemplate();
			//restTemplate.getMessageConverters().add(0, new StringHttpMessageConverter(Charset.forName("UTF-8")));
			
			HttpHeaders headers = new HttpHeaders();
			headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
			
			// 파라메터 세팅
            MultiValueMap<String, String> parameters = new LinkedMultiValueMap<>();
            if (paramMap != null) {
                for (Map.Entry<String, Object> entry : paramMap.entrySet()) {
                    if (entry.getValue() != null) {
                        parameters.set(entry.getKey(), entry.getValue().toString());
                    }
                }
            }

            logParamMap.put("apiUrl", url);
			logParamMap.put("intfCd", "OLIVE");
			logParamMap.put("intfNm", "OLIVE 포인트");
			
            //HttpEntity entity = new HttpEntity(headers);
			//jsonObj = restTemplate.postForEntity(url, parameters, JSONObject.class).getBody();

            //RestTemplate 주입 시, header정보 포함 필요
            HttpEntity<MultiValueMap<String, String>> requestEntity = new HttpEntity<>(parameters, headers);

            // identityHashCode 를 찍어서, 매번 같은 인스턴스인지 확인
            // RestTemplatePoolConfig 나 HttpUtils 등에서
            Log.Info("▶▶▶ RestTemplate instance hash="
                    + System.identityHashCode(this.restTemplate)
                    + ", toString=" + this.restTemplate);

			//ResponseEntity<?> responseEntity = restTemplate.postForEntity(url, parameters, JSONObject.class);

            System.out.println("▶▶▶ RestTemplate instance = " + this.restTemplate);
            this.restTemplate.getMessageConverters().forEach(
                    c -> System.out.println("   - converter: " + c.getClass().getSimpleName())
            );

            ResponseEntity<?> responseEntity = this.restTemplate.postForEntity(url, requestEntity, JSONObject.class);


			jsonObj 				   			= (JSONObject)responseEntity.getBody();

			HttpHeaders httpHeaders				= responseEntity.getHeaders();
			HttpStatus httpStatusCode			= responseEntity.getStatusCode();
			int httpStatusCodeValue 			= responseEntity.getStatusCodeValue();
			
			logParamMap.put("requestIp", 			requestIp);
			logParamMap.put("httpHeaders", 			httpHeaders);
			logParamMap.put("httpStatusCode", 		httpStatusCode);
			logParamMap.put("httpStatusCodeValue", 	httpStatusCodeValue);
			logParamMap.put("detailMsg", 			jsonObj.toString().length()> 2000 ? jsonObj.toString().substring(0,2000) : jsonObj);

		}catch (HttpServerErrorException ex) {
			Log.Error("===================== getRestTemplateJson HttpServerErrorException Start =========================");
			Log.Error(ex.toString());
			Log.Error("===================== getRestTemplateJson HttpServerErrorException Start =========================");
			logParamMap.put("requestIp", 		   requestIp);
			logParamMap.put("httpHeaders", 		   "");
			logParamMap.put("httpStatusCode", 	   ex.getRawStatusCode());
			logParamMap.put("httpStatusCodeValue", ex.getStatusText());
			logParamMap.put("detailMsg",           ex.toString());
			throw new HrException(ex.getMessage());			
		}catch (RestClientException ex) {
			Log.Error("===================== getRestTemplateJson RestClientException Start =========================");
			Log.Error(ex.toString());
			Log.Error("===================== getRestTemplateJson RestClientException Start =========================");
			logParamMap.put("requestIp", 		   requestIp);
			logParamMap.put("httpHeaders", 		   "");
			logParamMap.put("httpStatusCode", 	   "Err");
			logParamMap.put("httpStatusCodeValue", ex.getMessage());
			logParamMap.put("detailMsg",           ex.toString());
			throw new HrException(ex.getMessage());	
		}catch(Exception ex){
			Log.Error("===================== getRestTemplateJson Error Start =========================");
			Log.Error(ex.toString());
			Log.Error("===================== getRestTemplateJson Error Start =========================");
			logParamMap.put("requestIp", 			requestIp);
			logParamMap.put("httpHeaders", 		    "");
			logParamMap.put("httpStatusCode", 		"Err");
			logParamMap.put("httpStatusCodeValue",  "");
			logParamMap.put("detailMsg",            ex.toString());
			throw new HrException(ex.getMessage());
		}finally {
			Log.Debug("===================== getRestTemplateJson finally Start =========================");
			queryService.execute("insertApigeeLogMgr", logParamMap);
			Log.Debug("===================== getRestTemplateJson finally End =========================");
		}
		
		Log.DebugEnd();
		return jsonObj;
	}
	
	//화면에 script alert 으로 메시지 뿌려주는 , 
	//treu,fallse 로 history.back(); 조절 
	public static void alert(HttpServletResponse response, String message, boolean mtype ) throws IOException {
		response.setContentType("text/html; charset=utf-8");
		String safeMessage = escapeJavaScript(message);

		try (PrintWriter writer = response.getWriter()) {
			writer.write("<script>alert('" + safeMessage + "');" + (( mtype) ? "history.back();" : "") + "</script>");
		} catch (IOException e) {
			throw new IOException("응답에 오류가 발생했습니다.", e);
		}
	}

    public static void alertForPreView(HttpServletResponse response, String message, boolean mtype ) throws IOException {
        response.setContentType("text/html; charset=utf-8");
        String safeMessage = escapeJavaScript(message);

        try (PrintWriter writer = response.getWriter()) {
            writer.write("<script>alert('" + safeMessage + "');" + (( mtype) ? "self.close();" : "") + "</script>");
        } catch (IOException e) {
            throw new IOException("응답에 오류가 발생했습니다.", e);
        }
    }
	


    public static String getClientIP(HttpServletRequest request) {
        String[] headersToCheck = {
            "X-Forwarded-For",
            "Proxy-Client-IP",
            "WL-Proxy-Client-IP",
            "HTTP_CLIENT_IP",
            "HTTP_X_FORWARDED_FOR"
        };

        for (String header : headersToCheck) {
            String ip = request.getHeader(header);
            Log.Info("IP를 가져오는 중 header : " + ip);
            if (isValidIP(ip)) {
                return ip;
            }
        }

        String clientIP = request.getRemoteAddr();
        return isLocalhost(clientIP) ? getServerIP() : clientIP;
    }

    private static boolean isValidIP(String ip) {
        return ip != null && ip.length() > 0 && !"unknown".equalsIgnoreCase(ip);
    }

    private static boolean isLocalhost(String ip) {
        return "0:0:0:0:0:0:0:1".equals(ip) || "127.0.0.1".equals(ip);
    }

    private static String getServerIP() {
        try {
            return InetAddress.getLocalHost().getHostAddress();
        } catch (UnknownHostException e) {
            Log.Debug("Server IP를 가져오는 중 예외 발생: " + e.getMessage());
            return "localhost";
        }
    }

    private static boolean isInternalIP(String ip) {
        return ip.startsWith("10.") ||
               ip.startsWith("172.") && ip.substring(4, 7).matches("1[6-9]|2[0-9]|3[0-1]") ||
               ip.startsWith("192.168.");
    }

    private String getLocalIpAddress() {
        try {
            Enumeration<NetworkInterface> networkInterfaces = NetworkInterface.getNetworkInterfaces();
            while(networkInterfaces.hasMoreElements()) {
                NetworkInterface networkInterface = networkInterfaces.nextElement();
                Enumeration<InetAddress> inetAddresses = networkInterface.getInetAddresses();
                while(inetAddresses.hasMoreElements()) {
                    InetAddress inetAddress = inetAddresses.nextElement();
                    if (!inetAddress.isLoopbackAddress() && inetAddress.isSiteLocalAddress()) {
                        return inetAddress.getHostAddress();
                    }
                }
            }
        } catch (SocketException e) {
            e.printStackTrace();
        }
        return "Unknown";
    }

    @PostConstruct
    public void logConverters() {
        System.out.println("******************** Connector List Start *****************************************");
        this.restTemplate.getMessageConverters()
                .forEach(c -> System.out.println(c.getClass().getSimpleName()));
        System.out.println("******************** Connector List End *******************************************");
    }

    @PostConstruct
    public void verifyInjection() {
        System.out.println("▶▶▶ RestTemplate instance = " + this.restTemplate);
        this.restTemplate.getMessageConverters().forEach(
                c -> System.out.println("   - converter: " + c.getClass().getSimpleName())
        );
    }
}
