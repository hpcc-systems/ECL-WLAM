EXPORT Date := MODULE

// The core date format is an unsigned8 holding a number in the form YYYYMMDD
EXPORT Date_t := UNSIGNED4;
EXPORT Since_t := UNSIGNED4; // Used for 'days since' 1900 - note UNSIGNED3 would work ...
EXPORT Year(Date_t d) := d DIV 10000;
EXPORT Month(Date_t d) := d DIV 100 % 100;
EXPORT Day(Date_t d) := d % 100;
EXPORT FromParts(UNSIGNED2 year, UNSIGNED1 month, UNSIGNED1 day) := ( year * 100 + month ) * 100 + day;

EXPORT isLeapYear(INTEGER2 year) := year % 4 = 0 AND ( year % 100 != 0 OR year % 400 = 0);


dayofyr(INTEGER1 month,INTEGER1 day) := CHOOSE( month,0,31,59,90,120,151,181,212,243,273,304,334 ) + day;

EXPORT DayOfYear(Date_t d) := dayofyr(Month(d),Day(d)) + IF( isLeapYear(Year(d)) AND Month(d) > 2, 1, 0);

// Currently only works until Feb 2100 - if anyone can think of a fast routine that works beyond then ....

EXPORT ToDaysSince1900(Date_t d) := (Year(d)-1900)*365+ (Year(d)-1901) DIV 4 + dayofyear(d);

find_year(Since_t days1) := ((Since_t)(days1 / 365.25)) + 1900;
MonthsDays(Since_t days2) := ROUNDUP(days2 - ((find_year(days2) - 1901) * 365.25 + 365));

months(Since_t days3) := IF(~isLeapYear(find_year(days3)),
WHICH(MonthsDays(days3)<32,MonthsDays(days3)<60,MonthsDays(days3)<91,MonthsDays(days3)<121,
		MonthsDays(days3)<152,MonthsDays(days3)<182,MonthsDays(days3)<213,MonthsDays(days3)<244,
		MonthsDays(days3)<274,MonthsDays(days3)<305,MonthsDays(days3)<335 ,TRUE),
WHICH(MonthsDays(days3)<32,MonthsDays(days3)<61,MonthsDays(days3)<92,MonthsDays(days3)<122,
		MonthsDays(days3)<153,MonthsDays(days3)<183,MonthsDays(days3)<214,MonthsDays(days3)<245,
		MonthsDays(days3)<275,MonthsDays(days3)<306,MonthsDays(days3)<336 ,TRUE));


days_in(Since_t days4) := monthsDays(days4) - IF(isLeapYear(find_year(days4)) and months(days4)>2,1,0) -
			CHOOSE(months(days4),0,31,59,90,120,151,181,212,243,273,304,334);
			

export FromDaysSince1900(Since_t days) := FromParts(find_year(days),months(days),days_in(days));


/****************

Universal Date/Time format Converter

Parameters:
	s		the string to convert
	fmtin	input format string (See documentation fo strptime)
			http://linux.die.net/man/3/strftime
	fmtout	output format string (See documentation fo strftime)
			http://linux.die.net/man/3/strptime
			
Common date formats
	%b or %B	Month name (full or abbreviation)
	%C			Century (0-99)
	%d			Day of month
	%t			Whitespace
	%y			year within century (00-99)
	%Y			Full year (yyyy)
	
Common date formats
	American	'%m/%d/%Y'	mm/dd/yyyy  (default input format)
	Euro		'%d/%m/%Y'	dd/mm/yyyy
	Iso format	'%Y-%m-%d'	yyyy-mm-dd	
	Iso basic	'%Y%m%d'	yyyymmdd	(default output format)
				'%d-%b-%Y'  dd-mon-yyyy	e.g., '21-Mar-1954' 

NOTE: This function will also handle time data
	
Returns an empty string if the date cannot be parsed.

******************/
EXPORT STRING ConvertFormat(VARSTRING s, VARSTRING fmtin='%m/%d/%Y', VARSTRING fmtout='%Y%m%d') := BEGINC++
#include <stdio.h>
#include <time.h>
#body
struct tm tm;
char * out;
size32_t len;
char buf[255]; 

char * res = strptime(s, fmtin, &tm);

if (res != NULL)
{
   strftime(buf, sizeof(buf), fmtout, &tm); 
   len = strlen(buf);
   out = (char *)rtlMalloc(len);
   memcpy(out, buf, len);
}
else {
	len = 0;
	out = NULL;
}
__lenResult = len;
__result = out; 
ENDC++;

/****************

Universal Date/Time format Converter

This function is like ConvertDate, except that it will take a set of possible formats
It will match them in the order specified, stopping only if it finds a match

Parameters:
	s		the string to convert
	fmtsin	set of input format string (See documentation fo strptime)
			http://linux.die.net/man/3/strftime
	fmtout	output format string (See documentation fo strftime)
			http://linux.die.net/man/3/strptime
			
Returns an empty string if the date cannot be parsed using any of the supplied formats
******************/
EXPORT STRING ConvertFormatMultiple(VARSTRING s, SET OF VARSTRING fmtsin, VARSTRING fmtout='%Y%m%d') := BEGINC++
#include <stdio.h>
#include <time.h>
#body
struct tm tm;
char * out;
size32_t len;
char buf[255]; 

char *res;
char *fmtin = (char *)fmtsin;

for (int i = 0; i < lenFmtsin; ++i)
{ 
	res = strptime(s, fmtin, &tm);
	if (res != NULL)
		break;
	fmtin = fmtin + strlen(fmtin) + 1;
}
	
if (res != NULL)
{
   strftime(buf, sizeof(buf), fmtout, &tm); 
   len = strlen(buf);
   out = (char *)rtlMalloc(len);
   memcpy(out, buf, len);
}
else {
	len = 0;
	out = NULL;
}
__lenResult = len;
__result = out; 

ENDC++;

EXPORT FromString(STRING DateAsString,VARSTRING fmtin='%m/%d/%Y') := (Date_t)ConvertFormat(DateAsString,fmtin);

EXPORT ToString(Date_t d,VARSTRING fmtout='%m/%d/%Y') := ConvertFormat((VARSTRING)d,'%Y%m%d',fmtout);

END;