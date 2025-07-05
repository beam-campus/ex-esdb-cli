defmodule ExESDBTui.EventMonitor do
  @moduledoc """
  Advanced Event Monitor for real-time event streaming and analytics.

  This module provides sophisticated event monitoring capabilities including:
  - Real-time event streaming
  - Event pattern matching
  - Event aggregation and analytics
  - Event filtering and transformation
  - Performance metrics
  """

  use GenServer
  alias ExESDB.GatewayAPI, as: API
  require Logger

  @default_buffer_size 1_000
  @metrics_interval 5_000
  @cleanup_interval 30_000

  defstruct [
    :monitor_id,
    :store,
    :stream_pattern,
    :event_filters,
    :subscribers,
    :event_buffer,
    :metrics,
    :start_time,
    :last_event_time,
    :event_count,
    :buffer_size,
    :active,
    :subscription_refs
  ]

  @type monitor_config :: %{
          store: atom(),
          stream_pattern: String.t() | :all,
          event_filters: list(),
          buffer_size: pos_integer(),
          enable_metrics: boolean()
        }

  @type event_filter :: %{
          type: :event_type | :payload_pattern | :metadata_pattern | :custom,
          pattern: any(),
          action: :include | :exclude | :transform
        }

  @type monitor_metrics :: %{
          events_per_second: float(),
          total_events: non_neg_integer(),
          uptime_seconds: non_neg_integer(),
          buffer_utilization: float(),
          stream_distribution: map(),
          event_type_distribution: map()
        }

  ## Public API

  @doc """
  Start an event monitor with the given configuration.
  """
  @spec start_monitor(monitor_config()) :: {:ok, pid()} | {:error, term()}
  def start_monitor(config) do
    GenServer.start(__MODULE__, config)
  end

  @doc """
  Stop an event monitor.
  """
  @spec stop_monitor(pid()) :: :ok
  def stop_monitor(monitor_pid) do
    GenServer.stop(monitor_pid)
  end

  @doc """
  Subscribe to events from a monitor.
  """
  @spec subscribe(pid(), pid()) :: :ok | {:error, term()}
  def subscribe(monitor_pid, subscriber_pid) do
    GenServer.call(monitor_pid, {:subscribe, subscriber_pid})
  end

  @doc """
  Unsubscribe from events from a monitor.
  """
  @spec unsubscribe(pid(), pid()) :: :ok
  def unsubscribe(monitor_pid, subscriber_pid) do
    GenServer.call(monitor_pid, {:unsubscribe, subscriber_pid})
  end

  @doc """
  Get current metrics from a monitor.
  """
  @spec get_metrics(pid()) :: monitor_metrics()
  def get_metrics(monitor_pid) do
    GenServer.call(monitor_pid, :get_metrics)
  end

  @doc """
  Get recent events from the monitor buffer.
  """
  @spec get_recent_events(pid(), pos_integer()) :: list()
  def get_recent_events(monitor_pid, count \\ 10) do
    GenServer.call(monitor_pid, {:get_recent_events, count})
  end

  @doc """
  Add an event filter to the monitor.
  """
  @spec add_filter(pid(), event_filter()) :: :ok
  def add_filter(monitor_pid, filter) do
    GenServer.call(monitor_pid, {:add_filter, filter})
  end

  @doc """
  Remove an event filter from the monitor.
  """
  @spec remove_filter(pid(), non_neg_integer()) :: :ok
  def remove_filter(monitor_pid, filter_index) do
    GenServer.call(monitor_pid, {:remove_filter, filter_index})
  end

  @doc """
  Get the current state of the monitor.
  """
  @spec get_status(pid()) :: map()
  def get_status(monitor_pid) do
    GenServer.call(monitor_pid, :get_status)
  end

  ## GenServer Implementation
  @impl GenServer
  def init(config) do
    monitor_id = generate_monitor_id()

    state = %__MODULE__{
      monitor_id: monitor_id,
      store: Map.get(config, :store, :reg_gh),
      stream_pattern: Map.get(config, :stream_pattern, :all),
      event_filters: Map.get(config, :event_filters, []),
      subscribers: MapSet.new(),
      event_buffer: :queue.new(),
      metrics: init_metrics(),
      start_time: System.monotonic_time(:millisecond),
      last_event_time: nil,
      event_count: 0,
      buffer_size: Map.get(config, :buffer_size, @default_buffer_size),
      active: true,
      subscription_refs: []
    }

    Logger.info("Event monitor #{monitor_id} starting with config: #{inspect(config)}")
    {:ok, state}
  end
end
