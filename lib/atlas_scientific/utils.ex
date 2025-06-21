defmodule AtlasScientific.Utils do
  def parse_result(result) do
    case result do
      <<255, _::binary>> ->
        {:error, :no_data}

      <<254, _::binary>> ->
        {:error, :not_ready}

      <<2, _::binary>> ->
        {:error, :invalid_syntax}

      <<1, reading::binary>> ->
        {:ok, String.replace(reading, "\0", "")}
    end
  end
end
