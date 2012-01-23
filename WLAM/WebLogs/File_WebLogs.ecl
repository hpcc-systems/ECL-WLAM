IMPORT WLAM.UT,$;
IMPORT * FROM Std.Str;
IMPORT Date FROM WLAM.Ut;
EXPORT File_Weblogs := MODULE

// First we get the raw web data off of the disk
R := RECORD
  STRING Txt;
  END;

SHARED d := 	DATASET('~.::weblogs',R,CSV(SEPARATOR('')));
//SHARED d := 	CHOOSEN(DATASET('~.::weblog',R,CSV(SEPARATOR(''))),1000000);

// Parse out the logs into something a little more human-readable (and fielded)
EXPORT PATTERN Num := PATTERN('[0-9]')+;
EXPORT PATTERN Tok_IP := Num '.' Num '.' Num '.' Num; 
SHARED PATTERN ToBlank := PATTERN('[^ ]')+;
EXPORT PATTERN HttpCommand := ToBlank;
EXPORT PATTERN NotQuote := PATTERN('[^"]')*;
EXPORT PATTERN Params := OPT('?' NotQuote);
EXPORT PATTERN URL := PATTERN('[^"\\?]')*;
EXPORT PATTERN HttpMethod := 'HTTP/' Num '.' Num;
EXPORT PATTERN ws := ' '+;
EXPORT PATTERN HttpString_NoQuote := HttpCommand ws URL Params HttpMethod;
EXPORT PATTERN HttpString := '"' HttpString_NoQuote OPT(ws) '"';
EXPORT PATTERN Referer := URL Params;
EXPORT PATTERN QuoteString := '"' NotQuote '"';
EXPORT PATTERN DateForm := '[' PATTERN('[^\\]]')* ']';
EXPORT PATTERN HNum := Num; // Make available for counting

SHARED LayoutLog := RECORD
  STRING15 Ip := MATCHTEXT(Tok_Ip);
	STRING1 Identity := MATCHTEXT(ToBlank[1]);
	STRING19 UserID := MATCHTEXT(ToBlank[2]);
	Date.Date_t YYYYMMDD := Date.FromParts((UNSIGNED)MATCHTEXT(DateForm)[9..12],
	                                        CASE(MATCHTEXT(DateForm)[5..7],'Apr'=>4,'Aug'=>8,'Dec'=>12,'Feb'=>2,'Jan'=>1,'Jul'=>7,'Jun'=>6,'Mar'=>3,'May'=>5,'Nov'=>11,'Oct'=>10,'Sep'=>9,0),
																					(UNSIGNED)MATCHTEXT(DateForm)[2..3]);
	/*10000*(UNSIGNED)MATCHTEXT(DateForm)[9..12]
	                     +100*CASE(MATCHTEXT(DateForm)[5..7],'Apr'=>4,'Aug'=>8,'Dec'=>12,'Feb'=>2,'Jan'=>1,'Jul'=>7,'Jun'=>6,'Mar'=>3,'May'=>5,'Nov'=>11,'Oct'=>10,'Sep'=>9,0)
											 + (UNSIGNED)MATCHTEXT(DateForm)[2..3]; */
	UNSIGNED3 HHIISS := 10000*(UNSIGNED)MATCHTEXT(DateForm)[14..15]+100*(UNSIGNED)MATCHTEXT(DateForm)[17..18]+(UNSIGNED)MATCHTEXT(DateForm)[20..21];
	UNSIGNED response_code := (UNSIGNED)MATCHTEXT(HNum[1]);
	UNSIGNED response_size := (UNSIGNED)MATCHTEXT(HNum[2]);
	STRING10 Command := MATCHTEXT(HttpCommand);
	STRING http_url := ut.Strim(MATCHTEXT(URL),'.');
	STRING6 http_url_type := ToLowerCase(ut.Strimming(MATCHTEXT(URL),'.'));	
	STRING http_params := MATCHTEXT(Params);
	STRING http_refer := MATCHTEXT(Referer/URL);
	BOOLEAN self_reference := UT.Starts(MATCHTEXT(Referer/URL),$.Home) OR LENGTH($.Home2)>0 AND UT.Starts(MATCHTEXT(Referer/URL),$.Home2);
	STRING http_refer_params := MATCHTEXT(Referer/Params);
	STRING UserAgent := MATCHTEXT(QuoteString[1]);
	STRING10 Method := MATCHTEXT(HttpMethod);
  END;

