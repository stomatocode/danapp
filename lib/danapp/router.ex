# lib/danapp/router.ex
defmodule Danapp.Router do
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug Plug.Parsers,
    parsers: [:json, :urlencoded],
    pass: ["application/json", "application/x-www-form-urlencoded"],
    json_decoder: Jason
  plug :dispatch

  # =============================================================================
  # BASIC ENDPOINTS
  # =============================================================================

  # Basic health check endpoint
  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "ok"}))
  end

  # Endpoint to view stored data
  get "/data" do
    data = Danapp.Store.get_all()
    send_resp(conn, 200, Jason.encode!(data))
  end

  # =============================================================================
  # OAUTH ENDPOINTS
  # =============================================================================

  # OAuth login initiation
  get "/oauth/login" do
    authorize_url = Danapp.OAuthClient.get_authorize_url()

    html = """
    <!DOCTYPE html>
    <html>
      <head><title>NetSapiens API OAuth Login</title></head>
      <body>
        <h1>NetSapiens API Authentication</h1>
        <a href="#{authorize_url}" style="padding: 10px; background: #0066cc; color: white; text-decoration: none; border-radius: 4px;">
          Login with NetSapiens
        </a>
      </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  # OAuth callback handler
  get "/oauth/callback" do
    code = conn.query_params["code"]

    if code do
      case Danapp.OAuthClient.exchange_code_for_token(code) do
        {:ok, token_data} ->
          # Store token data
          Danapp.Store.put("oauth_token_data", token_data)

          html = """
          <!DOCTYPE html>
          <html>
            <head><title>Authentication Success</title></head>
            <body>
              <h1>Authentication Successful!</h1>
              <p>You can now close this window and return to the application.</p>
            </body>
          </html>
          """

          conn
          |> put_resp_content_type("text/html")
          |> send_resp(200, html)

        {:error, error} ->
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(400, "Authentication error: #{error}")
      end
    else
      error = conn.query_params["error"]
      error_description = conn.query_params["error_description"]

      conn
      |> put_resp_content_type("text/html")
      |> send_resp(400, "Error: #{error} - #{error_description}")
    end
  end

  # OAuth status check
  get "/oauth/status" do
    case Danapp.OAuthClient.get_access_token() do
      {:ok, token} ->
        send_resp(conn, 200, Jason.encode!(%{
          authenticated: true,
          token_preview: String.slice(token, 0..10) <> "..."
        }))

      {:error, _} ->
        send_resp(conn, 200, Jason.encode!(%{authenticated: false}))
    end
  end

  # =============================================================================
  # NETSAPIENS API ENDPOINTS
  # =============================================================================

  # NetSapiens webhook responder
  post "/netsapiens/webhook" do
    # Store the incoming webhook data
    Danapp.Store.put("last_webhook", conn.body_params)

    # Respond with 200 OK (required for webhooks)
    send_resp(conn, 200, Jason.encode!(%{status: "received"}))
  end

  # Test NetSapiens API calls with authentication
  get "/test/netsapiens/authenticated/:endpoint" do
    endpoint = conn.path_params["endpoint"]

    case Danapp.NetsapiensClient.call_api("/#{endpoint}", :get) do
      {:ok, response} ->
        send_resp(conn, 200, Jason.encode!(%{
          status: "success",
          endpoint: endpoint,
          response: response
        }))

      {:error, reason, details} ->
        send_resp(conn, 400, Jason.encode!(%{
          status: "error",
          endpoint: endpoint,
          reason: reason,
          details: details
        }))
    end
  end

  # Test NetSapiens API calls (POST with body)
  post "/test/netsapiens/:endpoint" do
    endpoint = conn.path_params["endpoint"]
    body = conn.body_params

    # Log the test request
    IO.puts("Testing NetSapiens API: #{endpoint}")
    IO.inspect(body)

    # Store the test request
    Danapp.Store.put("test_#{endpoint}", body)

    # Make the actual API call using the NetsapiensClient
    case Danapp.NetsapiensClient.call_api("/#{endpoint}", :post, body) do
      {:ok, response, _headers} ->
        send_resp(conn, 200, Jason.encode!(%{
          status: "success",
          endpoint: endpoint,
          request: body,
          response: response
        }))

      {:error, reason, details, _headers} ->
        send_resp(conn, 400, Jason.encode!(%{
          status: "error",
          endpoint: endpoint,
          request: body,
          reason: reason,
          details: details
        }))
    end
  end

  # =============================================================================
  # CATCH-ALL ROUTE
  # =============================================================================

  # Catch-all route for undefined endpoints
  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
  end

  # =============================================================================
  # HELPER FUNCTIONS
  # =============================================================================

  # Helper function to set content type
  defp put_resp_content_type(conn, content_type) do
    conn
    |> Plug.Conn.put_resp_header("content-type", content_type)
  end
end
