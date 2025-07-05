defmodule ExESDBTui.App do
  @moduledoc """
  Main Application module for ExESDB TUI.

  This module starts the SSH daemon and configures it to use ExESDBTuiApp
  as the terminal interface.
  """
  use Application,
    otp_app: :ex_esdb_tui

  require Logger
  alias ExESDBTui.Options

  @impl true
  def start(_type, _args) do
    config = Options.app_env()

    # Configure SSH daemon to use our enhanced TUI app
    tui_app = Application.get_env(:ex_esdb_tui, :tui_mode, :enhanced)

    selected_app =
      case tui_app do
        :basic -> ExESDBTuiApp
        :enhanced -> ExESDBTuiEnhanced
        _ -> ExESDBTuiEnhanced
      end

    ssh_opts =
      [
        ssh_cli: {Garnish, app: selected_app},
        system_dir: "/tmp/ssh_daemon",
        user_dir: "/tmp/ssh_daemon",
        auth_method_kb_interactive_data: fn _, _, _, _ -> {false, ""} end,
        # Default auth for demo
        user_passwords: [{"user", "password"}],
        silently_accept_hosts: true,
        save_accepted_host: false
      ] ++ config

    # Start SSH daemon
    case :ssh.daemon({127, 0, 0, 1}, 2222, ssh_opts) do
      {:ok, _ref} ->
        Logger.info("ExESDB CLI SSH daemon started on 127.0.0.1:2222")
        Logger.info("Connect with: ssh -p 2222 username@127.0.0.1")

        # Start the application supervisor
        children = [
          {ExESDBGater.API, config}
        ]

        case Supervisor.start_link(children, strategy: :one_for_one, name: ExESDBCli.Supervisor) do
          {:ok, pid} -> {:ok, pid}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to start SSH daemon: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def stop(_state) do
    Logger.info("ExESDB TUI application stopping")
    :ok
  end
end
