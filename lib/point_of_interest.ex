defmodule PointOfInterest do
  require Secrets

  @moduledoc """
  Documentation for PointOfInterest.
  """

  @doc """
  Hello world.

  ## Examples

      iex> PointOfInterest.hello()
      :world

  """
  @base_url "https://www.triposo.com/api/20181213"

  @doc """
  Fetches Informtion from Triposo based on the URL Passes.
  Throttle Request - Not to get Blocked
  """
  def fetch_request_triposo(url) do
    %{account: account, token: token} = Secrets.triposo_ids()
    headers = ["X-Triposo-Account": account, "X-Triposo-Token": token]

    wait = Enum.random(1..10) * 1000
    IO.puts("Lets Sleep for #{wait} milliseconds")
    :timer.sleep(wait)

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> {:ok, body}
      {:ok, %HTTPoison.Response{status_code: _}} -> {:error, "Nothing"}
      {:error, %HTTPoison.Error{reason: reason}} -> {:error, reason}
    end
  end

  @doc """
  Parallel Map
  """

  def pmap(collection, func) do
    collection
    |> Enum.map(&Task.async(fn -> func.(&1) end))
    |> Enum.map(&Task.await(&1, :infinity))
  end

  @doc """
  Fetch Top 100 cities for a Country
  ## Examples

  iex(82)> PointOfInterest.get_cities "IN"
  [
  %{city: "New_Delhi", country: "IN"},
  %{city: "Mumbai", country: "IN"},
  %{city: "Kolkata", country: "IN"},
  %{city: "Agra", country: "IN"},
  ...
  ]

  """
  def get_cities(country) do
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

  def parse_poi(poi) do
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
           "images" => poi_images,
           "id" => poi_id
         }}

      _ ->
        {:error, %{}}
    end
  end

  def write_poi(poi) do
    File.write!("../poi_data.json", Poison.encode!(poi), [:write])
    {:ok, poi}
  end

  @doc """
  Fetch Top 100 POIs for a City
  """
  def get_poi(%{city: city, country: country}) do
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

  def get_pois_for_country(country) do
    country
    |> get_cities
    |> Enum.take(2)
    |> pmap(&get_poi(&1))
    |> List.flatten()
    |> write_poi
  end
end
