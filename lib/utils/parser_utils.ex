defmodule MangaEx.Utils.ParserUtils do
  @spec generate_chapter_lists([{chapter_url :: String.t(), chapter :: String.t()}]) :: %{
          special_chapters: [{chapter_url :: String.t(), chapter :: String.t()}],
          chapters: [{chapter_url :: String.t(), chapter :: integer()}]
        }
  def generate_chapter_lists(chapters) do
    chapters
    |> Enum.map(fn {chapter_url, chapter} ->
      try do
        {chapter_url, String.to_integer(chapter)}
      rescue
        _ -> {chapter_url, chapter}
      end
    end)
    |> Enum.reduce(%{chapters: [], special_chapters: []}, fn
      chapter, acc when is_integer(chapter) ->
        %{acc | chapters: acc[:chapters] ++ [chapter]}

      chapter, acc ->
        %{acc | special_chapters: acc[:special_chapters] ++ [chapter]}
    end)
  end
end
