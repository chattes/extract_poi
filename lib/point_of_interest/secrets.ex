defmodule PointOfInterest.Secrets do
  @triposo_account_id "XWEBT8MY"
  @triposo_api_token "no49b0dn6d2da55u0xhw7nsjaxmyefc7"

  def triposo_ids do
    %{
      account: @triposo_account_id,
      token: @triposo_api_token
    }
  end
end
