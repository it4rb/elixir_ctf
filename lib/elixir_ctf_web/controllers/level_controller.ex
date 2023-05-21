defmodule ElixirCtfWeb.LevelController do
  use ElixirCtfWeb, :controller

  alias ElixirCtf.Levels.Level

  def index(conn, _params) do
    levels = Level.list_levels()
    render(conn, :index, levels: levels)
  end
end
