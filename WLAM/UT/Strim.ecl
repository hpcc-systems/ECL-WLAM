IMPORT * FROM $;
export Strim(STRING S,STRING1 After) := IF ( StrimLength(S,After) > 0, S[1..LENGTH(S)-StrimLength(S,After)], S );