defmodule MangaEx do
  @moduledoc """
  Documentation for `MangaEx`.
  """

  alias MangaEx.Options
  alias MangaEx.MangaProviders.Provider

  def download_pages(atom_to_match, pages_url, manga_name, chapter, sleep \\ 500)

  Options.possible_languages_and_providers()
  |> Map.values()
  |> Enum.flat_map(& &1)
  |> Enum.each(fn provider ->
    atom_to_match = String.to_atom(provider)

    def find_mangas(unquote(atom_to_match), manga_name) do
      Provider.find_mangas(unquote(atom_to_match), manga_name)
    end

    def get_chapters(unquote(atom_to_match), manga_url) do
      Provider.get_chapters(unquote(atom_to_match), manga_url)
    end

    def get_pages(unquote(atom_to_match), chapter_url, manga_name) do
      Provider.get_pages(
        unquote(atom_to_match),
        chapter_url,
        manga_name
      )
    end

    def download_pages(unquote(atom_to_match), pages_url, manga_name, chapter, sleep) do
      Provider.download_pages(
        unquote(atom_to_match),
        pages_url,
        manga_name,
        chapter,
        sleep
      )
    end

    def generate_chapter_url(unquote(atom_to_match), manga_url, chapter) do
      Provider.generate_chapter_url(unquote(atom_to_match), manga_url, chapter)
    end
  end)
end
