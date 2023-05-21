defmodule MSP430.IntelHex do
  @spec load(list(String.t()), integer) :: {:ok, Map} | {:error, String.t()}
  def load(records, mem_offset) do
    case traverse(records, &parse/1) do
      {:error, msg} ->
        {:error, msg}

      {:ok, records} ->
        rec_map =
          List.foldl(records, %{}, fn record, rom ->
            case record do
              :eof ->
                rom

              :start_segment ->
                rom

              {:data, offset, data} ->
                Enum.chunk_every(data, 2)
                |> Enum.with_index()
                |> Enum.reduce(rom, fn {bytes, idx}, rom ->
                  adr = div(offset, 2) + idx - div(mem_offset, 2)

                  <<word::16>> =
                    case bytes do
                      [b0, b1] -> <<b1::8, b0::8>>
                      [b] -> <<Map.get(rom, adr, 0)::8, b::8>>
                    end

                  Map.put(rom, adr, word)
                end)
            end
          end)

        {:ok, rec_map}
    end
  end

  @type record :: {:data, integer, list(byte)} | :start_segment | :eof

  @spec parse(String.t()) :: {:ok, record} | {:error, String.t()}
  def parse(s) do
    len = String.length(s)
    bytes_len = div(len - 1, 2)

    with :ok <-
           check(
             String.starts_with?(s, ":") && len >= 11 && rem(len, 2) == 1,
             ~s"invalid format #{s}"
           ),
         # parse and check length
         {:ok, bytes} <- String.trim_leading(s, ":") |> parse_hex(),
         <<data_len::8, rest::binary>> <- bytes,
         :ok <-
           check(
             data_len + 5 == bytes_len,
             ~s"invalid length #{data_len} vs #{bytes_len - 5}"
           ),
         # get offset and checksum
         <<offset1::8, offset2::8, rec_type::8, rest::binary>> <- rest,
         <<offset::16>> <- <<offset1, offset2>>,
         rest <- :binary.bin_to_list(rest),
         {checksum, data} <- List.pop_at(rest, -1),
         :ok <-
           check(
             rem(Enum.sum(data) + data_len + offset1 + offset2 + rec_type + checksum, 256) == 0,
             ~s"invalid checksum #{s}"
           ) do
      case rec_type do
        0 -> {:ok, {:data, offset, data}}
        1 -> {:ok, :eof}
        3 -> {:ok, :start_segment}
        _ -> {:error, ~s"unsupported record type #{rec_type}"}
      end
    end
  end

  defp parse_hex(s) do
    case Base.decode16(s, case: :mixed) do
      {:ok, bitstring} -> {:ok, bitstring}
      _ -> {:error, ~s"invalid hex #{s}"}
    end
  end

  # func: map each element to {:ok, data} or {:error, msg}
  # return: {:ok, [list of data]} or the first {:error, msg}
  defp traverse(enum, func) do
    acc =
      Enum.reduce_while(enum, [], fn elm, acc ->
        case func.(elm) do
          {:ok, elm} -> {:cont, [elm | acc]}
          {:error, msg} -> {:halt, {:error, msg}}
        end
      end)

    case acc do
      {:error, msg} -> {:error, msg}
      acc -> {:ok, Enum.reverse(acc)}
    end
  end

  defp check(condition, msg), do: if(condition, do: :ok, else: {:error, msg})
end
