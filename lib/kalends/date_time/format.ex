defmodule Kalends.DateTime.Format do
  alias Kalends.DateTime
  alias Kalends.DateTime.Format.Strftime

  @doc """
  Generate a string from a DateTime formatted by a format string. Similar to strftime! known from UNIX.
  A list of the letters and and what they do are available here: http://man7.org/linux/man-pages/man3/strftime.3.html
  The following codes are implemented: %a, %A, %b, %h, %B, %j, %u, %w, %V, %G, %g, %y, %Y, %C, %I, %l, %P, %p, %r, %R, %T, %F, %m, %e, %d, %H, %k, %M, %S, %z, %Z

  # Example
      iex> DateTime.from_erl!({{2014,9,6},{17,10,20}},"UTC") |> DateTime.Format.strftime! "%A %Y-%m-%e %H:%M:%S"
      "Saturday 2014-09- 6 17:10:20"

      iex> DateTime.from_erl!({{2014,9,6},{17,10,20}},"UTC") |> DateTime.Format.strftime! "%a %d.%m.%y"
      "Sat 06.09.14"
  """
  def strftime!(dt, string) do
    Strftime.strftime!(dt, string)
  end

  @doc """
  Takes a DateTime.
  Returns a string with the time in ISO 8601

  ## Example

      iex> Kalends.DateTime.from_erl!({{2014, 9, 26}, {17, 10, 20}}, "America/Montevideo") |> Kalends.DateTime.Format.iso8601
      "2014-09-26T17:10:20-03:00"
  """
  def iso8601(dt) do
    Strftime.strftime!(dt, "%Y-%m-%dT%H:%M:%S")<>
    iso8601_offset_part(dt, dt.timezone)
  end

  defp iso8601_offset_part(_, time_zone) when time_zone == "UTC" or time_zone == "Etc/UTC", do: "Z"
  defp iso8601_offset_part(dt, _) do
    Strftime.strftime!(dt, "%z")
  end

  @doc """
  Takes a DateTime.
  Returns a string with the date-time in RFC 2616 format. This format is used in
  the HTTP protocol. Note that the date-time will always be "shifted" to UTC.

  ## Example

      # The time is 6:09 in the morning in Montevideo, but 9:09 GMT/UTC.
      iex> DateTime.from_erl!({{2014, 9, 6}, {6, 9, 8}}, "America/Montevideo") |> DateTime.Format.httpdate
      "Sat, 06 Sep 2014 09:09:08 GMT"
  """
  def httpdate(dt) do
    dt
    |> DateTime.shift_zone!("UTC")
    |> Strftime.strftime!("%a, %d %b %Y %H:%M:%S GMT")
  end
end
