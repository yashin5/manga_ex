defmodule MangaEx.MangaProviders.Provider do
  @callback find_mangas(String.t()) ::
              [{manga_name :: String.t(), manga_url :: String.t()}]
              | {:error, :client_error | :server_error}
              | {:ok, :manga_not_found}

  @callback get_chapters(String.t()) ::
              :ok
              | {:error, :manga_not_found}
              | %{:chapters => [integer()], :special_chapters => [String.t()]}

  @callback download_pages(
              pages_url :: [String.t()],
              manga_name :: String.t(),
              chapter :: String.t() | integer(),
              sleep :: integer()
            ) :: list()

  @callback get_pages(chapter_url :: String.t(), manga_name :: String.t()) ::
              [{String.t(), integer()}] | {:error, :client_error | :server_error}

  @callback generate_chapter_url(manga_url :: String.t(), chapter :: String.t()) :: String.t()

  @spec find_mangas(atom(), String.t()) ::
          [{manga_name :: String.t(), manga_url :: String.t()}]
          | {:error, :client_error | :server_error}
          | {:ok, :manga_not_found}
  def find_mangas(adapter_name, manga_name) do
    adapter(adapter_name).find_mangas(manga_name)
  end

  @spec get_chapters(atom(), String.t()) ::
          :ok
          | {:error, :manga_not_found}
          | %{:chapters => [integer()], :special_chapters => [String.t()]}
  def get_chapters(adapter_name, manga_url) do
    adapter(adapter_name).get_chapters(manga_url)
  end

  @spec get_pages(atom(), chapter_url :: String.t(), manga_name :: String.t()) ::
          [{String.t(), integer()}] | {:error, :client_error | :server_error}
  def get_pages(adapter_name, chapter, manga_name) do
    adapter(adapter_name).get_pages(chapter, manga_name)
  end

  @spec download_pages(
          atom(),
          pages_url :: [String.t()],
          manga_name :: String.t(),
          chapter :: String.t() | integer(),
          sleep :: integer()
        ) :: list()
  def download_pages(adapter_name, pages_url, manga_name, chapter, sleep) do
    adapter(adapter_name).download_pages(pages_url, manga_name, chapter, sleep)
  end

  @spec generate_chapter_url(atom(), manga_url :: String.t(), chapter :: String.t()) :: String.t()
  def generate_chapter_url(adapter_name, manga_url, chapter) do
    adapter(adapter_name).generate_chapter_url(manga_url, chapter)
  end

  defp adapter(name) do
    :manga_ex
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(name)
  end
end
