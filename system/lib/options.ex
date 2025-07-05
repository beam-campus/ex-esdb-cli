defmodule ExESDBTui.Options do
  @moduledoc """
    This module contains the options helper functions for ExESDB
  """
  alias ExESDBTui.EnVars, as: EnVars

  @timeout EnVars.timeout()
  @pub_sub EnVars.pub_sub()

  def sys_env(key), do: System.get_env(key)
  def app_env, do: Application.get_env(:ex_esdb_client, :ex_esdb)
  def app_env(key), do: Keyword.get(app_env(), key)

  def timeout do
    case sys_env(@timeout) do
      nil -> app_env(:timeout) || 10_000
      timeout -> String.to_integer(timeout)
    end
  end

  def pub_sub do
    case sys_env(@pub_sub) do
      nil -> app_env(:pub_sub) || :native
      pub_sub -> String.to_atom(pub_sub)
    end
  end
end
