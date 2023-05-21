defmodule MSP430.ArithmeticTest do
  alias MSP430.CPU
  alias MSP430.Memory
  alias TestUtils, as: TU

  use ExUnit.Case

  test "DADD (sub)" do
    # spec page 3-63 (for SETC ins, simulate decimal subtract 0x04137 - 0x03987 = 0x0150)
    mem = %Memory{sr: 0, r5: 0x03987, r6: 0x04137}
    mem = CPU.exec_ins(mem, {:add, {:immediate, 0x06666}, {:register, 5}, false})
    # inv r5
    mem = CPU.exec_ins(mem, {:xor, {:immediate, 0x0FFFF}, {:register, 5}, false})
    # SETC
    mem = CPU.exec_ins(mem, {:bis, {:immediate, 1}, {:register, 2}, false})
    mem = CPU.exec_ins(mem, {:dadd, {:register, 5}, {:register, 6}, false})
    # V flag is set in XOR, C is from DADD
    assert mem == %Memory{sr: 256 + 1, r5: 0x06012, r6: 0x0150}
  end

  test "DADD" do
    mem = %Memory{sr: 0, r5: 0x03987, r6: 0x04137}
    mem = CPU.exec_ins(mem, {:dadd, {:register, 5}, {:register, 6}, false})
    # N flag
    assert mem == %Memory{sr: 4, r5: 0x03987, r6: 0x8124}
  end

  test "DADD.B" do
    mem = %Memory{sr: 0, r5: 0x03987, r6: 0x04137}
    mem = CPU.exec_ins(mem, {:dadd, {:register, 5}, {:register, 6}, true})
    # C flag
    assert mem == %Memory{sr: 1, r5: 0x03987, r6: 0x24}
  end

  test "BIT" do
    # N: Set if MSB of result is set, reset otherwise
    # Z: Set if result is zero, reset otherwise
    # C: Set if result is not zero, reset otherwise (.NOT. Zero)
    # V: Reset

    mem = %Memory{sr: 0, r5: 0x808F}
    mem = CPU.exec_ins(mem, {:bit, {:immediate, 0x8002}, {:register, 5}, false})
    # N,C flag
    assert mem == %Memory{sr: 5, r5: 0x808F}

    mem = CPU.exec_ins(mem, {:bit, {:immediate, 0x0F00}, {:register, 5}, false})
    # Z flag
    assert mem == %Memory{sr: 2, r5: 0x808F}

    mem = CPU.exec_ins(mem, {:bit, {:immediate, 0x82}, {:register, 5}, true})
    # N,C flag
    assert mem == %Memory{sr: 5, r5: 0x808F}

    mem = CPU.exec_ins(mem, {:bit, {:immediate, 0x70}, {:register, 5}, true})
    # Z flag
    assert mem == %Memory{sr: 2, r5: 0x808F}
  end

  test "BIC" do
    mem = %Memory{sr: 0, r5: 0x808F}
    mem = CPU.exec_ins(mem, {:bic, {:immediate, 0x8000}, {:register, 5}, false})
    assert mem == %Memory{sr: 0, r5: 0x008F}

    mem = CPU.exec_ins(mem, {:bic, {:immediate, 0x88}, {:register, 5}, true})
    assert mem == %Memory{sr: 0, r5: 0x0007}
  end

  test "BIS" do
    mem = %Memory{sr: 0xFE, r5: 0x808F}
    mem = CPU.exec_ins(mem, {:bis, {:immediate, 0x0060}, {:register, 5}, false})
    assert mem == %Memory{sr: 0xFE, r5: 0x80EF}

    mem = CPU.exec_ins(mem, {:bis, {:immediate, 0x10}, {:register, 5}, true})
    assert mem == %Memory{sr: 0xFE, r5: 0x00FF}
  end

  test "AND" do
    # N: Set if MSB of result is set, reset otherwise
    # Z: Set if result is zero, reset otherwise
    # C: Set if result is not zero, reset otherwise (.NOT. Zero)
    # V: Reset

    mem = %Memory{sr: 0, r5: 0x808F}
    mem = CPU.exec_ins(mem, {:and, {:immediate, 0x8002}, {:register, 5}, false})
    # N,C flag
    assert mem == %Memory{sr: 5, r5: 0x8002}

    mem = %Memory{sr: 0, r5: 0x808F}
    mem = CPU.exec_ins(mem, {:and, {:immediate, 0x0F00}, {:register, 5}, false})
    # Z flag
    assert mem == %Memory{sr: 2, r5: 0}

    mem = %Memory{sr: 0, r5: 0x808F}
    mem = CPU.exec_ins(mem, {:and, {:immediate, 0x82}, {:register, 5}, true})
    # N,C flag
    assert mem == %Memory{sr: 5, r5: 0x82}

    mem = %Memory{sr: 0, r5: 0x808F}
    mem = CPU.exec_ins(mem, {:and, {:immediate, 0x70}, {:register, 5}, true})
    # Z flag
    assert mem == %Memory{sr: 2, r5: 0}
  end

  test "RRC" do
    mem = %Memory{sr: 0, r5: 0x808F}
    mem = CPU.exec_ins(mem, {:rrc, {:register, 5}, false})
    assert mem == %Memory{sr: 1, r5: 0x4047}
    mem = CPU.exec_ins(mem, {:rrc, {:register, 5}, false})
    assert mem == %Memory{sr: 5, r5: 0xA023}

    mem = CPU.exec_ins(mem, {:rrc, {:register, 5}, true})
    assert mem == %Memory{sr: 5, r5: 0x91}
    mem = CPU.exec_ins(mem, {:rrc, {:register, 5}, true})
    assert mem == %Memory{sr: 5, r5: 0xC8}
    mem = CPU.exec_ins(mem, {:rrc, {:register, 5}, true})
    assert mem == %Memory{sr: 4, r5: 0xE4}
  end

  test "RRA" do
    mem = %Memory{sr: 0, r5: 0x808F}
    mem = CPU.exec_ins(mem, {:rra, {:register, 5}, false})
    assert mem == %Memory{sr: 5, r5: 0x8047}

    mem = CPU.exec_ins(mem, {:rra, {:register, 5}, true})
    assert mem == %Memory{sr: 1, r5: 0x23}
  end

  test "SWPB" do
    mem = %Memory{sr: 0, r5: 0x040BF}
    mem = CPU.exec_ins(mem, {:swpb, {:register, 5}, false})
    assert mem == %Memory{sr: 0, r5: 0b1011111101000000}

    mem = %Memory{sr: 0, r4: 0, r5: 12345}
    mem = CPU.exec_ins(mem, {:swpb, {:register, 5}, false})
    mem = CPU.exec_ins(mem, {:mov, {:register, 5}, {:register, 4}, false})
    mem = CPU.exec_ins(mem, {:bic, {:immediate, 0x0FF00}, {:register, 5}, false})
    mem = CPU.exec_ins(mem, {:bic, {:immediate, 0x00FF}, {:register, 4}, false})
    assert mem == %Memory{sr: 0, r5: 0x30, r4: 0x3900}
  end

  test "SXT" do
    mem = %Memory{sr: 0, r5: 0x080}
    mem = CPU.exec_ins(mem, {:sxt, {:register, 5}, false})
    assert mem == %Memory{sr: 5, r5: 0x0FF80}
  end

  test "PUSH" do
    mem = %Memory{sr: 0xF080, sp: 0x1094, ram: TU.load_ram(%{0x1090 => 0xFFFF})}
    mem = CPU.exec_ins(mem, {:push, {:register, 2}, false})

    assert mem == %Memory{
             sr: 0xF080,
             sp: 0x1092,
             ram: TU.load_ram(%{0x1090 => 0xFFFF, 0x1092 => 0xF080})
           }

    mem = CPU.exec_ins(mem, {:push, {:register, 2}, true})

    assert mem == %Memory{
             sr: 0xF080,
             sp: 0x1090,
             ram: TU.load_ram(%{0x1090 => 0x80, 0x1092 => 0xF080})
           }
  end
end
