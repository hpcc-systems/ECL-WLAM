// Perhaps this will eventually find its way into a stats module
// Warning - this module does linear, global iterates - your data had better be small or this could hurt
// This is soluble - you need to take control of the distribution and replicate a little data -
// But this is not worth doing in the current context so I am keeping the code simple
// This macro also takes the hard case where there is NO guarantee that data exits for all days
// but where the missing dates are considered missing samples - and not implicitely 0
// You can make this much, much faster (10x) if you have all the dates filled in
EXPORT MovingAverage(InFile,DateField,ValueField,TargetValueField,WindowSize,OutFile) := MACRO
IMPORT Date FROM WLAM.Ut;
#uniquename(vrec)
%vrec% := RECORD
  Date.Since_t DateF;
	TYPEOF(InFile.ValueField) Val;
  END;
	
#uniquename(arec)
%arec% := RECORD
  InFile;
	DATASET(%vrec%) val_history := DATASET([{Date.ToDaysSince1900(InFile.DateField),InFile.ValueField}],%vrec%);
  END;	

#uniquename(fat)	
%fat% := TABLE(InFile,%arec%);
	
#uniquename(build_history)
%arec% %build_history%(%arec% le,%arec% ri) := TRANSFORM
		SELF.val_history := (le.val_history+ri.val_history)(DateF >= ri.val_history[1].DateF - WindowSize);
    SELF := ri;
  END;	

#uniquename(built)	
%built% := ITERATE(SORT(%fat%,DateField),%build_history%(LEFT,RIGHT));

#uniquename(putback)
TYPEOF(InFile) %PutBack%(%built% le) := TRANSFORM
  SELF.TargetValueField := AVE(le.val_history,val);
  SELF := le;
  END;
  OutFile := PROJECT(%built%,%PutBack%(LEFT));
	
  ENDMACRO;
