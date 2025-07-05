defmodule ExESDBTui.EnVars do
  @moduledoc """
  This module is responsible for reading environment variables for the TUI.
  """
  def timeout, do: "EX_ESDB_TIMEOUT"
  def pub_sub, do: "EX_ESDB_PUB_SUB"
end
