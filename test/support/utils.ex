defmodule TestUtils do
  alias MSP430.Memory

  def load_rom(raw) do
    Map.new(Map.to_list(raw) |> Enum.map(fn {k, v} -> {div(k - Memory.rom_start(), 2), v} end))
  end

  def load_ram(raw) do
    Map.new(Map.to_list(raw) |> Enum.map(fn {k, v} -> {div(k - Memory.ram_start(), 2), v} end))
  end
end
