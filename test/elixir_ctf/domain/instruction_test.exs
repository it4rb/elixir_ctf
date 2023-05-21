defmodule MSP430.InstructionTest do
  alias MSP430.Memory
  alias MSP430.Instruction

  use ExUnit.Case

  defp fake_decode(words) do
    {ram, _} =
      List.foldl(words, {%{}, 0}, fn word, {ram, idx} -> {Map.put(ram, idx, word), idx + 1} end)

    mem = %Memory{pc: Memory.ram_start(), ram: ram}
    {_, ins} = Instruction.fetch_ins(mem)
    ins
  end

  test "decode" do
    pc = Memory.ram_start()
    assert fake_decode([0x01085]) == {:swpb, {:register, 5}, false}
    assert fake_decode([0x0F546]) == {:and, {:register, 5}, {:register, 6}, true}
    assert fake_decode([0x012B5]) == {:call, {:indirect_auto_inc, 5}, false}
    assert fake_decode([0x012A5]) == {:call, {:indirect_register, 5}, false}
    assert fake_decode([0x01290, 0x02]) == {:call, {:absolute, 0x02 + pc + 2}, false}
    assert fake_decode([0x01295, 0x03]) == {:call, {:indexed, 5, 0x03}, false}
    assert fake_decode([0x0E5A2, 0x01]) == {:xor, {:indirect_register, 5}, {:absolute, 1}, false}

    assert fake_decode([0x050B0, 0x21, 0x02]) ==
             {:add, {:immediate, 33}, {:absolute, 0x02 + pc + 4}, false}

    assert fake_decode([0x04292, 0x01, 0x02]) == {:mov, {:absolute, 1}, {:absolute, 0x02}, false}

    # ADD #1, R6 ==> ADD 0(R3) R6
    assert fake_decode([0x05316]) == {:add, {:immediate, 1}, {:register, 6}, false}
    # ADD #2, R6 ==> ADD @R3 R6
    assert fake_decode([0x05326]) == {:add, {:immediate, 2}, {:register, 6}, false}

    assert fake_decode([0x03C03]) == {:jmp, {:absolute, 3 * 2 + 2 + pc}}
    assert fake_decode([0x2004]) == {:jne, {:absolute, 4 * 2 + 2 + pc}}

    # from level Tutorial:
    #   4414:  0724           jz	$+0x10 <__do_clear_bss+0x0>
    #   4424 <__do_clear_bss>
    assert fake_decode([0x2407]) == {:jeq, {:absolute, 0x10 + pc}}

    assert fake_decode([0x04596, 0x00002, 0x00006]) ==
             {:mov, {:indexed, 5, 2}, {:indexed, 6, 6}, false}
  end
end
