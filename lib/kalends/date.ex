defmodule Kalends.Date do
  alias Kalends.DateTime
  alias Kalends.NaiveDateTime

  @moduledoc """
  The Date module provides a struct to represent a simple date: year, month and day.
  """

  defstruct [:year, :month, :day]

  @doc """
  Takes a Date struct and returns an erlang style date tuple.
  """
  def to_erl(%Kalends.Date{year: year, month: month, day: day}) do
    {year, month, day}
  end

  @doc """
  Takes a erlang style date tuple and returns a tuple with an :ok tag and a
  Date struct. If the provided date is invalid, it will not be tagged with :ok
  though as shown below:

      iex> from_erl({2014,12,27})
      {:ok, %Kalends.Date{day: 27, month: 12, year: 2014}}

      iex> from_erl({2014,99,99})
      {:error, :invalid_date}
  """
  def from_erl({year, month, day}) do
    if :calendar.valid_date({year, month, day}) do
      {:ok, %Kalends.Date{year: year, month: month, day: day}}
    else
      {:error, :invalid_date}
    end
  end

  @doc """
  Like from_erl without the exclamation point, but does not return a tuple
  with a tag. Instead returns just a Date if valid. Or raises an exception if
  the provided date is invalid.

      iex> from_erl! {2014,12,27}
      %Kalends.Date{day: 27, month: 12, year: 2014}
  """
  def from_erl!(erl_date) do
    {:ok, date} = from_erl(erl_date)
    date
  end

  @doc """
  Takes a Date struct and returns the number of days in the month of that date.
  The day of the date provided does not matter - the result is based on the
  month and the year.

      iex> from_erl!({2014,12,27}) |> number_of_days_in_month
      31
      iex> from_erl!({2015,2,27}) |> number_of_days_in_month
      28
      iex> from_erl!({2012,2,27}) |> number_of_days_in_month
      29
  """
  def number_of_days_in_month(date) do
    {year, month, _} = date |> to_erl
    :calendar.last_day_of_the_month(year, month)
  end

  @doc """
  Takes a Date struct and returns a tuple with the ISO week number
  and the year that the week belongs to.
  Note that the year returned does not always match the year provided.

      iex> from_erl!({2014,12,31}) |> week_number
      {2015, 1}
      iex> from_erl!({2014,12,27}) |> week_number
      {2014, 52}
  """
  def week_number(date) do
    :calendar.iso_week_number(date|>to_erl)
  end

  @doc """
  Takes a Date struct and returns the number of gregorian days since year 0.

      iex> from_erl!({2014,12,27}) |> to_gregorian_days
      735959
  """
  def to_gregorian_days(date) do
    :calendar.date_to_gregorian_days(date.year, date.month, date.day)
  end

  defp from_gregorian_days!(days) do
    :calendar.gregorian_days_to_date(days) |> from_erl!
  end

  @doc """
  Takes a Date struct and returns another one representing the next day.

      iex> from_erl!({2014,12,27}) |> next_day!
      %Kalends.Date{day: 28, month: 12, year: 2014}
      iex> from_erl!({2014,12,31}) |> next_day!
      %Kalends.Date{day: 1, month: 1, year: 2015}
  """
  def next_day!(date) do
    advance!(date, 1)
  end

  @doc """
  Takes a Date struct and returns another one representing the previous day.

      iex> from_erl!({2014,12,27}) |> prev_day!
      %Kalends.Date{day: 26, month: 12, year: 2014}
  """
  def prev_day!(date) do
    advance!(date, -1)
  end

  @doc """
  Difference in days between two dates.

  Takes two Date structs: `first_date` and `second_date`.
  Subtracts `second_date` from `first_date`.

      iex> from_erl!({2014,12,27}) |> diff from_erl!({2014,12,20})
      7
      iex> from_erl!({2014,12,27}) |> diff from_erl!({2014,12,29})
      -2
  """
  def diff(%Kalends.Date{} = first_date, %Kalends.Date{} = second_date) do
    to_gregorian_days(first_date) - to_gregorian_days(second_date)
  end

  @doc """
  Advances `date` by `days` number of days.

  ## Examples

      iex> from_erl!({2014,12,27}) |> advance(3)
      {:ok, %Kalends.Date{day: 30, month: 12, year: 2014} }
      iex> from_erl!({2014,12,27}) |> advance(-2)
      {:ok, %Kalends.Date{day: 25, month: 12, year: 2014} }
  """
  def advance(%Kalends.Date{} = date, days) when is_integer(days) do
    result = to_gregorian_days(date) + days
    |> from_gregorian_days!
    {:ok, result}
  end

  @doc """
  Like `advance/2`, but returns the result directly - not tagged with :ok.
  This function might raise an error.

  ## Examples

      iex> from_erl!({2014,12,27}) |> advance!(3)
      %Kalends.Date{day: 30, month: 12, year: 2014}
  """
  def advance!(%Kalends.Date{} = date, days) when is_integer(days) do
    {:ok, result} = advance(date, days)
    result
  end

  @doc """
  Format date as string.

  Takes

  * `date` - a Date struct
  * `string` - formatting string
  * `lang` (optional) - language code

  ## Examples

      iex> strftime!(from_erl!({2014,12,27}), "%Y-%m-%d")
      "2014-12-27"
  """
  def strftime!(date, string, lang \\ :en) do
    date_erl = date |> to_erl
    {date_erl, {0, 0, 0}}
    |> NaiveDateTime.from_erl!
    |> DateTime.Format.strftime! string, lang
  end

  @doc """
  Stream of dates after the date provided as argument.

      iex> days_after(from_erl!({2014,12,27})) |> Enum.take(6)
      [%Kalends.Date{day: 28, month: 12, year: 2014}, %Kalends.Date{day: 29, month: 12, year: 2014},
            %Kalends.Date{day: 30, month: 12, year: 2014}, %Kalends.Date{day: 31, month: 12, year: 2014}, %Kalends.Date{day: 1, month: 1, year: 2015},
            %Kalends.Date{day: 2, month: 1, year: 2015}]
  """
  def days_after(from_date) do
    Stream.unfold(next_day!(from_date), fn n -> {n, n |> next_day!} end)
  end

  @doc """
  Stream of dates before the date provided as argument.

      iex> days_before(from_erl!({2014,12,27})) |> Enum.take(3)
      [%Kalends.Date{day: 26, month: 12, year: 2014}, %Kalends.Date{day: 25, month: 12, year: 2014},
            %Kalends.Date{day: 24, month: 12, year: 2014}]
  """
  def days_before(from_date) do
    Stream.unfold(prev_day!(from_date), fn n -> {n, n |> prev_day!} end)
  end

  @doc """
  Get a stream of dates. Takes a starting date and an end date. Includes end date.
  Does not include start date.

      iex> days_after_until(from_erl!({2014,12,27}), from_erl!({2014,12,29})) |> Enum.to_list
      [%Kalends.Date{day: 28, month: 12, year: 2014}, %Kalends.Date{day: 29, month: 12, year: 2014}]
  """
  def days_after_until(from_date, until_date) do
    Stream.unfold(next_day!(from_date), fn n -> if n == next_day!(until_date) do nil else {n, n |> next_day!} end end)
  end

  @doc """
  Get a stream of dates going back in time. Takes a starting date and an end date. Includes end date.
  End date should be before start date.
  Does not include start date.

      iex> days_before_until(from_erl!({2014,12,27}), from_erl!({2014,12,24})) |> Enum.to_list
      [%Kalends.Date{day: 26, month: 12, year: 2014}, %Kalends.Date{day: 25, month: 12, year: 2014}, %Kalends.Date{day: 24, month: 12, year: 2014}]
  """
  def days_before_until(from_date, until_date) do
    Stream.unfold(prev_day!(from_date), fn n -> if n == prev_day!(until_date) do nil else {n, n |> prev_day!} end end)
  end
end
