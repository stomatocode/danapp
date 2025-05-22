# Danapp

**TODO: Add description**

## Installation

For OSX:

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

