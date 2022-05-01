defmodule MangaEx.MangaProviders.Mangahost do
  @moduledoc """
  This module is responsible to find mangas, get chapters,
  get pages and download chapter.
  """
  use Tesla, docs: false

  require Logger

  alias MangaEx.Actions.Download
  alias MangaEx.Actions.Find
  alias MangaEx.MangaProviders.Provider
  alias MangaEx.Util.DownloadUtils
  alias MangaEx.Utils.ParserUtils
  alias Tesla.Middleware.Headers
  alias Tesla.Middleware.JSON
  alias Tesla.Middleware.Retry

  plug(Headers, [
    {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:76.0) Gecko/20100101 Firefox/76.0"}
  ])

  plug(JSON)
  plug(Retry, Application.fetch_env!(:manga_ex, :retry_opts))

  @behaviour Provider

  @latest_url "mangahost4"
  @mangahost_url "https://" <> @latest_url <> ".com/"
  @find_url "find/"

  @impl Provider
  def download_pages(pages_url, manga_name, chapter, sleep) do
    Download.download_pages(pages_url, manga_name, chapter, sleep, [])
  end

  @impl Provider
  def find_mangas(manga_name) do
    manga_name_in_find_format =
      manga_name
      |> String.downcase()
      |> String.replace(" ", "+")

    url =
      @mangahost_url
      |> DownloadUtils.generate_find_url(
        @find_url,
        manga_name_in_find_format
      )

    manga_name
    |> Find.find_mangas(url)
    |> get_name_and_url()
  end

  @impl Provider
  def get_chapters(manga_url) do
    case get(manga_url) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        get_chapters_url(body)

      _response ->
        Logger.error("Error getting #{manga_url}")
        :ok
    end
  end

  @impl Provider
  def get_pages(chapter_url, manga_name) do
    case get(chapter_url) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        do_get_pages(body, manga_name)

      _response ->
        Logger.error("Error getting #{manga_name} in #{chapter_url}")
        :ok
    end
  end

  @impl Provider
  def generate_chapter_url(manga_url, chapter), do: "#{manga_url}/#{chapter}"

  defp do_get_pages(body, manga_name) do
    DownloadUtils.verify_path_and_mkdir(manga_name)

    body
    |> Floki.parse_document()
    |> elem(1)
    |> Floki.find(".image-content")
    |> Floki.find("img")
    |> Enum.map(fn element ->
      element
      |> Floki.attribute("src")
      |> List.first()
      |> URI.encode()
    end)
    |> Enum.with_index()
    |> case do
      [] ->
        {:error, :pages_not_found}

      pages ->
        pages
    end
  end

  defp get_name_and_url(<<body::bitstring>>) do
    body
    |> Floki.parse_document()
    |> elem(1)
    |> Floki.find(".entry-title")
    |> Floki.find("a")
    |> Enum.map(fn element ->
      {
        element |> Floki.attribute("title") |> List.last(),
        element |> Floki.attribute("href") |> List.last()
      }
    end)
    |> Find.handle_get_name_and_url()
  end

  defp get_name_and_url(error), do: error

  defp get_chapters_url(body) do
    body
    |> Floki.parse_document()
    |> elem(1)
    |> Floki.find(".chapters")
    |> Floki.find(".tags")
    |> Floki.find("a")
    |> Enum.map(fn element ->
      chapter_url =
        element
        |> Floki.attribute("href")
        |> List.last()
        |> URI.encode()

      chapter_number =
        chapter_url
        |> String.split("/")
        |> List.last()

      {chapter_url, chapter_number}
    end)
    |> case do
      [] ->
        {:error, :manga_not_found}

      chapters ->
        ParserUtils.generate_chapter_lists(chapters)
    end
  end
end
