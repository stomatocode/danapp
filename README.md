# Danapp

**TODO: Add description**

## Installation

## For OSX:

### Install Homebrew if you don't have it
```/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"```

### Install Erlang and Elixir
```brew install erlang```
```brew install elixir```

### Get dependencies
```mix deps.get```

### Compile the project
```mix compile ```

### Build the CLI executable
```mix escript.build```

### Make the CLI executable
```chmod +x danapp```

### See help
```./danapp help```

### Store some test data
```./danapp put --key test --value "Hello from macOS"```

### Retrieve the data
```./danapp get --key test```

### List all stored data
```./danapp list```

### Start the server in foreground mode
```./danapp server --port 4000```

### Starting in daemon mode 

First, make sure previous server is stopped (Ctrl+C)
### Then start in daemon mode
```./danapp server --daemon --port 4000```

### Check server status
```./danapp status```

### Later, stop the server when done
```./danapp stop```

### See running Erlang/Elixir processes
```ps aux | grep beam```

### Check open port
```lsof -i :4000```

### View application logs (if logging to file)
```cat /tmp/danapp.log  # If you've added file logging```


If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `danapp` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:danapp, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/danapp>.

