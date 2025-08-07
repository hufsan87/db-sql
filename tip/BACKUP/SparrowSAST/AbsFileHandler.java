package com.hr.common.util.fileupload.impl;

import com.hr.common.exception.FileUploadException;
import com.hr.common.exception.HrException;
import com.hr.common.logger.Log;
import com.hr.common.util.HttpUtils;
import com.hr.common.util.StringUtil;
import com.hr.common.util.fileupload.jfileupload.web.JFileUploadService;
import net.sf.jazzlib.CRC32;
import org.apache.commons.compress.archivers.zip.ZipArchiveEntry;
import org.apache.commons.compress.archivers.zip.ZipArchiveOutputStream;
import org.apache.commons.fileupload.FileItem;
import org.apache.commons.fileupload.disk.DiskFileItemFactory;
import org.apache.commons.fileupload.servlet.ServletFileUpload;
import org.apache.commons.fileupload.util.Streams;
import org.apache.commons.io.FilenameUtils;
import org.apache.commons.io.IOUtils;
import org.apache.tika.Tika;
import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.BeansException;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.web.context.support.WebApplicationContextUtils;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.io.*;
import java.net.URLEncoder;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

public abstract class AbsFileHandler implements IFileHandler {

	private final int DISK_THRESHOLD_SIZE = 1024 * 1024 * 3; // 3MB
	private static final Object lockObj = new Object();
	protected HttpSession session = null;
	protected HttpServletRequest request = null;
	protected HttpServletResponse response = null;
	protected FileUploadConfig config = null;
	protected String enterCd = null;
	
	protected String fileDownSetPwd = "N";
	protected String tmpPassword = "";
	

    private static final int BUFFER_SIZE = 1024;
    private static final String DEFAULT_IMG_PATH = System.getProperty("webapp.root") + File.separator + "common" + File.separator + "images" + File.separator + "common" + File.separator + "img_photo.gif";
    //private static final Object LOCK = new Object();
    //private final Object lockObj = new Object();


	public AbsFileHandler(HttpServletRequest request, HttpServletResponse response, FileUploadConfig config) {
		this.request = request;
		this.session = request.getSession();
		this.response= response;
		this.config  = config;
		this.enterCd = StringUtil.null2Blank(request.getParameter("enterCd"));

		if(this.enterCd.isEmpty()) {
			this.enterCd = (String) session.getAttribute("ssnEnterCd");
		}
		
		
	}

	protected abstract void init() throws Exception;

	public abstract void fileupload(InputStream inStrm, String fileNm, Map tsys200Map, Map tsys201Map, Map tsys202Map, int cnt) throws Exception;

	protected String getTimeStemp() {
		return System.currentTimeMillis()+"";
	}


