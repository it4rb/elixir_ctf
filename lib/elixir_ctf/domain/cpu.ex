defmodule MSP430.CPU do
  require Logger
  import Bitwise
  alias MSP430.Instruction
  alias MSP430.Memory

  defstruct [:memory, :ins_cnt]

  @type t :: %__MODULE__{
          memory: Memory.t(),
          ins_cnt: integer
        }

  @spec init(Memory.t()) :: t
  def init(mem) do
    %__MODULE__{
      memory: mem,
      ins_cnt: 0
    }
  end

  @spec exec_single(t) :: t
  def exec_single(cpu) do
    mem = cpu.memory
    {mem, ins} = Instruction.fetch_ins(mem)
    Logger.debug(ins: ins)
    mem = exec_ins(mem, ins)
    %{cpu | memory: mem, ins_cnt: cpu.ins_cnt + 1}
  end

  @spec exec_ins(Memory.t(), Instruction.instruction()) :: Memory.t()
  def exec_ins(mem, ins) do
    mem =
      case ins do
        {:mov, src, dst, is_byte} ->
          exec_format1(mem, src, dst, is_byte, fn src_val, _ -> {src_val, %{}} end)

        {:add, src, dst, is_byte} ->
          exec_format1(mem, src, dst, is_byte, fn src_val, dst_val ->
            cap_and_calc_flag(is_byte, src_val, dst_val, src_val + dst_val)
          end)

        {:addc, src, dst, is_byte} ->
          exec_format1(mem, src, dst, is_byte, fn src_val, dst_val ->
            res = src_val + dst_val + Memory.get_flag(mem)[:c]
            cap_and_calc_flag(is_byte, src_val, dst_val, res)
          end)

        {:sub, src, dst, is_byte} ->
          exec_format1(mem, src, dst, is_byte, fn src_val, dst_val ->
            src_val = comp2(is_byte, src_val)
            cap_and_calc_flag(is_byte, src_val, dst_val, src_val + dst_val)
          end)
      end

    mem
  end

  defp comp2(is_byte, x) do
    x = Bitwise.bnot(x) + 1

    if is_byte do
      <<res::8>> = <<x::8>>
      res
    else
      <<res::16>> = <<x::16>>
      res
    end
  end

  defp cap_and_calc_flag(is_byte, src_val, dst_val, raw_res) do
    cap = if is_byte, do: 0xFF, else: 0xFFFF
    sign_cap = if is_byte, do: 0x7F, else: 0x7FFF
    {src_positive, dst_positive} = {src_val <= sign_cap, dst_val <= sign_cap}
    c = if raw_res > cap, do: 1, else: 0

    res = raw_res &&& cap
    res_positive = res <= sign_cap
    Logger.debug(cap_and_flag: {is_byte, src_val, dst_val, raw_res, res})

    v =
      if (src_positive && dst_positive && !res_positive) ||
           (!src_positive && !dst_positive && res_positive),
         do: 1,
         else: 0

    n = if is_byte, do: res >>> 7, else: res >>> 15
    z = if res == 0, do: 1, else: 0
    {res, %{v: v, n: n, z: z, c: c}}
  end

  defp exec_format1(mem, src, dst, is_byte, calc_fn) do
    {mem, src_val} = if is_byte, do: Memory.read_byte(mem, src), else: Memory.read_word(mem, src)

    # the only mode that modified mem is indirect_auto_inc
    # but that's not valid for dst, so we're safe here
    {_, dst_val} = if is_byte, do: Memory.read_byte(mem, dst), else: Memory.read_word(mem, dst)

    {res, flags} = calc_fn.(src_val, dst_val)
    Logger.debug(src: src, dst: dst, src_val: src_val, dst_val: dst_val, res: res, flags: flags)

    mem = Memory.set_flag(mem, flags)

    if res != nil do
      if is_byte,
        do: Memory.write_byte(mem, dst, res),
        else: Memory.write_word(mem, dst, res)
    else
      mem
    end
  end
end
