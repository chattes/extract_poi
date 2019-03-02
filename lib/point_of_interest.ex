defmodule PointOfInterest do
  use Secrets
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

  def fetch_request_triposo(url) do



    
  end
  def get_cities(country) do
    url =
      "#{@base_url}/location.json?countrycode=#{country}&order_by=-score&count=100&fields=id,type,name,country_id"

    fetch_cities = Task.async(
      fn url -> 
    )
  end
end
