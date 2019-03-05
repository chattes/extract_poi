defmodule PointOfInterest do
  require Secrets

  @moduledoc """
  -->Takes a Country as Input
  -->Fetches top 100 cities
  -->Fetches Top 200 Points of Interest for Each City
  -->Writes the result to a file after parsing the data
  """

  @base_url "https://www.triposo.com/api/20181213"

  defp fetch_request_triposo(url) do
    %{account: account, token: token} = Secrets.triposo_ids()
    headers = ["X-Triposo-Account": account, "X-Triposo-Token": token]

    wait = Enum.random(1..5) * 1000
    IO.puts("Lets Sleep for #{wait} milliseconds")
    :timer.sleep(wait)

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> {:ok, body}
      {:ok, %HTTPoison.Response{status_code: _}} -> {:error, "Nothing"}
      {:error, %HTTPoison.Error{reason: reason}} -> {:error, reason}
    end
  end

  defp pmap(collection, func) do
    collection
    |> Enum.map(&Task.async(fn -> func.(&1) end))
    |> Enum.map(&Task.await(&1, :infinity))
  end

  defp get_cities(country) do
    url =
      "#{@base_url}/location.json?countrycode=#{country}&order_by=-score&count=100&fields=id,name"

    fetch_cities = Task.async(fn -> fetch_request_triposo(url) end)

    with {:ok, body} <- Task.await(fetch_cities, 25000) do
      response = Poison.decode!(body)
      Enum.map(response["results"], fn x -> %{:city => x["id"], :country => country} end)
    else
      _ ->
        {:error, "Cannot Fetch Cities"}
    end
  end

  defp get_image(images) do
    images
    |> Enum.fetch(0)
    |> (fn
          {:ok, value} -> value["source_url"]
          _ -> nil
        end).()
  end

  defp parse_poi(poi) do
    case poi do
      %{
        "name" => poi_name,
        "location_id" => poi_location,
        "coordinates" => poi_coordinates,
        "snippet" => poi_snippet,
        "images" => poi_images,
        "id" => poi_id
      } ->
        {:ok,
         %{
           "name" => poi_name,
           "location_id" => poi_location,
           "coordinates" => poi_coordinates,
           "snippet" => poi_snippet,
           "images" => get_image(poi_images),
           "id" => poi_id
         }}

      _ ->
        {:error, %{}}
    end
  end

  defp write_poi(poi, filename) do
    {:ok, cwd} = File.cwd()
    File.write!("#{cwd}/#{filename}", Poison.encode!(poi), [:write])
    {:ok, poi}
  end

  defp get_poi(%{city: city, country: country}) do
    url =
      "#{@base_url}/poi.json?location_id=#{city}&countrycode=#{country}&order_by=-score&count=100"

    fetch_poi = Task.async(fn -> fetch_request_triposo(url) end)

    with {:ok, body} <- Task.await(fetch_poi, :infinity) do
      response = Poison.decode!(body)
      %{"results" => pois} = response

      pois
      |> pmap(&parse_poi(&1))
    else
      _ ->
        {:error, "Cannot Fetch POI Data"}
    end
  end

  def get_pois_for_country(%{country: country, filename: filename}) do
    country
    |> get_cities
    |> pmap(&get_poi(&1))
    |> List.flatten()
    # |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.filter(fn
      {:ok, _value} -> true
      _ -> false
    end)
    |> Enum.map(&elem(&1, 1))
    |> write_poi(filename)
    |> (fn
          {:ok, data} -> IO.puts("Wrote #{Enum.count(data)} records succesfully")
          _ -> IO.puts("Failed to write records to File")
        end).()
  end
end
