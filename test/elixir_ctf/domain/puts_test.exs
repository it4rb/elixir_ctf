defmodule MSP430.PutsTest do
  alias MSP430.CPU
  alias MSP430.Memory
  alias MSP430.IntelHex

  use ExUnit.Case

  test "puts" do
    # #include <stdio.h>
    #
    # static void __attribute__((section ("int_section"))) INT (int arg, ...) {}
    #
    # int putchar(int c) {
    #   INT(0, c) ;
    #   return c;
    # }
    #
    # int main() {
    #   puts("hello world!");
    #   return 10;
    # }

    hex = [
      ":10C000005542200135D0085A8245000231400004D3",
      ":10C010003F4000000F9308249242000220012F832A",
      ":10C020009F4FB6C00002F8233F4000000F93072443",
      ":10C030009242000220011F83CF430002F9230441F2",
      ":10C0400024533F40A8C0B0127AC03F400A0032D00B",
      ":10C05000F000FD3F3040A6C0041204412453218368",
      ":10C06000844FFCFF1412FCFF0312B01200FF215298",
      ":10C070001F44FCFF2153344130410B120B4F6F4BD7",
      ":10C080004F9306241B538F11B01258C00F93F737EC",
      ":10C09000CB93000005203F400A00B01258C0013C7D",
      ":08C0A0003F433B413041001316",
      ":0EC0A80068656C6C6F20776F726C642100000D",
      ":0AFF0000041204412453344130413F",
      ":10FFE00054C054C054C054C054C054C054C054C071",
      ":10FFF00054C054C054C054C054C054C054C000C0B5",
      ":040000030000C00039",
      ":00000001FF"
    ]

    {:ok, words} = IntelHex.load(hex, Memory.rom_start())
    mem = Memory.init(words)
    cpu = CPU.init(mem)
    cpu = CPU.exec_continuously(cpu)

    assert CPU.is_on(cpu) == false
    assert cpu.memory.r15 == 10
    assert cpu.stdout == "hello world!\n"
  end
end
