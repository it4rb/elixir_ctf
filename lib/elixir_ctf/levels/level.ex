defmodule ElixirCtf.Levels.Level do
  defstruct [:id, :description, :title, :hex, :objdump, :score, :hint]

  @type t :: %__MODULE__{
          id: String.t(),
          description: String.t(),
          hint: String.t(),
          title: String.t(),
          hex: String.t(),
          objdump: String.t(),
          score: integer
        }

  @data_file_ext ".json"
  defp data_dir, do: Path.join(:code.priv_dir(:elixir_ctf), "level_data")

  def get_level!(id) do
    load_level_from_file(id <> @data_file_ext)
  end

  def list_levels do
    {:ok, files} = File.ls(data_dir())

    Enum.filter(files, &String.ends_with?(&1, @data_file_ext))
    |> Enum.map(&load_level_from_file/1)
    |> Enum.sort_by(& &1.score)
  end

  defp load_level_from_file(filename) do
    level_id = String.replace_trailing(filename, @data_file_ext, "")
    root_dir = data_dir()
    content = File.read!(Path.join(root_dir, filename))
    json = Jason.decode!(content)

    level = %__MODULE__{
      id: level_id,
      title: json["title"],
      description: json["description"],
      hint: json["hint"],
      score: json["score"],
      hex: File.read!(Path.join(root_dir, level_id <> ".c.hex")),
      objdump: File.read!(Path.join(root_dir, level_id <> ".c.dump"))
    }

    level
  end
end