	public JSONArray upload() throws Exception {
		synchronized (lockObj) {
			if (ServletFileUpload.isMultipartContent(request)) {
				init();

				DiskFileItemFactory factory = new DiskFileItemFactory();
				factory.setSizeThreshold(DISK_THRESHOLD_SIZE);

				File uploadDir = new File(config.getTempDir());
				if (!uploadDir.exists()) {
					uploadDir.mkdirs();
				}

				factory.setRepository(uploadDir);

				ServletFileUpload sUpload = new ServletFileUpload(factory);
				sUpload.setFileSizeMax(Long.valueOf(config.getProperty(FileUploadConfig.POSTFIX_FILE_SIZE)));

				List<FileItem> fList = sUpload.parseRequest(request);
				File toDir = null;
				FileOutputStream fo = null;

				try {
					JSONArray jsonArray = new JSONArray();


					WebApplicationContext webAppCtxt = WebApplicationContextUtils.getWebApplicationContext(session.getServletContext());
					JFileUploadService jFileUploadService = (JFileUploadService) webAppCtxt.getBean("JFileUploadService");
					Iterator<FileItem> fIt = fList.iterator();

					if (fIt != null) {
						int curFileCnt = fList.size();
						String fileCnt = config.getProperty(FileUploadConfig.POSTFIX_FILE_COUNT);
						int totFileCnt = Integer.valueOf(fileCnt != null && !"".equals(fileCnt) ? fileCnt : "0");
						String fileSeq = request.getParameter("fileSeq");

						int realCnt = 0;
						Map<String, Object> tsys200Map = null;
						boolean isMaster = false;

						if (fileSeq != null && !"".equals(fileSeq)) {
							Map<String, Object> paramMap = new HashMap<String, Object>();
							paramMap.put("ssnEnterCd", this.enterCd);
							paramMap.put("fileSeq", fileSeq);
							Map<?, ?> map = jFileUploadService.jFileCount(paramMap);

							if (map != null) {
								isMaster = true;
								String cnt = String.valueOf(map.get("cnt"));
								realCnt = Integer.valueOf(cnt != null && !"".equals(cnt) ? cnt : "0");

								if (totFileCnt > 0 && curFileCnt + realCnt > totFileCnt) {
									throw new FileUploadException("File Count Error!");
								}
								String mcnt = String.valueOf(map.get("mcnt"));
								realCnt = Integer.valueOf(mcnt != null && !"".equals(mcnt) ? mcnt : "0");
							}
							
						} else {
							fileSeq = jFileUploadService.jFileSequence();
						}

						if (!isMaster) {
							tsys200Map = new HashMap<String, Object>();
							tsys200Map.put("ssnEnterCd", session.getAttribute("ssnEnterCd"));
							tsys200Map.put("fileSeq", fileSeq);
							tsys200Map.put("ssnSabun", session.getAttribute("ssnSabun"));
						}

						List<Map<?, ?>> tsys201List = new ArrayList<Map<?, ?>>();
						List<Map<?, ?>> tsys202List = new ArrayList<Map<?, ?>>();

						while (fIt.hasNext()) {
							FileItem fItem = fIt.next();

							if (fItem.isFormField()) {

							} else {
								String itemName = FilenameUtils.getName(fItem.getName());
								boolean isVaild = true;
								String vaildMsg = null;

								String extExtension = config.getProperty(FileUploadConfig.POSTFIX_EXT_EXTENSION);
								if (extExtension != null && !"".equals(extExtension)) {
									String[] arr = itemName.split("\\.");

									if (arr.length == 1) {
										isVaild = false;
										vaildMsg = "File Type Error! " + itemName;
									} else {
										isVaild = true;
									}

									String ext = arr[arr.length - 1];
									Pattern p = Pattern.compile(extExtension.replaceAll(",", "|"), Pattern.CASE_INSENSITIVE);
									Matcher m = p.matcher(ext);
									if (!m.matches()) {
										isVaild = false;
										vaildMsg = "File Type Error! " + itemName;
									} else {
										isVaild = true;
									}
								}

								if(!isVaild) {
									String mimeExtension = config.getProperty(FileUploadConfig.POSTFIX_MIME_EXTENSION);
									if (mimeExtension != null && !"".equals(mimeExtension)) {
										mimeExtension = mimeExtension.replaceAll("\\*", ".*");

										//String path = StringUtil.replaceAll(config.getTempDir() + "/" + itemName, "//", "/");
										String path = config.getTempDir() + File.separator + itemName;
										path = path.replaceAll(Matcher.quoteReplacement(File.separator)+Matcher.quoteReplacement(File.separator), Matcher.quoteReplacement(File.separator));

										toDir = new File(path);

										File upDir = toDir.getParentFile();

										if (upDir != null && !upDir.exists()) {
											upDir.mkdirs();// 폴더경로 없으면 만들어 놓기.
										}

										fo = new FileOutputStream(toDir);

										Streams.copy(fItem.getInputStream(), fo, true);
										fo.flush();

										Tika tika = new Tika();
										String mType = tika.detect(toDir);
										toDir.delete();

										Pattern p = Pattern.compile(mimeExtension.replaceAll(",", "|"), Pattern.CASE_INSENSITIVE);
										Matcher m = p.matcher(mType);
										if (!m.matches()) {
											isVaild = false;
											vaildMsg = "File Type Error!  " + itemName + " [" + mType + "]";
										} else {
											isVaild = true;
										}
									}
								}

								if(!isVaild) {
									throw new FileUploadException(vaildMsg);
								}

								Map<String, Object> tsys201Map = new HashMap<String, Object>();
								Map<String, Object> tsys202Map = new HashMap<String, Object>();
								
								fileupload(fItem.getInputStream(), itemName, tsys200Map, tsys201Map, tsys202Map, realCnt);
								
								tsys201Map.put("fileSeq", fileSeq);
								tsys201List.add(tsys201Map);

								if(tsys202Map.size() > 0) {
									tsys202Map.put("fileSeq", fileSeq);
									tsys202List.add(tsys202Map);
								}
								JSONObject jsonObject = new JSONObject();
								jsonObject.put("fileSeq", fileSeq);
								jsonObject.put("seqNo", realCnt);
								jsonObject.put("rFileNm", tsys201Map.get("rFileNm"));
								jsonObject.put("sFileNm", tsys201Map.get("sFileNm"));
								jsonObject.put("fileSize", tsys201Map.get("fileSize"));
								jsonArray.put(jsonObject);

								realCnt++;
							}
						}

						boolean result = jFileUploadService.fileStoreSave(tsys200Map, tsys201List, tsys202List);

						if (!result) {
							throw new HrException("fileSave falied");
						}
					}

					return jsonArray;
				} catch(HrException e) {
				    Log.Error("Exception="+ e.getMessage());
					throw new HrException("Saved Error!");
				} finally {
					if(fo != null) {
                    	fo.close();
                    	fo = null;
                    }
					if(toDir != null) {
                    	toDir.delete();
                    }

				}
			} else {
				throw new HrException("Error!");
			}
		}
	}

    ///////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////
  
	
	
	
	
    ///////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////
    

	protected abstract InputStream filedownload(Map<?, ?> paramMap) throws Exception;

	public void download() throws Exception {
		download(false);
	}

