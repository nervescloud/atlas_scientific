defmodule AtlasScientific.Ezo.PH do
  use GenServer

  @moduledoc """
  Atlas Scientific : EZO-pH
  Embedded pH Circuit

  https://files.atlas-scientific.com/pH_EZO_Datasheet.pdf
  """

  require Logger

  alias AtlasScientific.Utils
  alias Circuits.I2C

  @default_i2c "i2c-1"
  @default_addr 0x63

  @polling_interval 5_000

  @smooth_average 0.85
  @smooth_recent 0.15

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args \\ []) do
    i2c = Keyword.get(args, :i2c, @default_i2c)
    addr = Keyword.get(args, :addr, @default_addr)

    {:ok, i2c_ref} = I2C.open(i2c)

    timer_ref = Process.send_after(self(), :poll_ph_readings, @polling_interval)

    {:ok, %{i2c_ref: i2c_ref, addr: addr, timer_ref: timer_ref, smoothed_average: nil}}
  end

  def smoothed_average(module \\ __MODULE__) do
    GenServer.call(module, :smoothed_average)
  end

  def read_ph(module \\ __MODULE__) do
    GenServer.call(module, :read_ph)
  end

  def read_ph_with_temp_compensation(module \\ __MODULE__, temp) do
    GenServer.call(module, {:read_ph_with_temp_compensation, temp})
  end

  def calibrated?(module \\ __MODULE__) do
    GenServer.call(module, :calibrated?)
  end

  def clear_calibration(module \\ __MODULE__) do
    GenServer.call(module, :clear_calibration)
  end

  def calibrate(module \\ __MODULE__, point) do
    GenServer.call(module, {:calibrate, point})
  end

  def slope(module \\ __MODULE__) do
    GenServer.call(module, :slope)
  end

  @impl true
  def handle_info(:poll_ph_readings, state) do
    timer_ref = Process.send_after(self(), :poll_ph_readings, @polling_interval)

    new_state = Map.put(state, :timer_ref, timer_ref)

    with {:ok, recent} <- read(state.i2c_ref, state.addr),
         true <- recent < 14 do
      new_smoothed_average =
        case state.smoothed_average do
          nil ->
            recent

          smoothed_average ->
            smooth_and_round(smoothed_average, recent)
        end

      {:noreply, Map.put(new_state, :smoothed_average, new_smoothed_average)}
    else
      _ ->
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_call(:smoothed_average, _from, state) do
    smoothed_average =
      case state.smoothed_average do
        val when is_float(val) -> Float.round(val, 1)
        val -> val
      end

    {:reply, smoothed_average, state}
  end

  def handle_call(:read_ph, _from, state) do
    {:reply, read(state.i2c_ref, state.addr), state}
  end

  def handle_call({:read_ph_with_temp_compensation, temp}, _from, state) do
    {:reply, read_with_compensation(state.i2c_ref, state.addr, temp), state}
  end

  def handle_call(:calibrated?, _from, state) do
    {:reply, check_calibrated?(state.i2c_ref, state.addr), state}
  end

  def handle_call(:clear_calibration, _from, state) do
    {:reply, clear_stored_calibration(state.i2c_ref, state.addr), state}
  end

  def handle_call({:calibrate, point}, _from, state) do
    {:reply, perform_calibration(state.i2c_ref, state.addr, point), state}
  end

  def handle_call(:slope, _from, state) do
    {:reply, fetch_slope(state.i2c_ref, state.addr), state}
  end

  #
  # Private functions
  #

  defp read(i2c_ref, addr) do
    :ok = I2C.write(i2c_ref, addr, "R")

    Process.sleep(900)

    {:ok, result} = I2C.read(i2c_ref, addr, 8)

    case Utils.parse_result(result) do
      {:ok, ph} ->
        if ph < 0 do
          {:error, :out_of_bounds}
        else
          {:ok, String.to_float(ph)}
        end

      error ->
        error
    end
  end

  defp read_with_compensation(i2c_ref, addr, temp) do
    :ok = I2C.write(i2c_ref, addr, "RT,#{temp}")

    Process.sleep(900)

    {:ok, reading} = I2C.read(i2c_ref, addr, 8)

    <<1, rest::binary>> = reading

    result = String.replace(rest, "\0", "")

    String.to_float(result)
  end

  defp check_calibrated?(i2c_ref, addr) do
    :ok = I2C.write(i2c_ref, addr, "Cal,?")

    Process.sleep(300)

    {:ok, result} = I2C.read(i2c_ref, addr, 8)

    case Utils.parse_result(result) do
      {:ok, "?CAL,0"} -> {:ok, :cleared}
      {:ok, "?CAL,1"} -> {:ok, :single_point}
      {:ok, "?CAL,2"} -> {:ok, :two_point}
      {:ok, "?CAL,3"} -> {:ok, :three_point}
      error -> error
    end
  end

  defp perform_calibration(i2c_ref, addr, point) do
    command =
      case point do
        :high -> "Cal,high,10.00"
        :mid -> "Cal,mid,7.00"
        :low -> "Cal,low,4.00"
      end

    :ok = I2C.write(i2c_ref, addr, command)

    Process.sleep(900)

    {:ok, result} = I2C.read(i2c_ref, addr, 2)

    case Utils.parse_result(result) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp clear_stored_calibration(i2c_ref, addr) do
    :ok = I2C.write(i2c_ref, addr, "Cal,clear")

    Process.sleep(300)

    {:ok, result} = I2C.read(i2c_ref, addr, 2)

    case Utils.parse_result(result) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp fetch_slope(i2c_ref, addr) do
    :ok = I2C.write(i2c_ref, addr, "Slope,?")

    Process.sleep(300)

    {:ok, reading} = I2C.read(i2c_ref, addr, 30)

    case Utils.parse_result(reading) do
      {:ok, output} ->
        [_header, acid, base, millivolts] = String.split(output, ",")

        formatted_result = %{
          acid: String.to_float(acid),
          base: String.to_float(base),
          millivolts: String.to_float(millivolts)
        }

        {:ok, formatted_result}

      error ->
        error
    end
  end

  defp smooth_and_round(smoothed_average, recent_reading) do
    (smoothed_average * @smooth_average + recent_reading * @smooth_recent)
    |> Float.round(4)
  end
end
