defmodule MSP430.FlagTest do
  alias MSP430.CPU
  alias MSP430.Memory
  alias TestUtils, as: TU

  use ExUnit.Case

  test "C flag: ADD" do
    # long a = 0xffff; // long is 4bytes
    # a += 0x40003;
    # return a;
    mem = %Memory{sr: 0, ram: TU.load_ram(%{0x1090 => 0xFFFF, 0x1092 => 0})}
    mem = CPU.exec_ins(mem, {:add, {:immediate, 3}, {:absolute, 0x1090}, false})
    mem = CPU.exec_ins(mem, {:addc, {:immediate, 4}, {:absolute, 0x1092}, false})
    assert mem == %Memory{sr: 0, ram: TU.load_ram(%{0x1090 => 0x2, 0x1092 => 0x5})}

    # long long a = 0x1ffffffff;
    # a += 0x400020003;
    # return a; // 0x600020002
    mem = %Memory{
      sr: 0,
      ram: TU.load_ram(%{0x1090 => 0xFFFF, 0x1092 => 0xFFFF, 0x1094 => 1, 0x1096 => 0})
    }

    mem = CPU.exec_ins(mem, {:add, {:immediate, 3}, {:absolute, 0x1090}, false})
    mem = CPU.exec_ins(mem, {:addc, {:immediate, 2}, {:absolute, 0x1092}, false})
    mem = CPU.exec_ins(mem, {:addc, {:immediate, 4}, {:absolute, 0x1094}, false})
    mem = CPU.exec_ins(mem, {:addc, {:immediate, 0}, {:absolute, 0x1096}, false})

    assert mem == %Memory{
             # Z flag
             sr: 2,
             ram: TU.load_ram(%{0x1090 => 0x2, 0x1092 => 0x2, 0x1094 => 6, 0x1096 => 0})
           }
  end

  test "C flag: ADD.B" do
    mem = %Memory{sr: 0, r15: 0, ram: TU.load_ram(%{0x1090 => 0xFFFF})}
    mem = CPU.exec_ins(mem, {:mov, {:absolute, 0x1090}, {:register, 15}, true})
    mem = CPU.exec_ins(mem, {:add, {:immediate, 3}, {:register, 15}, true})
    assert mem == %Memory{sr: 1, r15: 0x2, ram: TU.load_ram(%{0x1090 => 0xFFFF})}
  end

  test "N flag: SUB" do
    mem = %Memory{sr: 0, ram: TU.load_ram(%{0x1090 => 123})}
    mem = CPU.exec_ins(mem, {:sub, {:immediate, 125}, {:absolute, 0x1090}, false})
    # should have N flag
    assert mem == %Memory{sr: 4, ram: TU.load_ram(%{0x1090 => 0x10000 - 2})}

    # add back should give original
    mem = CPU.exec_ins(mem, {:add, {:immediate, 125}, {:absolute, 0x1090}, false})
    # here we have C flag because C only care about word level
    assert mem == %Memory{sr: 1, ram: TU.load_ram(%{0x1090 => 123})}
  end

  test "N flag: SUB.B" do
    mem = %Memory{sr: 0, ram: TU.load_ram(%{0x1090 => 123})}
    mem = CPU.exec_ins(mem, {:sub, {:immediate, 125}, {:absolute, 0x1090}, true})
    assert mem == %Memory{sr: 4, ram: TU.load_ram(%{0x1090 => 0x100 - 2})}

    mem = CPU.exec_ins(mem, {:add, {:immediate, 125}, {:absolute, 0x1090}, true})
    assert mem == %Memory{sr: 1, ram: TU.load_ram(%{0x1090 => 123})}
  end

  test "V flag: ADD" do
    mem = %Memory{sr: 0, ram: TU.load_ram(%{0x1090 => 3})}
    mem = CPU.exec_ins(mem, {:add, {:immediate, 0x7FFF}, {:absolute, 0x1090}, false})
    # should have V flag (also N)
    assert mem == %Memory{sr: 0x104, ram: TU.load_ram(%{0x1090 => 0x10000 - 0x7FFE})}

    # subtract back should give original and V flag (but not N)
    mem = CPU.exec_ins(mem, {:sub, {:immediate, 0x7FFF}, {:absolute, 0x1090}, false})
    # here we have C
    assert mem == %Memory{sr: 0x101, ram: TU.load_ram(%{0x1090 => 3})}
  end

  test "V flag: ADD.B" do
    # 3 is in high byte (0x1091)
    mem = %Memory{sr: 0, ram: TU.load_ram(%{0x1090 => 0x300})}
    mem = CPU.exec_ins(mem, {:add, {:immediate, 0x7F}, {:absolute, 0x1091}, true})
    # should have V flag (also N)
    assert mem == %Memory{sr: 0x104, ram: TU.load_ram(%{0x1090 => (0x100 - 0x7E) * 256})}

    # subtract back should give original and V flag (but not N)
    mem = CPU.exec_ins(mem, {:sub, {:immediate, 0x7F}, {:absolute, 0x1091}, true})
    # here we have C
    assert mem == %Memory{sr: 0x101, ram: TU.load_ram(%{0x1090 => 0x300})}
  end
end