	public void download(boolean isDirectView) throws Exception {
		Map<String, String[]> paramMap = request.getParameterMap();
		String[] fileSeqArr = paramMap.get("fileSeq");
		String[] seqNoArr = paramMap.get("seqNo");

		download(isDirectView, fileSeqArr, seqNoArr);
	}
/*
	public void download(boolean isDirectView, String[] fileSeqArr, String[] seqNoArr) throws Exception {
		synchronized (lockObj) {
			init();

			File zipFile = null;
			FileOutputStream fos = null;
			ZipArchiveOutputStream zos = null;
			InputStream in = null;
			OutputStream outt = null;
			List<Map<?, ?>> outputList = null;

			try {
				if(fileSeqArr != null) {
					outputList = new ArrayList<Map<?,?>>();
					WebApplicationContext webAppCtxt = WebApplicationContextUtils.getWebApplicationContext(session.getServletContext());
					JFileUploadService jFileUploadService = (JFileUploadService) webAppCtxt.getBean("JFileUploadService");

					for(int i = 0; i < fileSeqArr.length; i++) {
						String fileSeq = fileSeqArr[i];
						if(fileSeq == null || "".equals(fileSeq)) {
							continue;
						}

						Map<String, Object> map = new HashMap<String, Object>();
						map.put("ssnEnterCd", this.enterCd);
						map.put("fileSeq", fileSeq);

						if(seqNoArr == null) {
							Collection<?> resultList = jFileUploadService.fileSearchByFileSeq(map);

							for(Object listItem : resultList) {
								outputList.add((Map<?, ?>) listItem);
							}
						} else {
							String seqNo = seqNoArr[i];
							if(seqNo == null || "".equals(seqNo)) {
								continue;
							}

							map.put("seqNo", seqNo);
							//outputList.add(jFileUploadService.fileSearchBySeqNo(map));
							Map<?,?> tmp = jFileUploadService.fileSearchBySeqNo(map);
							if(tmp != null) {
								outputList.add(jFileUploadService.fileSearchBySeqNo(map));
							}
						}
					}

					if(outputList != null && outputList.size() > 0) {
						String downloadName = null;
						
						//Log.Debug(String.format("fileDownSetPwd : %s, tmpPassword : %s", fileDownSetPwd, tmpPassword));

						// 파일 암호 설정이 N이거나 설정값이 없는 경우[일반적인]
						if(fileDownSetPwd == null || "N".equals(fileDownSetPwd)) {
							// 파일이 1개인 경우
							if(outputList.size() == 1) {
								Map<?, ?> resultMap = outputList.get(0);
								//downloadName = String.valueOf(resultMap.get("rFileNm"));
								downloadName = StringUtil.stringValueOf(resultMap.get("rFileNm"));
								Log.Debug("downloadName>>>>>"+ downloadName);
								in = filedownload(resultMap);
								
								// 파일이 여러개인 경우
							} else {
								downloadName = getTimeStemp() + ".zip";
								zipFile = new File(config.getTempDir() + File.separator + downloadName);
								File upDir = zipFile.getParentFile();
								
								if(!upDir.isDirectory()) {
									upDir.mkdirs();
								}
								
								fos = new FileOutputStream(zipFile);
								zos = new ZipArchiveOutputStream(fos);
								
								Iterator<Map<?, ?>> it = outputList.iterator();
								
								while(it.hasNext()) {
									Map<?, ?> resultMap = it.next();
									addEntry(zos, filedownload(resultMap), String.valueOf(resultMap.get("rFileNm")));
								}
								
								zos.close();
								zos = null;
								fos.close();
								fos = null;
								
								in = new FileInputStream(zipFile);
								zipFile.delete();
							}
						} else {
							
							
							 // [2020.12.16 gjyoo]
							 // 파일 암호 설정이 활성화된 경우 비밀번호 설정된 zip파일로 압축하여 다운로드 처리함.
							 // - 참고
							 //     # 시스템 > 시스템 설정  > Code = SYS_FILE_DOWN_SET_PWD
							 //     # 사용라이브러리 : zip4j-2.6.4.jar
							 
							
							downloadName = getTimeStemp() + ".zip";
							zipFile = new File(config.getTempDir() + File.separator + downloadName);
							
							File upDir = zipFile.getParentFile();
							if(!upDir.isDirectory()) {
								upDir.mkdirs();
							}
							
							// load Zip4j util
							Zip4jUtil zip4jUtil = new Zip4jUtil(zipFile, true, tmpPassword.toCharArray());
							for (Map<?, ?> resultMap : outputList) {
								zip4jUtil.addEntry(String.valueOf(resultMap.get("rFileNm")), filedownload(resultMap));
							}
							// close zip4j out stream object
							zip4jUtil.close();
							
							in = new FileInputStream(zipFile);
							zipFile.delete();
							
						}

						//if(in == null) {
							//throw new HrException("<script>alert('download : The file does not exist.');</script>");						
						//}
						
						if(in == null) {
						    String errorMessage = "download : The file does not exist.";
						    // errorMessage 변수를 JavaScript로 전달하여 웹 페이지에서 표시
						    response.getWriter().write("<script>alert('" + errorMessage + "');</script>");
						}

						Tika tika = new Tika();
						String mType = tika.detect(downloadName);

						if ( !"".equals(mType)){
							response.setHeader("Content-Type", mType);
							response.setHeader("Content-Disposition", getEncodedFilename(downloadName, getBrowser(request)));
							response.setContentLength((int) in.available());
						}else{
							response.setHeader("Content-Type", "application/octet-stream");
							response.setHeader("Content-Disposition", getEncodedFilename(downloadName, getBrowser(request)));
							response.setContentLength((int) in.available());
						}

						outt = response.getOutputStream();

						byte b[] = new byte[1024];
						int numRead = 0;
						while ((numRead = in.read(b)) != -1) {
							outt.write(b, 0, numRead);
						}

						outt.flush();
						outt.close();
						outt = null;
						in.close();
						in = null;
					} else {
						File imgFile =  new  File(System.getProperty("webapp.root") + File.separator + "common" + File.separator + "images" + File.separator + "common" + File.separator + "img_photo.gif");
						FileInputStream ifo = new FileInputStream(imgFile);
						ByteArrayOutputStream baos = new ByteArrayOutputStream();
						byte[] buf = new byte[1024];
						int readlength = 0;
						while( (readlength =ifo.read(buf)) != -1 )
						{
							baos.write(buf,0,readlength);
						}
						byte[] imgbuf = null;
						imgbuf = baos.toByteArray();
						baos.close();
						ifo.close();

						int length = imgbuf.length;

						Log.Debug("img.length=> "+ length );

						OutputStream out = response.getOutputStream();
						out.write(imgbuf , 0, length);
						out.close();
					}

				} else {
					File imgFile =  new  File(System.getProperty("webapp.root") + File.separator + "common" + File.separator + "images" + File.separator + "common" + File.separator + "img_photo.gif");
					FileInputStream ifo = new FileInputStream(imgFile);
					ByteArrayOutputStream baos = new ByteArrayOutputStream();
					byte[] buf = new byte[1024];
					int readlength = 0;
					while( (readlength =ifo.read(buf)) != -1 )
					{
						baos.write(buf,0,readlength);
					}
					byte[] imgbuf = null;
					imgbuf = baos.toByteArray();
					baos.close();
					ifo.close();

					int length = imgbuf.length;

					Log.Debug("img.length=> "+ length );

					OutputStream out = response.getOutputStream();
					out.write(imgbuf , 0, length);
					out.close();
				}
			} catch (HrException e) {
			    Log.Debug("e: "+ e.getMessage() );
				//throw e;
			} finally {
				if(outt != null) {
                	outt.close();
                }

				if(in != null) {
                	in.close();
                }

				if(fos != null) {
                	fos.close();
                }

				if(zos != null) {
                	zos.close();
                }

				if(zipFile != null && zipFile.exists()) {
					zipFile.delete();
				}
			}
		}
	}
	*/
	
