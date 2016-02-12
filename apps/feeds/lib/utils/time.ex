defmodule Feeds.Utils.Time do
  use Timex

  def iso_date(date) do
    case date do
      nil -> nil
      d -> 
        try do
          DateFormat.format(d, "{ISO}") |> (fn {:ok, v} -> v end).()
        rescue
          _ -> nil
        end
    end
  end

end