SHARED PATTERN WebLine := FIRST Tok_IP ws ToBlank ws ToBlank ws DateForm ws HttpString ws HNum ws HNum ws '"' Referer '"' ws QuoteString LAST;
p := PARSE(d,Txt,WebLine,LayoutLog,FIRST);
// Data - fairly pure - but parsed out
EXPORT Txt := PROJECT(P,TRANSFORM($.LayoutLog,SELF := LEFT));

Errs := RECORD
  STRING T := d.Txt;
  END;
e := PARSE(d,Txt,WebLine,Errs,NOT MATCHED ONLY);
// This shows the records dropped on the floor; should only be read from time to time for validation
EXPORT Errors := e;

EXPORT DeriveSessions(DATASET($.LayoutLog) D) := FUNCTION
// I am going to build 'session' tracking logic in to the data layer - because it is easy to imagine a more stateful system
// providing this information as part of the raw data - obviously we may choose to pull some of this logic out into more 
// general purpose functions

// We are going to define a session as:
// those transactions that belong to a single IP and begin as external references; chaining through any number of self-references

// IF this gives a horrid skew it might be worth doing a SORT instead
// Hash is margninally faster but also allows 'new' records in superfiles to be put onto the right node easily
InTxt := DISTRIBUTE(D,HASH(IP)); // Allow rest of sessioning to be embarrasingly parallel

TimeBased := SORT(InTxt,IP,YYYYMMDD,HHIISS,self_reference,LOCAL); 

IpToIp4(STRING15 Ip) := FUNCTION
  SET OF STRING bts := SplitWords(ip,'.');
	RETURN ((((UNSIGNED4)bts[1] * 256) + (UNSIGNED4)bts[2]) * 256 + (UNSIGNED4)bts[3] ) * 256 + (UNSIGNED4)bts[4];
  END;
// Iterate through incrementing the session number on a non-self reference
$.LayoutLog NoteSessions(InTxt le,InTxt ri) := TRANSFORM
  SELF.spider := MAP ( ri.http_url = '/robots' => true,
											 le.IP <> ri.IP => false,
	                     le.spider );
  SELF.session_number := MAP ( le.IP<>ri.IP => 1,
	                             ri.self_reference => le.session_number,
															 le.session_number+1 );
	SELF.session_position := MAP ( le.IP<>ri.IP OR ~ri.self_reference => 1, // new session
																 ri.http_url_type IN $.PageExtensions => le.session_position+1, // A new real page in a session
																 le.session_position ); // Just a 'graphics' file
	SELF.Ip4 := IF ( ri.Ip4 > 0 OR ri.Ip = '', ri.Ip4, IPToIp4(ri.Ip) );
  SELF := ri;
  END;

L1 := ITERATE(TimeBased,NoteSessions(LEFT,RIGHT),LOCAL);

RChron := SORT(L1(http_url_type IN $.PageExtensions),IP,-session_number,-session_position,LOCAL);	

// Iterate through flagging the last page of every session; and the last session for every user
$.LayoutLog NoteExits(InTxt le,InTxt ri) := TRANSFORM
  SELF.exit_page := le.IP<>ri.IP OR le.session_number<>ri.session_number OR le.IP=ri.IP AND le.session_number=ri.session_number AND le.session_position = ri.session_position AND le.exit_page;
	SELF.exit_session := le.IP<>ri.IP OR le.IP=ri.IP AND le.session_number=ri.session_number AND le.exit_session;
  SELF := ri;
  END;

L2 := ITERATE(RChron,NoteExits(LEFT,RIGHT),LOCAL);

L3 := L1(http_url_type NOT IN $.PageExtensions)+L2;	

$.IPToCountry.MAC_AppendCountry(L3,Ip4,Country,L4);

  RETURN L4;
  
  END;

EXPORT Logs := DeriveSessions(Txt) : PERSIST('TMP::ParsedWeblogs');	

END;