# list of date/time formats, with my commonly used ones tabbed in

Time.strftime(format_string)
# ex: 

Symbol	    Meaning	                Example
%a  	Abbreviated weekday name (Sun, Mon, ...)	Sun
%A  	Full weekday name (Sunday, Monday, ...)	Sunday
%b  	Abbreviated month name (Jan, Feb, ...)	Jan
%B	    Full month name (January, February, ...)	January
%c	    Date and time representation	Mon Jan 01 00:00:00 2023
%C	    Century number (year/100) as a 2-digit integer	20
    %d	    Day of the month as a 2-digit integer	01
    %D	    Date in the format %m/%d/%y	01/01/23
%e	    Day of the month as a decimal number, padded with space	1
    %F	    ISO 8601 date format (yyyy-mm-dd)	2023-01-01
%H	    Hour of the day (00..23) as a 2-digit integer	00
%I	    Hour of the day (01..12) as a 2-digit integer	12
%j	    Day of the year as a 3-digit integer	001
%k	    Hour of the day (0..23) as a decimal number, padded	0
%l	    Hour of the day (1..12) as a decimal number, padded	12
    %m	    Month of the year as a 2-digit integer	01
%M	    Minute of the hour as a 2-digit integer	00
%n	    Newline	
%p	    AM or PM	AM
%P	    am or pm	am
%r	    Time in AM/PM format	12:00:00 AM
%R	    Time in 24-hour format	00:00
%s	    Unix timestamp (seconds since 1970-01-01 00:00:00 UTC)	1577836800
%S	    Second of the minute as a 2-digit integer	00
%t	    Tab	
%T	    Time in 24-hour format with seconds	00:00:00
%u	    Day of the week as a decimal, Monday being 1	1
%U	    Week number of the year (Sunday as the first day)	00
%V	    Week number of the year (ISO week numbering)	01
%w	    Day of the week as a decimal, Sunday being 0	0
%W	    Week number of the year (Monday as the first day)	00
%x	    Preferred representation of date	01/01/23
%X	    Preferred representation of time	00:00:00
%y	    Year without century as a 2-digit integer	23
    %Y	    Year with century as a 4-digit integer	2023
%z	    Time zone offset from UTC in the form +HHMM or -HHMM	+0000
%Z	    Time zone name or abbreviation	UTC
%%	    A literal '%' character	%
