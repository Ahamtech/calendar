defmodule Calendar.DateTime do
  @moduledoc """
  DateTime provides a struct which represents a certain time and date in a
  certain time zone.

  The functions in this module can be used to create and transform
  DateTime structs.
  """
  alias Calendar.TimeZoneData
  require Calendar.Date
  require Calendar.Time

  defstruct [:year, :month, :day, :hour, :min, :sec, :usec, :timezone, :abbr, :utc_off, :std_off]

  @doc """
  Like DateTime.now!("Etc/UTC")
  """
  def now_utc do
    erl_timestamp = :os.timestamp
    {_, _, usec} = erl_timestamp
    erl_timestamp
    |> :calendar.now_to_datetime
    |> from_erl!("Etc/UTC", "UTC", 0, 0, usec)
  end

  @doc """
  Takes a timezone name a returns a DateTime with the current time in
  that timezone. Timezone names must be in the TZ data format.

  ## Examples

      iex > DateTime.now! "UTC"
      %Calendar.DateTime{abbr: "UTC", day: 15, hour: 2,
       min: 39, month: 10, sec: 53, std_off: 0, timezone: "UTC", utc_off: 0,
       year: 2014}

      iex > DateTime.now! "Europe/Copenhagen"
      %Calendar.DateTime{abbr: "CEST", day: 15, hour: 4,
       min: 41, month: 10, sec: 1, std_off: 3600, timezone: "Europe/Copenhagen",
       utc_off: 3600, year: 2014}
  """
  def now!("Etc/UTC"), do: now_utc
  def now!(timezone) do
    {now_utc_secs, usec} = now_utc |> gregorian_seconds_and_usec
    period_list = TimeZoneData.periods_for_time(timezone, now_utc_secs, :utc)
    period = hd period_list
    now_utc_secs + period.utc_off + period.std_off
    |>from_gregorian_seconds!(timezone, period.zone_abbr, period.utc_off, period.std_off, usec)
  end

  @doc """
  Like now/1 without a bang. Deprecated version of now!/1
  """
  def now(timezone) do
    IO.puts :stderr, "Warning: now/1 is deprecated. Use now!/1 instead (with a !) " <>
                     "In the future now/1 will return a tuple with {:ok, [DateTime]}\n" <> Exception.format_stacktrace()
    now!(timezone)
  end

  @doc """
  Like shift_zone without "!", but does not check that the time zone is valid
  and just returns a DateTime struct instead of a tuple with a tag.

  ## Example

      iex> from_erl!({{2014,10,2},{0,29,10}},"America/New_York") |> shift_zone! "Europe/Copenhagen"
      %Calendar.DateTime{abbr: "CEST", day: 2, hour: 6, min: 29, month: 10, sec: 10,
                        timezone: "Europe/Copenhagen", utc_off: 3600, std_off: 3600, year: 2014}

  """
  # In case we are shifting a leap second, shift the second before and then
  # correct the second back to 60. This is to avoid problems with the erlang
  # gregorian second system (lack of) handling of leap seconds.
  def shift_zone!(%Calendar.DateTime{sec: 60} = date_time, timezone) do
    second_before = %Calendar.DateTime{date_time | sec: 59}
    |> shift_zone!(timezone)
    %Calendar.DateTime{second_before | sec: 60}
  end
  def shift_zone!(date_time, timezone) do
    date_time
    |>shift_to_utc
    |>shift_from_utc(timezone)
  end

  @doc """
  Takes a DateTime and an integer. Returns the `date_time` advanced by the number
  of seconds found in the `seconds` argument.

  If `seconds` is negative, the time is moved back.

  The advancement is done in UTC. The datetime is converted to UTC, then
  advanced, then converted back.

  NOTE: this ignores leap seconds. The calculation is based on the (wrong) assumption that
  there are no leap seconds.

  ## Examples

      # Advance 2 seconds
      iex> from_erl!({{2014,10,2},{0,29,10}}, "America/New_York",123456) |> advance(2)
      {:ok, %Calendar.DateTime{abbr: "EDT", day: 2, hour: 0, min: 29, month: 10,
            sec: 12, std_off: 3600, timezone: "America/New_York", usec: 123456,
            utc_off: -18000, year: 2014}}

      # Advance 86400 seconds (one day)
      iex> from_erl!({{2014,10,2},{0,29,10}}, "America/New_York",123456) |> advance(86400)
      {:ok, %Calendar.DateTime{abbr: "EDT", day: 3, hour: 0, min: 29, month: 10,
            sec: 10, std_off: 3600, timezone: "America/New_York", usec: 123456,
            utc_off: -18000, year: 2014}}

      # Go back 62 seconds
      iex> from_erl!({{2014,10,2},{0,0,0}}, "America/New_York",123456) |> advance(-62)
      {:ok, %Calendar.DateTime{abbr: "EDT", day: 1, hour: 23, min: 58, month: 10,
            sec: 58, std_off: 3600, timezone: "America/New_York", usec: 123456, utc_off: -18000,
            year: 2014}}

      # Advance 10 seconds just before DST "spring forward" so we go from 1:59:59 to 3:00:09
      iex> from_erl!({{2015,3,8},{1,59,59}}, "America/New_York",123456) |> advance(10)
      {:ok, %Calendar.DateTime{abbr: "EDT", day: 8, hour: 3, min: 0, month: 3,
            sec: 9, std_off: 3600, timezone: "America/New_York", usec: 123456,
            utc_off: -18000, year: 2015}}

      # Go back too far so that year would be before 0
      iex> from_erl!({{2014,10,2},{0,0,0}}, "America/New_York",123456) |> advance(-999999999999)
      {:error, :function_clause_error}
  """
  def advance(%Calendar.DateTime{} = date_time, seconds) do
    try do
      in_utc = date_time |> shift_zone!("Etc/UTC")
      greg_secs = in_utc |> gregorian_seconds
      advanced = greg_secs + seconds
      |>from_gregorian_seconds!("Etc/UTC", "UTC", 0, 0, date_time.usec)
      |>shift_zone!(date_time.timezone)
      {:ok, advanced}
    rescue
      e in FunctionClauseError -> e
      {:error, :function_clause_error}
    end
  end

  @doc """
  Like `advance` without exclamation points.
  Instead of returning a tuple with :ok and the result,
  the result is returned untagged. Will raise an error in case
  no correct result can be found based on the arguments.
  """
  def advance!(date_time, seconds) do
    {:ok, result} = advance(date_time, seconds)
    result
  end

  @doc """
  The difference between two DateTime structs. In seconds and microseconds.

  Leap seconds are ignored.

  Returns tuple with {:ok, seconds, microseconds}

  ## Examples

      # March 30th 2014 02:00:00 in Central Europe the time changed from
      # winter time to summer time. This means that clocks were set forward
      # and an hour skipped. So between 01:00 and 4:00 there were 2 hours
      # not 3. Two hours is 7200 seconds.
      iex> diff(from_erl!({{2014,3,30},{4,0,0}}, "Europe/Stockholm"), from_erl!({{2014,3,30},{1,0,0}}, "Europe/Stockholm"))
      {:ok, 7200, 0}

      # The first DateTime is 40 seconds after the second DateTime
      iex> diff(from_erl!({{2014,10,2},{0,29,50}}, "Etc/UTC"), from_erl!({{2014,10,2},{0,29,10}}, "Etc/UTC"))
      {:ok, 40, 0}

      # The first DateTime is 40 seconds before the second DateTime
      iex> diff(from_erl!({{2014,10,2},{0,29,10}}, "Etc/UTC"), from_erl!({{2014,10,2},{0,29,50}}, "Etc/UTC"))
      {:ok, -40, 0}

      # The first DateTime is 30 microseconds after the second DateTime
      iex> diff(from_erl!({{2014,10,2},{0,29,0}}, "Etc/UTC", 31), from_erl!({{2014,10,2},{0,29,0}}, "Etc/UTC", 1))
      {:ok, 0, 30}

      # The first DateTime is 2 microseconds after the second DateTime
      iex> diff(from_erl!({{2014,10,2},{0,29,0}}, "Etc/UTC", 0), from_erl!({{2014,10,2},{0,29,0}}, "Etc/UTC", 2))
      {:ok, 0, -2}

      # The first DateTime is 9.999998 seconds after the second DateTime
      iex> diff(from_erl!({{2014,10,2},{0,29,10}}, "Etc/UTC", 0), from_erl!({{2014,10,2},{0,29,0}}, "Etc/UTC", 2))
      {:ok, 9, 999998}

      # The first DateTime is 9.999998 seconds before the second DateTime
      iex> diff(from_erl!({{2014,10,2},{0,29,0}}, "Etc/UTC", 2), from_erl!({{2014,10,2},{0,29,10}}, "Etc/UTC", 0))
      {:ok, -9, 999998}

      iex> diff(from_erl!({{2014,10,2},{0,29,0}}, "Etc/UTC", 0), from_erl!({{2014,10,2},{0,29,10}}, "Etc/UTC", 2))
      {:ok, -10, 2}

      iex> diff(from_erl!({{2014,10,2},{0,29,1}}, "Etc/UTC", 100), from_erl!({{2014,10,2},{0,29,0}}, "Etc/UTC", 200))
      {:ok, 0, 999900}

      iex> diff(from_erl!({{2014,10,2},{0,29,0}}, "Etc/UTC", 10), from_erl!({{2014,10,2},{0,29,0}}, "Etc/UTC", 999999))
      {:ok, 0, -999989}
  """
  # If any datetime usec is nil, set it to 0
  def diff(%Calendar.DateTime{usec: nil} = first_dt, %Calendar.DateTime{usec: nil} = second_dt) do
    diff(Map.put(first_dt, :usec, 0), Map.put(second_dt, :usec, 0))
  end
  def diff(%Calendar.DateTime{usec: nil} = first_dt, %Calendar.DateTime{} = second_dt) do
    diff(Map.put(first_dt, :usec, 0), second_dt)
  end
  def diff(%Calendar.DateTime{} = first_dt, %Calendar.DateTime{usec: nil} = second_dt) do
    diff(first_dt, Map.put(second_dt, :usec, 0))
  end

  def diff(%Calendar.DateTime{usec: 0} = first_dt, %Calendar.DateTime{usec: 0} = second_dt) do
    first_utc = first_dt |> shift_to_utc |> gregorian_seconds
    second_utc = second_dt |> shift_to_utc |> gregorian_seconds
    {:ok, first_utc - second_utc, 0}
  end
  def diff(%Calendar.DateTime{usec: first_usec} = first_dt, %Calendar.DateTime{usec: second_usec} = second_dt) do
    {:ok, sec, 0} = diff(Map.put(first_dt, :usec, 0), Map.put(second_dt, :usec, 0))
    usec = first_usec - second_usec
    diff_sort_out_decimal {:ok, sec, usec}
  end

  defp diff_sort_out_decimal({:ok, sec, usec}) when sec > 0 and usec < 0 do
    sec = sec - 1
    usec = 1_000_000 + usec
    {:ok, sec, usec}
  end
  defp diff_sort_out_decimal({:ok, sec, usec}) when sec < 0 and usec > 0 do
    sec = sec + 1
    usec = 1_000_000 - usec
    {:ok, sec, usec}
  end
  defp diff_sort_out_decimal({:ok, sec, usec}) when sec < 0 and usec < 0 do
    {:ok, sec, abs(usec)}
  end
  defp diff_sort_out_decimal({:ok, sec, usec}), do: {:ok, sec, usec}

  @doc """
  Takes a DateTime and the name of a new timezone.
  Returns a DateTime with the equivalent time in the new timezone.

  ## Examples

      iex> from_erl!({{2014,10,2},{0,29,10}}, "America/New_York",123456) |> shift_zone("Europe/Copenhagen")
      {:ok, %Calendar.DateTime{abbr: "CEST", day: 2, hour: 6, min: 29, month: 10, sec: 10, timezone: "Europe/Copenhagen", utc_off: 3600, std_off: 3600, year: 2014, usec: 123456}}

      iex> {:ok, nyc} = from_erl {{2014,10,2},{0,29,10}},"America/New_York"; shift_zone(nyc, "Invalid timezone")
      {:invalid_time_zone, nil}
  """
  def shift_zone(date_time, timezone) do
    if TimeZoneData.zone_exists?(timezone) do
      {:ok, shift_zone!(date_time, timezone)}
    else
      {:invalid_time_zone, nil}
    end
  end

  defp shift_to_utc(%Calendar.DateTime{timezone: "Etc/UTC"} = dt), do: dt
  defp shift_to_utc(date_time) do
    greg_secs = :calendar.datetime_to_gregorian_seconds(date_time|>to_erl)
    period_list = TimeZoneData.periods_for_time(date_time.timezone, greg_secs, :wall)
    period = period_by_offset(period_list, date_time.utc_off, date_time.std_off)
    greg_secs-period.utc_off-period.std_off
    |>from_gregorian_seconds!("Etc/UTC", "UTC", 0, 0, date_time.usec)
  end

  # When we have a list of 2 periods, return the one where UTC offset
  # and standard offset matches. The is used for instance during ambigous
  # wall time in the fall when switching back from summer time to standard
  # time.
  # If there is just one period, just return the only period in the list
  defp period_by_offset(period_list, _utc_off, _std_off) when length(period_list) == 1 do
    hd(period_list)
  end
  defp period_by_offset(period_list, utc_off, std_off) do
    matching = period_list |> Enum.filter(&(&1.utc_off == utc_off && &1.std_off == std_off))
    hd(matching)
  end

  defp shift_from_utc(utc_date_time, to_timezone) do
    greg_secs = :calendar.datetime_to_gregorian_seconds(utc_date_time|>to_erl)
    period_list = TimeZoneData.periods_for_time(to_timezone, greg_secs, :utc)
    period = period_list|>hd
    greg_secs+period.utc_off+period.std_off
    |>from_gregorian_seconds!(to_timezone, period.zone_abbr, period.utc_off, period.std_off, utc_date_time.usec)
  end

  # Takes gregorian seconds and and optional timezone.
  # Returns a DateTime.

  # ## Examples
  #   iex> from_gregorian_seconds!(63578970620)
  #   %Calendar.DateTime{date: 26, hour: 17, min: 10, month: 9, sec: 20, timezone: nil, year: 2014}
  #   iex> from_gregorian_seconds!(63578970620, "America/Montevideo")
  #   %Calendar.DateTime{date: 26, hour: 17, min: 10, month: 9, sec: 20, timezone: "America/Montevideo", year: 2014}
  defp from_gregorian_seconds!(gregorian_seconds, timezone, abbr, utc_off, std_off, usec) do
    gregorian_seconds
    |>:calendar.gregorian_seconds_to_datetime
    |>from_erl!(timezone, abbr, utc_off, std_off, usec)
  end

  @doc """
  Like from_erl/2 without "!", but returns the result directly without a tag.
  Will raise if date is ambiguous or invalid! Only use this if you are sure
  the date is valid. Otherwise use "from_erl" without the "!".

  Example:

      iex> from_erl!({{2014, 9, 26}, {17, 10, 20}}, "America/Montevideo")
      %Calendar.DateTime{day: 26, hour: 17, min: 10, month: 9, sec: 20, year: 2014, timezone: "America/Montevideo", abbr: "UYT", utc_off: -10800, std_off: 0}
  """
  def from_erl!(date_time, time_zone, usec \\ nil) do
    {:ok, result} = from_erl(date_time, time_zone, usec)
    result
  end

  @doc """
  Takes an Erlang-style date-time tuple and additionally a timezone name.
  Returns a tuple with a tag and a DateTime struct.

  The tag can be :ok, :ambiguous or :error. :ok is for an unambigous time.
  :ambiguous is for a time that could have different UTC offsets and/or
  standard offsets. Usually when switching from summer to winter time.

  An erlang style date-time tuple has the following format:
  {{year, month, day}, {hour, minute, second}}

  ## Examples

    Normal, non-ambigous time

      iex> from_erl({{2014, 9, 26}, {17, 10, 20}}, "America/Montevideo")
      {:ok, %Calendar.DateTime{day: 26, hour: 17, min: 10, month: 9, sec: 20,
                              year: 2014, timezone: "America/Montevideo",
                              abbr: "UYT",
                              utc_off: -10800, std_off: 0, usec: nil} }

    Switching from summer to wintertime in the fall means an ambigous time.

      iex> from_erl({{2014, 3, 9}, {1, 1, 1}}, "America/Montevideo")
      {:ambiguous, %Calendar.AmbiguousDateTime{possible_date_times:
        [%Calendar.DateTime{day: 9, hour: 1, min: 1, month: 3, sec: 1,
                           year: 2014, timezone: "America/Montevideo",
                           abbr: "UYST", utc_off: -10800, std_off: 3600},
         %Calendar.DateTime{day: 9, hour: 1, min: 1, month: 3, sec: 1,
                           year: 2014, timezone: "America/Montevideo",
                           abbr: "UYT", utc_off: -10800, std_off: 0},
        ]}
      }

      iex> from_erl({{2014, 9, 26}, {17, 10, 20}}, "Non-existing timezone")
      {:error, :timezone_not_found}

    The time between 2:00 and 3:00 in the following example does not exist
    because of the one hour gap caused by switching to DST.

      iex> from_erl({{2014, 3, 30}, {2, 20, 02}}, "Europe/Copenhagen")
      {:error, :invalid_datetime_for_timezone}

    Time with fractional seconds. This represents the time 17:10:20.987654321

      iex> from_erl({{2014, 9, 26}, {17, 10, 20}}, "America/Montevideo", 987654)
      {:ok, %Calendar.DateTime{day: 26, hour: 17, min: 10, month: 9, sec: 20,
                              year: 2014, timezone: "America/Montevideo",
                              abbr: "UYT",
                              utc_off: -10800, std_off: 0, usec: 987654} }

  """
  def from_erl(date_time, timezone, usec \\ nil) do
    validity = validate_erl_datetime(date_time, timezone)
    from_erl_validity(date_time, timezone, validity, usec)
  end

  # Date, time and timezone. Date and time is valid.
  defp from_erl_validity(datetime, timezone, true, usec) do
    # validate that timezone exists
    from_erl_timezone_validity(datetime, timezone, TimeZoneData.zone_exists?(timezone), usec)
  end
  defp from_erl_validity(_, _, false, _) do
    {:error, :invalid_datetime}
  end

  defp from_erl_timezone_validity(_, _, false, _), do: {:error, :timezone_not_found}

  defp from_erl_timezone_validity({date, time}, timezone, true, usec) do
    # get periods for time
    greg_secs = :calendar.datetime_to_gregorian_seconds({date, time})
    periods = TimeZoneData.periods_for_time(timezone, greg_secs, :wall)
    from_erl_periods({date, time}, timezone, periods, usec)
  end

  defp from_erl_periods(_, _, periods, _) when periods == [] do
    {:error, :invalid_datetime_for_timezone}
  end
  defp from_erl_periods({{year, month, day}, {hour, min, sec}}, timezone, periods, usec) when length(periods) == 1 do
    period = periods |> hd
    {:ok, %Calendar.DateTime{year: year, month: month, day: day, hour: hour,
         min: min, sec: sec, timezone: timezone, abbr: period.zone_abbr,
         utc_off: period.utc_off, std_off: period.std_off, usec: usec } }
  end
  # When a time is ambigous (for instance switching from summer- to winter-time)
  defp from_erl_periods({{year, month, day}, {hour, min, sec}}, timezone, periods, usec) when length(periods) == 2 do
    possible_date_times =
    Enum.map(periods, fn period ->
           %Calendar.DateTime{year: year, month: month, day: day, hour: hour,
           min: min, sec: sec, timezone: timezone, abbr: period.zone_abbr,
           utc_off: period.utc_off, std_off: period.std_off, usec: usec }
       end )
    # sort by abbreviation
    |> Enum.sort(fn dt1, dt2 -> dt1.abbr <= dt2.abbr end)

    {:ambiguous, %Calendar.AmbiguousDateTime{ possible_date_times: possible_date_times} }
  end

  defp from_erl!({{year, month, day}, {hour, min, sec}}, timezone, abbr, utc_off, std_off, usec) do
    %Calendar.DateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec, timezone: timezone, abbr: abbr, utc_off: utc_off, std_off: std_off, usec: usec}
  end

  @doc """
  Like from_erl, but also takes an argument with the total UTC offset.
  (Total offset is standard offset + UTC offset)

  The result will be the same as from_erl, except if the datetime is ambiguous.
  When the datetime is ambiguous (for instance during change from DST to
  non-DST) the total_offset argument is use to try to disambiguise the result.
  If successful the matching result is returned tagged with `:ok`. If the
  `total_offset` argument does not match either, an error will be returned.

  ## Examples:

      iex> from_erl_total_off({{2014, 9, 26}, {17, 10, 20}}, "America/Montevideo", -10800, 2)
      {:ok, %Calendar.DateTime{day: 26, hour: 17, min: 10, month: 9, sec: 20,
                              year: 2014, timezone: "America/Montevideo",
                              abbr: "UYT",
                              utc_off: -10800, std_off: 0, usec: 2} }

      iex> from_erl_total_off({{2014, 3, 9}, {1, 1, 1}}, "America/Montevideo", -7200, 2)
      {:ok, %Calendar.DateTime{day: 9, hour: 1, min: 1, month: 3, sec: 1,
                    year: 2014, timezone: "America/Montevideo", usec: 2,
                           abbr: "UYST", utc_off: -10800, std_off: 3600}
      }
  """
  def from_erl_total_off(erl_dt, timezone, total_off, usec\\nil) do
    h_from_erl_total_off(from_erl(erl_dt, timezone, usec), total_off)
  end

  defp h_from_erl_total_off({:ok, result}, _total_off), do: {:ok, result}
  defp h_from_erl_total_off({:error, result}, _total_off), do: {:error, result}
  defp h_from_erl_total_off({:ambiguous, result}, total_off) do
    result |> Calendar.AmbiguousDateTime.disamb_total_off(total_off)
  end

  @doc """
  Like `from_erl_total_off/4` but takes a 7 element datetime tuple with
  microseconds instead of a "normal" erlang style tuple.

  ## Examples:

      iex> from_micro_erl_total_off({{2014, 3, 9}, {1, 1, 1, 2}}, "America/Montevideo", -7200)
      {:ok, %Calendar.DateTime{day: 9, hour: 1, min: 1, month: 3, sec: 1,
                    year: 2014, timezone: "America/Montevideo", usec: 2,
                           abbr: "UYST", utc_off: -10800, std_off: 3600}
      }
  """
  def from_micro_erl_total_off({{year, mon, day}, {hour, min, sec, usec}}, timezone, total_off) do
    from_erl_total_off({{year, mon, day}, {hour, min, sec}}, timezone, total_off, usec)
  end

  @doc """
  Takes a DateTime struct and returns an erlang style datetime tuple.

  ## Examples

      iex> from_erl!({{2014,10,15},{2,37,22}}, "Etc/UTC") |> Calendar.DateTime.to_erl
      {{2014, 10, 15}, {2, 37, 22}}
  """
  def to_erl(%Calendar.DateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec}) do
    {{year, month, day}, {hour, min, sec}}
  end

  @doc """
  Takes a DateTime struct and returns an Ecto style datetime tuple. This is
  like an erlang style tuple, but with microseconds added as an additional
  element in the time part of the tuple.

  If the datetime has its usec field set to nil, 0 will be used for usec.

  ## Examples

      iex> from_erl!({{2014,10,15},{2,37,22}}, "Etc/UTC", 999999) |> Calendar.DateTime.to_micro_erl
      {{2014, 10, 15}, {2, 37, 22, 999999}}

      iex> from_erl!({{2014,10,15},{2,37,22}}, "Etc/UTC", nil) |> Calendar.DateTime.to_micro_erl
      {{2014, 10, 15}, {2, 37, 22, 0}}
  """
  def to_micro_erl(%Calendar.DateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec, usec: nil}) do
    {{year, month, day}, {hour, min, sec, 0}}
  end
  def to_micro_erl(%Calendar.DateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec, usec: usec}) do
    {{year, month, day}, {hour, min, sec, usec}}
  end

  @doc """
  Takes a DateTime struct and returns a Date struct representing the date part
  of the provided DateTime.

      iex> from_erl!({{2014,10,15},{2,37,22}}, "UTC") |> Calendar.DateTime.to_date
      %Calendar.Date{day: 15, month: 10, year: 2014}
  """
  def to_date(dt) do
    %Calendar.Date{year: dt.year, month: dt.month, day: dt.day}
  end

  @doc """
  Takes a DateTime struct and returns a Time struct representing the time part
  of the provided DateTime.

      iex> from_erl!({{2014,10,15},{2,37,22}}, "UTC") |> Calendar.DateTime.to_time
      %Calendar.Time{usec: nil, hour: 2, min: 37, sec: 22}
  """
  def to_time(dt) do
    %Calendar.Time{hour: dt.hour, min: dt.min, sec: dt.sec, usec: dt.usec}
  end

  @doc """
  Returns a tuple with a Date struct and a Time struct.

      iex> from_erl!({{2014,10,15},{2,37,22}}, "UTC") |> Calendar.DateTime.to_date_and_time
      {%Calendar.Date{day: 15, month: 10, year: 2014}, %Calendar.Time{usec: nil, hour: 2, min: 37, sec: 22}}
  """
  def to_date_and_time(dt) do
    {to_date(dt), to_time(dt)}
  end

  @doc """
  Takes an NaiveDateTime and a time zone identifier and returns a DateTime

      iex> Calendar.NaiveDateTime.from_erl!({{2014,10,15},{2,37,22}}) |> from_naive "UTC"
      {:ok, %Calendar.DateTime{abbr: "UTC", day: 15, usec: nil, hour: 2, min: 37, month: 10, sec: 22, std_off: 0, timezone: "UTC", utc_off: 0, year: 2014}}
  """
  def from_naive(ndt, timezone) do
    ndt |> Calendar.NaiveDateTime.to_erl
    |> from_erl(timezone)
  end

  @doc """
  Takes a DateTime and returns a NaiveDateTime

      iex> Calendar.DateTime.from_erl!({{2014,10,15},{2,37,22}}, "UTC", 0.55) |> to_naive
      %Calendar.NaiveDateTime{day: 15, usec: 0.55, hour: 2, min: 37, month: 10, sec: 22, year: 2014}
  """
  def to_naive(dt) do
    dt |> to_erl
    |> Calendar.NaiveDateTime.from_erl!(dt.usec)
  end

  @doc """
  Takes a DateTime and returns an integer of gregorian seconds starting with
  year 0. This is done via the Erlang calendar module.

  ## Examples

      iex> from_erl!({{2014,9,26},{17,10,20}}, "UTC") |> gregorian_seconds
      63578970620
  """
  def gregorian_seconds(date_time) do
    :calendar.datetime_to_gregorian_seconds(date_time|>to_erl)
  end

  def gregorian_seconds_and_usec(date_time) do
    usec = date_time.usec
    {gregorian_seconds(date_time), usec}
  end

  defp validate_erl_datetime({date, time}, timezone) do
    :calendar.valid_date(date) && valid_time_part_of_datetime(date, time, timezone)
  end
  # Validate time part of a datetime
  # The date and timezone part is only used for leap seconds
  defp valid_time_part_of_datetime(date, {h, m, 60}, "Etc/UTC") do
    if TimeZoneData.leap_seconds_erl |> Enum.member?({date, {h, m, 60}}) do
      true
    else
      false
    end
  end
  defp valid_time_part_of_datetime(date, {h, m, 60}, timezone) do
    {tag, utc_datetime} = from_erl({date, {h, m, 59}}, timezone)
    if tag != :ok do
      false
    else
      {date_utc, {h, m, s}} = utc_datetime
        |> shift_zone!("Etc/UTC")
        |> to_erl
      valid_time_part_of_datetime(date_utc, {h, m, s+1}, "Etc/UTC")
    end
  end
  defp valid_time_part_of_datetime(_date, {h, m, s}, _timezone) when h>=0 and h<=23 and m>=0 and m<=59 and s>=0 and s<=60 do
    true
  end
  defp valid_time_part_of_datetime(_, _, _) do
    false
  end
end
