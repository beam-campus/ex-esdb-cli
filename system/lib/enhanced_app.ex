defmodule ExESDBTui.EnhancedApp do
  @moduledoc """
  Enhanced Terminal User Interface (TUI) application for interacting with ExESDB.
  Built with Garnish library with advanced features including:
  - Real-time event monitoring
  - Detailed event inspection
  - Subscription management
  - Event filtering and search
  - Configuration settings
  - Multiple store support
  - Event pagination
  """

  @behaviour Garnish.App

  import Garnish.View
  alias ExESDB.GatewayAPI, as: API
  require Logger

  @default_store :reg_gh
  @page_size 20
  @refresh_interval 3000

  # Enhanced application state structure
  defstruct [
    # Current UI mode
    :mode,
    # Sub-mode for detailed views
    :sub_mode,
    # Currently selected stream
    :selected_stream,
    # Currently selected event
    :selected_event,
    # Currently selected subscription
    :selected_subscription,
    # List of available streams
    :streams,
    # Events for selected stream
    :events,
    # Active subscriptions
    :subscriptions,
    # Active event monitors
    :event_monitors,
    # Status/error message to display
    :status_message,
    # Current cursor position in lists
    :cursor_position,
    # Loading state
    :loading,
    # Current event filter
    :event_filter,
    # Current search term
    :search_term,
    # Current page offset for pagination
    :page_offset,
    # Page size for pagination
    :page_size,
    # Auto-refresh enabled
    :auto_refresh,
    # Refresh interval in ms
    :refresh_interval,
    # Available stores
    :available_stores,
    # Currently selected store
    :current_store,
    # Input buffer for text entry
    :input_buffer,
    # Input mode for text entry
    :input_mode,
    # Detailed event information
    :event_details,
    # Form data for subscription creation
    :subscription_form,
    # Form data for event filtering
    :filter_form,
    # Application settings
    :settings,
    # Last refresh timestamp
    :last_refresh,
    # Sort criteria
    :sort_by,
    # Sort direction
    :sort_direction
  ]

  @type mode ::
          :main_menu
          | :streams
          | :events
          | :subscriptions
          | :event_monitor
          | :settings
          | :event_details
          | :subscription_manager
          | :search
          | :filter
  @type sub_mode :: :list | :details | :create | :edit | :filter | :input | :monitor

  ## Garnish.App Callbacks

  @impl Garnish.App
  def init(context) do
    Logger.info("ExESDB Enhanced TUI starting with context: #{inspect(context)}")

    # Setup auto-refresh timer
    if Application.get_env(:ex_esdb_cli, :auto_refresh, true) do
      Process.send_after(self(), :auto_refresh, @refresh_interval)
    end

    # Initialize available stores
    available_stores = discover_stores()

    initial_state = %__MODULE__{
      mode: :main_menu,
      sub_mode: :list,
      selected_stream: nil,
      selected_event: nil,
      selected_subscription: nil,
      streams: nil,
      events: nil,
      subscriptions: nil,
      event_monitors: [],
      status_message: "Welcome to ExESDB Enhanced TUI! Press 'h' for help, 'q' to quit.",
      cursor_position: 0,
      loading: false,
      event_filter: %{},
      search_term: nil,
      page_offset: 0,
      page_size: @page_size,
      auto_refresh: true,
      refresh_interval: @refresh_interval,
      available_stores: available_stores,
      current_store: @default_store,
      input_buffer: "",
      input_mode: nil,
      event_details: nil,
      subscription_form: %{},
      filter_form: %{},
      settings: load_default_settings(),
      last_refresh: System.monotonic_time(:millisecond),
      sort_by: :event_number,
      sort_direction: :desc
    }

    # 'q' and Ctrl+C
    {:ok, initial_state, quit_keys: [113, 3]}
  end

  @impl Garnish.App
  def handle_key(%{key: key}, state) do
    # Handle input mode differently
    if state.input_mode do
      handle_input_key(key, state)
    else
      handle_navigation_key(key, state)
    end
  end

  @impl Garnish.App
  def handle_resize({rows, cols}, state) do
    Logger.debug("Terminal resized to #{rows}x#{cols}")
    # Adjust page size based on terminal height
    new_page_size = max(5, rows - 10)
    {:ok, %{state | page_size: new_page_size}}
  end

  @impl Garnish.App
  def handle_info(:auto_refresh, state) do
    # Schedule next refresh
    if state.auto_refresh do
      Process.send_after(self(), :auto_refresh, state.refresh_interval)
    end

    # Perform refresh based on current mode
    case auto_refresh_current_view(state) do
      {:ok, new_state} ->
        {:ok, %{new_state | last_refresh: System.monotonic_time(:millisecond)}}

      {:error, _} ->
        {:ok, state}
    end
  end

  def handle_info({:event_received, event}, state) do
    # Handle real-time events from monitors
    updated_monitors = update_event_monitors(state.event_monitors, event)
    status_msg = "New event: #{event.event_type} in #{event.stream_id}"
    {:ok, %{state | event_monitors: updated_monitors, status_message: status_msg}}
  end

  def handle_info(msg, state) do
    Logger.debug("Received message: #{inspect(msg)}")
    {:ok, state, render: false}
  end

  @impl Garnish.App
  def render(state) do
    view do
      panel title: build_title(state), padding: 1, border: :single do
        render_header(state)
        render_content(state)
        render_footer(state)
      end
    end
  end

  ## Navigation Key Handling

  defp handle_navigation_key(key, state) do
    case {key, state.mode, state.sub_mode} do
      # Global keys
      # 'q' to quit
      {113, _, _} -> {:stop, :normal, state}
      # ESC 
      {27, _, _} -> handle_escape(state)
      # 'h' for help
      {?h, _, _} -> show_help(state)
      # '/' for search
      {?/, _, _} -> enter_search_mode(state)
      # Navigation keys
      # Down arrow
      {:kcud1, _, _} -> handle_cursor_down(state)
      # Up arrow
      {:kcuu1, _, _} -> handle_cursor_up(state)
      # Right arrow
      {:kcuf1, _, _} -> handle_cursor_right(state)
      # Left arrow
      {:kcub1, _, _} -> handle_cursor_left(state)
      # Enter
      {10, _, _} -> handle_enter(state)
      # Function keys
      # 'r' to refresh
      {?r, _, _} -> refresh_current_view(state)
      # 'f' to filter
      {?f, _, _} -> enter_filter_mode(state)
      # 's' to sort
      {?s, _, _} -> toggle_sort(state)
      # 'a' to toggle auto-refresh
      {?a, _, _} -> toggle_auto_refresh(state)
      # 'c' to create
      {?c, _, _} -> create_new_item(state)
      # 'd' to delete
      {?d, _, _} -> delete_current_item(state)
      # 'e' to edit
      {?e, _, _} -> edit_current_item(state)
      # 'i' to inspect
      {?i, _, _} -> inspect_current_item(state)
      # 'm' to monitor
      {?m, _, _} -> monitor_events(state)
      # Number keys for quick navigation
      {?1, :main_menu, _} -> quick_navigate(state, 0)
      {?2, :main_menu, _} -> quick_navigate(state, 1)
      {?3, :main_menu, _} -> quick_navigate(state, 2)
      {?4, :main_menu, _} -> quick_navigate(state, 3)
      {?5, :main_menu, _} -> quick_navigate(state, 4)
      {?6, :main_menu, _} -> quick_navigate(state, 5)
      # Page navigation
      # Page Down
      {:knp, _, _} -> handle_page_down(state)
      # Page Up
      {:kpp, _, _} -> handle_page_up(state)
      # Home
      {:khome, _, _} -> handle_home(state)
      # End
      {:kend, _, _} -> handle_end(state)
      # Mode-specific keys
      _ -> handle_mode_specific_key(key, state)
    end
  end

  ## Input Mode Handling

  defp handle_input_key(key, state) do
    case key do
      # Enter - submit input
      10 ->
        submit_input(state)

      # ESC - cancel input
      27 ->
        cancel_input(state)

      # Backspace
      127 ->
        backspace_input(state)

      # Ctrl+H (also backspace)
      8 ->
        backspace_input(state)

      char when is_integer(char) and char >= 32 and char <= 126 ->
        # Printable ASCII character
        add_char_to_input(state, char)

      _ ->
        {:ok, state, render: false}
    end
  end

  ## Navigation Handlers

  defp handle_escape(state) do
    case state.mode do
      :main_menu ->
        {:ok, state}

      _ ->
        {:ok,
         %{
           state
           | mode: :main_menu,
             sub_mode: :list,
             cursor_position: 0,
             status_message: "Returned to main menu"
         }}
    end
  end

  defp handle_cursor_down(state) do
    max_pos = get_max_cursor_position(state)
    new_position = min(state.cursor_position + 1, max_pos)
    {:ok, %{state | cursor_position: new_position}}
  end

  defp handle_cursor_up(state) do
    new_position = max(state.cursor_position - 1, 0)
    {:ok, %{state | cursor_position: new_position}}
  end

  defp handle_cursor_right(state) do
    case state.mode do
      :events when state.events && state.cursor_position < length(state.events) ->
        # Enter event details mode
        selected_event = Enum.at(state.events, state.cursor_position)

        {:ok,
         %{
           state
           | mode: :event_details,
             selected_event: selected_event,
             sub_mode: :details,
             cursor_position: 0
         }}

      _ ->
        {:ok, state}
    end
  end

  defp handle_cursor_left(state) do
    case state.mode do
      :event_details ->
        {:ok, %{state | mode: :events, sub_mode: :list, cursor_position: 0}}

      _ ->
        {:ok, state}
    end
  end

  defp handle_enter(state) do
    case state.mode do
      :main_menu -> handle_main_menu_select(state)
      :streams -> handle_stream_select(state)
      :events -> inspect_current_event(state)
      :subscriptions -> handle_subscription_select(state)
      :settings -> handle_settings_select(state)
      _ -> {:ok, state}
    end
  end

  ## Main Menu Handling

  defp handle_main_menu_select(state) do
    case state.cursor_position do
      0 -> load_streams_view(state)
      1 -> load_subscriptions_view(state)
      2 -> load_event_monitor_view(state)
      3 -> load_search_view(state)
      4 -> load_filter_view(state)
      5 -> load_settings_view(state)
      _ -> {:ok, state}
    end
  end

  defp load_streams_view(state) do
    case API.get_streams(state.current_store) do
      {:ok, streams} ->
        {:ok,
         %{
           state
           | mode: :streams,
             sub_mode: :list,
             streams: streams,
             cursor_position: 0,
             status_message: "Loaded #{length(streams)} streams"
         }}

      {:error, reason} ->
        {:ok, %{state | status_message: "Error loading streams: #{inspect(reason)}"}}
    end
  end

  defp load_subscriptions_view(state) do
    case API.get_subscriptions(state.current_store) do
      {:ok, subscriptions} ->
        {:ok,
         %{
           state
           | mode: :subscriptions,
             sub_mode: :list,
             subscriptions: subscriptions,
             cursor_position: 0,
             status_message: "Loaded #{length(subscriptions)} subscriptions"
         }}

      {:error, reason} ->
        {:ok, %{state | status_message: "Error loading subscriptions: #{inspect(reason)}"}}
    end
  end

  defp load_event_monitor_view(state) do
    {:ok,
     %{
       state
       | mode: :event_monitor,
         sub_mode: :monitor,
         cursor_position: 0,
         status_message: "Event monitoring active - press 'm' to add monitors"
     }}
  end

  defp load_search_view(state) do
    {:ok,
     %{
       state
       | mode: :search,
         sub_mode: :input,
         input_mode: :search,
         input_buffer: "",
         cursor_position: 0,
         status_message: "Enter search term and press Enter"
     }}
  end

  defp load_filter_view(state) do
    {:ok,
     %{
       state
       | mode: :filter,
         sub_mode: :input,
         input_mode: :filter,
         input_buffer: "",
         cursor_position: 0,
         status_message: "Enter filter criteria (event_type:value) and press Enter"
     }}
  end

  defp load_settings_view(state) do
    {:ok,
     %{
       state
       | mode: :settings,
         sub_mode: :list,
         cursor_position: 0,
         status_message: "Settings - use arrow keys to navigate, Enter to edit"
     }}
  end

  ## Stream Handling

  defp handle_stream_select(state) do
    if state.streams && length(state.streams) > state.cursor_position do
      selected_stream = Enum.at(state.streams, state.cursor_position)
      load_events_for_stream(state, selected_stream)
    else
      {:ok, state}
    end
  end

  defp load_events_for_stream(state, stream) do
    start_version = state.page_offset * state.page_size + 1

    case API.get_events(state.current_store, stream, start_version, state.page_size, :forward) do
      {:ok, events} ->
        sorted_events = sort_events(events, state.sort_by, state.sort_direction)
        filtered_events = apply_filters(sorted_events, state.event_filter)

        {:ok,
         %{
           state
           | mode: :events,
             sub_mode: :list,
             selected_stream: stream,
             events: filtered_events,
             cursor_position: 0,
             status_message:
               "Loaded #{length(filtered_events)} events from #{stream} (page #{state.page_offset + 1})"
         }}

      {:error, reason} ->
        {:ok, %{state | status_message: "Error loading events: #{inspect(reason)}"}}
    end
  end

  ## Event Inspection

  defp inspect_current_event(state) do
    if state.events && length(state.events) > state.cursor_position do
      selected_event = Enum.at(state.events, state.cursor_position)
      event_details = fetch_event_details(selected_event)

      {:ok,
       %{
         state
         | mode: :event_details,
           sub_mode: :details,
           selected_event: selected_event,
           event_details: event_details,
           cursor_position: 0,
           status_message: "Inspecting event #{selected_event.event_number}"
       }}
    else
      {:ok, state}
    end
  end

  ## Subscription Management

  defp handle_subscription_select(state) do
    if state.subscriptions && length(state.subscriptions) > state.cursor_position do
      selected_subscription = Enum.at(state.subscriptions, state.cursor_position)

      {:ok,
       %{
         state
         | selected_subscription: selected_subscription,
           status_message: "Selected subscription: #{inspect(selected_subscription)}"
       }}
    else
      {:ok, state}
    end
  end

  defp create_new_subscription(state) do
    {:ok,
     %{
       state
       | mode: :subscription_manager,
         sub_mode: :create,
         subscription_form: %{},
         cursor_position: 0,
         status_message: "Creating new subscription - fill in the details"
     }}
  end

  ## Settings Handling

  defp handle_settings_select(state) do
    setting_keys = Map.keys(state.settings)

    if state.cursor_position < length(setting_keys) do
      setting_key = Enum.at(setting_keys, state.cursor_position)
      enter_setting_edit(state, setting_key)
    else
      {:ok, state}
    end
  end

  defp enter_setting_edit(state, setting_key) do
    current_value = Map.get(state.settings, setting_key, "")

    {:ok,
     %{
       state
       | input_mode: {:setting, setting_key},
         input_buffer: to_string(current_value),
         status_message: "Editing #{setting_key} - press Enter to save, ESC to cancel"
     }}
  end

  ## Input Handling

  defp submit_input(state) do
    case state.input_mode do
      :search -> perform_search(state)
      :filter -> apply_new_filter(state)
      {:setting, key} -> update_setting(state, key)
      _ -> {:ok, %{state | input_mode: nil, input_buffer: ""}}
    end
  end

  defp cancel_input(state) do
    {:ok, %{state | input_mode: nil, input_buffer: "", status_message: "Input cancelled"}}
  end

  defp add_char_to_input(state, char) do
    new_buffer = state.input_buffer <> <<char>>
    {:ok, %{state | input_buffer: new_buffer}}
  end

  defp backspace_input(state) do
    new_buffer =
      case String.length(state.input_buffer) do
        0 -> ""
        len -> String.slice(state.input_buffer, 0, len - 1)
      end

    {:ok, %{state | input_buffer: new_buffer}}
  end

  ## Search and Filter

  defp perform_search(state) do
    search_term = String.trim(state.input_buffer)

    if String.length(search_term) > 0 do
      # Search across streams and events
      results = search_events(state.current_store, search_term)

      {:ok,
       %{
         state
         | search_term: search_term,
           events: results,
           mode: :events,
           sub_mode: :list,
           input_mode: nil,
           input_buffer: "",
           cursor_position: 0,
           status_message: "Found #{length(results)} events matching '#{search_term}'"
       }}
    else
      {:ok,
       %{
         state
         | input_mode: nil,
           input_buffer: "",
           status_message: "Search cancelled - empty term"
       }}
    end
  end

  defp apply_new_filter(state) do
    filter_text = String.trim(state.input_buffer)

    case parse_filter(filter_text) do
      {:ok, filter} ->
        filtered_events =
          if state.events do
            apply_filters(state.events, filter)
          else
            []
          end

        {:ok,
         %{
           state
           | event_filter: filter,
             events: filtered_events,
             input_mode: nil,
             input_buffer: "",
             status_message: "Applied filter: #{filter_text} (#{length(filtered_events)} results)"
         }}

      {:error, reason} ->
        {:ok, %{state | status_message: "Invalid filter: #{reason}"}}
    end
  end

  ## Auto-refresh and Monitoring

  defp refresh_streams(state) do
    case API.get_streams(state.current_store) do
      {:ok, streams} -> {:ok, %{state | streams: streams}}
      {:error, _} -> {:error, :refresh_failed}
    end
  end

  defp refresh_subscriptions(state) do
    case API.get_subscriptions(state.current_store) do
      {:ok, subscriptions} -> {:ok, %{state | subscriptions: subscriptions}}
      {:error, _} -> {:error, :refresh_failed}
    end
  end

  defp auto_refresh_current_view(state) do
    case state.mode do
      :streams ->
        refresh_streams(state)

      :events when state.selected_stream ->
        load_events_for_stream(state, state.selected_stream)

      :subscriptions ->
        refresh_subscriptions(state)

      :event_monitor ->
        # Update event monitors
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  defp monitor_events(state) do
    case state.mode do
      :streams when state.cursor_position < length(state.streams || []) ->
        stream = Enum.at(state.streams, state.cursor_position)
        start_event_monitor(state, stream)

      :events when state.selected_stream ->
        start_event_monitor(state, state.selected_stream)

      _ ->
        {:ok, %{state | status_message: "Select a stream to monitor events"}}
    end
  end

  defp start_event_monitor(state, stream) do
    # Create a subscription for monitoring
    subscription_name = "monitor_#{stream}_#{:os.system_time(:second)}"

    case API.save_subscription(
           state.current_store,
           :by_stream,
           "$#{stream}",
           subscription_name,
           0,
           self()
         ) do
      :ok ->
        monitor = %{
          name: subscription_name,
          stream: stream,
          type: :by_stream,
          start_time: System.monotonic_time(:millisecond),
          event_count: 0
        }

        new_monitors = [monitor | state.event_monitors]

        {:ok,
         %{
           state
           | event_monitors: new_monitors,
             status_message: "Started monitoring events for #{stream}"
         }}

      {:error, reason} ->
        {:ok, %{state | status_message: "Failed to start monitor: #{inspect(reason)}"}}
    end
  end

  ## Utility Functions

  defp get_max_cursor_position(state) do
    case state.mode do
      # 6 menu items (0-5)
      :main_menu -> 5
      :streams -> max(0, length(state.streams || []) - 1)
      :events -> max(0, length(state.events || []) - 1)
      :subscriptions -> max(0, length(state.subscriptions || []) - 1)
      :settings -> max(0, map_size(state.settings) - 1)
      _ -> 0
    end
  end

  defp sort_events(events, sort_by, direction) do
    sorted =
      Enum.sort_by(events, fn event ->
        case sort_by do
          :event_number -> event.event_number
          :event_type -> event.event_type
          :timestamp -> Map.get(event, :timestamp, 0)
          _ -> event.event_number
        end
      end)

    case direction do
      :asc -> sorted
      :desc -> Enum.reverse(sorted)
    end
  end

  defp apply_filters(events, filters) when map_size(filters) == 0, do: events

  defp apply_filters(events, filters) do
    Enum.filter(events, fn event ->
      Enum.all?(filters, fn {key, value} ->
        event_value = Map.get(event, key, "")
        String.contains?(to_string(event_value), to_string(value))
      end)
    end)
  end

  defp parse_filter(filter_text) do
    try do
      # Parse format: "key:value,key2:value2"
      filters =
        filter_text
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&(&1 != ""))
        |> Enum.map(fn pair ->
          case String.split(pair, ":") do
            [key, value] -> {String.to_atom(String.trim(key)), String.trim(value)}
            _ -> {:error, "Invalid format"}
          end
        end)

      if Enum.any?(filters, &match?({:error, _}, &1)) do
        {:error, "Use format: key:value,key2:value2"}
      else
        {:ok, Map.new(filters)}
      end
    rescue
      _ -> {:error, "Invalid filter format"}
    end
  end

  defp search_events(store, search_term) do
    # This is a simplified search - in reality, you'd implement more sophisticated search
    case API.get_streams(store) do
      {:ok, streams} ->
        streams
        |> Enum.flat_map(fn stream ->
          case API.get_events(store, stream, 1, 100, :forward) do
            {:ok, events} -> events
            {:error, _} -> []
          end
        end)
        |> Enum.filter(fn event ->
          String.contains?(String.downcase(event.event_type || ""), String.downcase(search_term)) ||
            String.contains?(
              String.downcase(to_string(event.event_data || "")),
              String.downcase(search_term)
            )
        end)
        # Limit results
        |> Enum.take(50)

      {:error, _} ->
        []
    end
  end

  defp fetch_event_details(event) do
    %{
      basic_info: %{
        event_number: event.event_number,
        event_type: event.event_type,
        event_stream_id: event.event_stream_id,
        created_epoch: Map.get(event, :created_epoch),
        position: Map.get(event, :position)
      },
      data: event.event_data || %{},
      metadata: event.event_metadata || %{},
      links: %{
        next: event.event_number + 1,
        previous: max(0, event.event_number - 1)
      }
    }
  end

  defp discover_stores do
    # In a real implementation, this would discover available stores
    [:reg_gh, :test_store, :prod_store]
  end

  defp load_default_settings do
    %{
      auto_refresh: true,
      refresh_interval: 3000,
      page_size: 20,
      sort_by: :event_number,
      sort_direction: :desc,
      current_store: :reg_gh,
      theme: :default,
      show_timestamps: true,
      show_metadata: false
    }
  end

  defp update_event_monitors(monitors, event) do
    Enum.map(monitors, fn monitor ->
      if monitor.stream == event.event_stream_id do
        %{monitor | event_count: monitor.event_count + 1}
      else
        monitor
      end
    end)
  end

  ## Enhanced Rendering Functions

  defp build_title(state) do
    store_info = " [Store: #{state.current_store}]"
    refresh_info = if state.auto_refresh, do: " [Auto-refresh: ON]", else: " [Auto-refresh: OFF]"
    "ExESDB Enhanced TUI#{store_info}#{refresh_info}"
  end

  defp render_header(state) do
    row do
      column size: 8 do
        mode_text = "Mode: #{state.mode |> to_string() |> String.upcase()}"

        sub_mode_text =
          if state.sub_mode, do: "/#{state.sub_mode |> to_string() |> String.upcase()}", else: ""

        label(content: "#{mode_text}#{sub_mode_text}", color: :cyan, attributes: :bold)
      end

      column size: 4 do
        page_info =
          if state.mode in [:streams, :events, :subscriptions] do
            total_items = get_total_items(state)
            current_page = state.page_offset + 1
            total_pages = max(1, div(total_items + state.page_size - 1, state.page_size))
            "Page #{current_page}/#{total_pages}"
          else
            ""
          end

        label(content: page_info, color: :yellow)
      end
    end
  end

  defp render_content(state) do
    case state.mode do
      :main_menu -> render_enhanced_main_menu(state)
      :streams -> render_enhanced_streams_list(state)
      :events -> render_enhanced_events_list(state)
      :subscriptions -> render_enhanced_subscriptions_list(state)
      :event_monitor -> render_event_monitor(state)
      :event_details -> render_event_details(state)
      :settings -> render_settings(state)
      :search -> render_search_interface(state)
      :filter -> render_filter_interface(state)
      _ -> label(content: "Unknown mode: #{state.mode}")
    end
  end

  defp render_enhanced_main_menu(state) do
    menu_items = [
      "1. View Streams",
      "2. View Subscriptions",
      "3. Monitor Events",
      "4. Search Events",
      "5. Filter Events",
      "6. Settings"
    ]

    column size: 12 do
      label(content: "\\nMain Menu:", color: :white, attributes: :bold)

      for {item, index} <- Enum.with_index(menu_items) do
        color = if index == state.cursor_position, do: :black, else: :white
        bg = if index == state.cursor_position, do: :white, else: :black

        label(content: "  #{item}", color: color, background: bg)
      end

      # Show active monitors
      if length(state.event_monitors) > 0 do
        label(content: "\\nActive Monitors:", color: :cyan, attributes: :bold)

        for monitor <- state.event_monitors do
          label(content: "  • #{monitor.stream} (#{monitor.event_count} events)", color: :green)
        end
      end
    end
  end

  defp render_enhanced_streams_list(state) do
    column size: 12 do
      header_text =
        if state.search_term do
          "Streams (filtered by: #{state.search_term}):"
        else
          "Streams:"
        end

      label(content: "\\n#{header_text}", color: :white, attributes: :bold)

      if state.streams && length(state.streams) > 0 do
        # Show page of streams
        page_streams = get_page_items(state.streams, state.page_offset, state.page_size)

        for {stream, index} <- Enum.with_index(page_streams) do
          absolute_index = state.page_offset * state.page_size + index
          color = if absolute_index == state.cursor_position, do: :black, else: :white
          bg = if absolute_index == state.cursor_position, do: :white, else: :black

          # Get stream info
          stream_info = get_stream_info(state.current_store, stream)
          info_text = " (#{stream_info.event_count} events, v#{stream_info.version})"

          label(content: "  #{stream}#{info_text}", color: color, background: bg)
        end
      else
        label(content: "  No streams available", color: :red)
      end
    end
  end

  defp render_enhanced_events_list(state) do
    column size: 12 do
      header_text =
        if state.selected_stream do
          filter_text =
            if map_size(state.event_filter) > 0 do
              " (filtered)"
            else
              ""
            end

          "Events from #{state.selected_stream}#{filter_text}:"
        else
          "Events:"
        end

      label(content: "\\n#{header_text}", color: :white, attributes: :bold)

      if state.events && length(state.events) > 0 do
        # Show page of events
        page_events = get_page_items(state.events, state.page_offset, state.page_size)

        for {event, index} <- Enum.with_index(page_events) do
          absolute_index = state.page_offset * state.page_size + index
          color = if absolute_index == state.cursor_position, do: :black, else: :white
          bg = if absolute_index == state.cursor_position, do: :white, else: :black

          # Enhanced event display
          timestamp =
            if state.settings.show_timestamps do
              created = Map.get(event, :created_epoch, 0)
              time_str = format_timestamp(created)
              " [#{time_str}]"
            else
              ""
            end

          metadata_info =
            if state.settings.show_metadata and map_size(event.event_metadata || %{}) > 0 do
              " (metadata)"
            else
              ""
            end

          event_summary = "#{event.event_number}: #{event.event_type}#{timestamp}#{metadata_info}"
          label(content: "  #{event_summary}", color: color, background: bg)
        end

        # Show sort info
        sort_info = "Sorted by: #{state.sort_by} (#{state.sort_direction})"
        label(content: "\\n#{sort_info}", color: :yellow)
      else
        label(content: "  No events available", color: :red)
      end
    end
  end

  defp render_enhanced_subscriptions_list(state) do
    column size: 12 do
      label(content: "\\nSubscriptions:", color: :white, attributes: :bold)

      if state.subscriptions && length(state.subscriptions) > 0 do
        for {sub, index} <- Enum.with_index(state.subscriptions) do
          color = if index == state.cursor_position, do: :black, else: :white
          bg = if index == state.cursor_position, do: :white, else: :black

          # Enhanced subscription display
          sub_info = format_subscription(sub)
          label(content: "  #{sub_info}", color: color, background: bg)
        end
      else
        label(content: "  No subscriptions active", color: :red)
      end

      label(
        content: "\\nPress 'c' to create new subscription, 'd' to delete selected",
        color: :cyan
      )
    end
  end

  defp render_event_monitor(state) do
    column size: 12 do
      label(content: "\\nEvent Monitor:", color: :white, attributes: :bold)

      if length(state.event_monitors) > 0 do
        for monitor <- state.event_monitors do
          runtime = System.monotonic_time(:millisecond) - monitor.start_time
          runtime_sec = div(runtime, 1000)

          monitor_info = "#{monitor.stream}: #{monitor.event_count} events (#{runtime_sec}s)"
          label(content: "  • #{monitor_info}", color: :green)
        end
      else
        label(content: "  No active monitors", color: :yellow)
      end

      label(content: "\\nPress 'm' on a stream to start monitoring", color: :cyan)
      label(content: "Real-time events will appear here as they occur", color: :cyan)
    end
  end

  defp render_event_details(state) do
    if state.event_details do
      column size: 12 do
        label(content: "\\nEvent Details:", color: :white, attributes: :bold)

        # Basic info
        basic = state.event_details.basic_info
        label(content: "  Number: #{basic.event_number}", color: :white)
        label(content: "  Type: #{basic.event_type}", color: :white)
        label(content: "  Stream: #{basic.event_stream_id}", color: :white)

        if basic.created_epoch do
          timestamp = format_timestamp(basic.created_epoch)
          label(content: "  Created: #{timestamp}", color: :white)
        end

        # Data
        label(content: "\\nEvent Data:", color: :cyan, attributes: :bold)
        data_json = Jason.encode!(state.event_details.data, pretty: true)

        for line <- String.split(data_json, "\\n") do
          label(content: "  #{line}", color: :white)
        end

        # Metadata
        if map_size(state.event_details.metadata) > 0 do
          label(content: "\\nMetadata:", color: :cyan, attributes: :bold)
          metadata_json = Jason.encode!(state.event_details.metadata, pretty: true)

          for line <- String.split(metadata_json, "\\n") do
            label(content: "  #{line}", color: :yellow)
          end
        end
      end
    else
      label(content: "No event selected", color: :red)
    end
  end

  defp render_settings(state) do
    column size: 12 do
      label(content: "\\nSettings:", color: :white, attributes: :bold)

      setting_keys = Map.keys(state.settings) |> Enum.sort()

      for {key, index} <- Enum.with_index(setting_keys) do
        value = Map.get(state.settings, key)
        color = if index == state.cursor_position, do: :black, else: :white
        bg = if index == state.cursor_position, do: :white, else: :black

        setting_text = "#{key}: #{inspect(value)}"
        label(content: "  #{setting_text}", color: color, background: bg)
      end

      label(content: "\\nPress Enter to edit setting, 'r' to reset to defaults", color: :cyan)
    end
  end

  defp render_search_interface(state) do
    column size: 12 do
      label(content: "\\nSearch Events:", color: :white, attributes: :bold)

      if state.input_mode == :search do
        label(content: "Enter search term:", color: :cyan)
        label(content: "> #{state.input_buffer}_", color: :white, background: :blue)
      else
        label(content: "Press '/' to start searching", color: :cyan)
      end

      if state.search_term do
        label(content: "\\nCurrent search: #{state.search_term}", color: :yellow)
      end
    end
  end

  defp render_filter_interface(state) do
    column size: 12 do
      label(content: "\\nFilter Events:", color: :white, attributes: :bold)

      if state.input_mode == :filter do
        label(content: "Enter filter (key:value,key2:value2):", color: :cyan)
        label(content: "> #{state.input_buffer}_", color: :white, background: :blue)
      else
        label(content: "Press 'f' to start filtering", color: :cyan)
      end

      if map_size(state.event_filter) > 0 do
        label(content: "\\nActive filters:", color: :yellow)

        for {key, value} <- state.event_filter do
          label(content: "  #{key}: #{value}", color: :white)
        end
      end
    end
  end

  defp render_footer(state) do
    row do
      column size: 12 do
        help_text = build_help_text(state)
        label(content: "\\n#{help_text}", color: :yellow)

        if state.status_message do
          label(content: "\\nStatus: #{state.status_message}", color: :green)
        end

        # Show refresh info
        if state.auto_refresh do
          time_since_refresh = System.monotonic_time(:millisecond) - state.last_refresh
          next_refresh = max(0, state.refresh_interval - time_since_refresh)
          refresh_text = "Next refresh in #{div(next_refresh, 1000)}s"
          label(content: "\\n#{refresh_text}", color: :cyan)
        end
      end
    end
  end

  defp build_help_text(state) do
    base_keys = "h:help q:quit ESC:menu ↑↓:navigate Enter:select r:refresh"

    mode_keys =
      case state.mode do
        :main_menu -> " 1-6:quick-select"
        :streams -> " m:monitor"
        :events -> " →:details ←:back i:inspect f:filter s:sort PgUp/PgDn:page"
        :subscriptions -> " c:create d:delete e:edit"
        :event_monitor -> " m:add-monitor"
        :settings -> " Enter:edit"
        _ -> ""
      end

    filter_keys = if map_size(state.event_filter) > 0, do: " f:filter", else: ""
    search_keys = if state.search_term, do: " /:search", else: ""

    "#{base_keys}#{mode_keys}#{filter_keys}#{search_keys}"
  end

  ## Utility Functions for Enhanced Features

  defp get_total_items(state) do
    case state.mode do
      :streams -> length(state.streams || [])
      :events -> length(state.events || [])
      :subscriptions -> length(state.subscriptions || [])
      _ -> 0
    end
  end

  defp get_page_items(items, page_offset, page_size) do
    start_index = page_offset * page_size
    Enum.slice(items, start_index, page_size)
  end

  defp get_stream_info(store, stream) do
    case API.get_version(store, stream) do
      {:ok, version} ->
        # Estimate event count (this is simplified)
        %{version: version, event_count: version}

      {:error, _} ->
        %{version: 0, event_count: 0}
    end
  end

  defp format_timestamp(epoch) when is_integer(epoch) do
    datetime = DateTime.from_unix!(epoch)
    DateTime.to_string(datetime)
  end

  defp format_timestamp(_), do: "unknown"

  defp format_subscription(sub) do
    # Format subscription information for display
    case sub do
      %{type: type, selector: selector, name: name} ->
        "#{name} (#{type}): #{selector}"

      _ ->
        inspect(sub)
    end
  end

  ## Additional Navigation Functions

  defp handle_page_down(state) do
    new_offset = state.page_offset + 1
    max_offset = calculate_max_page_offset(state)

    if new_offset <= max_offset do
      {:ok, %{state | page_offset: new_offset, cursor_position: 0}}
    else
      {:ok, state}
    end
  end

  defp handle_page_up(state) do
    new_offset = max(0, state.page_offset - 1)
    {:ok, %{state | page_offset: new_offset, cursor_position: 0}}
  end

  defp handle_home(state) do
    {:ok, %{state | cursor_position: 0, page_offset: 0}}
  end

  defp handle_end(state) do
    max_pos = get_max_cursor_position(state)
    max_offset = calculate_max_page_offset(state)
    {:ok, %{state | cursor_position: max_pos, page_offset: max_offset}}
  end

  defp calculate_max_page_offset(state) do
    total_items = get_total_items(state)
    max(0, div(total_items - 1, state.page_size))
  end

  defp quick_navigate(state, index) do
    if index <= get_max_cursor_position(state) do
      {:ok, %{state | cursor_position: index}}
    else
      {:ok, state}
    end
  end

  defp toggle_sort(state) do
    new_sort =
      case state.sort_by do
        :event_number -> :event_type
        :event_type -> :timestamp
        :timestamp -> :event_number
        _ -> :event_number
      end

    new_direction =
      if new_sort == state.sort_by do
        case state.sort_direction do
          :asc -> :desc
          :desc -> :asc
        end
      else
        :desc
      end

    # Re-sort current events if available
    new_events =
      if state.events do
        sort_events(state.events, new_sort, new_direction)
      else
        state.events
      end

    {:ok,
     %{
       state
       | sort_by: new_sort,
         sort_direction: new_direction,
         events: new_events,
         status_message: "Sorted by #{new_sort} (#{new_direction})"
     }}
  end

  defp toggle_auto_refresh(state) do
    new_auto_refresh = not state.auto_refresh

    # Start or stop the refresh timer
    if new_auto_refresh do
      Process.send_after(self(), :auto_refresh, state.refresh_interval)
    end

    {:ok,
     %{
       state
       | auto_refresh: new_auto_refresh,
         status_message: "Auto-refresh #{if new_auto_refresh, do: "enabled", else: "disabled"}"
     }}
  end

  defp show_help(state) do
    help_message = """
    ExESDB Enhanced TUI Help:

    Global: h=help q=quit ESC=main-menu r=refresh a=auto-refresh
    Navigation: ↑↓←→=move Enter=select PgUp/PgDn=page Home/End=start/end
    Numbers: 1-6=quick-select in main menu

    Streams: m=monitor Enter=view-events
    Events: i=inspect →=details ←=back f=filter s=sort /=search
    Subscriptions: c=create d=delete e=edit
    Settings: Enter=edit-setting

    Filters: Use format 'key:value,key2:value2'
    Search: Search in event types and data
    Monitor: Real-time event monitoring
    """

    {:ok, %{state | status_message: help_message}}
  end

  defp enter_search_mode(state) do
    {:ok,
     %{
       state
       | input_mode: :search,
         input_buffer: "",
         status_message: "Enter search term and press Enter"
     }}
  end

  defp enter_filter_mode(state) do
    {:ok,
     %{
       state
       | input_mode: :filter,
         input_buffer: "",
         status_message: "Enter filter criteria (key:value,key2:value2) and press Enter"
     }}
  end

  defp create_new_item(state) do
    case state.mode do
      :subscriptions -> create_new_subscription(state)
      _ -> {:ok, %{state | status_message: "Create not available in this mode"}}
    end
  end

  defp delete_current_item(state) do
    case state.mode do
      :subscriptions when state.selected_subscription ->
        # Delete subscription logic would go here
        {:ok, %{state | status_message: "Delete subscription feature coming soon"}}

      _ ->
        {:ok, %{state | status_message: "Delete not available in this mode"}}
    end
  end

  defp edit_current_item(state) do
    case state.mode do
      :subscriptions when state.selected_subscription ->
        {:ok, %{state | status_message: "Edit subscription feature coming soon"}}

      :settings ->
        handle_settings_select(state)

      _ ->
        {:ok, %{state | status_message: "Edit not available in this mode"}}
    end
  end

  defp inspect_current_item(state) do
    case state.mode do
      :events -> inspect_current_event(state)
      _ -> {:ok, %{state | status_message: "Inspect not available in this mode"}}
    end
  end

  defp handle_mode_specific_key(_key, state) do
    {:ok, state, render: false}
  end

  defp refresh_current_view(state) do
    auto_refresh_current_view(state)
  end

  defp update_setting(state, key) do
    value = parse_setting_value(state.input_buffer)
    new_settings = Map.put(state.settings, key, value)

    {:ok,
     %{
       state
       | settings: new_settings,
         input_mode: nil,
         input_buffer: "",
         status_message: "Updated #{key} to #{inspect(value)}"
     }}
  end

  defp parse_setting_value(value_string) do
    # Try to parse as different types
    cond do
      value_string in ["true", "false"] ->
        value_string == "true"

      String.match?(value_string, ~r/^\d+$/) ->
        String.to_integer(value_string)

      String.match?(value_string, ~r/^\d+\.\d+$/) ->
        String.to_float(value_string)

      String.starts_with?(value_string, ":") ->
        String.to_atom(String.slice(value_string, 1..-1))

      true ->
        value_string
    end
  end
end
