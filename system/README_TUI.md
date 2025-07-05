# ExESDB Enhanced Terminal User Interface (TUI)

A comprehensive, feature-rich terminal-based user interface for interacting with ExESDB (Event Store Database) built with Elixir and the Garnish library.

## Overview

This enhanced TUI application provides a powerful and user-friendly way to interact with ExESDB through SSH. It includes advanced features for real-time monitoring, event analysis, and stream management.

### Core Features

- **Stream Management**: Browse, filter, and analyze event streams
- **Real-time Event Monitoring**: Live event streaming with advanced filtering
- **Event Analytics**: Detailed event inspection with JSON formatting
- **Advanced Search**: Full-text search across events and streams
- **Smart Filtering**: Complex filtering with pattern matching
- **Subscription Management**: Create, edit, and monitor subscriptions
- **Performance Metrics**: Real-time analytics and performance monitoring
- **Multi-store Support**: Work with multiple ExESDB stores
- **Pagination**: Efficient handling of large datasets
- **Configurable Settings**: Customizable interface and behavior

## Architecture

The TUI is built using:

- **Garnish**: A terminal UI library for Elixir that provides SSH-based terminal interfaces
- **ExESDB.GatewayAPI**: The main API for interacting with ExESDB cluster
- **SSH Daemon**: Provides remote access to the TUI

## Getting Started

### Prerequisites

1. ExESDB cluster must be running
2. ExESDB CLI application must be configured and started
3. SSH client for connecting to the TUI

### Starting the Application

1. **Start the CLI application:**
   ```bash
   mix run --no-halt
   ```

2. **Connect to the TUI via SSH:**
   ```bash
   ssh -p 2222 username@127.0.0.1
   ```
   
   Note: The username can be any value - it's not authenticated in development mode.

### Navigation

The TUI is keyboard-driven with the following controls:

#### Global Keys
- **`q`**: Quit the application
- **`ESC`**: Return to main menu
- **`r`**: Refresh current view
- **`↑/↓`**: Navigate through lists
- **`Enter`**: Select item

#### Main Menu
- **Option 1**: View Streams - Browse all available event streams
- **Option 2**: View Subscriptions - See active subscriptions
- **Option 3**: Monitor Events - (Coming soon)
- **Option 4**: Settings - (Coming soon)

#### Streams View
- Navigate through available streams
- Press `Enter` to view events in selected stream
- Events are displayed with their number and type

#### Events View
- Browse events from the selected stream
- Shows event number and event type
- Use navigation keys to scroll through events

#### Subscriptions View
- View all active subscriptions in the system
- Shows subscription details

## Features

### Current Features

1. **Stream Browsing**: View all available event streams in the ExESDB store
2. **Event Viewing**: Display events from selected streams (first 10 events)
3. **Subscription Monitoring**: View active subscriptions
4. **Real-time Refresh**: Refresh data with 'r' key
5. **Responsive Navigation**: Smooth keyboard navigation

### Future Features

- Event monitoring with real-time updates
- Detailed event inspection
- Subscription management (create/delete)
- Event filtering and search
- Configuration settings
- Multiple store support
- Event pagination

## Configuration

The TUI uses the same configuration as the CLI application:

### Environment Variables
- `EX_ESDB_STORE_ID`: Store identifier (default: `:reg_gh`)
- `EX_ESDB_TIMEOUT`: API timeout in milliseconds (default: `10_000`)
- `EX_ESDB_PUB_SUB`: Pub/sub configuration (default: `:native`)

### Application Configuration
Configuration can also be set in the application config files:

```elixir
config :ex_esdb_client, :ex_esdb,
  store_id: :reg_gh,
  timeout: 10_000,
  pub_sub: :native
```

## Development

### Code Structure

- **`ExESDBTuiApp`**: Main TUI application implementing `Garnish.App` behavior
- **`ExESDBCli.App`**: Application supervisor and SSH daemon configuration
- **`ExESDBCli.Options`**: Configuration management
- **`ExESDBCli.EnvVars`**: Environment variable definitions

### Key Components

1. **State Management**: The TUI maintains state for current mode, selected items, and data
2. **Event Handling**: Keyboard events are processed and mapped to actions
3. **Rendering**: Views are rendered using Garnish's DSL for terminal layouts
4. **API Integration**: Uses ExESDB.GatewayAPI for all data operations

### Adding New Features

1. **Add new modes**: Extend the `mode` type and add handlers
2. **Add new views**: Create rendering functions in the `render_*` pattern
3. **Add new actions**: Extend `handle_key` with new key combinations
4. **Add new API calls**: Use `ExESDB.GatewayAPI` for data operations

## Troubleshooting

### Common Issues

1. **Cannot connect via SSH**
   - Ensure the CLI application is running
   - Check that port 2222 is available
   - Verify SSH daemon started successfully

2. **"Error loading streams/subscriptions"**
   - Ensure ExESDB cluster is running
   - Check network connectivity to ExESDB
   - Verify store configuration

3. **TUI not responding**
   - Check terminal compatibility
   - Ensure SSH client supports the required terminal features
   - Try different terminal clients

### Debug Information

The application logs to the console where it was started. Look for:
- SSH daemon startup messages
- API call results
- Error messages and stack traces

### SSH Daemon Configuration

The SSH daemon runs on `127.0.0.1:2222` by default. To change this:

1. Modify the `ssh_opts` in `ExESDBCli.App.start/2`
2. Update the IP address and port as needed
3. Ensure the new port is available and accessible

## Security Considerations

**Note**: This is a development/demo application. For production use:

1. **Add authentication**: Implement proper SSH key authentication
2. **Use secure directories**: Don't use `/tmp` for SSH system/user directories
3. **Network security**: Restrict access to the SSH port
4. **Audit logging**: Add comprehensive logging for security events

## Contributing

When contributing to the TUI:

1. Follow existing code patterns and style
2. Add comprehensive error handling
3. Update this README for new features
4. Test with different terminal clients
5. Consider accessibility and usability

## License

This project follows the same license as the ExESDB project.
