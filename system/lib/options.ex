defmodule ExESDBCli.Options do
  @moduledoc """
    This module contains the options helper functions for ExESDB
  """
  alias ExESDBCli.EnvVars, as: EnvVars

  @store_id EnvVars.store_id()
  @timeout EnvVars.timeout()
  @pub_sub EnvVars.pub_sub()

  def sys_env(key), do: System.get_env(key)
  def app_env, do: Application.get_env(:ex_esdb_client, :ex_esdb)
  def app_env(key), do: Keyword.get(app_env(), key)

  def store_id do
    case sys_env(@store_id) do
      nil -> app_env(:store_id) || :ex_esdb_store
      store_id -> to_unique_atom(store_id)
    end
  end

  def timeout do
    case sys_env(@timeout) do
      nil -> app_env(:timeout) || 10_000
      timeout -> String.to_integer(timeout)
    end
  end

  def pub_sub do
    case sys_env(@pub_sub) do
      nil -> app_env(:pub_sub) || :native
      pub_sub -> to_unique_atom(pub_sub)
    end
  end

  defp to_unique_atom(candidate) do
    try do
      String.to_existing_atom(candidate)
    rescue
      _ -> String.to_atom(candidate)
    end
  end
end
