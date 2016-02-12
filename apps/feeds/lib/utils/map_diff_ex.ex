# lifted from https://github.com/markschmidt/
# License Do What The Fuck You Want To Public License, Version 2

defmodule Feeds.Utils.MapDiffEx do

  def diff(map1, map2), do: do_diff(map1, map2) |> to_map |> filter_empty_map

  defp do_diff(map1, map2) when map1 == map2 do
    nil
  end
  defp do_diff(map1, map2) when is_map(map1) and is_map(map2) do
    x = Map.keys(map1) ++ Map.keys(map2)
    |> Enum.uniq
    # filter out __struct__  to compare on a strict key basis regardless
    |> Enum.filter(fn(e) -> e != :__struct__ end)
    |> Enum.map(fn key ->
      {key, do_diff(Map.get(map1, key, :key_not_set), Map.get(map2, key, :key_not_set))}
    end)
    |> filter_nil_values
    _x = case x do
      [] -> nil
      _ -> x
    end
    
  end

  defp do_diff(list1, list2) when is_list(list1) and is_list(list2) do
    ret = case length(list1) == length(list2) do
      false -> {list1, list2}
      true  -> (0..length(list1)-1)
               |> Enum.map(fn(i) ->
                 do_diff(Enum.at(list1, i), Enum.at(list2, i))
               end)
    end
    ret = case ret do
      [nil, nil] -> nil
      _ -> ret
    end
    ret
  end

  defp do_diff(value1, value2) do
    {value1, value2}
  end

  defp to_map(nil) do
    nil
  end
  defp to_map([]) do
    nil
  end

  defp to_map(list) do
    Enum.into(list, %{})
  end

  defp filter_nil_values(list) do
    list 
    |> Enum.map(fn({key, value}) ->
      case is_list(value) do
        true -> 
          case Enum.all?(value, fn(v) -> is_nil(v) end) do
            true -> {key, nil}
            false -> {key, value}
          end
        false -> {key, value}
      end
    end)
    |> Enum.reject(fn({_key, value}) -> is_map(value) && map_size(value) == 0 end)
    |> Enum.reject(fn({_key, value}) -> is_nil(value) end)
  end

  defp filter_empty_map(map) when map_size(map) == 0, do: nil
  defp filter_empty_map(map), do: map
end