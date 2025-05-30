# lib/danapp/oauth_client.ex
defmodule Danapp.OAuthClient do
  use GenServer

  # Configuration - replace with your actual values from NetSapiens documentation
  @client_id "danapp"
  @client_secret "65b7a46345c709181d4b496a8a00c71a"
  @redirect_uri "http://localhost:4000/oauth/callback"
  @authorization_url "https://auth.netsapiens.com/oauth/authorize"
  @token_url "https://auth.netsapiens.com/oauth/token"
  @scope "read write"  # Adjust based on NetSapiens docs

  # Client API
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_authorize_url do
    params = %{
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      response_type: "code",
      scope: @scope
    }

    query = URI.encode_query(params)
    @authorization_url <> "?" <> query
  end


  # # Environment-specific redirect URI configuration
  # defp get_redirect_uri do
  #   case Mix.env() do
  #     :dev ->
  #       # For local development
  #       "http://localhost:4000/oauth/callback"

  #     :test ->
  #       # For testing
  #       "http://localhost:4001/oauth/callback"

  #     :prod ->
  #       # For production - get from environment variable
  #       System.get_env("OAUTH_REDIRECT_URI") || "https://yourdomain.com/oauth/callback"
  #   end
  # end

  # # Alternative: Configure based on your deployment
  # defp get_redirect_uri_advanced do
  #   base_url = case System.get_env("DEPLOYMENT_ENV") do
  #     "local" -> "http://localhost:4000"
  #     "staging" -> "https://staging.yourdomain.com"
  #     "production" -> "https://yourdomain.com"
  #     _ -> "http://localhost:4000"  # fallback
  #   end

  #   base_url <> "/oauth/callback"
  # end

  # # Use the dynamic redirect URI
  # def get_authorize_url do
  #   params = %{
  #     client_id: get_client_id(),
  #     redirect_uri: get_redirect_uri(),
  #     response_type: "code",
  #     scope: get_scope(),
  #     state: generate_state()  # CSRF protection
  #   }

  #   query = URI.encode_query(params)
  #   get_authorization_url() <> "?" <> query
  # end




  def exchange_code_for_token(code) do
    GenServer.call(__MODULE__, {:exchange_code, code})
  end

  def get_access_token do
    GenServer.call(__MODULE__, :get_access_token)
  end

  def refresh_token do
    GenServer.call(__MODULE__, :refresh_token)
  end

  # Server callbacks
  @impl true
  def init(_) do
    {:ok, %{access_token: nil, refresh_token: nil, expires_at: nil}}
  end

  @impl true
  def handle_call({:exchange_code, code}, _from, state) do
    body = {
      :form,
      [
        client_id: @client_id,
        client_secret: @client_secret,
        grant_type: "authorization_code",
        code: code,
        redirect_uri: @redirect_uri
      ]
    }

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post(@token_url, body, headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        token_data = Jason.decode!(response_body)
        expires_at = :os.system_time(:second) + token_data["expires_in"]

        new_state = %{
          access_token: token_data["access_token"],
          refresh_token: token_data["refresh_token"],
          expires_at: expires_at
        }

        {:reply, {:ok, new_state}, new_state}

      {:ok, %{status_code: status_code, body: response_body}} ->
        {:reply, {:error, "HTTP Error #{status_code}: #{response_body}"}, state}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:reply, {:error, "Request failed: #{reason}"}, state}
    end
  end

  @impl true
  def handle_call(:get_access_token, _from, %{access_token: nil} = state) do
    {:reply, {:error, "No access token available"}, state}
  end

  @impl true
  def handle_call(:get_access_token, _from, %{access_token: token, expires_at: expires_at} = state) do
    # Check if token is expired or about to expire
    if :os.system_time(:second) > expires_at - 300 do
      # Token is expired or will expire soon, try to refresh
      case refresh_token_impl(state.refresh_token) do
        {:ok, new_state} ->
          {:reply, {:ok, new_state.access_token}, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      # Token is still valid
      {:reply, {:ok, token}, state}
    end
  end

  @impl true
  def handle_call(:refresh_token, _from, %{refresh_token: nil} = state) do
    {:reply, {:error, "No refresh token available"}, state}
  end

  @impl true
  def handle_call(:refresh_token, _from, %{refresh_token: refresh_token} = state) do
    case refresh_token_impl(refresh_token) do
      {:ok, new_state} ->
        {:reply, {:ok, new_state}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Helper function to refresh the token
  defp refresh_token_impl(refresh_token) do
    body = {
      :form,
      [
        client_id: @client_id,
        client_secret: @client_secret,
        grant_type: "refresh_token",
        refresh_token: refresh_token
      ]
    }

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post(@token_url, body, headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        token_data = Jason.decode!(response_body)
        expires_at = :os.system_time(:second) + token_data["expires_in"]

        new_state = %{
          access_token: token_data["access_token"],
          refresh_token: token_data["refresh_token"] || refresh_token,
          expires_at: expires_at
        }

        {:ok, new_state}

      {:ok, %{status_code: status_code, body: response_body}} ->
        {:error, "HTTP Error #{status_code}: #{response_body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Request failed: #{reason}"}
    end
  end
end
