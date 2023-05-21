defmodule MSP430.HexTest do
  alias MSP430.Memory
  alias MSP430.Instruction
  alias MSP430.IntelHex

  use ExUnit.Case

  test "load hex and decode" do
    hex = [
      ":10C000000441245321828443FAFF9453FAFF944459",
      ":0AC01000FAFFFCFF1F44FCFF215261",
      ":00000001FF"
    ]

    {:ok, words} = IntelHex.load(hex, Memory.rom_start())
    mem = %Memory{pc: Memory.rom_start(), rom: words}

    instructions = [
      {:mov, {:register, 1}, {:register, 4}, false},
      {:add, {:immediate, 2}, {:register, 4}, false},
      {:sub, {:immediate, 4}, {:register, 1}, false},
      {:mov, {:immediate, 0}, {:indexed, 4, 65530}, false},
      {:add, {:immediate, 1}, {:indexed, 4, 65530}, false},
      {:mov, {:indexed, 4, 65530}, {:indexed, 4, 65532}, false},
      {:mov, {:indexed, 4, 65532}, {:register, 15}, false},
      {:add, {:immediate, 4}, {:register, 1}, false}
    ]

    Enum.reduce(instructions, mem, fn expected_ins, mem ->
      {mem, ins} = Instruction.fetch_ins(mem)
      assert ins == expected_ins
      mem
    end)
  end

  test "load sample" do
    hex = [
      ":10C000005542200135D0085A8245000231400004D3",
      ":10C010003F4000000F9308249242000220012F832A",
      ":10C020009F4F64C00002F8233F4000000F93072495",
      ":10C030009242000220011F83CF430002F9230441F2",
      ":10C04000245321828443FAFF9453FAFF9444FAFF65",
      ":10C05000FCFF1F44FCFF215232D0F000FD3F304076",
      ":04C0600062C00013A7",
      ":10FFE0005EC05EC05EC05EC05EC05EC05EC05EC021",
      ":10FFF0005EC05EC05EC05EC05EC05EC05EC000C06F",
      ":040000030000C00039",
      ":00000001FF"
    ]

    {:ok, words} = IntelHex.load(hex, Memory.rom_start())
    mem = %Memory{pc: Memory.rom_start(), rom: words}

    Stream.unfold(mem, fn mem ->
      {mem, ins} = Instruction.fetch_ins(mem)
      if elem(ins, 0) == :reti, do: nil, else: {ins, mem}
    end)
    |> Enum.to_list()
    |> IO.inspect()
  end
end
