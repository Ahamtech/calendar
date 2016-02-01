defmodule Calendar.Time.Format do
  alias Calendar.Strftime
  alias Calendar.ContainsTime

  @doc """
  Format a time as ISO 8601 extended format

  ## Examples

      iex> Calendar.Time.from_erl!({20, 5, 18}) |> Calendar.Time.Format.iso_8601
      "20:05:18"
  """
  def iso_8601(time) do
    time
    |> contained_time
    |> Strftime.strftime!("%H:%M:%S")
  end

  @doc """
  Format as ISO 8601 Basic

  # Examples

      iex> Calendar.Time.from_erl!({20, 10, 20}) |> Calendar.Time.Format.iso_8601_basic
      "201020"

  """
  def iso_8601_basic(time) do
    time = time |> contained_time
    Strftime.strftime!(time, "%H%M%S")
  end

  defp contained_time(time_container) do
    ContainsTime.time_struct(time_container)
  end
end
