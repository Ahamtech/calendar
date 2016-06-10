defmodule SomethingThatContainsDateTime do
  defstruct []
end

defimpl Calendar.ContainsDateTime, for: SomethingThatContainsDateTime do
  def dt_struct(_), do: Calendar.DateTime.from_erl!({{2015, 1, 1}, {1, 1, 1}}, "Etc/UTC", {0, 0})
end

defmodule DateTimeTest do
  use ExUnit.Case, async: true
  import Calendar.DateTime
  doctest Calendar.DateTime

  test "now" do
    assert Calendar.DateTime.now!("America/Montevideo").year > 1900
    # the test below needs to be changed if there are changes on Iceland
    assert Calendar.DateTime.now!("Atlantic/Reykjavik").zone_abbr == "GMT"
  end

  test "to erl" do
    {{year,_,_},{_,_,_}} = Calendar.DateTime.to_erl(Calendar.DateTime.now!("Etc/UTC"))
    assert year > 1900
  end

  test "from_erl invalid datetime" do
    result = from_erl({{2014, 99, 99}, {17, 10, 20}}, "UTC")
    assert result == {:error, :invalid_datetime}
  end

  test "from_erl non-existing timezone" do
    result = from_erl({{2014, 9, 26}, {17, 10, 20}}, "Non-existing timezone")
    assert result == {:error, :timezone_not_found}
  end

  test "non-existing wall time" do
    result = from_erl({{2014, 3, 30}, {2, 20, 02}}, "Europe/Copenhagen")
    assert result == {:error, :invalid_datetime_for_timezone}
  end

  test "shift_zone! works even for periods when wall clock is set back in fall because of DST" do
      result =  from_erl!({{1999,10,31},{0,29,10}}, "Etc/UTC") |> shift_zone!("Europe/Copenhagen") |> shift_zone!("Etc/UTC") |> shift_zone!("Europe/Copenhagen")
      assert result == %DateTime{zone_abbr: "CEST", day: 31, hour: 2, minute: 29, month: 10, second: 10, time_zone: "Europe/Copenhagen", utc_offset: 3600, std_offset: 3600, year: 1999}

      result2 = from_erl!({{1999,10,31},{1,29,10}}, "Etc/UTC") |> shift_zone!("Europe/Copenhagen") |> shift_zone!("Etc/UTC") |> shift_zone!("Europe/Copenhagen")
      assert result2 == %DateTime{zone_abbr: "CET", day: 31, hour: 2, minute: 29, month: 10, second: 10, time_zone: "Europe/Copenhagen", utc_offset: 3600, std_offset: 0, year: 1999}
  end

  test "shift_zone of a leap second" do
    date_time_utc = from_erl!({{2015, 6, 30}, {23, 59, 60}}, "Etc/UTC")
    date_time_berlin = from_erl!({{2015, 7, 1}, {1, 59, 60}}, "Europe/Berlin")
    date_time_london = from_erl!({{2015, 7, 1}, {0, 59, 60}}, "Europe/London")

    {:ok, shifted_datetime} = date_time_utc |> shift_zone("Europe/Berlin")
    assert shifted_datetime == date_time_berlin
    {:ok, shifted_datetime} = date_time_berlin |> shift_zone("Europe/London")
    assert shifted_datetime == date_time_london
  end

  test "date times with invalid times should raise error when calling from_erl" do
    result = from_erl({{2014, 3, 1}, {27, 59, 00}}, "Etc/UTC")
    assert result == {:error, :invalid_datetime}
    result = from_erl({{2014, 3, 1}, {23, 60, 00}}, "Etc/UTC")
    assert result == {:error, :invalid_datetime}
    result = from_erl({{2014, 3, 1}, {23, 50, 61}}, "Etc/UTC")
    assert result == {:error, :invalid_datetime}
  end

  test "date times where sec part is 60 should only be valid if they are actually leap seconds" do
    # Testing 23:59:60 on date without leap second
    result = from_erl({{2014, 3, 1}, {23, 59, 60}}, "Etc/UTC")
    assert result == {:error, :invalid_datetime}

    result = from_erl({{2015, 6, 30}, {23, 59, 60}}, "Europe/Berlin")
    assert result == {:error, :invalid_datetime}

    # Testing 23:59:60 on dates with leap seconds
    {tag, _date_time} = from_erl({{2015, 6, 30}, {23, 59, 60}}, "Etc/UTC")
    assert tag == :ok
    {tag, _date_time} = from_erl({{1995, 12, 31}, {23, 59, 60}}, "Etc/UTC")
    assert tag == :ok
    {tag, _date_time} = from_erl({{2015, 7, 1}, {1, 59, 60}}, "Europe/Berlin")
    assert tag == :ok
  end

  test "to_erl works for anything that contains a date time" do
    assert to_erl(%SomethingThatContainsDateTime{}) == {{2015, 1, 1}, {1, 1, 1}}
  end

  test "before? returns true when the first is before the second" do
    first = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {0, 0})
    second = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {1, 6})
    assert before?(first, second) == true

    first = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {0, 0})
    second = from_erl!({{2015, 1, 1}, {12, 0, 1}}, "Etc/UTC", {0, 0})
    assert before?(first, second) == true
  end

  test "before? returns false when the first is after the second" do
    first = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {1, 6})
    second = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {0, 0})
    assert before?(first, second) == false

    first = from_erl!({{2015, 1, 1}, {12, 0, 1}}, "Etc/UTC", {0, 0})
    second = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {0, 0})
    assert before?(first, second) == false
  end

  test "before? returns false when first and second are equal" do
    first = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {0, 0})
    second = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {0, 0})
    assert before?(first, second) == false
  end

  test "after? returns false when the first is before the second" do
    first = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {0, 0})
    second = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {1, 6})
    assert after?(first, second) == false

    first = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {0, 0})
    second = from_erl!({{2015, 1, 1}, {12, 0, 1}}, "Etc/UTC", {0, 0})
    assert after?(first, second) == false
  end

  test "after? returns true when the first is after the second" do
    first = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {1, 6})
    second = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {0, 0})
    assert after?(first, second) == true

    first = from_erl!({{2015, 1, 1}, {12, 0, 1}}, "Etc/UTC", {0, 0})
    second = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {0, 0})
    assert after?(first, second) == true
  end

  test "after? returns false when first and second are equal" do
    first = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {0, 0})
    second = from_erl!({{2015, 1, 1}, {12, 0, 0}}, "Etc/UTC", {0, 0})
    assert after?(first, second) == false
  end

  test "diff works for anything that contains a date time" do
    assert diff(%SomethingThatContainsDateTime{}, from_erl!({{2015, 6, 30}, {23, 59, 60}}, "Etc/UTC")) == {:ok, -15634739, 0, :before}
  end
end
