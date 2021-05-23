defmodule MangaEx.Options do
  @spec possible_languages_and_providers() :: map()
  def possible_languages_and_providers do
    %{"pt-br" => ["mangahost"], "en" => ["mangakakalot"]}
  end
end
