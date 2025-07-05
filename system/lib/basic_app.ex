defmodule ExESDBTui.BasicApp do
  @moduledoc """
  Terminal User Interface (TUI) application for interacting with ExESDB.
  Built with Garnish library for SSH-based terminal interface.
  """

  @behaviour Garnish.App

  import Garnish.View
  alias ExESDB.GatewayAPI, as: API
  require Logger

  @store :reg_gh

  # Application state structure
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
    # Refresh interval in seconds
    :refresh_interval,
    # Configurable store ID
    :config_store_id,
    # Input buffer for text entry
    :input_buffer,
    # Input mode for text entry
    :input_mode,
    # Detailed event information
    :event_details,
    # Form data for subscription creation
    :subscription_form
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
  @type sub_mode :: :list | :details | :create | :edit | :filter | :input

  @type state :: %__MODULE__{
          mode: mode(),
          sub_mode: sub_mode() | nil,
          selected_stream: String.t() | nil,
          selected_event: map() | nil,
          selected_subscription: map() | nil,
          streams: list() | nil,
          events: list() | nil,
          subscriptions: list() | nil,
          event_monitors: list() | nil,
          status_message: String.t() | nil,
          cursor_position: non_neg_integer(),
          loading: boolean(),
          event_filter: map() | nil,
          search_term: String.t() | nil,
          page_offset: non_neg_integer(),
          page_size: non_neg_integer(),
          auto_refresh: boolean(),
          refresh_interval: non_neg_integer(),
          config_store_id: atom(),
          input_buffer: String.t() | nil,
          input_mode: atom() | nil,
          event_details: map() | nil,
          subscription_form: map() | nil
        }

  ## Garnish.App Callbacks

  @impl Garnish.App
  def init(context) do
    Logger.info("ExESDB TUI starting with context: #{inspect(context)}")

    # Setup auto-refresh timer
    Process.send_after(self(), :auto_refresh, 5000)

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
      status_message: "Welcome to ExESDB TUI! Use ↑/↓ to navigate, Enter to select, 'q' to quit.",
      cursor_position: 0,
      loading: false,
      event_filter: %{},
      search_term: nil,
      page_offset: 0,
      page_size: 10,
      auto_refresh: true,
      refresh_interval: 5,
      config_store_id: @store,
      input_buffer: "",
      input_mode: nil,
      event_details: nil,
      subscription_form: %{}
    }

    # 'q' and Ctrl+C
    {:ok, initial_state, quit_keys: [113, 3]}
  end

  @impl Garnish.App
  def handle_key(%{key: key}, state) do
    case {key, state.mode} do
      # Global navigation keys
      # 'q' to quit
      {113, _} -> {:stop, :normal, state}
      # ESC to main menu
      {27, _} -> {:ok, %{state | mode: :main_menu, status_message: "Returned to main menu"}}
      # Main menu navigation
      # Down arrow
      {:kcud1, :main_menu} -> handle_main_menu_down(state)
      # Up arrow
      {:kcuu1, :main_menu} -> handle_main_menu_up(state)
      # Enter
      {10, :main_menu} -> handle_main_menu_select(state)
      # Stream list navigation
      {:kcud1, :streams} -> handle_streams_down(state)
      {:kcuu1, :streams} -> handle_streams_up(state)
      {10, :streams} -> handle_stream_select(state)
      # Event list navigation
      {:kcud1, :events} -> handle_events_down(state)
      {:kcuu1, :events} -> handle_events_up(state)
      # Subscriptions navigation
      {:kcud1, :subscriptions} -> handle_subscriptions_down(state)
      {:kcuu1, :subscriptions} -> handle_subscriptions_up(state)
      # Function keys for actions
      # 'r' to refresh
      {?r, _} -> refresh_current_view(state)
      # Default case - ignore unknown keys
      _ -> {:ok, state, render: false}
    end
  end

  @impl Garnish.App
  def handle_resize({rows, cols}, state) do
    Logger.debug("Terminal resized to #{rows}x#{cols}")
    {:ok, state}
  end

  @impl Garnish.App
  def handle_info(msg, state) do
    Logger.debug("Received message: #{inspect(msg)}")
    {:ok, state, render: false}
  end

  @impl Garnish.App
  def render(state) do
    view do
      panel title: "ExESDB Terminal User Interface", padding: 1 do
        render_header(state)
        render_content(state)
        render_footer(state)
      end
    end
  end

  ## Private Helper Functions

  # Main menu navigation
  defp handle_main_menu_down(state) do
    # 4 menu items (0-3)
    new_position = min(state.cursor_position + 1, 3)
    {:ok, %{state | cursor_position: new_position}}
  end

  defp handle_main_menu_up(state) do
    new_position = max(state.cursor_position - 1, 0)
    {:ok, %{state | cursor_position: new_position}}
  end

  defp handle_main_menu_select(state) do
    case state.cursor_position do
      # View Streams
      0 ->
        case API.get_streams(@store) do
          {:ok, streams} ->
            {:ok,
             %{
               state
               | mode: :streams,
                 streams: streams,
                 cursor_position: 0,
                 status_message: "Loaded #{length(streams)} streams"
             }}

          {:error, reason} ->
            {:ok, %{state | status_message: "Error loading streams: #{inspect(reason)}"}}
        end

      # View Subscriptions
      1 ->
        case API.get_subscriptions(@store) do
          {:ok, subscriptions} ->
            {:ok,
             %{
               state
               | mode: :subscriptions,
                 subscriptions: subscriptions,
                 cursor_position: 0,
                 status_message: "Loaded #{length(subscriptions)} subscriptions"
             }}

          {:error, reason} ->
            {:ok, %{state | status_message: "Error loading subscriptions: #{inspect(reason)}"}}
        end

      # Monitor Events (future feature)
      2 ->
        {:ok, %{state | status_message: "Event monitoring - Coming soon!"}}

      # Settings (future feature)
      3 ->
        {:ok, %{state | status_message: "Settings - Coming soon!"}}

      _ ->
        {:ok, state}
    end
  end

  # Stream list navigation
  defp handle_streams_down(state) do
    max_pos = if state.streams, do: length(state.streams) - 1, else: 0
    new_position = min(state.cursor_position + 1, max_pos)
    {:ok, %{state | cursor_position: new_position}}
  end

  defp handle_streams_up(state) do
    new_position = max(state.cursor_position - 1, 0)
    {:ok, %{state | cursor_position: new_position}}
  end

  defp handle_stream_select(state) do
    if state.streams && length(state.streams) > state.cursor_position do
      selected_stream = Enum.at(state.streams, state.cursor_position)

      case API.get_events(@store, selected_stream, 1, 10, :forward) do
        {:ok, events} ->
          {:ok,
           %{
             state
             | mode: :events,
               selected_stream: selected_stream,
               events: events,
               cursor_position: 0,
               status_message: "Loaded #{length(events)} events from #{selected_stream}"
           }}

        {:error, reason} ->
          {:ok, %{state | status_message: "Error loading events: #{inspect(reason)}"}}
      end
    else
      {:ok, state}
    end
  end

  # Event list navigation
  defp handle_events_down(state) do
    max_pos = if state.events, do: length(state.events) - 1, else: 0
    new_position = min(state.cursor_position + 1, max_pos)
    {:ok, %{state | cursor_position: new_position}}
  end

  defp handle_events_up(state) do
    new_position = max(state.cursor_position - 1, 0)
    {:ok, %{state | cursor_position: new_position}}
  end

  # Subscription list navigation
  defp handle_subscriptions_down(state) do
    max_pos = if state.subscriptions, do: length(state.subscriptions) - 1, else: 0
    new_position = min(state.cursor_position + 1, max_pos)
    {:ok, %{state | cursor_position: new_position}}
  end

  defp handle_subscriptions_up(state) do
    new_position = max(state.cursor_position - 1, 0)
    {:ok, %{state | cursor_position: new_position}}
  end

  # Refresh current view
  defp refresh_current_view(state) do
    case state.mode do
      :streams ->
        case API.get_streams(@store) do
          {:ok, streams} ->
            {:ok, %{state | streams: streams, status_message: "Streams refreshed"}}

          {:error, reason} ->
            {:ok, %{state | status_message: "Error refreshing streams: #{inspect(reason)}"}}
        end

      :subscriptions ->
        case API.get_subscriptions(@store) do
          {:ok, subscriptions} ->
            {:ok,
             %{state | subscriptions: subscriptions, status_message: "Subscriptions refreshed"}}

          {:error, reason} ->
            {:ok, %{state | status_message: "Error refreshing subscriptions: #{inspect(reason)}"}}
        end

      :events when state.selected_stream ->
        case API.get_events(@store, state.selected_stream, 1, 10, :forward) do
          {:ok, events} ->
            {:ok, %{state | events: events, status_message: "Events refreshed"}}

          {:error, reason} ->
            {:ok, %{state | status_message: "Error refreshing events: #{inspect(reason)}"}}
        end

      _ ->
        {:ok, state}
    end
  end

  ## Rendering Functions

  defp render_header(state) do
    row do
      column size: 12 do
        label(
          content: "Mode: #{state.mode |> to_string() |> String.upcase()}",
          color: :cyan
        )
      end
    end
  end

  defp render_content(state) do
    case state.mode do
      :main_menu -> render_main_menu(state)
      :streams -> render_streams_list(state)
      :events -> render_events_list(state)
      :subscriptions -> render_subscriptions_list(state)
      _ -> label(content: "Unknown mode: #{state.mode}")
    end
  end

  defp render_main_menu(state) do
    menu_items = [
      "1. View Streams",
      "2. View Subscriptions",
      "3. Monitor Events",
      "4. Settings"
    ]

    column size: 12 do
      label(content: "\nMain Menu:", color: :white, attributes: :bold)

      for {item, index} <- Enum.with_index(menu_items) do
        color = if index == state.cursor_position, do: :black, else: :white
        bg = if index == state.cursor_position, do: :white, else: :black

        label(content: "  #{item}", color: color, background: bg)
      end
    end
  end

  defp render_streams_list(state) do
    column size: 12 do
      label(content: "\nStreams:", color: :white, attributes: :bold)

      if state.streams && length(state.streams) > 0 do
        for {stream, index} <- Enum.with_index(state.streams) do
          color = if index == state.cursor_position, do: :black, else: :white
          bg = if index == state.cursor_position, do: :white, else: :black

          label(content: "  #{stream}", color: color, background: bg)
        end
      else
        label(content: "  No streams available", color: :red)
      end
    end
  end

  defp render_events_list(state) do
    column size: 12 do
      if state.selected_stream do
        label(
          content: "\nEvents from #{state.selected_stream}:",
          color: :white,
          attributes: :bold
        )

        if state.events && length(state.events) > 0 do
          for {event, index} <- Enum.with_index(state.events) do
            color = if index == state.cursor_position, do: :black, else: :white
            bg = if index == state.cursor_position, do: :white, else: :black

            event_summary = "#{event.event_number}: #{event.event_type}"
            label(content: "  #{event_summary}", color: color, background: bg)
          end
        else
          label(content: "  No events available", color: :red)
        end
      else
        label(content: "\nNo stream selected", color: :red)
      end
    end
  end

  defp render_subscriptions_list(state) do
    column size: 12 do
      label(content: "\nSubscriptions:", color: :white, attributes: :bold)

      if state.subscriptions && length(state.subscriptions) > 0 do
        for {sub, index} <- Enum.with_index(state.subscriptions) do
          color = if index == state.cursor_position, do: :black, else: :white
          bg = if index == state.cursor_position, do: :white, else: :black

          sub_summary = "#{inspect(sub)}"
          label(content: "  #{sub_summary}", color: color, background: bg)
        end
      else
        label(content: "  No subscriptions active", color: :red)
      end
    end
  end

  defp render_footer(state) do
    row do
      column size: 12 do
        label(content: "\n" <> footer_help_text(state.mode), color: :yellow)

        if state.status_message do
          label(content: "\nStatus: #{state.status_message}", color: :green)
        end
      end
    end
  end

  defp footer_help_text(:main_menu),
    do: "Keys: ↑/↓ navigate, Enter select, ESC main menu, 'r' refresh, 'q' quit"

  defp footer_help_text(:streams),
    do: "Keys: ↑/↓ navigate, Enter view events, ESC main menu, 'r' refresh, 'q' quit"

  defp footer_help_text(:events), do: "Keys: ↑/↓ navigate, ESC main menu, 'r' refresh, 'q' quit"

  defp footer_help_text(:subscriptions),
    do: "Keys: ↑/↓ navigate, ESC main menu, 'r' refresh, 'q' quit"

  defp footer_help_text(_), do: "Keys: ESC main menu, 'q' quit"
end
