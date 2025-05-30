# lib/danapp/cli.ex
defmodule Danapp.CLI do
  @moduledoc """
  Command-line interface for Danapp.
  """

  def main(args) do
    # Parse command-line options
    {opts, action, _} = parse_args(args)

    # Start the application (store and possibly web server)
    {:ok, _} = Application.ensure_all_started(:danapp)

    # Process the command
    process_command(action, opts)

    # Add a small delay to ensure all output is printed before exit
    Process.sleep(100)
  end

  defp parse_args(args) do
    {opts, action, rest} = OptionParser.parse(
      args,
      switches: [
        port: :integer,
        method: :string,
        data: :string,
        key: :string,
        value: :string,
        url: :string,
        format: :string,
        daemon: :boolean
      ],
      aliases: [
        p: :port,
        m: :method,
        d: :data,
        k: :key,
        v: :value,
        u: :url,
        f: :format
      ]
    )


    # Determine the action based on the first argument

    # Server should [...]

    action = case action do
      ["server" | _] -> :server
      ["stop" | _] -> :stop
      ["status" | _] -> :status
      ["get" | _] -> :get
      ["put" | _] -> :put
      ["list" | _] -> :list
      ["api" | rest] -> {:api, List.first(rest)}
      ["set-api-url" | _] -> :set_api_url
      ["help" | _] -> :help
      _ -> :help
    end

    {opts, action, rest}
  end

  # Run server command to start the web server
  defp process_command(:server, opts) do
    port = Keyword.get(opts, :port, 4000)
    daemon = Keyword.get(opts, :daemon, false)

    IO.puts("Starting web server on port #{port}...")

    case Danapp.Application.start_web_server(port) do
      {:ok, _pid, actual_port} ->
        IO.puts("Server running at http://localhost:#{actual_port}")

        if daemon do
          # Create PID file
          pid = System.pid()
          File.write("/tmp/danapp.pid", pid)
          IO.puts("Server running in daemon mode. PID: #{pid}")
          IO.puts("To stop the server: ./danapp stop")

          # Detach from console
          spawn(fn ->
            Process.sleep(:infinity)
          end)

          # Sleep briefly to allow the spawn to take effect
          Process.sleep(1000)
        else
          # Keep the application running in foreground
          IO.puts("Press Ctrl+C to stop the server")
          Process.sleep(:infinity)
        end

      error ->
        IO.puts("Failed to start server: #{inspect(error)}")
    end
  end

  # Stop server command
  defp process_command(:stop, _opts) do
    case File.read("/tmp/danapp.pid") do
      {:ok, pid_str} ->
        pid = String.trim(pid_str)
        IO.puts("Stopping server with PID #{pid}...")

        # Send SIGTERM to the process
        System.cmd("kill", [pid])

        # Remove PID file
        File.rm("/tmp/danapp.pid")
        IO.puts("Server stopped")

      {:error, _} ->
        IO.puts("No running server found (PID file not found)")
    end
  end

  # Server status command
  defp process_command(:status, _opts) do
    case File.read("/tmp/danapp.pid") do
      {:ok, pid_str} ->
        pid = String.trim(pid_str)
        IO.puts("Server is running with PID #{pid}")

        # Check if the process is actually running
        case System.cmd("ps", ["-p", pid], stderr_to_stdout: true) do
          {output, 0} ->
            if String.contains?(output, pid) do
              IO.puts("Server is active")
            else
              IO.puts("WARNING: PID file exists but process is not running")
            end

          {_, _} ->
            IO.puts("WARNING: PID file exists but process is not running")
        end

      {:error, _} ->
        IO.puts("No running server found (PID file not found)")
    end
  end

  # Get value command
  defp process_command(:get, opts) do
    key = Keyword.get(opts, :key)
    format = Keyword.get(opts, :format, "inspect")

    if key do
      value = Danapp.Store.get(key)

      case format do
        "json" ->
          case Jason.encode(value) do
            {:ok, json} -> IO.puts(json)
            {:error, _} -> IO.puts("Error: Value for '#{key}' could not be encoded as JSON")
          end

        "raw" ->
          IO.write(value)

        _ -> # Default inspect format
          IO.puts("#{key}: #{inspect(value)}")
      end
    else
      IO.puts("Error: Key is required. Use --key or -k")
    end
  end

  # Put value command
  defp process_command(:put, opts) do
    key = Keyword.get(opts, :key)
    data = Keyword.get(opts, :data)
    value = Keyword.get(opts, :value)

    cond do
      key && data ->
        # Try to parse as JSON
        case Jason.decode(data) do
          {:ok, parsed_data} ->
            Danapp.Store.put(key, parsed_data)
            IO.puts("Successfully stored JSON data under key '#{key}'")

          {:error, _} ->
            # Store as string if not valid JSON
            Danapp.Store.put(key, data)
            IO.puts("Successfully stored string under key '#{key}'")
        end

      key && value ->
        # Store simple string value
        Danapp.Store.put(key, value)
        IO.puts("Successfully stored string under key '#{key}'")

      true ->
        IO.puts("Error: Key and either data or value are required")
        IO.puts("Use: --key KEY --data '{\"json\":\"data\"}' or --key KEY --value 'simple value'")
    end
  end

  # List values command
  defp process_command(:list, opts) do
    format = Keyword.get(opts, :format, "table")
    all_data = Danapp.Store.get_all()

    case format do
      "json" ->
        case Jason.encode(all_data) do
          {:ok, json} -> IO.puts(json)
          {:error, _} -> IO.puts("Error: Could not encode stored data as JSON")
        end

      "table" ->
        if Enum.empty?(all_data) do
          IO.puts("No data stored")
        else
          IO.puts("\nStored Data:")
          IO.puts(String.duplicate("-", 80))
          IO.puts("| KEY" <> String.duplicate(" ", 29) <> " | VALUE" <> String.duplicate(" ", 38) <> " |")
          IO.puts(String.duplicate("-", 80))

          Enum.each(all_data, fn {key, value} ->
            key_str = String.slice("#{key}" <> String.duplicate(" ", 30), 0, 30)
            val_str = String.slice("#{inspect(value)}" <> String.duplicate(" ", 40), 0, 40)
            IO.puts("| #{key_str} | #{val_str} |")
          end)

          IO.puts(String.duplicate("-", 80))
        end

      _ ->
        IO.puts("Stored data:")
        Enum.each(all_data, fn {key, value} ->
          IO.puts("#{key}: #{inspect(value)}")
        end)
    end
  end

  # API call command
  defp process_command({:api, endpoint}, opts) do
    if is_nil(endpoint) do
      IO.puts("Error: Endpoint is required for API calls")
      IO.puts("Example: ./danapp api users/list --method get")
      :ok
    end

    method_str = Keyword.get(opts, :method, "get")
    method = String.to_atom(String.downcase(method_str))
    data_str = Keyword.get(opts, :data, "{}")
    format = Keyword.get(opts, :format, "pretty")

    # Parse data as JSON
    data = case Jason.decode(data_str) do
      {:ok, parsed} -> parsed
      {:error, _} ->
        # Check if it's a reference to stored data
        if String.starts_with?(data_str, "@") do
          key = String.slice(data_str, 1..-1)
          case Danapp.Store.get(key) do
            nil ->
              IO.puts("Error: Referenced key '#{key}' not found in store")
              %{}
            value -> value
          end
        else
          # Not JSON or reference, use as raw string
          data_str
        end
    end

    IO.puts("Calling API endpoint: #{endpoint}")
    IO.puts("Method: #{method}")
    IO.puts("Data: #{inspect(data)}")

    # Make the actual API call
    case Danapp.NetsapiensClient.call_api(endpoint, method, data) do
      {:ok, response, _headers} ->
        IO.puts("API call successful")

        # Format the response according to requested format
        case format do
          "json" ->
            case Jason.encode(response) do
              {:ok, json} -> IO.puts(json)
              {:error, _} -> IO.puts(inspect(response))
            end

          "pretty" ->
            case Jason.encode(response, pretty: true) do
              {:ok, json} -> IO.puts(json)
              {:error, _} -> IO.puts(inspect(response, pretty: true, width: 80))
            end

          _ ->
            IO.puts(inspect(response))
        end

        # Store the successful response
        Danapp.Store.put("last_api_response", response)

      {:error, message, details, _headers} ->
        IO.puts("API call failed: #{message}")
        IO.puts("Details: #{inspect(details)}")
    end
  end

  # Set API URL command
  defp process_command(:set_api_url, opts) do
    url = Keyword.get(opts, :url)

    if url do
      Danapp.NetsapiensClient.set_base_url(url)
      IO.puts("API base URL set to: #{url}")

      # Also store it for persistence across runs
      Danapp.Store.put("api_base_url", url)
    else
      current_url = Danapp.NetsapiensClient.get_base_url()
      IO.puts("Current API base URL: #{current_url}")
      IO.puts("To change it, use: ./danapp set-api-url --url https://api.example.com")
    end
  end

  # Help command
  defp process_command(:help, _opts) do
    IO.puts("""
    Danapp CLI - NetSapiens API Testing Tool

    USAGE:
      ./danapp COMMAND [OPTIONS]

    SERVER COMMANDS:
      server [--port/-p PORT] [--daemon]   Start the web server
      stop                                 Stop a running daemon server
      status                               Check if server is running

    DATA COMMANDS:
      get --key/-k KEY [--format/-f FORMAT]        Get a value from the store
      put --key/-k KEY (--data/-d DATA | --value/-v VALUE)  Store a value
      list [--format/-f FORMAT]                    List all stored values

    API COMMANDS:
      api ENDPOINT [--method/-m METHOD] [--data/-d DATA] [--format/-f FORMAT]
                                        Call NetSapiens API
      set-api-url --url/-u URL          Set the base URL for API calls

    OTHER COMMANDS:
      help                               Show this help message

    FORMAT OPTIONS:
      For 'get' and 'list': json, raw, table (default varies by command)
      For 'api': json, pretty (default: pretty)

    EXAMPLES:
      # Start server in foreground on port 4000
      ./danapp server --port 4000

      # Start server as daemon (background)
      ./danapp server --daemon

      # Store JSON data
      ./danapp put --key credentials --data '{"username":"user","password":"pass"}'

      # Store simple string
      ./danapp put --key greeting --value "Hello World"

      # Get stored data
      ./danapp get --key credentials

      # Get data as JSON
      ./danapp get --key credentials --format json

      # List all stored data
      ./danapp list

      # Set API base URL
      ./danapp set-api-url --url https://api.netsapiens.com/v1

      # Make API call with JSON data
      ./danapp api users/list --method get --data '{}'

      # Make API call using stored data (reference with @)
      ./danapp api auth/login --method post --data @credentials
    """)
  end
end
