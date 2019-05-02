defmodule PointOfInterest do
  alias PointOfInterest.Secrets, as: Secrets

  @moduledoc """
  -->Takes a Country as Input
  -->Fetches top 100 cities
  -->Fetches Top 200 Points of Interest for Each City
  -->Writes the result to a file after parsing the data
  """

  @base_url "https://www.triposo.com/api/20181213"

  def fetch_request_triposo(url) do
    %{account: account, token: token} = Secrets.triposo_ids()
    headers = ["X-Triposo-Account": account, "X-Triposo-Token": token]
    IO.inspect(headers)

    wait = :rand.uniform(5) * 1000
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

  def download_and_save_image(url, filename) when is_nil(url), do: nil

  def download_and_save_image(url, filename) do
    download_image =
      Task.async(fn ->
        case HTTPoison.get(url, [], follow_redirect: true, max_redirect: 10) do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> {:ok, body}
          {:ok, %HTTPoison.Response{status_code: _}} -> {:error, "Nothing"}
          _ -> {:error, "Cannot Download Image"}
        end
      end)

    with {:ok, body} <- Task.await(download_image, 30000) do
      File.write!("./poi_images/#{filename}.jpg", body)
      "/poi_images/#{filename}.jpg"
    else
      _ -> nil
    end
  end

  defp get_image(images, poi_id) do
    url =
      images
      |> Enum.fetch(0)
      |> (fn
            {:ok, value} -> value["sizes"]["thumbnail"]["url"]
            _ -> nil
          end).()

    download_and_save_image(url, poi_id)
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
           "type" => "Feature",
           "id" => poi_id,
           "properties" => %{
             "osm_id" => poi_id,
             "other_tags" => "amenity, historic, tourism, attractions",
             "name" => poi_name,
             "place" => poi_location
           },
           "geometry" => %{
             "type" => "Point",
             "coordinates" => [poi_coordinates["longitude"], poi_coordinates["latitude"]]
           },
           "extract" => poi_snippet,
           "image" => get_image(poi_images, poi_id),
           "random_text" => poi_snippet
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

  def read_file_contents(filename) do
    {:ok, cwd} = File.cwd()

    case File.exists?("#{cwd}/#{filename}") do
      true ->
        File.read!("#{cwd}/#{filename}")
        |> Poison.decode()
        |> case do
          {:ok, contents} -> contents
          _ -> {:error, "Cannot Read File Contents"}
        end

      false ->
        %{
          "type" => "FeatureCollection",
          "name" => "points",
          "crs" => %{
            "type" => "name",
            "properties" => %{
              "name" => "urn:ogc:def:crs:OGC:1.3:CRS84"
            }
          },
          "features" => []
        }
    end
  end

  defp get_poi(%{city: city, country: country}) do
    url =
      "#{@base_url}/poi.json?score=>=6&tag_labels=nightlife|topattractions|sightseeing|foodexperiences&location_id=#{
        city
      }&countrycode=#{country}&order_by=-score&count=30"

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

  defp status_message({:ok, data}), do: "Wrote #{Enum.count(data)} succesfully"
  defp status_message(_), do: "Failed to wrote Data to file"

  def get_pois_for_country(%{country: country, filename: filename, city: city}) do
    all_pois = %{country: country, city: city} |> get_poi |> List.flatten()
    pois = for {:ok, data} <- all_pois, do: data

    {_, new_pois} =
      read_file_contents(filename)
      |> Map.get_and_update!("features", fn current_value ->
        {current_value, Enum.concat(current_value, pois)}
      end)

    write_poi(new_pois, filename)
    |> status_message
    |> IO.puts()
  end

  def get_pois_for_country(%{country: country, filename: filename}) do
    all_pois = country |> get_cities |> pmap(&get_poi(&1)) |> List.flatten()
    pois = for {:ok, data} <- all_pois, do: data

    {_, new_pois} =
      read_file_contents(filename)
      |> Map.get_and_update!("features", fn current_value ->
        {current_value, Enum.concat(current_value, pois)}
      end)

    write_poi(new_pois, filename)
    |> status_message
    |> IO.puts()
  end
end
