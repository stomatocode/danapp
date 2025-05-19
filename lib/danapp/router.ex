# lib/danapp/router.ex
defmodule Danapp.Router do
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  plug :dispatch

  # Basic health check endpoint
  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "ok"}))
  end

  # NetSapiens webhook responder
  post "/netsapiens/webhook" do
    # Store the incoming webhook data
    Danapp.Store.put("last_webhook", conn.body_params)

    # Respond with 200 OK
    send_resp(conn, 200, Jason.encode!(%{status: "received"}))
  end

  # Endpoint to view stored data
  get "/data" do
    data = Danapp.Store.get_all()
    send_resp(conn, 200, Jason.encode!(data))
  end

  # Endpoint to test NetSapiens API calls
  post "/test/netsapiens/:endpoint" do
    # Extract the endpoint from params
    endpoint = conn.path_params["endpoint"]

    # Get the request body
    body = conn.body_params

    # Log the test request
    IO.puts("Testing NetSapiens API: #{endpoint}")
    IO.inspect(body)

    # Store the test request
    Danapp.Store.put("test_#{endpoint}", body)

    # Here you would implement the actual API call to NetSapiens
    # For now, just return a success response
    send_resp(conn, 200, Jason.encode!(%{
      status: "test_executed",
      endpoint: endpoint,
      request: body
    }))
  end

  # Catch-all route
  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
  end
end