    ///////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////
	

	//private static final Logger log = LoggerFactory.getLogger(YourClassName.class); // Replace YourClassName

	public void download(boolean isDirectView, String[] fileSeqs, String[] seqNos) throws Exception {
	    synchronized (lockObj) {
	        init();

	        if (fileSeqs == null || fileSeqs.length == 0) {
	            sendImg();
	            return;
	        }

	        List<Map<?, ?>> files = getFiles(fileSeqs, seqNos);
	        if (files.isEmpty()) {
	            sendImg();
	            return;
	        }

            processFiles(files, isDirectView);
	    }
	}

	private List<Map<?, ?>> getFiles(String[] fileSeqs, String[] seqNos) {
	    List<Map<?, ?>> output = new ArrayList<>();
	    JFileUploadService service = getFileUploadService();

	    for (int i = 0; i < fileSeqs.length; i++) {
	        String fileSeq = fileSeqs[i];
	        if (StringUtil.isEmpty(fileSeq)) {
	            continue;
	        }

	        Map<String, Object> criteria = new HashMap<>();
	        criteria.put("ssnEnterCd", this.enterCd);
	        criteria.put("fileSeq", fileSeq);

	        try {
	            if (seqNos == null) {
	                output.add((Map<?, ?>) service.fileSearchByFileSeq(criteria));
	            } else if (!StringUtil.isEmpty(seqNos[i])) {
	                criteria.put("seqNo", seqNos[i]);
	                Map<?, ?> file = service.fileSearchBySeqNo(criteria);
	                if (file != null) {
	                    output.add(file);
	                }
	            }
	        } catch(HrException e){
	            Log.Error("Error while fetching file"+ e);
	        }catch(Exception e){
				throw new RuntimeException(e);
			}
		}

	    return output;
	}

	private JFileUploadService getFileUploadService() {
	    WebApplicationContext ctx = WebApplicationContextUtils.getWebApplicationContext(session.getServletContext());
	    return (JFileUploadService) ctx.getBean("JFileUploadService");
	}

	private void processFiles(List<Map<?, ?>> files) throws IOException {
	    String name;
	    InputStream in;

	    if (files.size() == 1) {
	        Map<?, ?> file = files.get(0);
	        name = StringUtil.stringValueOf(file.get("rFileNm"));
	        in = downloadFileSafely(file);
	    } else {

	    	SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd");
			Date now 		= new Date();
			Calendar cal = new GregorianCalendar(Locale.KOREA);
			cal.setTime(now);
			String today 	= format.format(cal.getTime());
	    	
	    	//name = getTimeStemp() + ".zip";
			name = today + ".zip";
	        in = createZip(files, name);
	    }

	    sendFileOrError(in, name);
	}

