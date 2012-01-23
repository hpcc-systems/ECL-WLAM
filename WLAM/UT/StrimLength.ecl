IMPORT * FROM Std.Str;
export StrimLength(STRING S,STRING1 After) := IF ( FindCount(S,After) > 0, 1+LENGTH(S)-Find(S,After,FindCount(S,After)), 0);