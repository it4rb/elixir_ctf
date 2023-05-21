defmodule MSP430.Instruction do
  require Logger
  import Bitwise
  alias MSP430
  alias MSP430.Memory

  # Format 1: dual-operand
  @type instruction ::
          {:mov, Memory.address(), Memory.address(), boolean()}
          | {:add, Memory.address(), Memory.address(), boolean()}
          | {:addc, Memory.address(), Memory.address(), boolean}
          | {:sub, Memory.address(), Memory.address(), boolean}
          | {:subc, Memory.address(), Memory.address(), boolean}
          | {:cmp, Memory.address(), Memory.address(), boolean}
          | {:dadd, Memory.address(), Memory.address(), boolean}
          | {:bit, Memory.address(), Memory.address(), boolean}
          | {:bic, Memory.address(), Memory.address(), boolean}
          | {:bis, Memory.address(), Memory.address(), boolean}
          | {:xor, Memory.address(), Memory.address(), boolean}
          | {:and, Memory.address(), Memory.address(), boolean}
          # Format 2: single-operand
          | {:rrc, Memory.address(), boolean}
          | {:rra, Memory.address(), boolean}
          | {:push, Memory.address(), boolean}
          | {:swpb, Memory.address(), boolean}
          | {:call, Memory.address(), boolean}
          | {:reti, Memory.address(), boolean}
          | {:sxt, Memory.address(), boolean}
          # Format 3: Jump
          | {:jeq, Memory.address_symbolic()}
          | {:jne, Memory.address_symbolic()}
          | {:jc, Memory.address_symbolic()}
          | {:jnc, Memory.address_symbolic()}
          | {:jn, Memory.address_symbolic()}
          | {:jge, Memory.address_symbolic()}
          | {:jl, Memory.address_symbolic()}
          | {:jmp, Memory.address_symbolic()}

  @spec next_ins_word(Memory.t()) :: {Memory.t(), MSP430.word()}
  def next_ins_word(mem) do
    ins_word = Memory.read_raw_word(mem, mem.pc)
    mem = %{mem | pc: mem.pc + 2}
    {mem, ins_word}
  end

  @spec fetch_ins(Memory.t()) :: {Memory.t(), instruction()}
  def fetch_ins(mem) do
    {mem, header} = next_ins_word(mem)

    <<fmt1_op::4, _r::bitstring>> = <<header::16>>
    <<fmt2_op::9, _r::bitstring>> = <<header::16>>
    <<fmt3_op_cond::6, _r::bitstring>> = <<header::16>>
    fmt1_op = fmt1_op <<< 12
    fmt2_op = fmt2_op <<< 7
    fmt3_op_cond = fmt3_op_cond <<< 10

    case {fmt2_op, fmt3_op_cond, fmt1_op} do
      {0x01000, _, _} -> decode_format2(mem, header, :rrc)
      {0x01080, _, _} -> decode_format2(mem, header, :swpb)
      {0x01100, _, _} -> decode_format2(mem, header, :rra)
      {0x01180, _, _} -> decode_format2(mem, header, :sxt)
      {0x01200, _, _} -> decode_format2(mem, header, :push)
      {0x01280, _, _} -> decode_format2(mem, header, :call)
      {0x01300, _, _} -> decode_format2(mem, header, :reti)
      {_, 0x2000, _} -> decode_format3(mem, header, :jne)
      {_, 0x2400, _} -> decode_format3(mem, header, :jeq)
      {_, 0x2800, _} -> decode_format3(mem, header, :jnc)
      {_, 0x2C00, _} -> decode_format3(mem, header, :jc)
      {_, 0x3000, _} -> decode_format3(mem, header, :jn)
      {_, 0x3400, _} -> decode_format3(mem, header, :jge)
      {_, 0x3800, _} -> decode_format3(mem, header, :jl)
      {_, 0x3C00, _} -> decode_format3(mem, header, :jmp)
      {_, _, 0x04000} -> decode_format1(mem, header, :mov)
      {_, _, 0x05000} -> decode_format1(mem, header, :add)
      {_, _, 0x06000} -> decode_format1(mem, header, :addc)
      {_, _, 0x07000} -> decode_format1(mem, header, :subc)
      {_, _, 0x08000} -> decode_format1(mem, header, :sub)
      {_, _, 0x09000} -> decode_format1(mem, header, :cmp)
      {_, _, 0x0A000} -> decode_format1(mem, header, :dadd)
      {_, _, 0x0B000} -> decode_format1(mem, header, :bit)
      {_, _, 0x0C000} -> decode_format1(mem, header, :bic)
      {_, _, 0x0D000} -> decode_format1(mem, header, :bis)
      {_, _, 0x0E000} -> decode_format1(mem, header, :xor)
      {_, _, 0x0F000} -> decode_format1(mem, header, :and)
      _ -> {mem, invalid_ins_reset(header)}
    end
  end

  defp invalid_ins_reset(header) do
    if header != nil, do: Logger.error(invalid_ins_header: header)
    {:mov, {:absolute, Memory.reset_addr()}, {:register, 0}, false}
  end

  @spec decode_format1(Memory.t(), integer, any) :: {Memory.t(), instruction}
  defp decode_format1(mem, header, ins_type) do
    <<_op::4, src_reg::4, dst_adr_mode::1, is_byte_bit::1, src_adr_mode::2, dst_reg::4>> =
      <<header::16>>

    is_byte = is_byte_bit == 1

    {mem, src} = decode_adr_mode(mem, src_adr_mode, src_reg)
    {mem, dst} = decode_adr_mode(mem, dst_adr_mode, dst_reg)
    {mem, {ins_type, src, dst, is_byte}}
  end

  @spec decode_format2(Memory.t(), integer, any) :: {Memory.t(), instruction}
  defp decode_format2(mem, header, ins_type) do
    <<_op::9, is_byte_bit::1, dst_adr_mode::2, dst_reg::4>> = <<header::16>>
    is_byte = is_byte_bit == 1
    {mem, adr} = decode_adr_mode(mem, dst_adr_mode, dst_reg)
    {mem, {ins_type, adr, is_byte}}
  end

  @spec decode_format3(Memory.t(), integer, any) :: {Memory.t(), instruction}
  defp decode_format3(mem, header, ins_type) do
    <<_op::3, _c::3, offset_s::1, offset_v::9>> = <<header::16>>
    # offset can be negative (10 bit)
    offset = if offset_s == 0, do: offset_v, else: offset_v - 512
    # here PC already got increased, so no need to +2
    dst = mem.pc + offset * 2 &&& 0xFFFF
    Logger.debug(jump: {ins_type, mem.pc, offset, dst})
    {mem, {ins_type, {:absolute, dst}}}
  end

  @spec decode_adr_mode(Memory.t(), MSP430.word(), MSP430.word()) ::
          {Memory.t(), Memory.address()}
  defp decode_adr_mode(mem, adr_mode, reg) do
    case adr_mode do
      # CG2 00
      0 when reg == 3 ->
        {mem, {:immediate, 0}}

      # Rn
      0 ->
        {mem, {:register, reg}}

      # ADDR
      1 when reg == 0 ->
        cur_pc = mem.pc
        {mem, nxt} = next_ins_word(mem)
        {mem, {:absolute, rem(cur_pc + nxt, 0x10000)}}

      # &ADDR
      1 when reg == 2 ->
        {mem, nxt} = next_ins_word(mem)
        {mem, {:absolute, nxt}}

      # CG2 01
      1 when reg == 3 ->
        {mem, {:immediate, 1}}

      # X(Rn)
      1 ->
        {mem, nxt} = next_ins_word(mem)
        {mem, {:indexed, reg, nxt}}

      # CG1 10
      2 when reg == 2 ->
        {mem, {:immediate, 4}}

      # CG2 10
      2 when reg == 3 ->
        {mem, {:immediate, 2}}

      # @Rn
      2 ->
        {mem, {:indirect_register, reg}}

      # #N (use @PC+)
      3 when reg == 0 ->
        {mem, nxt} = next_ins_word(mem)
        {mem, {:immediate, nxt}}

      # CG1 11
      3 when reg == 2 ->
        {mem, {:immediate, 8}}

      # CG2 11
      3 when reg == 3 ->
        {mem, {:immediate, 0x0FFFF}}

      # @Rn+
      3 ->
        {mem, {:indirect_auto_inc, reg}}
    end
  end
end
