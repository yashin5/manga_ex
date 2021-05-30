defmodule MangaEx do
  @moduledoc """
  Documentation for `MangaEx`.
  """

  alias MangaEx.Options

  Options.possible_languages_and_providers()
  |> Map.values()
  |> Enum.flat_map(& &1)
  |> Enum.each(fn provider ->
    atom_to_match = String.to_atom(provider)

    module_name =
      provider
      |> String.capitalize()

    def find_mangas(unquote(atom_to_match), manga_name) do
      apply(
        String.to_existing_atom("Elixir.MangaEx.MangaProviders.#{unquote(module_name)}"),
        :find_mangas,
        [manga_name]
      )
    end

    def get_chapters(unquote(atom_to_match), manga_url) do
      apply(
        String.to_existing_atom("Elixir.MangaEx.MangaProviders.#{unquote(module_name)}"),
        :get_chapters,
        [manga_url]
      )
    end

    def get_pages(unquote(atom_to_match), chapter_url, manga_name) do
      apply(
        String.to_existing_atom("Elixir.MangaEx.MangaProviders.#{unquote(module_name)}"),
        :get_pages,
        [
          chapter_url,
          manga_name
        ]
      )
    end

    def download_pages(unquote(atom_to_match), pages_url, manga_name, chapter) do
      apply(
        String.to_existing_atom("Elixir.MangaEx.MangaProviders.#{unquote(module_name)}"),
        :download_pages,
        [
          pages_url,
          manga_name,
          chapter
        ]
      )
    end
  end)
end
