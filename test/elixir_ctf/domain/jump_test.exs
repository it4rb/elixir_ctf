defmodule MSP430.JumpTest do
  alias MSP430.CPU
  alias MSP430.Memory
  alias TestUtils, as: TU

  use ExUnit.Case

  test "jl jmp" do
    # int a = 123, b = 0;
    # if (a > 124) b = 1; else b = 2;
    # return b;
    rom =
      TU.load_rom(%{
        0xC04E => 0x90B4,
        0xC050 => 0x007D,
        0xC052 => 0xFFFC,
        0xC054 => 0x3803,
        0xC056 => 0x4394,
        0xC058 => 0xFFFA,
        0xC05A => 0x3C02,
        0xC05C => 0x43A4,
        0xC05E => 0xFFFA
      })

    cpu = %CPU{
      memory: %Memory{
        pc: 0xC04E,
        sr: 0,
        r4: 0x1096,
        rom: rom,
        ram: TU.load_ram(%{0x1092 => 123, 0x1090 => 0})
      },
      ins_cnt: 0
    }

    cpu = CPU.exec_single(cpu)
    cpu = CPU.exec_single(cpu)
    cpu = CPU.exec_single(cpu)

    assert cpu == %CPU{
             memory: %Memory{
               pc: 0xC060,
               sr: 4,
               r4: 0x1096,
               rom: rom,
               ram: TU.load_ram(%{0x1092 => 123, 0x1090 => 2})
             },
             ins_cnt: 3
           }

    # same prog but a=125
    cpu = %CPU{
      memory: %Memory{
        pc: 0xC04E,
        sr: 0,
        r4: 0x1096,
        rom: rom,
        ram: TU.load_ram(%{0x1092 => 125, 0x1090 => 0})
      },
      ins_cnt: 0
    }

    cpu = CPU.exec_single(cpu)
    cpu = CPU.exec_single(cpu)
    cpu = CPU.exec_single(cpu)
    cpu = CPU.exec_single(cpu)

    assert cpu == %CPU{
             memory: %Memory{
               pc: 0xC060,
               # both Z and C
               sr: 3,
               r4: 0x1096,
               rom: rom,
               ram: TU.load_ram(%{0x1092 => 125, 0x1090 => 1})
             },
             ins_cnt: 4
           }
  end

  test "jge" do
    # int a = 123, b = 0;
    # if (a < 0) b = 1; else b = 2;
    # return b;
    rom =
      TU.load_rom(%{
        0xC04E => 0x9384,
        0xC050 => 0xFFFC,
        0xC052 => 0x3403,
        0xC054 => 0x4394,
        0xC056 => 0xFFFA,
        0xC058 => 0x3C02,
        0xC05A => 0x43A4,
        0xC05C => 0xFFFA
      })

    cpu = %CPU{
      memory: %Memory{
        pc: 0xC04E,
        sr: 0,
        r4: 0x1096,
        rom: rom,
        ram: TU.load_ram(%{0x1092 => 123, 0x1090 => 0})
      },
      ins_cnt: 0
    }

    cpu = CPU.exec_single(cpu)
    cpu = CPU.exec_single(cpu)
    cpu = CPU.exec_single(cpu)

    assert cpu == %CPU{
             memory: %Memory{
               pc: 0xC05E,
               sr: 0,
               r4: 0x1096,
               rom: rom,
               ram: TU.load_ram(%{0x1092 => 123, 0x1090 => 2})
             },
             ins_cnt: 3
           }
  end

  test "jnz" do
    # int a = 123, b = 0;
    # if (a == 0) b = 1; else b = 2;
    # return b;
    rom =
      TU.load_rom(%{
        0xC04E => 0x9384,
        0xC050 => 0xFFFC,
        0xC052 => 0x2003,
        0xC054 => 0x4394,
        0xC056 => 0xFFFA,
        0xC058 => 0x3C02,
        0xC05A => 0x43A4,
        0xC05C => 0xFFFA
      })

    cpu = %CPU{
      memory: %Memory{
        pc: 0xC04E,
        sr: 0,
        r4: 0x1096,
        rom: rom,
        ram: TU.load_ram(%{0x1092 => 123, 0x1090 => 0})
      },
      ins_cnt: 0
    }

    cpu = CPU.exec_single(cpu)
    cpu = CPU.exec_single(cpu)
    cpu = CPU.exec_single(cpu)

    assert cpu == %CPU{
             memory: %Memory{
               pc: 0xC05E,
               sr: 0,
               r4: 0x1096,
               rom: rom,
               ram: TU.load_ram(%{0x1092 => 123, 0x1090 => 2})
             },
             ins_cnt: 3
           }
  end
end
