// This is the format that the weblog must be hammered into
EXPORT LayoutLog := RECORD
  STRING15 Ip := '';
	UNSIGNED4 Ip4 := 0;
	STRING1 Identity := '';
	STRING19 UserId := '';
	UNSIGNED4 YYYYMMDD := 0;
	UNSIGNED3 HHIISS := 0;
	UNSIGNED2 response_code := 0;
	UNSIGNED4 response_size := 0;
	STRING10 Command := '';
	STRING http_url := '';
	STRING6 http_url_type := '';
	STRING http_params := '';
	STRING http_refer := '';
	BOOLEAN self_reference := false;
	STRING http_refer_params := '';
	STRING UserAgent := '';
	STRING10 Method := '';
	STRING encoding_info := '';
	STRING5 country := '';
	BOOLEAN   spider := false;
	UNSIGNED4 session_number := 0; // Filled in later - the Session number for this IP
	UNSIGNED4 session_position := 0; // The 'chain number' in this Session
	BOOLEAN   exit_page := false;
	BOOLEAN   exit_session := false;
  END;
