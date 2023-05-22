defmodule MSP430.CallTest do
  alias MSP430.CPU
  alias MSP430.Memory
  alias MSP430.IntelHex

  use ExUnit.Case

  test "Call" do
    # int x(int a) {
    #   return a + 10;
    # }
    #
    # int main() {
    #   int a = 123, b = 0;
    #   if (a == 0) b = 1; else b = 2;
    #   int c = x(b);
    #   return c;
    # }
    hex = [
      ":10C000005542200135D0085A8245000231400004D3",
      ":10C010003F4000000F9308249242000220012F832A",
      ":10C020009F4F9AC00002F8233F4000000F9307245F",
      ":10C030009242000220011F83CF430002F9230441F2",
      ":10C0400024533150FAFFB4407B00FAFF8443F8FFD9",
      ":10C050008493FAFF03209443F8FF023CA443F8FFC3",
      ":10C060001F44F8FFB0127EC0844FFCFF1F44FCFF4A",
      ":10C070003150060032D0F000FD3F304098C004122D",
      ":10C08000044124532183844FFCFF1F44FCFF3F5095",
      ":0AC090000A0021533441304100132F",
      ":10FFE0007AC07AC07AC07AC07AC07AC07AC07AC041",
      ":10FFF0007AC07AC07AC07AC07AC07AC07AC000C0AB",
      ":040000030000C00039",
      ":00000001FF"
    ]

    {:ok, words} = IntelHex.load(hex, Memory.rom_start())
    mem = Memory.init(words)
    cpu = %CPU{memory: mem, ins_cnt: 0}
    {:ok, cpu} = CPU.exec_continuously(cpu)

    assert CPU.is_on(cpu) == false
    assert cpu.memory.r15 == 12
  end
end
