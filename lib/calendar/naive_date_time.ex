defprotocol Calendar.ContainsNaiveDateTime do
  @doc """
  Returns a Calendar.NaiveDateTime struct for the provided data
  """
  def ndt_struct(data)
end

defmodule Calendar.NaiveDateTime do
  alias Calendar.DateTime
  alias Calendar.ContainsNaiveDateTime
  require Calendar.DateTime.Format

  @moduledoc """
  NaiveDateTime can represents a "naive time". That is a point in time without
  a specified time zone.
  """
  defstruct [:year, :month, :day, :hour, :min, :sec, :usec]

  @doc """
  Like from_erl/1 without "!", but returns the result directly without a tag.
  Will raise if date is invalid. Only use this if you are sure the date is valid.

  ## Examples

      iex> from_erl!({{2014, 9, 26}, {17, 10, 20}})
      %Calendar.NaiveDateTime{day: 26, hour: 17, min: 10, month: 9, sec: 20, year: 2014}

      iex from_erl!({{2014, 99, 99}, {17, 10, 20}})
      # this will throw a MatchError
  """
  def from_erl!(erl_date_time, usec \\ nil) do
    {:ok, result} = from_erl(erl_date_time, usec)
    result
  end

  @doc """
  Takes an Erlang-style date-time tuple.
  If the datetime is valid it returns a tuple with a tag and a naive DateTime.
  Naive in this context means that it does not have any timezone data.

  ## Examples

      iex>from_erl({{2014, 9, 26}, {17, 10, 20}})
      {:ok, %Calendar.NaiveDateTime{day: 26, hour: 17, min: 10, month: 9, sec: 20, year: 2014} }

      iex>from_erl({{2014, 9, 26}, {17, 10, 20}}, 321321)
      {:ok, %Calendar.NaiveDateTime{day: 26, hour: 17, min: 10, month: 9, sec: 20, year: 2014, usec: 321321} }

      iex>from_erl({{2014, 99, 99}, {17, 10, 20}})
      {:error, :invalid_datetime}
  """
  def from_erl({{year, month, day}, {hour, min, sec}}, usec \\ nil) do
    if validate_erl_datetime {{year, month, day}, {hour, min, sec}} do
      {:ok, %Calendar.NaiveDateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec, usec: usec}}
    else
      {:error, :invalid_datetime}
    end
  end

  defp validate_erl_datetime({date, _}) do
    :calendar.valid_date date
  end

  @doc """
  Takes a NaiveDateTime struct and returns an erlang style datetime tuple.

  ## Examples

      iex> from_erl!({{2014, 10, 15}, {2, 37, 22}}) |> to_erl
      {{2014, 10, 15}, {2, 37, 22}}
  """
  def to_erl(%Calendar.NaiveDateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec}) do
    {{year, month, day}, {hour, min, sec}}
  end

  @doc """
  Takes a NaiveDateTime struct and returns an Ecto style datetime tuple. This is
  like an erlang style tuple, but with microseconds added as an additional
  element in the time part of the tuple.

  If the datetime has its usec field set to nil, 0 will be used for usec.

  ## Examples

      iex> from_erl!({{2014,10,15},{2,37,22}}, 999999) |> Calendar.NaiveDateTime.to_micro_erl
      {{2014, 10, 15}, {2, 37, 22, 999999}}

      iex> from_erl!({{2014,10,15},{2,37,22}}, nil) |> Calendar.NaiveDateTime.to_micro_erl
      {{2014, 10, 15}, {2, 37, 22, 0}}
  """
  def to_micro_erl(%Calendar.NaiveDateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec, usec: nil}) do
    {{year, month, day}, {hour, min, sec, 0}}
  end
  def to_micro_erl(%Calendar.NaiveDateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec, usec: usec}) do
    {{year, month, day}, {hour, min, sec, usec}}
  end

  @doc """
  Takes a NaiveDateTime struct and returns a Date struct representing the date part
  of the provided NaiveDateTime.

      iex> from_erl!({{2014,10,15},{2,37,22}}) |> Calendar.NaiveDateTime.to_date
      %Calendar.Date{day: 15, month: 10, year: 2014}
  """
  def to_date(ndt) do
    ndt = ndt |> contained_ndt
    %Calendar.Date{year: ndt.year, month: ndt.month, day: ndt.day}
  end

  @doc """
  Takes a NaiveDateTime struct and returns a Time struct representing the time part
  of the provided NaiveDateTime.

      iex> from_erl!({{2014,10,15},{2,37,22}}) |> Calendar.NaiveDateTime.to_time
      %Calendar.Time{usec: nil, hour: 2, min: 37, sec: 22}
  """
  def to_time(ndt) do
    ndt = ndt |> contained_ndt
    %Calendar.Time{hour: ndt.hour, min: ndt.min, sec: ndt.sec, usec: ndt.usec}
  end

  @doc """
  For turning NaiveDateTime structs to into a DateTime.

  Takes a NaiveDateTime and a timezone name. If timezone is valid, returns a tuple with an :ok and DateTime.

      iex> from_erl!({{2014,10,15},{2,37,22}}) |> Calendar.NaiveDateTime.to_date_time("UTC")
      {:ok, %Calendar.DateTime{abbr: "UTC", day: 15, usec: nil, hour: 2, min: 37, month: 10, sec: 22, std_off: 0, timezone: "UTC", utc_off: 0, year: 2014}}
  """
  def to_date_time(ndt, timezone) do
    ndt = ndt |> contained_ndt
    DateTime.from_erl(to_erl(ndt), timezone)
  end

  @doc """
  Promote to DateTime with UTC time zone. Should only be used if you
  are sure that the provided argument is in UTC.

  Takes a NaiveDateTime. Returns a DateTime.

      iex> from_erl!({{2014,10,15},{2,37,22}}) |> Calendar.NaiveDateTime.to_date_time_utc
      %Calendar.DateTime{abbr: "UTC", day: 15, usec: nil, hour: 2, min: 37, month: 10, sec: 22, std_off: 0, timezone: "Etc/UTC", utc_off: 0, year: 2014}
  """
  def to_date_time_utc(ndt) do
    ndt = ndt |> contained_ndt
    {:ok, dt} = to_date_time(ndt, "Etc/UTC")
    dt
  end

  @doc """
  If you have a naive datetime and you know the offset, promote it to a
  UTC DateTime.

  ## Examples

      # A naive datetime at 2:37:22 with a 3600 second offset will return
      # a UTC DateTime with the same date, but at 1:37:22
      iex> with_offset_to_datetime_utc {{2014,10,15},{2,37,22}}, 3600
      {:ok, %Calendar.DateTime{abbr: "UTC", day: 15, usec: nil, hour: 1, min: 37, month: 10, sec: 22, std_off: 0, timezone: "Etc/UTC", utc_off: 0, year: 2014} }
      iex> with_offset_to_datetime_utc{{2014,10,15},{2,37,22}}, 999_999_999_999_999_999_999_999_999
      {:error, nil}
  """
  def with_offset_to_datetime_utc(ndt, total_utc_offset) do
    ndt = ndt |> contained_ndt
    {tag, advanced_ndt} = ndt |> advance(total_utc_offset*-1)
    case tag do
      :ok -> to_date_time(advanced_ndt, "Etc/UTC")
      _ -> {:error, nil}
    end
  end

  @doc """
  Takes a NaiveDateTime and an integer.
  Returns the `naive_date_time` advanced by the number
  of seconds found in the `seconds` argument.

  If `seconds` is negative, the time is moved back.

  ## Examples

      # Advance 2 seconds
      iex> from_erl!({{2014,10,2},{0,29,10}}, 123456) |> advance(2)
      {:ok, %Calendar.NaiveDateTime{day: 2, hour: 0, min: 29, month: 10,
            sec: 12, usec: 123456,
            year: 2014}}
  """
  def advance(ndt, seconds) do
    try do
      ndt = ndt |> contained_ndt
      greg_secs = ndt |> gregorian_seconds
      advanced = greg_secs + seconds
      |>from_gregorian_seconds!(ndt.usec)
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

  ## Examples

      # Advance 2 seconds
      iex> from_erl!({{2014,10,2},{0,29,10}}, 123456) |> advance!(2)
      %Calendar.NaiveDateTime{day: 2, hour: 0, min: 29, month: 10,
            sec: 12, usec: 123456,
            year: 2014}
  """
  def advance!(ndt, seconds) do
    ndt = ndt |> contained_ndt
    {:ok, result} = advance(ndt, seconds)
    result
  end

  @doc """
  Takes a NaiveDateTime and returns an integer of gregorian seconds starting with
  year 0. This is done via the Erlang calendar module.

  ## Examples

      iex> from_erl!({{2014,9,26},{17,10,20}}) |> gregorian_seconds
      63578970620
  """
  def gregorian_seconds(ndt) do
    ndt
    |> contained_ndt
    |> to_erl
    |> :calendar.datetime_to_gregorian_seconds
  end

  defp from_gregorian_seconds!(gregorian_seconds, usec) do
    gregorian_seconds
    |>:calendar.gregorian_seconds_to_datetime
    |>from_erl!(usec)
  end

  @doc """
  Like DateTime.Format.strftime! but for NaiveDateTime.

  Refer to documentation for DateTime.Format.strftime!

      iex> from_erl!({{2014,10,15},{2,37,22}}) |> strftime! "%Y %h %d"
      "2014 Oct 15"
  """
  def strftime!(ndt, string, lang \\ :en) do
    ndt
    |> contained_ndt
    |> to_date_time_utc
    |> Calendar.DateTime.Format.strftime! string, lang
  end

  defp contained_ndt(ndt_container) do
    ContainsNaiveDateTime.ndt_struct(ndt_container)
  end
end

defimpl Calendar.ContainsNaiveDateTime, for: Calendar.NaiveDateTime do
  def ndt_struct(data), do: data
end

defimpl Calendar.ContainsNaiveDateTime, for: Calendar.DateTime do
  def ndt_struct(data), do: data |> Calendar.DateTime.to_naive
end

defimpl Calendar.ContainsNaiveDateTime, for: Tuple do
  def ndt_struct({{year, month, day}, {hour, min, sec}}) do
    Calendar.NaiveDateTime.from_erl!({{year, month, day}, {hour, min, sec}})
  end
end
