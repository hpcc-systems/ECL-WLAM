export File_Custom_WebLogs := MODULE

IMPORT WLAM.Ut;
IMPORT WLAM.WebLogs;
IMPORT * FROM Std.Str;
IMPORT Date FROM WLAM.Ut;

EXPORT PATTERN Num := PATTERN('[0-9]')+;
EXPORT PATTERN Tok_IP := Num '.' Num '.' Num '.' Num; 
SHARED PATTERN ToBlank := PATTERN('[^ ]')+;
EXPORT PATTERN HttpCommand := ToBlank;
EXPORT PATTERN NotQuote := PATTERN('[^"]')*;
EXPORT PATTERN Params := OPT('?' NotQuote);
EXPORT PATTERN HttpMethod := 'HTTP/' Num '.' Num;
EXPORT PATTERN ws := ' '+;
EXPORT PATTERN URL := PATTERN('[^"\\?]')*;
EXPORT PATTERN HttpString_NoQuote := HttpCommand ws URL Params HttpMethod;
EXPORT PATTERN HttpString := '"' HttpString_NoQuote OPT(ws) '"';

RawRec := RECORD
  STRING raw_txt;
END;

/* Testing Data */

SHARED file_raw := DATASET([
{'2011-06-28 05:55:45|85.115.60.180|200|22696|140925|GET /sites/default/files/css/css_dd044cee0c4747f84666f78a93d2b1fa.css HTTP/1.1|Mozilla/5.0 (X11; Linux x86_64; rv:5.0) Gecko/20100101 Firefox/5.0|gzip, deflate'},
{'2011-06-29 05:44:45|75.115.60.180|200|22696|140925|GET /sites/default/files/css/css_dd044cee0c4747f84666f78a93d2b1fa.css HTTP/1.1|Mozilla/5.0 (X11; Linux x86_64; rv:5.0) Gecko/20100101 Firefox/5.0|'},
{'2011-06-30 05:33:45|65.115.60.180|200|22696|140925|GET /sites/default/files/css/css_dd044cee0c4747f84666f78a93d2b1fa.css HTTP/1.1|Mozilla/5.0 (X11; Linux x86_64; rv:5.0) Gecko/20100101 Firefox/5.0|'}],RawRec);


//shared file_raw := choosen(dataset('~.::hpcc-log',RawRec,csv(separator(''))),5000000);

shared pattern year_fmt := Num;
shared pattern month_fmt := Num;
shared pattern day_fmt := Num;
shared pattern hours_fmt := Num;
shared pattern minutes_fmt := Num;
shared pattern seconds_fmt := Num;
shared pattern date_fmt := year_fmt '-' month_fmt '-' day_fmt ' ' hours_fmt ':' minutes_fmt ':' seconds_fmt;
shared pattern ip_fmt := Tok_IP;
shared pattern response_code_fmt := Num;
shared pattern response_size_fmt := Num;
shared pattern time_taken_fmt := Num;
shared pattern encoding_info_fmt :=NotQuote;

shared pattern sep := '|';

shared pattern line := date_fmt sep ip_fmt sep response_code_fmt sep response_size_fmt sep time_taken_fmt sep HttpString sep NotQuote sep encoding_info_fmt;

export LayoutLog := RECORD
  string15 ip := matchtext(ip_fmt);
	Date.Date_t yyyymmdd := Date.FromParts((unsigned)matchtext(year_fmt),
																				  CASE(matchtext(month_fmt),'Apr'=>4,'Aug'=>8,'Dec'=>12,'Feb'=>2,'Jan'=>1,'Jul'=>7,'Jun'=>6,'Mar'=>3,'May'=>5,'Nov'=>11,'Oct'=>10,'Sep'=>9,0),
																			    (unsigned)matchtext(day_fmt));
	unsigned3 hhiiss := 10000*(unsigned)matchtext(hours_fmt)+100*(unsigned)matchtext(minutes_fmt)+(unsigned)matchtext(seconds_fmt);
	unsigned response_code := (unsigned)matchtext(response_code_fmt);
	unsigned response_size := (unsigned)matchtext(response_size_fmt);
	time_taken := matchtext(time_taken_fmt);
	STRING10 command := matchtext(HttpCommand);
	STRING http_url := ut.Strim(MATCHTEXT(URL),'.');
	STRING6 http_url_type := ToLowerCase(ut.Strimming(MATCHTEXT(URL),'.'));	
	STRING http_params := MATCHTEXT(Params);
	STRING UserAgent := MATCHTEXT(NotQuote);
	STRING10 Method := MATCHTEXT(HttpMethod);
	STRING encoding_info := matchtext(encoding_info_fmt);
end;

shared p := parse(file_raw,raw_txt,line,LayoutLog,first);

// Data - fairly pure - but parsed out
EXPORT Txt := PROJECT(P,TRANSFORM($.LayoutLog,SELF := LEFT));

Errs := RECORD
  STRING T := file_raw.raw_Txt;
  END;

e := PARSE(file_raw,raw_Txt,Line,Errs,NOT MATCHED ONLY);
// This shows the records dropped on the floor; should only be read from time to time for validation
EXPORT Errors := e;

// Note - in this particular example we do not have referer information - so much of the session derivation logic will NOT work
EXPORT Logs := WebLogs.File_WebLogs.DeriveSessions(Txt);	

END;