defmodule MangaEx.MangaProviders.ProvidersBehaviour do
  @callback find_mangas(String.t(), pos_integer()) ::
              [{manga_name :: String.t(), manga_url :: String.t()}]
              | {:error, :client_error | :server_error}
              | {:ok, :manga_not_found}

  @callback get_chapters(String.t(), pos_integer()) ::
              :ok
              | {:error, :manga_not_found}
              | %{:chapters => [integer()], :special_chapters => [String.t()]}

  @callback download_pages(
              pages_url :: [String.t()],
              manga_name :: String.t(),
              chapter :: String.t() | integer()
            ) :: list()

  @callback get_pages(chapter_url :: String.t(), manga_name :: String.t(), pos_integer()) ::
              [{String.t(), integer()}] | {:error, :client_error | :server_error}
end
