defmodule Calendar.Strftime do
  alias Calendar.ContainsDate
  alias Calendar.ContainsTime

  @moduledoc """
  Format different types of time representations as strings.
  """

  @doc """
  Like strftime without the exclamation point, but returns the result
  without tagging it with :ok. Raises in case of errors.

  # Examples

      # Passing NaiveDateTime struct
      iex> {{2014,9,6},{17,10,20}} |> NaiveDateTime.from_erl! |> strftime! "%A %Y-%m-%e %H:%M:%S"
      "Saturday 2014-09- 6 17:10:20"
      # Passing naive date time tuple
      iex> {{2014,9,6},{17,10,20}} |> strftime! "%A %Y-%m-%e %H:%M:%S"
      "Saturday 2014-09- 6 17:10:20"
      # Passing Date struct
      iex> {2014,9,6} |> Date.from_erl! |> strftime! "%A %Y-%m-%e"
      "Saturday 2014-09- 6"
      # Passing Time struct
      iex> {17,10,20} |> Time.from_erl! |> strftime! "%H:%M:%S"
      "17:10:20"
  """
  def strftime!(dt, string, lang\\:en) do
    parse_for_con_specs(string)
    |> Enum.reduce(string, fn(conv_spec, new_string) -> String.replace(new_string, "%#{conv_spec}", string_for_conv_spec(dt, conv_spec, lang)) end)
  end

  @doc """
  Generate a string from a DateTime, NaiveDateTime, Time or Date
  formatted by a format string. Similar to strftime known from Unix systems.

  # Examples

      iex> {{2014,9,6},{17,10,20}} |> NaiveDateTime.from_erl! |> strftime "%A %Y-%m-%e %H:%M:%S"
      {:ok, "Saturday 2014-09- 6 17:10:20"}

      # Passing erlang style naive date time tuple directly
      iex> {{2014,9,6},{17,10,20}} |> strftime "%A %Y-%m-%e %H:%M:%S"
      {:ok, "Saturday 2014-09- 6 17:10:20"}

      iex> DateTime.from_erl!({{2014,9,6},{17,10,20}},"Etc/UTC") |> strftime "%A %Y-%m-%e %H:%M:%S"
      {:ok, "Saturday 2014-09- 6 17:10:20"}

      iex> DateTime.from_erl!({{2014,9,6},{17,10,20}},"Etc/UTC") |> strftime "%a %d.%m.%y"
      {:ok, "Sat 06.09.14"}

      # Passing a Date struct
      iex> Date.from_erl!({2014,9,6}) |> strftime "%a %d.%m.%y"
      {:ok, "Sat 06.09.14"}

      # Trying to use date conversion specs and passing a Time struct results in errors
      iex>  Time.from_erl!({12, 30, 59}) |> strftime "%a %d.%m.%y"
      {:error, :missing_data_for_conversion_spec}

      # Passing a Time and using just conversion specs suitable for time
      iex>  Time.from_erl!({12, 30, 59}) |> strftime "%r"
      {:ok, "12:30:59 PM"}

      # Tuples in erlang datetime format will work like NaiveDateTime structs
      iex> {{2014,9,6},{17,10,20}} |> strftime "%A %Y-%m-%e %H:%M:%S"
      {:ok, "Saturday 2014-09- 6 17:10:20"}

      iex> {{2014,9,6},{17,10,20}} |> strftime "%A %d/%m/%Y", :da
      {:ok, "lørdag 06/09/2014"}

      iex> {{2014,9,6},{17,10,20}} |> strftime "%A %d/%m/%Y", :es
      {:ok, "sábado 06/09/2014"}

  | conversion spec. | Description                                                     | Example            | req. date | req. time | req. TZ |
  | -----------------|:---------------------------------------------------------------:| ------------------:| ---------:| ---------:| -------:|
  | %a               | Abbreviated name of day                                         | _Mon_              |         ✓ |           |         |
  | %A               | Full name of day                                                | _Monday_           |         ✓ |           |         |
  | %b               | Abbreviated month name                                          | _Jan_              |         ✓ |           |         |
  | %h               | (Equivalent to %b)                                              |                    |         ✓ |           |         |
  | %B               | Full month name                                                 | _January_          |         ✓ |           |         |
  | %j               | Day of the year as a decimal number (001 to 366).               | _002_              |         ✓ |           |         |
  | %u               | Day of the week as a decimal number (1 through 7). Also see %w  | _1_ for Monday     |         ✓ |           |         |
  | %w               | Day of the week as a decimal number (0 through 6). Also see %u  | _0_ for Sunday     |         ✓ |           |         |
  | %V               | Week number (ISO 8601). (01 through 53)                         | _02_ for week 2    |         ✓ |           |         |
  | %G               | Year for ISO 8601 week number (see %V). Not the same as %Y!     | _2015_             |         ✓ |           |         |
  | %g               | 2 digit version of %G. Iso week-year. (00 through 99)           | _15_ for 2015      |         ✓ |           |         |
  | %y               | 2 digit version of %Y. (00 through 99)                          | _15_ for 2015      |         ✓ |           |         |
  | %Y               | The year in four digits. (0001 through 9999)                    | _2015_             |         ✓ |           |         |
  | %C               | Century number as two digits. 21st century will be 20.          | _20_ for year 2015 |         ✓ |           |         |
  | %I               | Hour as decimal number using 12 hour clock. (01-12)             | _07_ for 19:00     |           |         ✓ |         |
  | %l               | Like %I but with single digits preceded by a space.             | _7_ for 19:00      |           |         ✓ |         |
  | %P               | am or pm for 12 hour clock. In lower case.                      | _pm_ for 19:00     |           |         ✓ |         |
  | %p               | AM or PM for 12 hour clock. In upper case.                      | _PM_ for 19:00     |           |         ✓ |         |
  | %r               | Time in 12 hour notation. Equivalent to %I:%M:%S %p.            | _07:25:41 PM_      |           |         ✓ |         |
  | %R               | Time in 24 hour notation excluding seconds. Equivalent of %H:%M.| _19:25_            |           |         ✓ |         |
  | %T               | Time in 24 hour notation. Equivalent of %H:%M:%S.               | _19:25:41_         |           |         ✓ |         |
  | %F               | Date in ISO 8601 format. Equivalent of %Y-%m-%d.                | _2015-02-05_       |         ✓ |         ✓ |         |
  | %v               | VMS date. Equivalent of %e-%b-%Y.                               | _ 5-Feb-2015_      |         ✓ |         ✓ |         |
  | %m               | Month as decimal number (01-12).                                | _01_ for January   |         ✓ |           |         |
  | %e               | Day of the month as decimal number. Leading space if 1-digit.   | _5_ for 2015-02-05 |         ✓ |           |         |
  | %d               | Day of the month as decimal number. Leading zero. (01-31).      | _05_ for 2015-02-05|         ✓ |           |         |
  | %H               | Hour as decimal number using 24 hour clock (00-23).             | _08_ for 08:25     |           |         ✓ |         |
  | %k               | Like %H, but with leading space instead of leading zero.        | _8_ for 08:25      |           |         ✓ |         |
  | %M               | Minute as decimal number (00-59).                               | _04_ for 19:04     |           |         ✓ |         |
  | %S               | Seconds as decimal number (00-60).                              | _02_ for 19:04:02  |           |         ✓ |         |
  | %z               | Hour and minute timezone offset from UTC.                       | _-0200_            |         ✓ |         ✓ |       ✓ |
  | %Z               | Time zone abbreviation. Sometimes depends on DST.               | _UYST_             |         ✓ |         ✓ |       ✓ |

  The ticks in the table above tells you what input is needed for the conversion spec.
  The table below shows which kinds of input you can use depending on which boxes
  are ticked:

  | Which boxes are ticked | Compatible input for conversion spec.         |
  | -----------------------| ---------------------------------------------:|
  | date                   | Date, DateTime, NaiveDateTime, datetime tuple |
  | time                   | Time, DateTime, NaiveDateTime, datetime tuple |
  | date and time          | DateTime, NaiveDateTime, datetime tuple       |
  | date and time and TZ   | DateTime                                      |
  """
  def strftime(dt, string, lang\\:en) do
    try do
      {:ok, strftime!(dt, string, lang)}
    rescue
      _error in [KeyError, Protocol.UndefinedError] ->
        {:error, :missing_data_for_conversion_spec}
      _error ->
        {:error, nil}
    end
  end

  defp tuple_to_naive_datetime({{y, month, d}, {h, min, s}}) do
    Calendar.NaiveDateTime.from_erl!({{y, month, d}, {h, min, s}})
  end
  defp tuple_to_naive_datetime(dt), do: dt

  defp parse_for_con_specs(string) do
    Regex.scan(~r/\%[a-zA-Z]/, string)
    |> Enum.map fn(x) -> hd(x)|>String.replace("%","")|>String.to_atom end
  end

  # Takes for instance a DateTime for 2014-9-6 17:10:20 and :Y and returns "2014"
  defp string_for_conv_spec(dt, :a, lang) do weekday_abbr(dt, lang) end
  defp string_for_conv_spec(dt, :A, lang) do weekday(dt, lang) end
  defp string_for_conv_spec(dt, :b, lang) do month_abbr(dt, lang) end
  defp string_for_conv_spec(dt, :h, lang) do string_for_conv_spec(dt, :b, lang) end
  defp string_for_conv_spec(dt, :B, lang) do month(dt, lang) end
  defp string_for_conv_spec(dt, :f, _) do micro_seconds(dt) end
  defp string_for_conv_spec(dt, :j, _) do "#{day_number_in_year(dt)}"|>pad(3) end
  defp string_for_conv_spec(dt, :u, _) do "#{day_of_the_week(dt)}" end
  defp string_for_conv_spec(dt, :w, _) do "#{day_of_the_week_zero_sunday(dt)}" end
  defp string_for_conv_spec(dt, :V, _) do "#{elem(iso_week_number(dt),1)}"|>pad end
  defp string_for_conv_spec(dt, :G, _) do "#{elem(iso_week_number(dt),0)}"|>pad(4) end
  defp string_for_conv_spec(dt, :g, _) do string_for_conv_spec(dt, :G, nil)|>String.slice(-2..-1) end
  defp string_for_conv_spec(dt, :y, _) do dt=to_date(dt);"#{dt.year}" |> String.slice(-2..-1) end
  defp string_for_conv_spec(dt, :Y, _) do dt=to_date(dt);"#{dt.year}"|>pad(4) end
  defp string_for_conv_spec(dt, :C, _) do dt=to_date(dt);"#{(dt.year/100.0)|>trunc}" end
  defp string_for_conv_spec(dt, :I, _) do dt=to_time(dt);"#{dt.hour|>x24h_to_12_h|>elem(0)}"|>pad end
  defp string_for_conv_spec(dt, :l, _) do dt=to_time(dt);"#{dt.hour|>x24h_to_12_h|>elem(0)}"|>pad(2, hd ' ') end
  defp string_for_conv_spec(dt, :P, _) do dt=to_time(dt);"#{dt.hour|>x24h_to_12_h|>elem(1)}" end
  defp string_for_conv_spec(dt, :p, _) do dt=to_time(dt);"#{dt.hour|>x24h_to_12_h|>elem(1)}"|>String.upcase end
  defp string_for_conv_spec(dt, :r, _) do strftime! dt, "%I:%M:%S %p" end
  defp string_for_conv_spec(dt, :R, _) do strftime! dt, "%H:%M" end
  defp string_for_conv_spec(dt, :T, _) do strftime! dt, "%H:%M:%S" end
  defp string_for_conv_spec(dt, :F, _) do strftime! dt, "%Y-%m-%d" end
  defp string_for_conv_spec(dt, :c, lang) do strftime! dt, "%a %b %e %T %Y", lang end
  defp string_for_conv_spec(dt, :v, _) do strftime! dt, "%e-%b-%Y" end
  defp string_for_conv_spec(dt, :m, _) do dt=to_date(dt);"#{dt.month}"|>pad end
  defp string_for_conv_spec(dt, :e, _) do dt=to_date(dt);"#{dt.day}"|>pad(2, hd ' ') end
  defp string_for_conv_spec(dt, :d, _) do dt=to_date(dt);"#{dt.day}"|>pad end
  defp string_for_conv_spec(dt, :H, _) do dt=to_time(dt);"#{dt.hour}"|>pad end
  defp string_for_conv_spec(dt, :k, _) do dt=to_time(dt);"#{dt.hour}"|>pad(2, hd ' ') end
  defp string_for_conv_spec(dt, :M, _) do dt=to_time(dt);"#{dt.min}"|>pad end
  defp string_for_conv_spec(dt, :S, _) do dt=to_time(dt);"#{dt.sec}"|>pad end
  defp string_for_conv_spec(dt, :z, _) do z_offset_part(dt) end
  defp string_for_conv_spec(dt, :Z, _) do "#{dt.abbr}" end

  defp micro_seconds(dt) do
    "#{dt.usec}"
  end

  defp pad(subject, len\\2, char\\?0) do
    String.rjust("#{subject}", len, char)
  end

  defp z_offset_part(dt) do
    total_off = dt.utc_off + dt.std_off
    sign = sign_for_offset(total_off)
    offset_amount_string = total_off |> secs_to_hours_mins_string
    sign<>offset_amount_string
  end
  defp sign_for_offset(offset) when offset < 0, do: "-"
  defp sign_for_offset(_), do: "+"
  defp secs_to_hours_mins_string(secs) do
    secs = abs(secs)
    hours = secs/3600.0 |> Float.floor |> trunc
    mins = rem(secs, 3600)/60.0 |> Float.floor |> trunc
    "#{hours|>pad(2)}#{mins|>pad(2)}"
  end

  defp weekday_abbr(dt, lang) do
    Enum.fetch!(names_for_language(lang)[:weekdays_abbr], day_of_the_week_off_by_one(dt))
  end
  defp weekday(dt, lang) do
    Enum.fetch!(names_for_language(lang)[:weekdays], day_of_the_week_off_by_one(dt))
  end

  defp month_abbr(dt, lang) do
    dt = dt |> to_date
    Enum.fetch!(names_for_language(lang)[:months_abbr], dt.month-1)
  end
  defp month(dt, lang) do
    dt = dt |> to_date
    Enum.fetch!(names_for_language(lang)[:months], dt.month-1)
  end

  defp iso_week_number(dt) do
    dt |> Calendar.Date.week_number
  end

  defp day_number_in_year(dt) do
    dt |> Calendar.Date.day_number_in_year
  end

  defp day_of_the_week_zero_sunday(dt) do # sunday is 0
    day = day_of_the_week(dt)
    if day == 7 do
      day = 0
    end
    day
  end

  defp x24h_to_12_h(0) do {12, :am} end
  defp x24h_to_12_h(12) do {12, :pm} end
  defp x24h_to_12_h(hour) when hour >= 1 and hour < 12 do {hour, :am} end
  defp x24h_to_12_h(hour) when hour > 12 do {hour - 12, :pm} end

  defp day_of_the_week_off_by_one(data) do
    date = to_date(data)
    date |> day_of_the_week |> - 1
  end
  defp day_of_the_week(dt) do
    dt |> Calendar.Date.day_of_week
  end

  defp to_date(data), do: ContainsDate.date_struct(data)
  defp to_time(data), do: ContainsTime.time_struct(data)

  defp names_for_language(:en) do
    %{weekdays: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
      weekdays_abbr: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
      months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
      months_abbr: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
    }
  end
  defp names_for_language(:da) do
    %{weekdays: ["mandag", "tirsdag", "onsdag", "torsdag", "fredag", "lørdag", "søndag"],
      weekdays_abbr: ["man", "tir", "ons", "tor", "fre", "lør", "søn"],
      months: ["Januar", "Februar", "Marts", "April", "Maj", "Juni", "Juli", "August", "September", "Oktober", "November", "December"],
      months_abbr: ["jan", "feb", "mar", "apr", "maj", "jun", "jul", "aug", "sep", "okt", "nov", "dec"],
    }
  end
  defp names_for_language(:es) do
    %{weekdays: ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"],
      weekdays_abbr: ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"],
      months: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre" ],
      months_abbr: ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"],
    }
  end
  defp names_for_language(_) do
    raise "unknown language code"
  end
end
