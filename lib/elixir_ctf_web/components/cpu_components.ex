defmodule ElixirCtfWeb.CPUComponents do
  use Phoenix.Component
  import ElixirCtfWeb.CoreComponents

  @doc """
  Renders a box.
  """
  attr(:id, :string)
  attr(:title, :string, default: nil)
  attr(:class, :string, default: nil)
  attr(:rest, :global, doc: "the arbitrary HTML attributes to add to the main div")
  slot(:inner_block, required: true)

  def box(assigns) do
    ~H"""
    <div id={@id} class={["border", @class]} {@rest}>
      <h2 class="bg-slate-100 border sticky top-0"><%= @title %></h2>
      <div class="m-1">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a line of code.
  """
  attr(:code, :string)
  attr(:adr, :string, default: nil)

  def codeline(assigns) do
    ~H"""
    <%= cond do %>
      <% @adr != nil -> %>
        <pre
          id={"code-#{@adr}"}
          style="tab-size: 8;"
          phx-click="toggle_breakpoint"
          phx-value-address={@adr}
        ><%= @code %></pre>
      <% true -> %>
        <pre style="tab-size: 8;"><%= @code %></pre>
    <% end %>
    """
  end

  @doc """
  Renders a line of data.
  """
  attr(:adr, :integer)
  attr(:words, :list)

  def dataline(assigns) do
    ~H"""
    <pre><%= to_hex(@adr) %>: <.dataline_hex words={@words}/>	<.dataline_ascii words={@words}/></pre>
    """
  end

  attr(:words, :list)

  defp dataline_hex(assigns) do
    if assigns.words == [] do
      ~H"*"
    else
      ~H"<%= Enum.map(@words, &to_hex_be/1) |> Enum.intersperse(\" \") %>"
    end
  end

  attr(:words, :list)

  defp dataline_ascii(assigns) do
    if assigns.words == [] do
      ~H""
    else
      ~H"<%= Enum.map(@words, &to_ascii/1) |> List.to_string() %>"
    end
  end

  @spec to_hex(integer) :: String.t()
  def to_hex(i), do: String.pad_leading(Integer.to_string(i, 16), 4, "0")

  defp to_hex_be(i) do
    <<b1::8, b2::8>> = <<i::16>>
    <<i::16>> = <<b2::8, b1::8>>
    to_hex(i)
  end

  defp to_ascii(i) do
    <<b1::8, b2::8>> = <<i::16>>
    String.module_info()
    c1 = if b1 >= 32 and b1 <= 126, do: <<b1::8>>, else: '.'
    c2 = if b2 >= 32 and b2 <= 126, do: <<b2::8>>, else: '.'
    [c2, c1]
  end

  @doc """
  Renders the control panel.
  """
  attr(:cpu_on, :boolean)

  def control_panel(assigns) do
    ~H"""
    <div>
      <.button phx-click="step" disabled={!@cpu_on} title={step_tooltip(@cpu_on)}>Step</.button>
      <.button phx-click="run" disabled={!@cpu_on} title={run_tooltip(@cpu_on)}>Run</.button>
      <.button phx-click="reset" title="Reset the CPU">Reset</.button>
    </div>
    """
  end

  @reset_text "CPU is OFF, hit Reset to continue"
  @step_text "Step one instruction"
  @run_text "Run continuously until CPU off or input required"
  defp step_tooltip(cpu_on), do: if(cpu_on, do: @step_text, else: @reset_text)
  defp run_tooltip(cpu_on), do: if(cpu_on, do: @run_text, else: @reset_text)
end