    private void processFiles(List<Map<?, ?>> files, boolean isDirectView) throws IOException {
        String name;
        InputStream in;
        if (files.size() == 1) {
            Map<?, ?> file = files.get(0);
            name = StringUtil.stringValueOf(file.get("rFileNm"));
            in = downloadFileSafely(file);
        }else{
            SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd");
            Date now 		= new Date();
            Calendar cal = new GregorianCalendar(Locale.KOREA);
            cal.setTime(now);
            String today 	= format.format(cal.getTime());
            name = today + ".zip";
            in = createZip(files, name);
        }

        sendFileOrError(in, name, isDirectView);
    }

	private InputStream downloadFileSafely(Map<?, ?> file) {
	    try {
	        return filedownload(file);
	    } catch(HrException e){
	        Log.Error("Error downloading file: "+ e);
	        return null;
	    }catch(Exception e){
			throw new RuntimeException(e);
		}
	}

	private void sendFileOrError(InputStream in, String name) throws IOException {
	    if (in == null) {
			HttpUtils.alert(response, "다운로드: 파일이 존재하지 않습니다.", false);
			return;
	    }
	    try (OutputStream out = response.getOutputStream()) {
	        setHeaders(name, in.available());
	        IOUtils.copy(in, out);
	        out.flush();
	    }
	}

    //isDirectView 추가
    private void sendFileOrError(InputStream in, String name, boolean isDirectView) throws IOException {
        if (in == null) {
            HttpUtils.alert(response, "다운로드: 파일이 존재하지 않습니다.", false);
            return;
        }
        try (OutputStream out = response.getOutputStream()) {
            setHeaders(name, in.available(), isDirectView);

            IOUtils.copy(in, out);
            out.flush();
        }
    }
	
	private InputStream createZip(List<Map<?, ?>> files, String name) throws IOException {
	    ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
	    try (ZipOutputStream zos = new ZipOutputStream(byteArrayOutputStream)) {
	        for (Map<?, ?> file : files) {
	            String fileName = StringUtil.stringValueOf(file.get("rFileNm")); // Assuming the map contains a file name
	            try (InputStream fis = downloadFileSafely(file)) {
	                ZipEntry zipEntry = new ZipEntry(fileName);
	                zos.putNextEntry(zipEntry);

	                byte[] bytes = new byte[1024];
	                int length;
	                while ((length = fis.read(bytes)) >= 0) {
	                    zos.write(bytes, 0, length);
	                }
	                zos.closeEntry();
	            }
	        }
	    }

	    return new ByteArrayInputStream(byteArrayOutputStream.toByteArray());
	}

	private InputStream getFileStream(Map<?, ?> file) {
	    // Scenario 1: File stored on disk
	    if (file.containsKey("filePath")) {
	        String filePath = (String) file.get("filePath");
	        try {
	            return new FileInputStream(new File(filePath));
	        } catch (FileNotFoundException e) {
	            Log.Error("Exception="+ e.getMessage());
	        }
	    }

	    // Scenario 2: File stored as a byte array
	    if (file.containsKey("fileData")) {
	        byte[] fileData = (byte[]) file.get("fileData");
	        return new ByteArrayInputStream(fileData);
	    }

	    return null; // if none of the above conditions are met
	}


	private void sendImg() throws IOException {
	    String imgPath = System.getProperty("webapp.root") + "/common/images/common/img_photo.gif";
	    try (FileInputStream fis = new FileInputStream(imgPath);
	         OutputStream out = response.getOutputStream()) {
	        byte[] imgData = IOUtils.toByteArray(fis);
	        out.write(imgData);
	    }
	}

	private void setHeaders(String name, int length) throws IOException {
	    Tika tika = new Tika();
	    String mType = tika.detect(name);

	    if (mType.isEmpty()) {
	        mType = "application/octet-stream";
	    }
	    response.setHeader("Content-Type", mType);
	    //response.setHeader("Content-Disposition", encodeName(name));
	    response.setHeader("Content-Disposition", "attachment; filename=\"" + encodeName(name) + "\"");
	    response.setContentLength(length);
	}

    private void setHeaders(String name, int length, boolean isDirectView) throws IOException{
        Tika tika = new Tika();
        String mType = tika.detect(name);

        if (mType.isEmpty()) {
            mType = "application/octet-stream";
        }
        response.setHeader("Content-Type", mType);
        if(!isDirectView){
            response.setHeader("Content-Disposition", "attachment; filename=\"" + encodeName(name) + "\"");
        }
        response.setContentLength(length);
    }

	private String encodeName(String name) throws UnsupportedEncodingException {
	    return URLEncoder.encode(name, "UTF-8").replaceAll("\\+", "%20");
	}
	
	///////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////

	private void addEntry(ZipArchiveOutputStream zos, InputStream is, String realFileName) throws Exception {
	    try (BufferedInputStream bis = new BufferedInputStream(is);
	         ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
	        byte[] buffer = new byte[102400];
	        int bytesRead;
	        CRC32 crc = new CRC32();

	        while ((bytesRead = bis.read(buffer)) > 0) {
	            baos.write(buffer, 0, bytesRead);
	            crc.update(buffer, 0, bytesRead);
	        }

	        ZipArchiveEntry entry = new ZipArchiveEntry(realFileName);
	        entry.setMethod(ZipEntry.STORED);
	        entry.setCompressedSize(baos.size());
	        entry.setSize(baos.size());
	        entry.setCrc(crc.getValue());
	        zos.putArchiveEntry(entry);

	        byte[] data = baos.toByteArray();
	        zos.write(data, 0, data.length);

	        zos.closeArchiveEntry();
	    }
	}

