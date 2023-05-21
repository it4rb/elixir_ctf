defmodule MSP430.GetsTest do
  alias MSP430.CPU
  alias MSP430.Memory
  alias MSP430.IntelHex
  require Logger

  use ExUnit.Case

  defp run_with_input(input, expected_in_mem) do
    # static void __attribute__((section ("int_section"))) INT (int arg, ...) {}
    #
    # void gets(char* buf, unsigned int length) {
    #   INT(2, buf, length);
    # }
    #
    # int main() {
    #   char pwd[10];
    #   gets(pwd, 10);
    #   return 10;
    # }

    hex = [
      ":10C000005542200135D0085A8245000231400004D3",
      ":10C010003F4000000F9308249242000220012F832A",
      ":10C020009F4F90C00002F8233F4000000F93072469",
      ":10C030009242000220011F83CF430002F9230441F2",
      ":10C0400024533150F6FF3E400A000F443F50F4FFA6",
      ":10C05000B01266C03F400A0031500A0032D0F000F2",
      ":10C06000FD3F30408EC00412044124532182844F8E",
      ":10C07000FAFF844EFCFF1412FCFF1412FAFF231285",
      ":10C08000B01200FF315006002152344130410013FC",
      ":0AFF0000041204412453344130413F",
      ":10FFE00062C062C062C062C062C062C062C062C001",
      ":10FFF00062C062C062C062C062C062C062C000C053",
      ":040000030000C00039",
      ":00000001FF"
    ]

    {:ok, words} = IntelHex.load(hex, Memory.rom_start())
    mem = Memory.init(words)
    cpu = CPU.init(mem)
    cpu = CPU.exec_continuously(cpu)

    assert cpu.require_input == true
    cpu = CPU.provide_input(cpu, input)
    cpu = CPU.exec_continuously(cpu)

    assert CPU.is_on(cpu) == false
    assert cpu.memory.r15 == 10
    Logger.debug(ram: cpu.memory.ram, r4: cpu.memory.r4)

    buf_adr = cpu.memory.r4 - 12

    i =
      String.codepoints(expected_in_mem)
      |> Enum.reduce(0, fn c, i ->
        {_, cc} = Memory.read_byte(cpu.memory, {:absolute, buf_adr + i})
        <<ci>> = c
        assert cc == ci
        i + 1
      end)

    assert elem(Memory.read_byte(cpu.memory, {:absolute, buf_adr + i}), 1) == 0
  end

  test "gets" do
    run_with_input("abcd", "abcd")
    run_with_input("", "")
    run_with_input("123456789abcd", "123456789")
  end
end
