IMPORT * from WLAM.WebLogs;
Analysis(File_WebLogs.Logs).Stats;
Analysis(File_WebLogs.Logs).ContentSummary;

OUTPUT(Topn(File_WebLogs.Logs,100,IP));

MyFormat := RECORD
				Ips := Analysis(File_WebLogs.Logs).Stats.TopIps.ip;
				Cnt := Analysis(File_WebLogs.Logs).Stats.TopIps.cnt;
			END;

//The following statement will generate an IP/sessions example Pie Chart. 
//You'll need to download the VL tree from: https://github.com/hpcc-systems/ecl-samples/tree/master/visualizations/google_charts
//and unpack it so that the "files" directory is at the
//level of "UT" and "WebLogs".

/*
OUTPUT(TABLE(Analysis(File_WebLogs.Logs).Stats.TopIps,MyFormat),named('PieChart_IP_Count_Pie_Chart'));
*/