	protected abstract void filedelete(List<Map<?, ?>> deleteList) throws Exception;

	public void delete() throws Exception {
		synchronized(lockObj) {
			init();

			Map<String, String[]> paramMap = request.getParameterMap();

			String[] fileSeqArr = paramMap.get("fileSeq");
			String[] seqNoArr = paramMap.get("seqNo");

			try {
				if(fileSeqArr != null) {
					WebApplicationContext webAppCtxt = WebApplicationContextUtils.getWebApplicationContext(session.getServletContext());
					JFileUploadService jFileUploadService = (JFileUploadService) webAppCtxt.getBean("JFileUploadService");

					List<Map<?, ?>> deleteList = new ArrayList<Map<?,?>>();

					if(seqNoArr == null || seqNoArr.length > 1) {
						if(seqNoArr == null) {
							for(String fSeq : fileSeqArr) {
								Map<String, Object> map = new HashMap<String, Object>();
								map.put("ssnEnterCd", this.enterCd);
								map.put("fileSeq", fSeq);

								Collection<?> resultList = jFileUploadService.fileSearchByFileSeq(map);

								for(Object listItem : resultList) {
									deleteList.add((Map<?, ?>) listItem);
								}
							}
						} else {
							for(String sNo : seqNoArr) {
								Map<String, Object> map = new HashMap<String, Object>();
								map.put("ssnEnterCd", this.enterCd);
								map.put("fileSeq", fileSeqArr[0]);
								map.put("seqNo", sNo);

								deleteList.add(jFileUploadService.fileSearchBySeqNo(map));
							}
						}
					} else {
						Map<String, Object> map = new HashMap<String, Object>();
						map.put("ssnEnterCd", this.enterCd);
						map.put("fileSeq", fileSeqArr[0]);
						map.put("seqNo", seqNoArr[0]);

						deleteList.add(jFileUploadService.fileSearchBySeqNo(map));
					}


					filedelete(deleteList);
				}
			} catch (HrException e) {
			    Log.Error("Exception="+ e.getMessage());
			}
		}
	}

	protected String getBrowser(HttpServletRequest request) {
		/*
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
		*/
		return HttpUtils.getBrowser(request);
	}

	protected String getEncodedFilename(String filename, String browser) throws Exception {
		/*
		String dispositionPrefix = "attachment;filename=";
		// String getDecodedFilename = "attachment;filename=";
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

		return dispositionPrefix + encodedFilename;
		*/
		//return HttpUtils.getEncodedFilenameAddPrefix(filename, browser, "attachment;filename=");
		// [2021.08.31] 파일명에 쉼표가 포함된 경우 IE 브라우저외 브라우저에서 다운로드 안되는 현상 수정
		return HttpUtils.getEncodedFilenameAddPrefix(filename.replace(",", "_"), browser, "attachment;filename=");
	}

