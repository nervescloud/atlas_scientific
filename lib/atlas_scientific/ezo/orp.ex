defmodule AtlasScientific.Ezo.ORP do
  use GenServer

  @moduledoc """
  Atlas Scientific : EZO-ORP
  Embedded ORP Circuit

  https://files.atlas-scientific.com/ORP_EZO_Datasheet.pdf
  """

  require Logger

  alias AtlasScientific.Utils
  alias Circuits.I2C

  @default_i2c "i2c-1"
  @default_addr 0x62

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

    timer_ref = Process.send_after(self(), :poll_orp_readings, @polling_interval)

    {:ok, %{i2c_ref: i2c_ref, addr: addr, timer_ref: timer_ref, smoothed_average: nil}}
  end

  def smoothed_average(module \\ __MODULE__) do
    GenServer.call(module, :smoothed_average)
  end

  def read_orp(module \\ __MODULE__) do
    GenServer.call(module, :read_orp)
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

  @impl true
  def handle_info(:poll_orp_readings, state) do
    timer_ref = Process.send_after(self(), :poll_orp_readings, @polling_interval)

    new_state = Map.put(state, :timer_ref, timer_ref)

    with {:ok, recent} <- read(state.i2c_ref, state.addr) do
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
    {:reply, state.smoothed_average, state}
  end

  def handle_call(:read_orp, _from, state) do
    {:reply, read(state.i2c_ref, state.addr), state}
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

  #
  # Private functions
  #

  defp read(i2c_ref, addr) do
    :ok = I2C.write(i2c_ref, addr, "R")

    Process.sleep(900)

    {:ok, result} = I2C.read(i2c_ref, addr, 8)

    case Utils.parse_result(result) do
      {:ok, raw_orp} ->
        formatted_orp =
          raw_orp
          |> String.to_float()
          |> round()

        if formatted_orp < 0 do
          {:error, :out_of_bounds}
        else
          {:ok, formatted_orp}
        end

      error ->
        error
    end
  end

  defp check_calibrated?(i2c_ref, addr) do
    :ok = I2C.write(i2c_ref, addr, "Cal,?")

    Process.sleep(300)

    {:ok, result} = I2C.read(i2c_ref, addr, 8)

    case Utils.parse_result(result) do
      {:ok, "?CAL,0"} -> {:ok, false}
      {:ok, "?CAL,1"} -> {:ok, true}
      error -> error
    end
  end

  defp perform_calibration(i2c_ref, addr, orp) do
    :ok = I2C.write(i2c_ref, addr, "Cal,#{orp}")

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

  defp smooth_and_round(smoothed_average, recent_reading) do
    (smoothed_average * @smooth_average + recent_reading * @smooth_recent)
    |> round()
  end
end
