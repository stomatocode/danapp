# lib/danapp/application.ex
defmodule Danapp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the in-memory store
      Danapp.Store
      # Web server will be started conditionally
    ]

    opts = [strategy: :one_for_one, name: Danapp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Function to start the web server when needed
  def start_web_server(port) do
    web_child = {Plug.Cowboy, scheme: :http, plug: Danapp.Router, options: [port: port]}
    case Supervisor.start_child(Danapp.Supervisor, web_child) do
      {:ok, pid} -> {:ok, pid, port}
      {:error, {:already_started, pid}} -> {:ok, pid, port}
      error -> error
    end
  end

  # Function to stop the web server if it's running
  def stop_web_server do
    Supervisor.terminate_child(Danapp.Supervisor, Plug.Cowboy)
    Supervisor.delete_child(Danapp.Supervisor, Plug.Cowboy)
  end
end