	public JSONArray copy(String targetUploadType, String[] fileSeqArr, String[] seqNoArr) throws Exception {
		JSONArray jsonArray = new JSONArray();

		if (fileSeqArr == null || fileSeqArr.length == 0) {
			return jsonArray;
		}

		//if(fileSeqArr != null && fileSeqArr.length > 0) {
		WebApplicationContext webAppCtxt = WebApplicationContextUtils.getWebApplicationContext(session.getServletContext());
		//JFileUploadService jFileUploadService = (JFileUploadService) webAppCtxt.getBean("JFileUploadService");
//SparrowSAST 분석 2392, 널 반환값 역참조
        if (webAppCtxt == null) {
            throw new IllegalStateException("Failed to get WebApplicationContext from the servlet context.");
        }

        JFileUploadService jFileUploadService;
        try {
            jFileUploadService = (JFileUploadService) webAppCtxt.getBean("JFileUploadService");
        } catch (BeansException ex) {
            throw new IllegalStateException("JFileUploadService bean is not available in the context.", ex);
        }

        if (jFileUploadService == null) {
            throw new IllegalStateException("JFileUploadService bean is null.");
        }

// jFileUploadService를 안전하게 사용


		String newFileSeq = jFileUploadService.jFileSequence();
		IFileHandler fileHandler = FileHandlerFactory.getFileHandler(targetUploadType, request, response);

		Map<String, Object> tsys200Map = new HashMap<>();
		Map<String, Object> tsys201Map = new HashMap<>();
		Map<String, Object> tsys202Map = new HashMap<>();
		tsys200Map.put("ssnEnterCd", session.getAttribute("ssnEnterCd"));
		tsys200Map.put("fileSeq", newFileSeq);
		tsys200Map.put("ssnSabun", session.getAttribute("ssnSabun"));


		List<Map<?, ?>> tsys201List = new ArrayList<>();
		List<Map<?, ?>> tsys202List = new ArrayList<>();


		for(int i = 0; i < fileSeqArr.length; i++) {
			Map<String, Object> searchCriteria = new HashMap<>();
			searchCriteria.put("ssnEnterCd", this.enterCd);
			searchCriteria.put("fileSeq", fileSeqArr[i]);
			searchCriteria.put("seqNo", seqNoArr[i]);

			Map<?, ?> fileDetails = jFileUploadService.fileSearchBySeqNo(searchCriteria);
			if (fileDetails == null || fileDetails.isEmpty() ) {
				throw new HrException("파일 세부 정보를 검색하지 못했습니다.");
			}

			// File upload
			InputStream is = filedownload(fileDetails);
			tsys201Map.put("fileSeq", newFileSeq);
			String rFileNm = StringUtil.null2Blank(fileDetails.get("rFileNm"));
			fileHandler.fileupload(is, rFileNm, tsys200Map, tsys201Map, tsys202Map, i);

			// Update JSON array
			tsys201List.add(tsys201Map);
			JSONObject fileData = new JSONObject();
			fileData.put("fileSeq", fileSeqArr[i]);
			fileData.put("seqNo", i);
			fileData.put("rFileNm", tsys201Map.get("rFileNm"));
			fileData.put("sFileNm", tsys201Map.get("sFileNm"));
			fileData.put("fileSize", tsys201Map.get("fileSize"));
			jsonArray.put(fileData);

			if(tsys202Map.size() > 0) {
				tsys202List.add(tsys202Map);
			}
		}

		// Save file details
		boolean saveResult = jFileUploadService.fileStoreSave(tsys200Map, tsys201List, tsys202List);
		if (!saveResult) {
			throw new HrException("파일 저장 중 오류 발생");
		}

		return jsonArray;
	}
	
	
	public JSONArray ibupload() throws Exception {
		
		synchronized (lockObj) {
			if (ServletFileUpload.isMultipartContent(request)) {
				init();

				DiskFileItemFactory factory = new DiskFileItemFactory();
				factory.setSizeThreshold(DISK_THRESHOLD_SIZE);

				File uploadDir = new File(config.getTempDir());
				if (!uploadDir.exists()) {
					uploadDir.mkdirs();
				}

				factory.setRepository(uploadDir);

				ServletFileUpload sUpload = new ServletFileUpload(factory);
				sUpload.setFileSizeMax(Long.valueOf(config.getProperty(FileUploadConfig.POSTFIX_FILE_SIZE)));

				List<FileItem> fList = sUpload.parseRequest(request);
				File toDir = null;
				FileOutputStream fo = null;

				try {
					JSONArray jsonArray = new JSONArray();

					WebApplicationContext webAppCtxt = WebApplicationContextUtils.getWebApplicationContext(session.getServletContext());
					JFileUploadService jFileUploadService = (JFileUploadService) webAppCtxt.getBean("JFileUploadService");
					Iterator<FileItem> fIt = fList.iterator();

					String fileCnt = config.getProperty(FileUploadConfig.POSTFIX_FILE_COUNT);
					int totFileCnt = Integer.valueOf(fileCnt != null && !"".equals(fileCnt) ? fileCnt : "0");
					String fileSeq = request.getParameter("fileSeq");

					if (fIt != null) {
						//int curFileCnt = fList.size();
						int curFileCnt = 0;
						for (FileItem item : fList) {
							if (!item.isFormField()) {
								curFileCnt++;
							}
						}

						int realCnt = 0;
						Map<String, Object> tsys200Map = null;
						boolean isMaster = false;

						if (fileSeq != null && !"".equals(fileSeq)) {
							Map<String, Object> paramMap = new HashMap<String, Object>();
							paramMap.put("ssnEnterCd", this.enterCd);
							paramMap.put("fileSeq", fileSeq);
							Map<?, ?> map = jFileUploadService.jFileCount(paramMap);

							if (map != null) {
								isMaster = true;
								String cnt = String.valueOf(map.get("cnt"));
								realCnt = Integer.valueOf(cnt != null && !"".equals(cnt) ? cnt : "0");

								if (totFileCnt > 0 && curFileCnt + realCnt > totFileCnt) {
									throw new FileUploadException("File Count Error!");
								}
								String mcnt = String.valueOf(map.get("mcnt"));
								realCnt = Integer.valueOf(mcnt != null && !"".equals(mcnt) ? mcnt : "0");
							}
							
						} else {
							fileSeq = jFileUploadService.jFileSequence();
						}

						if (!isMaster) {
							tsys200Map = new HashMap<String, Object>();
							tsys200Map.put("ssnEnterCd", session.getAttribute("ssnEnterCd"));
							tsys200Map.put("fileSeq", fileSeq);
							tsys200Map.put("ssnSabun", session.getAttribute("ssnSabun"));
						}

						List<Map<?, ?>> tsys201List = new ArrayList<Map<?, ?>>();
						List<Map<?, ?>> tsys202List = new ArrayList<Map<?, ?>>();

						while (fIt.hasNext()) {
							FileItem fItem = fIt.next();

							if (fItem.isFormField()) {

							} else {
								String itemName = FilenameUtils.getName(fItem.getName());
								
								boolean isVaild = true;
								String vaildMsg = null;

								String extExtension = config.getProperty(FileUploadConfig.POSTFIX_EXT_EXTENSION);
								if (extExtension != null && !"".equals(extExtension)) {
									String[] arr = itemName.split("\\.");

									if (arr.length == 1) {
										isVaild = false;
										vaildMsg = "File Type Error! " + itemName;
									} else {
										isVaild = true;
									}

									String ext = arr[arr.length - 1];
									Pattern p = Pattern.compile(extExtension.replaceAll(",", "|"), Pattern.CASE_INSENSITIVE);
									Matcher m = p.matcher(ext);
									if (!m.matches()) {
										isVaild = false;
										vaildMsg = "File Type Error! " + itemName;
									} else {
										isVaild = true;
									}
								}
								
								if(!isVaild) {
									String mimeExtension = config.getProperty(FileUploadConfig.POSTFIX_MIME_EXTENSION);
									if (mimeExtension != null && !"".equals(mimeExtension)) {
										mimeExtension = mimeExtension.replaceAll("\\*", ".*");

										String path = config.getTempDir() + File.separator + itemName;
										path = path.replaceAll(Matcher.quoteReplacement(File.separator)+Matcher.quoteReplacement(File.separator), Matcher.quoteReplacement(File.separator));
										toDir = new File(path);

										File upDir = toDir.getParentFile();

										if (upDir != null && !upDir.exists()) {
											upDir.mkdirs();// 폴더경로 없으면 만들어 놓기.
										}

										fo = new FileOutputStream(toDir);
										Streams.copy(fItem.getInputStream(), fo, true);
										fo.flush();
										
										Tika tika = new Tika();
										String mType = tika.detect(toDir);
										toDir.delete();

										Pattern p = Pattern.compile(mimeExtension.replaceAll(",", "|"), Pattern.CASE_INSENSITIVE);
										Matcher m = p.matcher(mType);
										
										if (!m.matches()) {
											isVaild = false;
											vaildMsg = "File Type Error!  " + itemName + " [" + mType + "]";
										} else {
											isVaild = true;
										}
									}
								}
								
								if(!isVaild) {
									throw new FileUploadException(vaildMsg);
								}
								
								Map<String, Object> tsys201Map = new HashMap<String, Object>();
								Map<String, Object> tsys202Map = new HashMap<String, Object>();
								
								fileupload(fItem.getInputStream(), itemName, tsys200Map, tsys201Map, tsys202Map, realCnt);
								tsys201Map.put("fileSeq", fileSeq);
								tsys201List.add(tsys201Map);

								if(tsys202Map.size() > 0) {
									tsys202Map.put("fileSeq", fileSeq);
									tsys202List.add(tsys202Map);
								}
								JSONObject jsonObject = new JSONObject();
								jsonObject.put("fileSeq", fileSeq);
								jsonObject.put("seqNo", realCnt);
								jsonObject.put("rFileNm", tsys201Map.get("rFileNm"));
								jsonObject.put("sFileNm", tsys201Map.get("sFileNm"));
								jsonObject.put("fileSize", tsys201Map.get("fileSize"));
								jsonArray.put(jsonObject);

								realCnt++;
							}
						}

						boolean result = jFileUploadService.fileStoreSave(tsys200Map, tsys201List, tsys202List);

						if (!result) {
							throw new HrException("fileSave falied");
						}
					}

					return jsonArray;
				} catch(HrException e) {
				    Log.Error("Exception="+ e.getMessage());
					throw new HrException("Saved Error!");
				} finally {
					if(fo != null) {
                    	fo.close();
                    	fo = null;
                    }
					if(toDir != null) {
                    	toDir.delete();
                    }

				}
			} else {
			    Log.Error("Error!");
				throw new HrException("Error!");
			}
		}
		
	}

