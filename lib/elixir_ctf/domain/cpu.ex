defmodule MSP430.CPU do
  require Logger
  import Bitwise
  alias MSP430.Instruction
  alias MSP430.Memory

  defstruct [:memory, :ins_cnt, :stdout, :stdin, :require_input, :unlocked]

  @type t :: %__MODULE__{
          memory: Memory.t(),
          ins_cnt: integer,
          stdout: String.t(),
          stdin: String.t(),
          require_input: boolean(),
          unlocked: boolean()
        }
  @int_handle_adr 0xFF00

  @spec init(Memory.t()) :: t
  def init(mem) do
    %__MODULE__{
      memory: mem,
      ins_cnt: 0,
      stdout: "",
      stdin: "",
      require_input: false,
      unlocked: false
    }
  end

  @spec is_on(t) :: boolean
  def is_on(cpu), do: (cpu.memory.sr &&& 0x10) == 0

  @spec provide_input(t, String.t()) :: t
  def provide_input(cpu, input) do
    cpu = %{cpu | stdin: input}
    if cpu.memory.pc == @int_handle_adr, do: handle_int(cpu), else: cpu
  end

  @spec exec_continuously(t, MapSet.t(integer)) :: t
  def exec_continuously(cpu, breakpoints \\ MapSet.new()) do
    if is_on(cpu) && !cpu.require_input do
      cpu = exec_single(cpu)

      if MapSet.member?(breakpoints, cpu.memory.pc),
        do: cpu,
        else: exec_continuously(cpu, breakpoints)
    else
      cpu
    end
  end

  @spec exec_single(t) :: t
  def exec_single(cpu) do
    mem = cpu.memory
    {mem, ins} = Instruction.fetch_ins(mem)
    Logger.debug(ins: ins)
    mem = exec_ins(mem, ins)
    cpu = %{cpu | memory: mem, ins_cnt: cpu.ins_cnt + 1}
    if mem.pc == @int_handle_adr, do: handle_int(cpu), else: cpu
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

        {:subc, src, dst, is_byte} ->
          exec_format1(mem, src, dst, is_byte, fn src_val, dst_val ->
            src_val = comp2(is_byte, src_val)
            res = src_val + dst_val + Memory.get_flag(mem)[:c]
            cap_and_calc_flag(is_byte, src_val, dst_val, res)
          end)

        {:cmp, src, dst, is_byte} ->
          exec_format1(mem, src, dst, is_byte, fn src_val, dst_val ->
            src_val = comp2(is_byte, src_val)
            {_, flags} = cap_and_calc_flag(is_byte, src_val, dst_val, src_val + dst_val)
            {nil, flags}
          end)

        {:dadd, src, dst, is_byte} ->
          exec_format1(mem, src, dst, is_byte, fn src_val, dst_val ->
            dadd(is_byte, src_val, dst_val, Memory.get_flag(mem)[:c])
          end)

        {:bit, src, dst, is_byte} ->
          exec_format1(mem, src, dst, is_byte, fn src_val, dst_val ->
            {_, flags} = cap_and_calc_flag(is_byte, src_val, dst_val, src_val &&& dst_val)
            {nil, %{flags | c: 1 - flags[:z]}}
          end)

        {:bic, src, dst, is_byte} ->
          exec_format1(mem, src, dst, is_byte, fn src_val, dst_val ->
            {Bitwise.bnot(src_val) &&& dst_val, %{}}
          end)

        {:bis, src, dst, is_byte} ->
          exec_format1(mem, src, dst, is_byte, fn src_val, dst_val ->
            {src_val ||| dst_val, %{}}
          end)

        {:xor, src, dst, is_byte} ->
          exec_format1(mem, src, dst, is_byte, fn src_val, dst_val ->
            res = Bitwise.bxor(src_val, dst_val)
            cap_and_calc_flag(is_byte, src_val, dst_val, res)
          end)

        {:and, src, dst, is_byte} ->
          exec_format1(mem, src, dst, is_byte, fn src_val, dst_val ->
            {res, flags} = cap_and_calc_flag(is_byte, src_val, dst_val, src_val &&& dst_val)
            {res, %{flags | c: 1 - flags[:z]}}
          end)

        # format 2
        {:rrc, dst, is_byte} ->
          exec_format2(mem, dst, is_byte, fn dst_val ->
            lsb = dst_val &&& 1
            dst_val = dst_val >>> 1
            c = Memory.get_flag(mem)[:c]

            {dst_val, n} =
              if is_byte do
                <<dst_val::8>> = <<c::1, dst_val::7>>
                {dst_val, dst_val >>> 7}
              else
                <<dst_val::16>> = <<c::1, dst_val::15>>
                {dst_val, dst_val >>> 15}
              end

            z = if dst_val == 0, do: 1, else: 0
            {dst_val, %{v: 0, n: n, z: z, c: lsb}}
          end)

        {:rra, dst, is_byte} ->
          exec_format2(mem, dst, is_byte, fn dst_val ->
            lsb = dst_val &&& 1

            {dst_val, n} =
              if is_byte do
                <<msb::1, r::7>> = <<dst_val::8>>
                <<dst_val::8>> = <<msb::1, r >>> 1::7>>
                {dst_val, dst_val >>> 7}
              else
                <<msb::1, r::15>> = <<dst_val::16>>
                <<dst_val::16>> = <<msb::1, r >>> 1::15>>
                {dst_val, dst_val >>> 15}
              end

            z = if dst_val == 0, do: 1, else: 0
            {dst_val, %{v: 0, n: n, z: z, c: lsb}}
          end)

        {:swpb, dst, _} ->
          exec_format2(mem, dst, false, fn dst_val ->
            <<h::8, l::8>> = <<dst_val::16>>
            <<dst_val::16>> = <<l::8, h::8>>
            {dst_val, %{}}
          end)

        {:sxt, dst, _} ->
          exec_format2(mem, dst, false, fn dst_val ->
            <<_::8, s::1, l::7>> = <<dst_val::16>>
            <<dst_val::16>> = <<s::1, s::1, s::1, s::1, s::1, s::1, s::1, s::1, s::1, l::7>>
            z = if dst_val == 0, do: 1, else: 0
            c = if dst_val == 0, do: 0, else: 1
            {dst_val, %{v: 0, n: s, z: z, c: c}}
          end)

        {:push, dst, is_byte} ->
          {mem, dst_val} =
            if is_byte, do: Memory.read_byte(mem, dst), else: Memory.read_word(mem, dst)

          mem = %{mem | sp: mem.sp - 2}
          Memory.write_word(mem, {:indexed, 1, 0}, dst_val)

        {:call, dst, _} ->
          {mem, dst_val} = Memory.read_word(mem, dst)
          mem = %{mem | sp: mem.sp - 2}
          mem = Memory.write_word(mem, {:indexed, 1, 0}, mem.pc)
          %{mem | pc: dst_val}

        # format 3 (jump)
        {:jeq, {:absolute, target}} ->
          exec_format3(mem, target, Memory.get_flag(mem)[:z] == 1)

        {:jne, {:absolute, target}} ->
          exec_format3(mem, target, Memory.get_flag(mem)[:z] == 0)

        {:jc, {:absolute, target}} ->
          exec_format3(mem, target, Memory.get_flag(mem)[:c] == 1)

        {:jnc, {:absolute, target}} ->
          exec_format3(mem, target, Memory.get_flag(mem)[:c] == 0)

        {:jn, {:absolute, target}} ->
          exec_format3(mem, target, Memory.get_flag(mem)[:n] == 1)

        {:jge, {:absolute, target}} ->
          flags = Memory.get_flag(mem)
          exec_format3(mem, target, Bitwise.bxor(flags[:n], flags[:v]) == 0)

        {:jl, {:absolute, target}} ->
          flags = Memory.get_flag(mem)
          exec_format3(mem, target, Bitwise.bxor(flags[:n], flags[:v]) == 1)

        {:jmp, {:absolute, target}} ->
          exec_format3(mem, target, true)
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

  defp dadd(is_byte, src_val, dst_val, c) do
    if is_byte do
      <<sd1::4, sd0::4>> = <<src_val::8>>
      <<dd1::4, dd0::4>> = <<dst_val::8>>
      tmp = sd0 + dd0 + c
      {r0, c} = if tmp >= 10, do: {rem(tmp, 10), 1}, else: {tmp, 0}
      tmp = sd1 + dd1 + c
      {r1, c} = if tmp >= 10, do: {rem(tmp, 10), 1}, else: {tmp, 0}
      <<res::8>> = <<r1::4, r0::4>>
      n = res >>> 8
      z = if res == 0, do: 1, else: 0
      Logger.debug(src_val: src_val, dst_val: dst_val, res: res, r: {r1, r0})
      {res, %{n: n, z: z, c: c}}
    else
      <<sd3::4, sd2::4, sd1::4, sd0::4>> = <<src_val::16>>
      <<dd3::4, dd2::4, dd1::4, dd0::4>> = <<dst_val::16>>
      tmp = sd0 + dd0 + c
      {r0, c} = if tmp >= 10, do: {rem(tmp, 10), 1}, else: {tmp, 0}
      tmp = sd1 + dd1 + c
      {r1, c} = if tmp >= 10, do: {rem(tmp, 10), 1}, else: {tmp, 0}
      tmp = sd2 + dd2 + c
      {r2, c} = if tmp >= 10, do: {rem(tmp, 10), 1}, else: {tmp, 0}
      tmp = sd3 + dd3 + c
      {r3, c} = if tmp >= 10, do: {rem(tmp, 10), 1}, else: {tmp, 0}
      <<res::16>> = <<r3::4, r2::4, r1::4, r0::4>>
      n = res >>> 15
      z = if res == 0, do: 1, else: 0
      Logger.debug(src_val: src_val, dst_val: dst_val, res: res, r: {r3, r2, r1, r0})
      {res, %{n: n, z: z, c: c}}
    end
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

  defp exec_format2(mem, dst, is_byte, calc_fn) do
    {mem, dst_val} = if is_byte, do: Memory.read_byte(mem, dst), else: Memory.read_word(mem, dst)

    {res, flags} = calc_fn.(dst_val)
    Logger.debug(dst: dst, dst_val: dst_val, res: res, flags: flags)

    mem = Memory.set_flag(mem, flags)

    if res != nil do
      if is_byte,
        do: Memory.write_byte(mem, dst, res),
        else: Memory.write_word(mem, dst, res)
    else
      mem
    end
  end

  defp exec_format3(mem, target, cond) do
    if cond, do: %{mem | pc: target}, else: mem
  end

  defp handle_int(cpu) do
    {_, int_type} = Memory.read_word(cpu.memory, {:indexed, 1, 2})

    case int_type do
      0 ->
        # The putchar interrupt: sends a single byte to the display.
        # Takes one argument with the character to print.
        {_, c} = Memory.read_byte(cpu.memory, {:indexed, 1, 4})
        %{cpu | stdout: cpu.stdout <> <<c>>}

      2 ->
        # The gets interrupt: read a specific number of bytes to standard input.
        # Takes two arguments. The first is the address to place the string, the
        # second is the maximum number of bytes to read. Null bytes are not handled
        # specially null-terminated.
        if !cpu.require_input do
          %{cpu | require_input: true}
        else
          {_, buf_adr} = Memory.read_word(cpu.memory, {:indexed, 1, 4})
          {_, buf_len} = Memory.read_word(cpu.memory, {:indexed, 1, 6})

          {mem, cnt} =
            :binary.bin_to_list(cpu.stdin)
            |> Enum.reduce_while({cpu.memory, 0}, fn c, {mem, cnt} ->
              if cnt >= buf_len - 1 do
                {:halt, {mem, cnt}}
              else
                adr = {:absolute, buf_adr + cnt &&& 0xFFFF}
                {:cont, {Memory.write_byte(mem, adr, c), cnt + 1}}
              end
            end)

          adr = {:absolute, buf_adr + cnt &&& 0xFFFF}
          mem = Memory.write_byte(mem, adr, 0)
          %{cpu | memory: mem, require_input: false}
        end

      0x7F ->
        # Interface with deadbolt to trigger an unlock if the password is correct.
        # Takes no arguments.
        %{cpu | unlocked: true}
    end
  end
end
