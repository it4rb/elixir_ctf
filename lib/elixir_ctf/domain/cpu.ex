defmodule MSP430.CPU do
  require Logger
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
      end

    mem
  end

  defp exec_format1(mem, src, dst, is_byte, calc_fn) do
    {mem, src_val} = if is_byte, do: Memory.read_byte(mem, src), else: Memory.read_word(mem, src)

    # the only mode that modified mem is indirect_auto_inc
    # but that's not valid for dst, so we're safe here
    {_, dst_val} = if is_byte, do: Memory.read_byte(mem, dst), else: Memory.read_word(mem, dst)

    {res, flags} = calc_fn.(src_val, dst_val)
    Logger.debug(src: src, dst: dst, src_val: src_val, dst_val: dst_val, res: res, flags: flags)

    if res != nil do
      if is_byte,
        do: Memory.write_byte(mem, dst, res),
        else: Memory.write_word(mem, dst, res)
    else
      mem
    end
  end
end