    public void downloadPdf(String filePath, String fileName) throws Exception {
        synchronized (lockObj) {
            init();

            File file = new File(System.getProperty("webapp.root") + File.separator + filePath + File.separator + fileName);

            if (!file.isFile()) {
                HttpUtils.alert(response, "파일이 존재하지 않습니다.", false);
                return;
            }

            String mimeType = new Tika().detect(fileName);
            mimeType = StringUtil.isNotEmpty(mimeType) ? mimeType : "application/octet-stream";

            response.setHeader("Content-Type", mimeType);
            response.setHeader("Content-Disposition", getEncodedFilename(fileName, getBrowser(request)));
            response.setContentLength((int) file.length());

            try (
                    InputStream in = new FileInputStream(file);
                    OutputStream out = response.getOutputStream()
            ) {
                //SparrowSAST 자원누수 2025.05.09
                // 이 안에서 HrException을 던질 수 있는 로직이 있어야 함
                response.setHeader("Content-Disposition", getEncodedFilename(fileName, getBrowser(request)));

                byte[] buffer = new byte[1024];
                int numRead;
                while ((numRead = in.read(buffer)) != -1) {
                    out.write(buffer, 0, numRead);
                }
                out.flush();
            } catch (HrException e) {
                HttpUtils.alert(response, "파일 다운로드 중 오류가 발생했습니다.", false);
                throw e;
            }
        }
    }




	private void closeQuietly(Closeable resource) {
	    if (resource != null) {
	        try {
	            resource.close();
	        } catch (IOException e) {
	            Log.Error(e.getMessage());
	        }
	    }
	}
}
