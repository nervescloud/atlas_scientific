defmodule AtlasScientific.NervesHubLink.MetricSet do
  @behaviour NervesHubLink.Extensions.Health.MetricSet

  alias AtlasScientific.Ezo.RTD
  alias AtlasScientific.Ezo.ORP
  alias AtlasScientific.Ezo.PH

  @impl NervesHubLink.Extensions.Health.MetricSet
  def sample() do
    %{
      atlas_ezo_temp_celsius: RTD.recent_reading(),
      atlas_ezo_orp: ORP.smoothed_average(),
      atlas_ezo_ph: PH.smoothed_average()
    }
    |> Map.reject(fn {_key, val} -> is_nil(val) end)
  rescue
    _ ->
      %{}
  end
end
