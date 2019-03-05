defmodule Poi.CLI do
  require PointOfInterest
  require Logger
  import IO.ANSI

  def main(args \\ []) do
    args
    |> parse_args
    |> response
  end

  defp parse_args(args) do
    {opts, word, _} =
      args
      |> OptionParser.parse(switches: [country: :string, filename: :string, count: :integer])

    {opts, List.to_string(word)}
  end

  defp response({opts, word}) do
    case opts do
      [country: country, filename: filename, count: count] ->
        IO.puts("Start Processing Point Of Interest for #{country}")

        %{country: country, filename: filename}
        |> PointOfInterest.get_pois_for_country()

      [country: country, filename: filename] ->
        IO.puts("""
        Start Processing Point Of Interest for #{country}.Will fetch 200 records
        """)

        %{country: country, filename: filename}
        |> PointOfInterest.get_pois_for_country()

      [help: _] ->
        IO.puts(
          yellow <>
            """

            **************Welcome to point_of_interest CLI tool*********************

            To download all the POIs for a Country pass --country as an argument.
            Pass the Filename as --filename.
            Optional : You can also specify the count of POI to be downloaded using --count.

            Example: ./point_of_interest --country "IN" --filename india.poi.json --count 100
            """
        )

      _ ->
        IO.puts(
          green <>
            """
            Invalid Arguments Supplied. Start with --help for more information
            point_of_interest --help
            """
        )
    end
  end
end
