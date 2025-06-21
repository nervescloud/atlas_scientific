defmodule AtlasScientific.Ezo.RTD do
  use GenServer

  @moduledoc """
  Atlas Scientific : EZO-RTD
  Embedded Temperature Circuit

  https://files.atlas-scientific.com/EZO_RTD_Datasheet.pdf
  """

  require Logger

  alias AtlasScientific.Utils
  alias Circuits.I2C

  @default_i2c "i2c-1"
  @default_addr 0x66

  @polling_interval 5_000

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args \\ []) do
    i2c = Keyword.get(args, :i2c, @default_i2c)
    addr = Keyword.get(args, :addr, @default_addr)

    {:ok, i2c_ref} = I2C.open(i2c)

    timer_ref = Process.send_after(self(), :poll_temp_readings, @polling_interval)

    {:ok, %{i2c_ref: i2c_ref, addr: addr, timer_ref: timer_ref, recent_reading: nil}}
  end

  def recent_reading(module \\ __MODULE__) do
    GenServer.call(module, :recent_reading)
  end

  def read_temp(module \\ __MODULE__) do
    GenServer.call(module, :read_temp)
  end

  def calibrated?(module \\ __MODULE__) do
    GenServer.call(module, :calibrated?)
  end

  def clear_calibration(module \\ __MODULE__) do
    GenServer.call(module, :clear_calibration)
  end

  def calibrate(module \\ __MODULE__, temp) do
    GenServer.call(module, {:calibrate, temp})
  end

  @impl true
  def handle_info(:poll_temp_readings, state) do
    timer_ref = Process.send_after(self(), :poll_temp_readings, @polling_interval)

    new_state = Map.put(state, :timer_ref, timer_ref)

    case read(state.i2c_ref, state.addr) do
      {:ok, temp} ->
        {:noreply, Map.put(new_state, :recent_reading, temp)}

      _ ->
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_call(:recent_reading, _from, state) do
    {:reply, state.recent_reading, state}
  end

  def handle_call(:read_temp, _from, state) do
    {:reply, read(state.i2c_ref, state.addr), state}
  end

  def handle_call(:calibrated?, _from, state) do
    {:reply, check_calibrated?(state.i2c_ref, state.addr), state}
  end

  def handle_call(:clear_calibration, _from, state) do
    {:reply, clear_stored_calibration(state.i2c_ref, state.addr), state}
  end

  def handle_call({:calibrate, temp}, _from, state) do
    {:reply, perform_calibration(state.i2c_ref, state.addr, temp), state}
  end

  #
  # Private functions
  #

  defp read(i2c_ref, addr) do
    :ok = I2C.write(i2c_ref, addr, "R")

    Process.sleep(600)

    {:ok, result} = I2C.read(i2c_ref, addr, 8)

    case Utils.parse_result(result) do
      {:ok, reading} ->
        temp =
          reading
          |> String.to_float()
          |> Float.round(1)

        if temp < 0 do
          {:error, :out_of_bounds}
        else
          {:ok, temp}
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

  defp perform_calibration(i2c_ref, addr, temp) do
    :ok = I2C.write(i2c_ref, addr, "Cal,#{temp}")

    Process.sleep(600)

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
end
