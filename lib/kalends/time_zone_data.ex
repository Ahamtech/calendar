defmodule Kalends.TimeZoneData do
  # make sure TzPeriodBuilder is compiled before compiling this module
  require Kalends.TzParsing.TzPeriodBuilder
  require Kalends.TzParsing.TzData
  alias Kalends.TzParsing.TzPeriodBuilder, as: TzPeriodBuilder
  alias Kalends.TzParsing.TzData, as: TzData

  # For each canonical zone, calculate periods
  Enum.each TzData.zone_list, fn (zone_name) ->
    def periods(unquote(zone_name)) do
      {:ok, unquote(Macro.escape(TzPeriodBuilder.calc_periods(zone_name)))}
    end
  end

  # For each linked zone, call canonical zone
  Enum.each TzData.links, fn {alias_name, canonical_name} ->
    def periods(unquote(alias_name)) do
      periods(unquote(canonical_name))
    end
  end

  # if a periods for a zone has not been defined at this point,
  # the zone name does not exist
  @doc """
  A list of pre-compiled periods for a given zone name. This function is
  used by the TimeZonePeriods module.
  """
  def periods(_zone_name), do: {:error, :not_found}

  # Provide lists of zone- and link-names
  # Note that the function names are different from TzData!
  # The term "alias" is used instead of "link"
  @doc """
  zone_list provides a list of all the zone names that can be used with
  DateTime. This includes aliases.
  """
  def zone_list, do: unquote(Macro.escape(TzData.zone_and_link_list))

  @doc """
  Like zone_list, but excludes aliases for zones. 
  """
  def canonical_zone_list, do: unquote(Macro.escape(TzData.zone_list))

  @doc """
  A list of aliases for zone names. For instance Europe/Jersey
  is an alias for Europe/London. Aliases are also known as linked zones.
  """
  def zone_alias_list, do: unquote(Macro.escape(TzData.link_list))

  @doc """
  Takes the name of a zone. Returns true zone exists. Otherwise false.

      iex> Kalends.TimeZoneData.zone_exists? "Pacific/Auckland"
      true
      iex> Kalends.TimeZoneData.zone_exists? "America/Sao_Paulo"
      true
      iex> Kalends.TimeZoneData.zone_exists? "Europe/Jersey"
      true
  """
  def zone_exists?(name), do: Enum.member?(zone_list, name)

  @doc """
  Takes the name of a zone. Returns true if zone exists and is canonical.
  Otherwise false.

      iex> Kalends.TimeZoneData.canonical_zone? "Europe/London"
      true
      iex> Kalends.TimeZoneData.canonical_zone? "Europe/Jersey"
      false
  """
  def canonical_zone?(name), do: Enum.member?(canonical_zone_list, name)

  @doc """
  Takes the name of a zone. Returns true if zone exists and is an alias.
  Otherwise false.

      iex> Kalends.TimeZoneData.zone_alias? "Europe/Jersey"
      true
      iex> Kalends.TimeZoneData.zone_alias? "Europe/London"
      false
  """
  def zone_alias?(name), do: Enum.member?(zone_alias_list, name)

  # Provide map of links
  @doc """
  Returns a map of links. Also known as aliases.

      iex> Kalends.TimeZoneData.links["Europe/Jersey"]
      "Europe/London"
  """
  def links, do: unquote(Macro.escape(TzData.links))
end
