IMPORT $;
IMPORT Date FROM WLAM.Ut;
EXPORT Trending(DATASET($.LayoutLog) upon0) := MODULE

upon := DISTRIBUTE(upon0,HASH(YYYYMMDD));
// Our first task is to produce some meaningful summaries by day

// First we count the number of unique hits
R := RECORD
		upon.ip;
		upon.http_url;
		upon.http_url_type;
		upon.session_number;
		upon.session_position;
		upon.YYYYMMDD;
		UNSIGNED Hits := COUNT(GROUP); // Only the number of hits for this page so far
  END;
	
T1 := TABLE(upon,R,YYYYMMDD,ip,session_number,http_url,http_url_type,session_position,LOCAL);

// Now we narrow ourselves down to valid page reads per session
R1 := RECORD
			T1.YYYYMMDD;
			UNSIGNED Hits := SUM(GROUP,T1.Hits);
			UNSIGNED PageViews := COUNT(GROUP,T1.http_url_type IN $.PageExtensions); // Only count valid pages
			T1.ip;
			T1.http_url;
			T1.session_number;
      END;	

T2 := TABLE(T1,R1,YYYYMMDD,ip,session_number,http_url,LOCAL);

// Now we are down to sessions
R2 := RECORD
			T2.ip;
			UNSIGNED PagesViewed := COUNT(GROUP,T2.PageViews>0); // Only count valid pages
			UNSIGNED Hits := SUM(GROUP,T2.Hits);
			UNSIGNED PageViews := SUM(GROUP,T2.PageViews);
			T2.session_number;
			T2.YYYYMMDD;
      END;	

T3 := TABLE(T2,R2,YYYYMMDD,ip,session_number,LOCAL);

// Now go down to vistors
R3 := RECORD
			T3.YYYYMMDD;
			UNSIGNED Visits := COUNT(GROUP,T3.PageViews > 0);
			UNSIGNED PagesViewed := SUM(GROUP,T3.PagesViewed);
			UNSIGNED Hits := SUM(GROUP,T3.Hits);
			UNSIGNED PageViews := SUM(GROUP,T3.PageViews);
			T3.ip;
      END;	

T4 := TABLE(T3,R3,YYYYMMDD,ip,LOCAL);

// Finally down to the day
R4 := RECORD
			T4.YYYYMMDD;
			UNSIGNED Hits := SUM(GROUP,T4.Hits);
			UNSIGNED PageViews := SUM(GROUP,T4.PageViews);
			UNSIGNED PagesViewed := SUM(GROUP,T4.PagesViewed);
			UNSIGNED Visits := SUM(GROUP,T4.Visits);
			UNSIGNED Visitors := COUNT(GROUP);
      END;	

EXPORT DailySummaries := TABLE(T4,R4,YYYYMMDD,LOCAL);

MaxWindow := 90;

H := RECORD
		Date.Since_t Since;
		UNSIGNED PageViews;
		UNSIGNED Visitors;
  END;
	
R := RECORD
  DailySummaries;
	Date.Since_t today := Date.ToDaysSince1900(DailySummaries.YYYYMMDD);
	DATASET(H) val_history := DATASET([{Date.ToDaysSince1900(DailySummaries.YYYYMMDD),DailySummaries.PageViews,DailySummaries.Visitors}],H);
  END;	

T := TABLE(DailySummaries,R);
	

R build_history(R le,R ri) := TRANSFORM
		SELF.val_history := (le.val_history+ri.val_history)( Since >= ri.val_history[1].Since - MaxWindow);
    SELF := ri;
  END;	

Built := ITERATE(SORT(T,YYYYMMDD),build_history(LEFT,RIGHT));

R2 := RECORD
  Built.YYYYMMDD;
	Built.Hits;
	Built.PageViews;
	Built.PagesViewed;
	Built.Visits;
	Built.Visitors;
	UNSIGNED Ave_PageViews_30Days := ROUND(AVE(Built.val_history(Since>=Built.Today-30),PageViews));
	UNSIGNED Ave_PageViews_90Days := ROUND(AVE(Built.val_history(Since>=Built.Today-90),PageViews));
	UNSIGNED Ave_Visitors_30Days := ROUND(AVE(Built.val_history(Since>=Built.Today-30),Visitors));
	UNSIGNED Ave_Visitors_90Days := ROUND(AVE(Built.val_history(Since>=Built.Today-90),Visitors));
  END;

EXPORT DailyAverages := TABLE(Built,R2);

  END;