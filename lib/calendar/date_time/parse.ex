defmodule Calendar.DateTime.Parse do
  import Calendar.ParseUtil

  @secs_between_year_0_and_unix_epoch 719528*24*3600 # From erlang calendar docs: there are 719528 days between Jan 1, 0 and Jan 1, 1970. Does not include leap seconds


  @doc """
  Parses an RFC 822 datetime string and shifts it to UTC.

  Takes an RFC 822 `string` and `year_guessing_base`. The `year_guessing_base`
  argument is used in case of a two digit year which is allowed in RFC 822.
  The function tries to guess possible four digit versions of the year and
  chooses the one closest to `year_guessing_base`. It defaults to 2015.

  # Examples
      # 2 digit year
      iex> "5 Jul 15 20:26:13 PST" |> rfc822_utc
      {:ok,
            %Calendar.DateTime{abbr: "UTC", day: 6, hour: 4, min: 26, month: 7,
             sec: 13, std_off: 0, timezone: "Etc/UTC", usec: nil, utc_off: 0,
             year: 2015}}
      # 82 as year
      iex> "5 Jul 82 20:26:13 PST" |> rfc822_utc
      {:ok,
            %Calendar.DateTime{abbr: "UTC", day: 6, hour: 4, min: 26, month: 7,
             sec: 13, std_off: 0, timezone: "Etc/UTC", usec: nil, utc_off: 0,
             year: 1982}}
      # 1982 as year
      iex> "5 Jul 82 20:26:13 PST" |> rfc822_utc
      {:ok,
            %Calendar.DateTime{abbr: "UTC", day: 6, hour: 4, min: 26, month: 7,
             sec: 13, std_off: 0, timezone: "Etc/UTC", usec: nil, utc_off: 0,
             year: 1982}}
      # 2 digit year and we use 2099 as the base guessing year
      # which means that 15 should be interpreted as 2115 no 2015
      iex> "5 Jul 15 20:26:13 PST" |> rfc822_utc(2099)
      {:ok,
            %Calendar.DateTime{abbr: "UTC", day: 6, hour: 4, min: 26, month: 7,
             sec: 13, std_off: 0, timezone: "Etc/UTC", usec: nil, utc_off: 0,
             year: 2115}}
  """
  def rfc822_utc(string, year_guessing_base \\ 2015) do
    string
    |> capture_rfc822_string
    |> change_captured_year_to_four_digit(year_guessing_base)
    |> rfc2822_utc_from_captured
  end
  defp capture_rfc822_string(string) do
    ~r/(?<day>[\d]{1,2})[\s]+(?<month>[^\d]{3})[\s]+(?<year>[\d]{2,4})[\s]+(?<hour>[\d]{2})[^\d]?(?<min>[\d]{2})[^\d]?(?<sec>[\d]{2})[^\d]?(((?<offset_sign>[+-])(?<offset_hours>[\d]{2})(?<offset_mins>[\d]{2})|(?<offset_letters>[A-Z]{1,3})))?/
    |> Regex.named_captures(string)
  end
  defp change_captured_year_to_four_digit(cap, year_guessing_base) do
    changed_year = to_int(cap["year"])
    |> two_to_four_digit_year(year_guessing_base)
    |> to_string
    %{cap | "year" => changed_year}
  end
  defp two_to_four_digit_year(year, year_guessing_base) when year < 100 do
    closest_year(year, year_guessing_base)
  end
  defp two_to_four_digit_year(year, _), do: year

  defp closest_year(two_digit_year, year_guessing_base) do
    two_digit_year
    |> possible_years(year_guessing_base)
    |> Enum.map(fn year -> {year, abs(year_guessing_base-year)} end)
    |> Enum.min_by(fn {_year, diff} -> diff end)
    |> elem(0)
  end
  defp possible_years(two_digit_year, year_guessing_base) do
    centuries_for_guessing_base(year_guessing_base)
    |> Enum.map(&(&1+two_digit_year))
  end
  # The three centuries closest to the guessing base
  # if you provide e.g. 2015 it should return [1900, 2000, 2100]
  defp centuries_for_guessing_base(year_guessing_base) do
    base_century = year_guessing_base-rem(year_guessing_base, 100)
    [base_century-100, base_century, base_century+100]
  end

  @doc """
  Parses an RFC 2822 or RFC 1123 datetime string.

  The datetime is shifted to UTC.

  ## Examples
      iex> rfc2822_utc("Sat, 13 Mar 2010 11:23:03 -0800")
      {:ok,
            %Calendar.DateTime{abbr: "UTC", day: 13, hour: 19, min: 23, month: 3, sec: 3, std_off: 0,
             timezone: "Etc/UTC", usec: nil, utc_off: 0, year: 2010}}

      # PST is the equivalent of -0800 in the RFC 2822 standard
      iex> rfc2822_utc("Sat, 13 Mar 2010 11:23:03 PST")
      {:ok,
            %Calendar.DateTime{abbr: "UTC", day: 13, hour: 19, min: 23, month: 3, sec: 3, std_off: 0,
             timezone: "Etc/UTC", usec: nil, utc_off: 0, year: 2010}}

      # Z is the equivalent of UTC
      iex> rfc2822_utc("Sat, 13 Mar 2010 11:23:03 Z")
      {:ok,
            %Calendar.DateTime{abbr: "UTC", day: 13, hour: 11, min: 23, month: 3, sec: 3, std_off: 0,
             timezone: "Etc/UTC", usec: nil, utc_off: 0, year: 2010}}
  """
  def rfc2822_utc(string) do
    string
    |> capture_rfc2822_string
    |> rfc2822_utc_from_captured
  end

  defp rfc2822_utc_from_captured(cap) do
    month_num = month_number_for_month_name(cap["month"])
    {:ok, offset_in_secs} = offset_in_seconds_rfc2822(cap["offset_sign"],
                                               cap["offset_hours"],
                                               cap["offset_mins"],
                                               cap["offset_letters"])
    {:ok, result} = Calendar.DateTime.from_erl({{cap["year"]|>to_int, month_num, cap["day"]|>to_int}, {cap["hour"]|>to_int, cap["min"]|>to_int, cap["sec"]|>to_int}}, "Etc/UTC")
    Calendar.DateTime.add(result, offset_in_secs*-1)
  end

  defp offset_in_seconds_rfc2822(_, _, _, "UTC"), do: {:ok, 0 }
  defp offset_in_seconds_rfc2822(_, _, _, "UT"),  do: {:ok, 0 }
  defp offset_in_seconds_rfc2822(_, _, _, "Z"),   do: {:ok, 0 }
  defp offset_in_seconds_rfc2822(_, _, _, "GMT"), do: {:ok, 0 }
  defp offset_in_seconds_rfc2822(_, _, _, "EDT"), do: {:ok, -4*3600 }
  defp offset_in_seconds_rfc2822(_, _, _, "EST"), do: {:ok, -5*3600 }
  defp offset_in_seconds_rfc2822(_, _, _, "CDT"), do: {:ok, -5*3600 }
  defp offset_in_seconds_rfc2822(_, _, _, "CST"), do: {:ok, -6*3600 }
  defp offset_in_seconds_rfc2822(_, _, _, "MDT"), do: {:ok, -6*3600 }
  defp offset_in_seconds_rfc2822(_, _, _, "MST"), do: {:ok, -7*3600 }
  defp offset_in_seconds_rfc2822(_, _, _, "PDT"), do: {:ok, -7*3600 }
  defp offset_in_seconds_rfc2822(_, _, _, "PST"), do: {:ok, -8*3600 }
  defp offset_in_seconds_rfc2822(_, _, _, letters) when letters != "", do: {:error, :invalid_letters}
  defp offset_in_seconds_rfc2822(offset_sign, offset_hours, offset_mins, _letters) do
    offset_in_secs = hours_mins_to_secs!(offset_hours, offset_mins)
    offset_in_secs = case offset_sign do
      "-" -> offset_in_secs*-1
      _   -> offset_in_secs
    end
    {:ok, offset_in_secs}
  end

  @doc """
  Takes unix time as an integer or float. Returns a DateTime struct.

  ## Examples

      iex> unix!(1_000_000_000)
      %Calendar.DateTime{abbr: "UTC", day: 9, usec: nil, hour: 1, min: 46, month: 9, sec: 40, std_off: 0, timezone: "Etc/UTC", utc_off: 0, year: 2001}

      iex> unix!("1000000000")
      %Calendar.DateTime{abbr: "UTC", day: 9, usec: nil, hour: 1, min: 46, month: 9, sec: 40, std_off: 0, timezone: "Etc/UTC", utc_off: 0, year: 2001}

      iex> unix!(1_000_000_000.9876)
      %Calendar.DateTime{abbr: "UTC", day: 9, usec: 987600, hour: 1, min: 46, month: 9, sec: 40, std_off: 0, timezone: "Etc/UTC", utc_off: 0, year: 2001}

      iex> unix!(1_000_000_000.999999)
      %Calendar.DateTime{abbr: "UTC", day: 9, usec: 999999, hour: 1, min: 46, month: 9, sec: 40, std_off: 0, timezone: "Etc/UTC", utc_off: 0, year: 2001}
  """
  def unix!(unix_time_stamp) when is_integer(unix_time_stamp) do
    unix_time_stamp + @secs_between_year_0_and_unix_epoch
    |>:calendar.gregorian_seconds_to_datetime
    |> Calendar.DateTime.from_erl!("Etc/UTC")
  end
  def unix!(unix_time_stamp) when is_float(unix_time_stamp) do
    {whole, micro} = int_and_usec_for_float(unix_time_stamp)
    whole + @secs_between_year_0_and_unix_epoch
    |>:calendar.gregorian_seconds_to_datetime
    |> Calendar.DateTime.from_erl!("Etc/UTC", micro)
  end
  def unix!(unix_time_stamp) when is_binary(unix_time_stamp) do
    unix_time_stamp
    |> to_int
    |> unix!
  end

  defp int_and_usec_for_float(float) do
    float_as_string = Float.to_string(float, [decimals: 6, compact: false])
    {int, frac} = Integer.parse(float_as_string)
    {int, parse_unix_fraction(frac)}
  end
  # recieves eg. ".987654321" returns usecs. eg. 987654
  defp parse_unix_fraction(string), do: String.slice(string, 1..6) |> String.ljust(6, ?0) |> Integer.parse |> elem(0)

  @doc """
  Parse JavaScript style milliseconds since epoch.

  # Examples

      iex> js_ms!("1000000000123")
      %Calendar.DateTime{abbr: "UTC", day: 9, usec: 123000, hour: 1, min: 46, month: 9, sec: 40, std_off: 0, timezone: "Etc/UTC", utc_off: 0, year: 2001}

      iex> js_ms!(1_000_000_000_123)
      %Calendar.DateTime{abbr: "UTC", day: 9, usec: 123000, hour: 1, min: 46, month: 9, sec: 40, std_off: 0, timezone: "Etc/UTC", utc_off: 0, year: 2001}

      iex> js_ms!(1424102000000)
      %Calendar.DateTime{abbr: "UTC", day: 16, hour: 15, usec: 0, min: 53, month: 2, sec: 20, std_off: 0, timezone: "Etc/UTC", utc_off: 0, year: 2015}
  """
  def js_ms!(millisec) when is_integer(millisec) do
    (millisec/1000.0)
    |> unix!
  end

  def js_ms!(millisec) when is_binary(millisec) do
    {int, ""} = millisec
    |> Integer.parse
    js_ms!(int)
  end

  @doc """
  Parses a timestamp in RFC 2616 format.

      iex> httpdate("Sat, 06 Sep 2014 09:09:08 GMT")
      {:ok, %Calendar.DateTime{year: 2014, month: 9, day: 6, hour: 9, min: 9, sec: 8, timezone: "Etc/UTC", abbr: "UTC", std_off: 0, utc_off: 0}}

      iex> httpdate("invalid")
      {:bad_format, nil}

      iex> httpdate("Foo, 06 Foo 2014 09:09:08 GMT")
      {:error, :invalid_datetime}
  """
  def httpdate(rfc2616_string) do
    ~r/(?<weekday>[^\s]{3}),\s(?<day>[\d]{2})\s(?<month>[^\s]{3})[\s](?<year>[\d]{4})[^\d](?<hour>[\d]{2})[^\d](?<min>[\d]{2})[^\d](?<sec>[\d]{2})\sGMT/
    |> Regex.named_captures(rfc2616_string)
    |> httpdate_parsed
  end
  defp httpdate_parsed(nil), do: {:bad_format, nil}
  defp httpdate_parsed(mapped) do
    Calendar.DateTime.from_erl(
      {
        {mapped["year"]|>to_int,
          mapped["month"]|>month_number_for_month_name,
          mapped["day"]|>to_int},
        {mapped["hour"]|>to_int, mapped["min"]|>to_int, mapped["sec"]|>to_int }
      }, "Etc/UTC")
  end

  @doc """
  Like `httpdate/1`, but returns the result without tagging it with :ok
  in case of success. In case of errors it raises.

      iex> httpdate!("Sat, 06 Sep 2014 09:09:08 GMT")
      %Calendar.DateTime{year: 2014, month: 9, day: 6, hour: 9, min: 9, sec: 8, timezone: "Etc/UTC", abbr: "UTC", std_off: 0, utc_off: 0}
  """
  def httpdate!(rfc2616_string) do
    {:ok, dt} = httpdate(rfc2616_string)
    dt
  end

  @doc """
  Parse RFC 3339 timestamp strings as UTC. If the timestamp is not in UTC it
  will be shifted to UTC.

  ## Examples

      iex> rfc3339_utc("fooo")
      {:bad_format, nil}

      iex> rfc3339_utc("1996-12-19T16:39:57Z")
      {:ok, %Calendar.DateTime{year: 1996, month: 12, day: 19, hour: 16, min: 39, sec: 57, timezone: "Etc/UTC", abbr: "UTC", std_off: 0, utc_off: 0}}

      iex> rfc3339_utc("1996-12-19T16:39:57.123Z")
      {:ok, %Calendar.DateTime{year: 1996, month: 12, day: 19, hour: 16, min: 39, sec: 57, timezone: "Etc/UTC", abbr: "UTC", std_off: 0, utc_off: 0, usec: 123000}}

      iex> rfc3339_utc("1996-12-19T16:39:57-08:00")
      {:ok, %Calendar.DateTime{year: 1996, month: 12, day: 20, hour: 0, min: 39, sec: 57, timezone: "Etc/UTC", abbr: "UTC", std_off: 0, utc_off: 0}}

      # No seperation chars between numbers. Not RFC3339, but we still parse it.
      iex> rfc3339_utc("19961219T163957-08:00")
      {:ok, %Calendar.DateTime{year: 1996, month: 12, day: 20, hour: 0, min: 39, sec: 57, timezone: "Etc/UTC", abbr: "UTC", std_off: 0, utc_off: 0}}

      # Offset does not have colon (-0800). That makes it ISO8601, but not RFC3339. We still parse it.
      iex> rfc3339_utc("1996-12-19T16:39:57-0800")
      {:ok, %Calendar.DateTime{year: 1996, month: 12, day: 20, hour: 0, min: 39, sec: 57, timezone: "Etc/UTC", abbr: "UTC", std_off: 0, utc_off: 0}}
  """
  def rfc3339_utc(<<year::4-bytes, ?-, month::2-bytes , ?-, day::2-bytes , ?T, hour::2-bytes, ?:, min::2-bytes, ?:, sec::2-bytes, ?Z>>) do
    # faster version for certain formats of of RFC3339
    {{year|>to_int, month|>to_int, day|>to_int},{hour|>to_int, min|>to_int, sec|>to_int}} |> Calendar.DateTime.from_erl("Etc/UTC")
  end
  def rfc3339_utc(rfc3339_string) do
    parsed = rfc3339_string
    |> parse_rfc3339_string
    if parsed do
      parse_rfc3339_as_utc_parsed_string(parsed, parsed["z"], parsed["offset_hours"], parsed["offset_mins"])
    else
      {:bad_format, nil}
    end
  end

  @doc """
  Parses an RFC 3339 timestamp and shifts it to
  the specified time zone.

      iex> rfc3339("1996-12-19T16:39:57Z", "Etc/UTC")
      {:ok, %Calendar.DateTime{year: 1996, month: 12, day: 19, hour: 16, min: 39, sec: 57, timezone: "Etc/UTC", abbr: "UTC", std_off: 0, utc_off: 0}}

      iex> rfc3339("1996-12-19T16:39:57.1234Z", "Etc/UTC")
      {:ok, %Calendar.DateTime{year: 1996, month: 12, day: 19, hour: 16, min: 39, sec: 57, timezone: "Etc/UTC", abbr: "UTC", std_off: 0, utc_off: 0, usec: 123400}}

      iex> rfc3339("1996-12-19T16:39:57-8:00", "America/Los_Angeles")
      {:ok, %Calendar.DateTime{abbr: "PST", day: 19, hour: 16, min: 39, month: 12, sec: 57, std_off: 0, timezone: "America/Los_Angeles", utc_off: -28800, year: 1996}}

      iex> rfc3339("invalid", "America/Los_Angeles")
      {:bad_format, nil}

      iex> rfc3339("1996-12-19T16:39:57-08:00", "invalid time zone name")
      {:invalid_time_zone, nil}
  """
  def rfc3339(rfc3339_string, "Etc/UTC") do
    rfc3339_utc(rfc3339_string)
  end
  def rfc3339(rfc3339_string, time_zone) do
    rfc3339_utc(rfc3339_string) |> do_parse_rfc3339_with_time_zone(time_zone)
  end
  defp do_parse_rfc3339_with_time_zone({utc_tag, _utc_dt}, _time_zone) when utc_tag != :ok do
    {utc_tag, nil}
  end
  defp do_parse_rfc3339_with_time_zone({_utc_tag, utc_dt}, time_zone) do
    utc_dt |> Calendar.DateTime.shift_zone(time_zone)
  end

  defp parse_rfc3339_as_utc_parsed_string(mapped, z, _offset_hours, _offset_mins) when z == "Z" or z=="z" do
    parse_rfc3339_as_utc_parsed_string(mapped, "", "00", "00")
  end
  defp parse_rfc3339_as_utc_parsed_string(mapped, _z, offset_hours, offset_mins) when offset_hours == "00" and offset_mins == "00" do
    Calendar.DateTime.from_erl(erl_date_time_from_regex_map(mapped), "Etc/UTC", parse_fraction(mapped["fraction"]))
  end
  defp parse_rfc3339_as_utc_parsed_string(mapped, _z, offset_hours, offset_mins) do
    offset_in_secs = hours_mins_to_secs!(offset_hours, offset_mins)
    offset_in_secs = case mapped["offset_sign"] do
      "-" -> offset_in_secs*-1
      _   -> offset_in_secs
    end
    erl_date_time = erl_date_time_from_regex_map(mapped)
    parse_rfc3339_as_utc_with_offset(offset_in_secs, erl_date_time)
  end

  defp parse_fraction(""), do: nil
  # parse and return microseconds
  defp parse_fraction(string), do: String.slice(string, 0..5) |> String.ljust(6, ?0) |> Integer.parse |> elem(0)

  defp parse_rfc3339_as_utc_with_offset(offset_in_secs, erl_date_time) do
    greg_secs = :calendar.datetime_to_gregorian_seconds(erl_date_time)
    new_time = greg_secs - offset_in_secs
    |> :calendar.gregorian_seconds_to_datetime
    Calendar.DateTime.from_erl(new_time, "Etc/UTC")
  end

  defp erl_date_time_from_regex_map(mapped) do
    erl_date_time_from_strings({{mapped["year"],mapped["month"],mapped["day"]},{mapped["hour"],mapped["min"],mapped["sec"]}})
  end

  defp erl_date_time_from_strings({{year, month, date},{hour, min, sec}}) do
    { {year|>to_int, month|>to_int, date|>to_int},
      {hour|>to_int, min|>to_int, sec|>to_int} }
  end

  defp parse_rfc3339_string(rfc3339_string) do
    ~r/(?<year>[\d]{4})[^\d]?(?<month>[\d]{2})[^\d]?(?<day>[\d]{2})[^\d](?<hour>[\d]{2})[^\d]?(?<min>[\d]{2})[^\d]?(?<sec>[\d]{2})(\.(?<fraction>[\d]+))?(?<z>[zZ])?((?<offset_sign>[\+\-])(?<offset_hours>[\d]{1,2}):?(?<offset_mins>[\d]{2}))?/
    |> Regex.named_captures(rfc3339_string)
  end
end
