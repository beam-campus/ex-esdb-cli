defmodule ExESDBCli.EnvVars do
  @moduledoc """
    This module contains the environment variables that are used by ExESDBClient
  """
  def store_id, do: "EX_ESDB_STORE_ID"

  @doc """
    Returns the db type. `single` or `cluster`. default: `single`
  """
  def pub_sub, do: "EX_ESDB_PUB_SUB"

  @doc """
    Returns the timeout in milliseconds. default: `1_000`
  """
  def timeout, do: "EX_ESDB_TIMEOUT"
end
