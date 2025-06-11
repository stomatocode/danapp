# lib/danapp/oauth_client.ex - Simplified IP-based OAuth configuration
defmodule Danapp.OAuthClient do
  use GenServer

  # Static configuration (fallbacks)
  @client_id "danapp"
  @client_secret "65b7a46345c709181d4b496a8a00c71a"
  @authorization_url "https://auth.netsapiens.com/oauth/authorize"
  @token_url "https://auth.netsapiens.com/oauth/token"
  @scope "reseller"  # Changed to NetSapiens-specific scope
  @default_ip "193.122.201.136"  # Default fallback IP
  @default_port "4000"

  # Client API
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_authorize_url do
    params = %{
      client_id: get_client_id(),
      redirect_uri: get_redirect_uri(),
      response_type: "code",
      scope: get_scope(),
      state: generate_state()
    }

    query = URI.encode_query(params)
    get_authorization_url() <> "?" <> query
  end

  # Configuration functions
  defp get_client_id do
    System.get_env("NETSAPIENS_CLIENT_ID") || @client_id
  end

  defp get_client_secret do
    System.get_env("NETSAPIENS_CLIENT_SECRET") || @client_secret
  end

  defp get_authorization_url do
    System.get_env("NETSAPIENS_AUTH_URL") || @authorization_url
  end

  defp get_token_url do
    System.get_env("NETSAPIENS_TOKEN_URL") || @token_url
  end

  defp get_scope do
    System.get_env("NETSAPIENS_SCOPE") || @scope
  end

  # IP-based redirect URI with CLI/environment support
  defp get_redirect_uri do
    # Priority order:
    # 1. Full redirect URI from environment variable (highest priority)
    # 2. IP and PORT from environment variables
    # 3. Default hardcoded values (fallback)

    case System.get_env("OAUTH_REDIRECT_URI") do
      nil ->
        # Build from IP and PORT
        ip = System.get_env("SERVER_IP") || @default_ip
        port = System.get_env("PORT") || @default_port
        protocol = if System.get_env("USE_HTTPS") == "true", do: "https", else: "http"
        redirect_uri = "#{protocol}://#{ip}:#{port}/oauth/callback"

        IO.puts("Using constructed redirect URI: #{redirect_uri}")
        redirect_uri

      full_uri ->
        IO.puts("Using environment redirect URI: #{full_uri}")
        full_uri
    end
  end

  # Generate secure state parameter for CSRF protection
  defp generate_state do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  # Store state for verification
  def store_state(state) do
    expiry = System.system_time(:second) + 300  # 5 minutes
    Danapp.Store.put("oauth_state_#{state}", expiry)
  end

  # Verify state parameter
  def verify_state(state) do
    case Danapp.Store.get("oauth_state_#{state}") do
      nil ->
        {:error, "Invalid state parameter"}
      expiry when is_integer(expiry) ->
        if System.system_time(:second) < expiry do
          Danapp.Store.put("oauth_state_#{state}", nil)  # Clean up
          :ok
        else
          {:error, "State parameter expired"}
        end
      _ ->
        {:error, "Invalid state format"}
    end
  end

  # Helper function to get current redirect URI (for debugging/CLI)
  def current_redirect_uri do
    get_redirect_uri()
  end

  # Helper function to get current configuration (for CLI info command)
  def current_config do
    %{
      client_id: get_client_id(),
      redirect_uri: get_redirect_uri(),
      authorization_url: get_authorization_url(),
      token_url: get_token_url(),
      scope: get_scope()
    }
  end

  # OAuth flow functions
  def exchange_code_for_token(code) do
    GenServer.call(__MODULE__, {:exchange_code, code})
  end

  def get_access_token do
    GenServer.call(__MODULE__, :get_access_token)
  end

  def refresh_token do
    GenServer.call(__MODULE__, :refresh_token)
  end

  # GenServer callbacks
  @impl true
  def init(_) do
    IO.puts("OAuth Client initialized with redirect URI: #{get_redirect_uri()}")
    {:ok, %{access_token: nil, refresh_token: nil, expires_at: nil}}
  end

  @impl true
  def handle_call({:exchange_code, code}, _from, state) do
    body = {
      :form,
      [
        client_id: get_client_id(),
        client_secret: get_client_secret(),
        grant_type: "authorization_code",
        code: code,
        redirect_uri: get_redirect_uri()
      ]
    }

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post(get_token_url(), body, headers) do
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
    if :os.system_time(:second) > expires_at - 300 do
      case refresh_token_impl(state.refresh_token) do
        {:ok, new_state} ->
          {:reply, {:ok, new_state.access_token}, new_state}
        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
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

  defp refresh_token_impl(refresh_token) do
    body = {
      :form,
      [
        client_id: get_client_id(),
        client_secret: get_client_secret(),
        grant_type: "refresh_token",
        refresh_token: refresh_token
      ]
    }

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post(get_token_url(), body, headers) do
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
