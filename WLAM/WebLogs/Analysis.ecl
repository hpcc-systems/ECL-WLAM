IMPORT $;
IMPORT Date FROM WLAM.Ut;
EXPORT Analysis(DATASET($.LayoutLog) upon) := MODULE

SHARED Count_T := UNSIGNED4; // Make UNSIGNED8 if you have > billions of pages

LOADXML('<root></root>');
#declare(recname)
#declare(tablename)
SHARED ExampleSize := 100;

// Ensure uniformity and minimize coding for lots of fields ...
// SALT has a better way of doing this kind of profiling - but it is quite a lot of work ...
SHARED MAC_Summary(fieldname) := MACRO
// Am going to deliberately leak symbols
#set(recname,#text(fieldname)+'_rec')
SHARED %recname% := RECORD
  upon.fieldname;
	Count_T cnt := COUNT(GROUP);
	UNSIGNED Bandwidth := SUM(GROUP,upon.response_size);
  END;
// Note - ECL is very nice - those labels not used will simply be ignored
#set(tablename,#text(fieldname)+'_table')
EXPORT %tablename% := TABLE(upon,%recname%,fieldname,MERGE);	
#set(recname,'TOP100_'+#text(fieldname))
EXPORT %recname% := TOPN(%tablename%,ExampleSize,-cnt);
#set(recname,'UNIQUE_'+#text(fieldname))
EXPORT %recname% := COUNT(%tablename%);
#set(recname,'MAX_'+#text(fieldname))
EXPORT %recname% := MAX(%tablename%,fieldname);
	
  ENDMACRO;

MAC_Summary(session_number);	
MAC_Summary(session_position);
MAC_Summary(ip);	
MAC_Summary(country);	
MAC_Summary(response_code);
MAC_Summary(http_url);
MAC_Summary(http_url_type);
MAC_Summary(yyyymmdd);

// Does not fit into my standard macro
SHARED http_refer_rec := RECORD
  upon.http_refer;
	upon.self_reference;
	Count_T Cnt := COUNT(GROUP);
  END;
	
SHARED http_refer_table := TABLE(upon,http_refer_rec,http_refer,self_reference,MERGE);	

EXPORT TOP100_http_refer_internal := TOPN(http_refer_table(self_reference),100,-cnt);
EXPORT TOP100_http_refer_external := TOPN(http_refer_table(~self_reference),100,-cnt);
EXPORT UNIQUE_http_refer_external := COUNT(http_refer_table(~self_reference));
EXPORT UNIQUE_http_refer_internal := COUNT(http_refer_table(self_reference));

// Compute some session based statistics
R := RECORD
  upon.IP;
	upon.session_number;
	BOOLEAN Final := MAX(GROUP,upon.exit_session);
	Count_T Pages := MAX(GROUP,upon.session_position);
	END;
	
SHARED Sessions := TABLE(upon,R,IP,session_number,MERGE);	

// Select the statistics I think will be interesting to people
R := RECORD
  Count_T Hits;
  Count_T Visits;
	Count_T Hard_Bounces;
	Count_T Pings;
	Count_T Visitors;
	Count_T NewVisitors;
	REAL     PagesPerVisit;
  DATASET(ip_rec) TopIps;
	Count_T NumURLs;
  DATASET(http_url_rec) TopURLs;
	UNSIGNED4 NumDays;
	DATASET(yyyymmdd_rec) TopDays;
	UNSIGNED4 NumCountries;
	DATASET(country_rec) TopCountries;
	Count_T InternalReferences;
	Count_T ExternalReferences;
  DATASET(http_refer_rec) TopRefers_Internal;
  DATASET(http_refer_rec) TopRefers_External;
	DATASET(response_code_rec) Response_Codes;
	DATASET(session_number_rec) Session_Count;
	Count_T MaxSessions;
	DATASET(session_position_rec) Session_Positions;
	Count_T MaxSessionPositions;
	DATASET(http_url_type_rec) TopTypes;
  END;
	
EXPORT Stats := DATASET([{COUNT(upon), // its
						COUNT(Sessions),  // visits
						COUNT(Sessions(pages=1,session_number=1,Final)),
						COUNT(Sessions(pages=1,session_number>1,~Final)), // Define a ping as a one-page visit after an initial visit; but where people come back
						UNIQUE_IP,
						COUNT(Sessions(session_number=1)),  // number of new visitors
						AVE(Sessions,pages),
						TOP100_IP,
						UNIQUE_http_url,
						TOP100_http_url,
						UNIQUE_yyyymmdd,
						TOP100_yyyymmdd,
						UNIQUE_Country,
						TOP100_Country,
						UNIQUE_http_refer_internal,
						UNIQUE_http_refer_external,
						TOP100_http_refer_internal,
						TOP100_http_refer_external,
						Top100_response_code,
						Top100_session_number,Max_session_number,
						Top100_session_position,Max_session_position,
						TOP100_http_url_type}],R);

/*
  Construct a summary by page of certain key facts
*/
R := RECORD
		upon.ip;
		upon.session_number;
		upon.session_position;
		upon.YYYYMMDD;
		upon.http_url;
		upon.exit_page;
		http_url_type := MAX(GROUP,upon.http_url_type);
  END;
	
T1 := TABLE(upon(http_url_type IN $.PageExtensions),R,http_url,ip,session_number,session_position,YYYYMMDD,exit_page,MERGE);

R2 := RECORD
		T1.ip;
		Date.Date_t EarliestSeen := MIN(GROUP,T1.YYYYMMDD);
		Date.Date_t LatestSeen := MAX(GROUP,T1.YYYYMMDD);
		Count_T Views := COUNT(GROUP);
		Count_T Entries := COUNT(GROUP,T1.session_position=1);
		Count_T Exits := COUNT(GROUP,T1.exit_page);
		Count_T Bounces := COUNT(GROUP,T1.exit_page AND T1.session_position=1);
		http_url_type := MAX(GROUP,T1.http_url_type);
		T1.http_url;
  END;
	
T2 := TABLE(T1,R2,http_url,ip,MERGE);

R3 := RECORD
		T2.http_url;
		http_url_type := MAX(GROUP,T2.http_url_type);
		Count_T Views := SUM(GROUP,T2.Views);
		Count_T UniqueViews := COUNT(GROUP);
		Count_T Entries := SUM(GROUP,T2.Entries);
		Count_T Exits := SUM(GROUP,T2.Exits);
		Count_T Bounces := SUM(GROUP,T2.Bounces);
		Date.Date_t EarliestSeen := MIN(GROUP,T2.EarliestSeen);
		Date.Date_t LatestSeen := MAX(GROUP,T2.LatestSeen);
  END;
	
T3 := TABLE(T2,R3,http_url,MERGE);

EXPORT ContentSummary := T3;

END;