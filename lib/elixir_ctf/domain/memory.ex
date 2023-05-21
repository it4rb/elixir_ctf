defmodule MSP430 do
  @type word :: integer()
end

defmodule MSP430.Memory do
  require Logger
  import Bitwise
  alias MSP430

  defstruct [
    :pc,
    :sp,
    :sr,
    :r4,
    :r5,
    :r6,
    :r7,
    :r8,
    :r9,
    :r10,
    :r11,
    :r12,
    :r13,
    :r14,
    :r15,
    :rom,
    :ram
  ]

  @type t :: %__MODULE__{
          pc: integer(),
          sp: integer(),
          sr: integer(),
          r4: integer,
          r5: integer,
          r6: integer,
          r7: integer,
          r8: integer,
          r9: integer,
          r10: integer,
          r11: integer,
          r12: integer,
          r13: integer,
          r14: integer,
          r15: integer,
          rom: map,
          ram: map
        }

  # 16KB Flash, 512B SRAM
  # @ram_size 256
  # 16KB Flash, 16kB SRAM
  @ram_size 8192
  @rom_size 8 * 1024
  @ram_start 0x00200
  @ram_end @ram_start + 2 * @ram_size
  @rom_end 0x10000
  @rom_start @rom_end - 2 * @rom_size
  @reset_addr 0x0FFFE

  @type reg_no :: 0..15
  @type offset :: integer()
  @type raw_addr :: integer()

  # we'll need to add pc and offset together to form raw address right at decoding time
  # so symbolic mode will become absolute mode
  @type address_symbolic :: {:absolute, raw_addr}

  @type address ::
          {:register, reg_no()}
          | {:indexed, reg_no(), offset()}
          | address_symbolic
          | {:absolute, raw_addr}
          | {:indirect_register, reg_no()}
          | {:indirect_auto_inc, reg_no()}
          | {:immediate, MSP430.word()}

  @spec read_raw_word(t(), MSP430.word()) :: MSP430.word()
  def read_raw_word(mem, addr) do
    Logger.debug(memory_access: Integer.to_string(addr, 16))

    case addr do
      x when x >= 0 and x < @ram_start ->
        # no SFR/peripheral for now
        0

      x when x >= @ram_start and x < @ram_end ->
        Map.get(mem.ram, div(x - @ram_start, 2), 0)

      x when x >= @rom_start and x < @rom_end ->
        Map.get(mem.rom, div(x - @rom_start, 2), 0)

      x ->
        Logger.error(invalid_access: x)
        0
    end
  end

  @spec read_word(t, address) :: {t, MSP430.word()}
  def read_word(mem, addr) do
    case addr do
      {:register, reg_no} ->
        {mem, read_reg(mem, reg_no)}

      {:indexed, reg_no, offset} ->
        raw_adr = read_reg(mem, reg_no) + offset
        raw_adr = raw_adr &&& 0xFFFF
        {mem, read_raw_word(mem, raw_adr)}

      {:absolute, addr} ->
        {mem, read_raw_word(mem, addr)}

      {:indirect_register, reg_no} ->
        {mem, read_raw_word(mem, read_reg(mem, reg_no))}

      {:indirect_auto_inc, reg_no} ->
        reg = read_reg(mem, reg_no)
        mem = write_reg(mem, reg_no, reg + 2)
        {mem, read_raw_word(mem, reg)}

      {:immediate, value} ->
        {mem, value}
    end
  end

  defp extract_byte(word, adr) do
    if rem(adr, 2) == 0, do: word &&& 0xFF, else: (word &&& 0xFF00) >>> 8
  end

  @spec read_byte(t, address) :: {t, byte()}
  def read_byte(mem, addr) do
    case addr do
      {:register, reg_no} ->
        {mem, read_reg(mem, reg_no) &&& 0xFF}

      {:indexed, reg_no, offset} ->
        raw_adr = read_reg(mem, reg_no) + offset
        raw_adr = raw_adr &&& 0xFFFF
        {mem, extract_byte(read_raw_word(mem, raw_adr), raw_adr)}

      {:absolute, addr} ->
        {mem, extract_byte(read_raw_word(mem, addr), addr)}

      {:indirect_register, reg_no} ->
        raw_adr = read_reg(mem, reg_no)
        {mem, extract_byte(read_raw_word(mem, raw_adr), raw_adr)}

      {:indirect_auto_inc, reg_no} ->
        reg = read_reg(mem, reg_no)
        mem = write_reg(mem, reg_no, reg + 1)
        {mem, extract_byte(read_raw_word(mem, reg), reg)}

      {:immediate, value} ->
        {mem, value &&& 0xFF}
    end
  end

  @spec write_word(t, address, MSP430.word()) :: t
  def write_word(mem, addr, value) do
    case addr do
      {:register, reg_no} ->
        write_reg(mem, reg_no, value)

      {:indexed, reg_no, offset} ->
        addr = read_reg(mem, reg_no) + offset
        addr = addr &&& 0xFFFF
        write_ram(mem, addr, value)

      {:absolute, addr} ->
        write_ram(mem, addr, value)

      _ ->
        Logger.error(invalid_dst_address_mode: addr)
        mem
    end
  end

  defp set_byte(word, byte, adr) do
    if rem(adr, 2) == 0, do: (word &&& 0xFF00) + byte, else: (word &&& 0xFF) + (byte <<< 8)
  end

  @spec write_byte(t, address, byte()) :: t
  def write_byte(mem, addr, value) do
    case addr do
      {:register, reg_no} ->
        write_reg(mem, reg_no, value)

      {:indexed, reg_no, offset} ->
        raw_adr = read_reg(mem, reg_no) + offset
        raw_adr = raw_adr &&& 0xFFFF
        word = read_raw_word(mem, raw_adr)
        write_ram(mem, raw_adr, set_byte(word, value, raw_adr))

      {:absolute, addr} ->
        word = read_raw_word(mem, addr)
        write_ram(mem, addr, set_byte(word, value, addr))

      _ ->
        Logger.error(invalid_dst_address_mode: addr)
        mem
    end
  end

  defp write_ram(mem, addr, value) do
    %{mem | ram: Map.put(mem.ram, div(addr - @ram_start, 2), value)}
  end

  defp read_reg(mem, reg_no) do
    case reg_no do
      0 -> mem.pc
      1 -> mem.sp
      2 -> mem.sr
      4 -> mem.r4
      5 -> mem.r5
      6 -> mem.r6
      7 -> mem.r7
      8 -> mem.r8
      9 -> mem.r9
      10 -> mem.r10
      11 -> mem.r11
      12 -> mem.r12
      13 -> mem.r13
      14 -> mem.r14
      15 -> mem.r15
    end
  end

  defp write_reg(mem, reg_no, value) do
    case reg_no do
      0 -> %{mem | pc: value}
      1 -> %{mem | sp: value}
      2 -> %{mem | sr: value}
      4 -> %{mem | r4: value}
      5 -> %{mem | r5: value}
      6 -> %{mem | r6: value}
      7 -> %{mem | r7: value}
      8 -> %{mem | r8: value}
      9 -> %{mem | r9: value}
      10 -> %{mem | r10: value}
      11 -> %{mem | r11: value}
      12 -> %{mem | r12: value}
      13 -> %{mem | r13: value}
      14 -> %{mem | r14: value}
      15 -> %{mem | r15: value}
    end
  end

  @spec ram_start :: integer()
  def ram_start, do: @ram_start
  @spec rom_start :: integer()
  def rom_start, do: @rom_start
  @spec reset_addr :: integer()
  def reset_addr, do: @reset_addr
end
