defmodule Feeds.Utils.Id do

  @non_letters ~r/[ \!\"\#\$\%\&\§\'\(\)\*\+\,\-\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~\’]+/
  @dashes_at_beginning_or_end ~r/(^-+|-+$)/

  def make(string) do
    case string do
      nil -> "null"
      _ ->
        ret = String.strip(string) |> String.downcase()
        ret = Regex.replace(~r/^http(s)?:\/\//, ret, "")
        ret = Regex.replace(@non_letters, ret, "-")
        ret = Regex.replace(@dashes_at_beginning_or_end, ret, "")
        ret
    end
  end

end