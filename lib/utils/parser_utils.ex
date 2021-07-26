defmodule MangaEx.Utils.ParserUtils do
  @spec generate_chapter_lists([String.t()]) :: %{
          special_chapters: [String.t()],
          chapters: [integer()]
        }
  def generate_chapter_lists(chapters) do
    chapters
    |> Enum.map(fn chapter ->
      try do
        String.to_integer(chapter)
      rescue
        _ -> chapter
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
