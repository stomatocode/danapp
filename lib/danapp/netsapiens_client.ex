# lib/danapp/netsapiens_client.ex
defmodule Danapp.NetsapiensClient do
  @base_url "https://api.netsapiens.com/v1"  # Replace with actual API base URL

  # Allow changing the base URL
  def set_base_url(url) do
    Application.put_env(:danapp, :netsapiens_base_url, url)
  end

  def get_base_url do
    Application.get_env(:danapp, :netsapiens_base_url, @base_url)
  end

  def call_api(endpoint, method, params \\ %{}, headers \\ []) do
    url = get_base_url() <> endpoint

    # Get authentication token if stored
    auth_token = case Danapp.Store.get("auth_token") do
      nil -> nil
      token -> token
    end

    # Add auth header if token exists
    headers = if auth_token do
      [{"Authorization", "Bearer #{auth_token}"} | headers]
    else
      headers
    end

    # Default headers with content type
    headers = [{"Content-Type", "application/json"} | headers]

    # Make the HTTP request based on the method
    result = case method do
      :get ->
        HTTPoison.get(url, headers)

      :post ->
        body = Jason.encode!(params)
        HTTPoison.post(url, body, headers)

      :put ->
        body = Jason.encode!(params)
        HTTPoison.put(url, body, headers)

      :delete ->
        HTTPoison.delete(url, headers)
    end

    # Store the full request/response for debugging
    Danapp.Store.put("last_api_call", %{
      url: url,
      method: method,
      params: params,
      headers: headers,
      timestamp: DateTime.utc_now() |> DateTime.to_string()
    })

    # Process the response
    handle_response(result)
  end

  defp handle_response({:ok, %HTTPoison.Response{status_code: status, body: body, headers: headers}}) when status in 200..299 do
    # Try to parse JSON response
    case Jason.decode(body) do
      {:ok, parsed_body} ->
        {:ok, parsed_body, headers}

      {:error, _} ->
        # Return as string if not valid JSON
        {:ok, body, headers}
    end
  end

  defp handle_response({:ok, %HTTPoison.Response{status_code: status, body: body, headers: headers}}) do
    # Store error response
    Danapp.Store.put("last_api_error", %{
      status: status,
      body: body,
      timestamp: DateTime.utc_now() |> DateTime.to_string()
    })

    # Try to parse JSON response
    error_body = case Jason.decode(body) do
      {:ok, parsed_body} -> parsed_body
      {:error, _} -> body
    end

    {:error, "API error: status #{status}", error_body, headers}
  end

  defp handle_response({:error, %HTTPoison.Error{reason: reason}}) do
    # Store error
    Danapp.Store.put("last_api_error", %{
      reason: reason,
      timestamp: DateTime.utc_now() |> DateTime.to_string()
    })

    {:error, "Request failed: #{reason}", nil, []}
  end
end
