defmodule MSP430.AdrModeTest do
  alias MSP430.CPU
  alias MSP430.Memory
  alias TestUtils, as: TU

  use ExUnit.Case

  test "adr mode: reg" do
    mem = %Memory{r10: 0x0A023, r11: 0x0FA15}
    mem = CPU.exec_ins(mem, {:mov, {:register, 10}, {:register, 11}, false})
    assert mem == %Memory{r10: 0x0A023, r11: 0x0A023}
  end

  test "adr mode: indexed" do
    rom = TU.load_rom(%{0x0FF16 => 0x00006, 0x0FF14 => 0x0002, 0x0FF12 => 0x04596})

    cpu = %CPU{
      memory: %Memory{
        pc: 0x0FF12,
        r5: 0x01080,
        r6: 0x0108C,
        rom: rom,
        ram: TU.load_ram(%{0x01092 => 0x05555, 0x01082 => 0x01234})
      },
      ins_cnt: 0
    }

    assert CPU.exec_single(cpu) == %CPU{
             memory: %Memory{
               pc: 0x0FF18,
               r5: 0x01080,
               r6: 0x0108C,
               rom: rom,
               ram: TU.load_ram(%{0x01092 => 0x01234, 0x01082 => 0x01234})
             },
             ins_cnt: 1
           }
  end

  test "adr mode: symbolic" do
    rom =
      TU.load_rom(%{
        0x0FF16 => 0x011FE,
        0x0FF14 => 0x0F102,
        0x0FF12 => 0x04090,
        0x0F016 => 0x0A123
      })

    cpu = %CPU{
      memory: %Memory{pc: 0x0FF12, rom: rom, ram: TU.load_ram(%{0x01114 => 0x05555})},
      ins_cnt: 0
    }

    assert CPU.exec_single(cpu) == %CPU{
             memory: %Memory{pc: 0x0FF18, rom: rom, ram: TU.load_ram(%{0x01114 => 0x0A123})},
             ins_cnt: 1
           }
  end

  test "adr mode: absolute" do
    rom =
      TU.load_rom(%{
        0x0FF16 => 0x01114,
        0x0FF14 => 0x0F016,
        0x0FF12 => 0x04292,
        0x0F016 => 0x0A123
      })

    cpu = %CPU{
      memory: %Memory{pc: 0x0FF12, rom: rom, ram: TU.load_ram(%{0x01114 => 0x01234})},
      ins_cnt: 0
    }

    assert CPU.exec_single(cpu) == %CPU{
             memory: %{cpu.memory | pc: 0x0FF18, ram: TU.load_ram(%{0x01114 => 0x0A123})},
             ins_cnt: 1
           }
  end

  test "adr mode: indirect register" do
    rom = TU.load_rom(%{0x0FF16 => 0x0, 0x0FF14 => 0x04AEB, 0x0FA32 => 0x05BC1})

    cpu = %CPU{
      memory: %Memory{
        pc: 0x0FF14,
        r10: 0xFA33,
        r11: 0x2A7,
        rom: rom,
        ram: TU.load_ram(%{0x002A6 => 0x01201})
      },
      ins_cnt: 0
    }

    assert CPU.exec_single(cpu) == %CPU{
             memory: %{cpu.memory | pc: 0x0FF18, ram: TU.load_ram(%{0x002A6 => 0x05B01})},
             ins_cnt: 1
           }
  end

  test "adr mode: indirect auto increment" do
    rom = TU.load_rom(%{0x0FF16 => 0x0, 0x0FF14 => 0x04ABB, 0x0FA32 => 0x05BC1})

    cpu = %CPU{
      memory: %Memory{
        pc: 0x0FF14,
        r10: 0xFA32,
        r11: 0x10A8,
        rom: rom,
        ram: TU.load_ram(%{0x010A8 => 0x01234})
      },
      ins_cnt: 0
    }

    assert CPU.exec_single(cpu) == %CPU{
             memory: %{
               cpu.memory
               | pc: 0x0FF18,
                 r10: 0xFA34,
                 ram: TU.load_ram(%{0x010A8 => 0x05BC1})
             },
             ins_cnt: 1
           }
  end

  test "adr mode: immediate" do
    rom = TU.load_rom(%{0x0FF16 => 0x01192, 0x0FF14 => 0x00045, 0x0FF12 => 0x040B0})

    cpu = %CPU{
      memory: %Memory{pc: 0x0FF12, rom: rom, ram: TU.load_ram(%{0x010A8 => 0x01234})},
      ins_cnt: 0
    }

    assert CPU.exec_single(cpu) == %CPU{
             memory: %{cpu.memory | pc: 0x0FF18, ram: TU.load_ram(%{0x010A8 => 0x00045})},
             ins_cnt: 1
           }
  end
end
