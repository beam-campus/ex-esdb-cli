defmodule ExESDBCli.App do
  @moduledoc false
  use Application,
    otp_app: :ex_esdb_cli

  @behaviour Garnish.App

  @impl true
  def start(_type, _args) do
    config = Options.app_env()

    ssh_opts =
      [
        ssh_cli: {Garnish, app: ExESDBCli.App}
      ] ++ config

    {:ok, ref} = :ssh.daemon({127, 0, 0, 1}, 2222, ssh_opts)

    sup_opts = [strategy: :one_for_one, name: ExESDBCli.Supervisor]

    children = [
      {ExESDB.GatewayAPI, config}
    ]

    with {:ok, pid} <- Application.start(:ex_esdb_cli, children) do
      {:ok, pid, ref}
    end
  end
end
