defmodule MangaEx.MangaProviders.Mangahost do
  @moduledoc """
  This module is responsible to find mangas, get chapters,
  get pages and download chapter.
  """
  use Tesla

  alias MangaEx.Actions.Download
  alias MangaEx.MangaProviders.ProvidersBehaviour
  alias MangaEx.Utils.ParserUtils
  alias MangaEx.Util.DownloadUtils

  require Logger

  plug(Tesla.Middleware.Headers, [
    {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:76.0) Gecko/20100101 Firefox/76.0"}
  ])

  plug(Tesla.Middleware.JSON)

  @behaviour ProvidersBehaviour

  @latest_url "mangahost4"
  @mangahost_url "https://" <> @latest_url <> ".com/"
  @find_url "find/"

  @impl true
  def download_pages(pages_url, manga_name, chapter) do
    headers = []

    Download.download_pages(pages_url, manga_name, chapter, headers)
  end

  @impl true
  def find_mangas(_, attempt \\ 0)

  def find_mangas(manga_name, attempt) when attempt <= 10 do
    manga_name_in_find_format =
      manga_name
      |> String.downcase()
      |> String.replace(" ", "+")

    @mangahost_url
    |> DownloadUtils.generate_find_url(@find_url, manga_name_in_find_format)
    |> get()
    |> case do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        get_name_and_url(body, manga_name_in_find_format, manga_name, attempt)

      _response ->
        :timer.sleep(:timer.seconds(1))
        find_mangas(manga_name, attempt + 1)
    end
  end

  def find_mangas(manga_name, _attempt) do
    Logger.error("Error getting #{manga_name}")
    :ok
  end

  @impl true
  def get_chapters(_, attempt \\ 0)

  def get_chapters(manga_url, attempt) when attempt <= 10 do
    case get(manga_url) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        body
        |> get_chapters_url(manga_url, attempt)

      _response ->
        :timer.sleep(:timer.seconds(1))
        get_chapters(manga_url, attempt + 1)
    end
  end

  @impl true
  def get_chapters(manga_url, _) do
    Logger.error("Error getting #{manga_url}")
    :ok
  end

  @impl true
  def get_pages(_, _, attempt \\ 0)

  def get_pages(chapter_url, manga_name, attempt) when attempt <= 10 do
    case get(chapter_url) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        do_get_pages(body, manga_name, chapter_url, attempt)

      _response ->
        :timer.sleep(:timer.seconds(1))
        get_pages(chapter_url, manga_name, attempt + 1)
    end
  end

  def get_pages(chapter_url, manga_name, _) do
    Logger.error("Error getting #{manga_name} in #{chapter_url}")
    :ok
  end

  defp do_get_pages(body, manga_name, chapter_url, attempt) do
    DownloadUtils.verify_path_and_mkdir(manga_name)

    body
    |> Floki.parse_document()
    |> elem(1)
    |> Floki.find(".image-content")
    |> Floki.find("picture")
    |> Floki.find("img")
    |> Enum.map(fn element ->
      Floki.attribute(element, "src")
      |> List.first()
      |> URI.encode()
    end)
    |> Enum.with_index()
    |> case do
      pages when pages == [] and attempt < 10 ->
        :timer.sleep(:timer.seconds(1))

        get_pages(chapter_url, manga_name, attempt + 1)

      [] ->
        {:error, :pages_not_found}

      pages ->
        pages
    end
  end

  defp get_name_and_url(body, _manga_name, manga_name_unformated, attempt) do
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
    |> Enum.uniq()
    |> case do
      mangas when mangas == [] and attempt < 10 ->
        find_mangas(manga_name_unformated, attempt + 1)

      mangas when mangas == [] and attempt > 10 ->
        {:ok, :manga_not_found}

      mangas ->
        mangas
    end
  end

  defp get_chapters_url(body, manga_url, attempt) do
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

      chapter_number =
        chapter_url
        |> String.split("/")
        |> List.last()

      {chapter_url, chapter_number}
    end)
    |> case do
      chapters when chapters == [] and attempt < 10 ->
        get_chapters(manga_url, attempt + 1)

      chapters when chapters == [] and attempt > 10 ->
        {:error, :manga_not_found}

      chapters ->
        ParserUtils.generate_chapter_lists(chapters)
    end
  end

  def generate_chapter_url(manga_url, chapter), do: "#{manga_url}/#{chapter}"
end
