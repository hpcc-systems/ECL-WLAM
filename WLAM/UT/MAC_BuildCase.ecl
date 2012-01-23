/* MAC_BuildCase takes a file with at least two columns: one labeled field text and one labelled field-num
   The result of the macro is two labels each of which contain a string which is valid ECL.
   The first will map from values of FieldNum to values of FieldText
	 The second will map from values of FieldText to values of FieldNum 

Sample Usage:
	IMPORT KJV,UT;
	ut.MAC_BuildCase(KJV.File_KJV.Txt,Book,BookNum,O,RO);
	O;
	RO
*/
	 
	 
EXPORT MAC_BuildCase(Infile,FieldText,FieldNum,OutVal,ROutVal) := MACRO

IMPORT * FROM Std.Str;

#uniquename(ded)
%ded% := DEDUP(SORT(Infile,FieldNum),FieldNum);

#uniquename(r)
%r% := RECORD
  STRING Val := (STRING)%ded%.FieldNum + ' => \'' + TRIM((STRING)%ded%.FieldText) + '\'';
	STRING RVal := '\'' + ToUpperCase(TRIM((STRING)%ded%.FieldText)) + '\' => '+(STRING)%ded%.FieldNum;
	END;
	
#uniquename(Conc)
%r% %Conc%(%r% le,%r% ri) := TRANSFORM
  SELF.Val := le.Val + ',' + ri.Val;
  SELF.RVal := le.RVal + ',' + ri.RVal;
  END;
#uniquename(s)
%s% := ROLLUP(TABLE(%ded%,%r%),TRUE,%Conc%(LEFT,RIGHT));

OutVal := 'IntTo'+#TEXT(FieldText)+'(INTEGER i) := CASE(i,'+%s%[1].Val+',\'?\');';
ROutVal := #TEXT(FieldText)+'ToInt(STRING s) := CASE(ToUpperCase(s),'+%s%[1].RVal+',0);';

  ENDMACRO;
