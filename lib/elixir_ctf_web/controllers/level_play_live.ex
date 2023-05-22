defmodule ElixirCtfWeb.LevelPlayLive do
  use Phoenix.LiveView
  use Phoenix.HTML
  alias MSP430.CPU
  alias MSP430.Memory
  alias MSP430.IntelHex
  alias ElixirCtf.Levels.Level
  require Logger

  use ElixirCtfWeb, :html

  @max_ins_cnt_msg "Exceed maximum number of instructions, reset to continue"

  defp update_assign_for_cpu(assigns, cpu) do
    mem = cpu.memory

    regs =
      [:r4, :r5, :r6, :r7, :r8, :r9, :r10, :r11, :r12, :r13, :r14, :r15]
      |> Enum.map(fn r -> {r, to_hex(Map.get(mem, r))} end)

    cpu_on = CPU.is_on(cpu)

    assigns =
      assign(assigns,
        cpu: cpu,
        regs: regs,
        pc: mem.pc,
        sp: mem.sp,
        sr: mem.sr,
        ram_dump: Memory.dump_ram(mem, 8),
        rom_dump: Memory.dump_rom(mem, 8),
        cpu_on: cpu_on,
        flags: Memory.get_flag(mem)
      )

    assigns
  end

  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />
    <div class="flex h-screen text-sm">
      <div class="w-1/2 m-2 space-y-2">
        <.box id="objdump" title="Disassembly" class="h-1/2 overflow-auto">
          <code>
            <.codeline :for={{code, adr} <- @objdump} code={code} adr={adr} />
          </code>
        </.box>

        <.box id="rom" title="ROM" class="overflow-auto h-1/2">
          <.dataline :for={{adr, words} <- @rom_dump} adr={adr} words={words} />
        </.box>
      </div>

      <div class="w-1/2 m-2 space-y-2">
        <div class="flex flex-row space-x-2">
          <.box id="register" title="Register" class="basis-1/2">
            <table>
              <tr>
                <td>pc:</td>
                <td id="pc" phx-hook="PC"><%= to_hex(@pc) %></td>
                <td>sp:</td>
                <td><%= to_hex(@sp) %></td>
                <td>sr:</td>
                <td><%= to_hex(@sr) %></td>
              </tr>
              <tr :for={regline <- Enum.chunk_every(@regs, 4)}>
                <%= for {rname, rval} <- regline do %>
                  <td><%= rname %>:</td>
                  <td><%= rval %>&nbsp;&nbsp;&nbsp;</td>
                <% end %>
              </tr>
            </table>
          </.box>

          <.box id="cpu_status" title="CPU Status" class="basis-1/2">
            <span>
              Power:
              <%= if @cpu_on do %>
                ON
              <% else %>
                OFF
              <% end %>
            </span>
            <br />
            <span>
              Flags: V: <%= @flags[:v] %> N: <%= @flags[:n] %> Z: <%= @flags[:z] %> C: <%= @flags[:c] %>
            </span>
            <br />
            <span>Instruction count: <%= @cpu.ins_cnt %></span>
          </.box>
        </div>

        <.box id="stdout" title="Output" class="h-28 overflow-auto">
          <pre><%= @cpu.stdout %></pre>
        </.box>

        <.control_panel cpu_on={@cpu_on} />

        <.box id="ram" title="RAM" class="overflow-auto">
          <.dataline :for={{adr, words} <- @ram_dump} adr={adr} words={words} />
        </.box>
      </div>
    </div>

    <%= if @cpu.require_input do %>
      <.input_modal />
    <% end %>

    <.confirm_modal is_solving={@is_solving} unlocked={@cpu.unlocked} cpu_on={@cpu_on} />

    <style>
      #code-<%= Integer.to_string(@pc, 16) |> String.upcase %>{color: red; font-weight: bold;}
      <%= for adr <- @breakpoints do %>
      #code-<%= Integer.to_string(adr, 16) |> String.upcase %>{background: lightblue; font-weight: bold;}
      <% end %>
    </style>
    """
  end

  def mount(%{"id" => id}, session, socket) do
    Logger.info("mount", session: session, id: id)

    level = Level.get_level!(id)
    {:ok, setup_for_level(socket, level)}
  end

  def handle_event("step", _value, socket) do
    if socket.assigns.is_solving do
      Logger.error("stepping not allowed in solve mode", assigns: socket.assigns)
      {:noreply, socket}
    else
      case CPU.exec_single(socket.assigns.cpu) do
        {:ok, cpu} -> {:noreply, update_assign_for_cpu(socket, cpu)}
        {:error, _} -> {:noreply, put_flash(socket, :error, @max_ins_cnt_msg)}
      end
    end
  end

  def handle_event("run", _value, socket) do
    if socket.assigns.is_solving do
      Logger.error("running not allowed in solve mode", assigns: socket.assigns)
      {:noreply, socket}
    else
      case CPU.exec_continuously(socket.assigns.cpu, socket.assigns.breakpoints) do
        {:ok, cpu} -> {:noreply, update_assign_for_cpu(socket, cpu)}
        {:error, _} -> {:noreply, put_flash(socket, :error, @max_ins_cnt_msg)}
      end
    end
  end

  def handle_event("provide_input", value, socket) do
    input = Map.get(value, "input")
    ishex = Map.get(value, "ishex")

    input =
      if ishex == "true",
        do: Base.decode16(input, case: :mixed),
        else: {:ok, input}

    case input do
      {:ok, input} ->
        cpu = CPU.provide_input(socket.assigns.cpu, input)

        if socket.assigns.is_solving do
          # no breakpoints in solve mode
          case CPU.exec_continuously(cpu) do
            {:ok, cpu} -> {:noreply, update_assign_for_cpu(socket, cpu)}
            {:error, _} -> {:noreply, put_flash(socket, :error, @max_ins_cnt_msg)}
          end
        else
          {:noreply, update_assign_for_cpu(socket, cpu)}
        end

      _ ->
        Logger.error("invalid input", input: input, ishex: ishex)
        {:noreply, socket}
    end
  end

  def handle_event("toggle_breakpoint", value, socket) do
    adr = Map.get(value, "address")

    if adr == nil do
      Logger.error("invalid breakpoint address")
      {:noreply, socket}
    else
      address = String.to_integer(adr, 16)

      breakpoints =
        if MapSet.member?(socket.assigns.breakpoints, address),
          do: MapSet.delete(socket.assigns.breakpoints, address),
          else: MapSet.put(socket.assigns.breakpoints, address)

      socket = assign(socket, breakpoints: breakpoints)
      {:noreply, socket}
    end
  end

  def handle_event("solve", _value, socket) do
    id = socket.assigns.level.id
    Logger.info("solve", id: id)

    level = Level.get_level!(id)
    {:noreply, setup_for_level(socket, level, true)}
  end

  def handle_event("reset", _value, socket) do
    id = socket.assigns.level.id

    level = Level.get_level!(id)
    socket = put_flash(socket, :error, nil)
    {:noreply, setup_for_level(socket, level)}
  end

  defp setup_for_level(socket, level, is_solving \\ false) do
    hex = String.split(level.hex, ~r{\n|\r\n}) |> Enum.filter(&(String.length(&1) > 0))
    {:ok, words} = IntelHex.load(hex, Memory.rom_start())
    mem = Memory.init(words)
    cpu = CPU.init(mem)

    cpu =
      if is_solving do
        {:ok, cpu} = CPU.exec_continuously(cpu)
        cpu
      else
        cpu
      end

    regex = ~r/^[[:blank:]]+(?<address>[0-9a-f]{4}):[[:blank:]]+/i

    objdump =
      String.split(level.objdump, ~r{\n})
      |> Enum.map(fn line ->
        adr = Regex.named_captures(regex, line)["address"]
        adr = if adr != nil, do: String.upcase(adr), else: nil
        {line, adr}
      end)

    breakpoints = Map.get(socket.assigns, :breakpoints, MapSet.new())

    socket =
      assign(socket,
        level: level,
        objdump: objdump,
        is_solving: is_solving,
        breakpoints: breakpoints
      )

    socket = update_assign_for_cpu(socket, cpu)
    socket
  end
end
