defmodule MangaEx.MangaProviders.Mangakakalot do
  @moduledoc """
  This module is responsible to find mangas, get chapters,
  get pages and download chapter.
  """
  use Tesla

  alias MangaEx.Actions.Download
  alias MangaEx.Actions.Find
  alias MangaEx.MangaProviders.ProvidersBehaviour
  alias MangaEx.Utils.ParserUtils
  alias MangaEx.Util.DownloadUtils

  require Logger

  plug(Tesla.Middleware.Headers, [
    {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:76.0) Gecko/20100101 Firefox/76.0"}
  ])

  plug(Tesla.Middleware.JSON)

  @behaviour ProvidersBehaviour

  @latest_url "mangakakalot"
  @mangakakalot_url "https://" <> @latest_url <> ".com/"
  @find_url "search/story/"

  @impl true
  def download_pages(pages_url, manga_name, chapter, sleep) do
    headers = [
      "-H",
      "user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.72 Safari/537.36",
      "-H",
      "authority: s31.mkklcdnv6tempv2.com",
      "-H",
      "scheme: https",
      "-H",
      "accept: image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
      "-H",
      "referer: https://readmanganato.com/"
    ]

    Download.download_pages(pages_url, manga_name, chapter, sleep, headers)
  end

  @impl true
  def find_mangas(manga_name) do
    manga_name_in_find_format =
      manga_name
      |> String.downcase()
      |> String.replace(" ", "_")

    url =
      @mangakakalot_url
      |> DownloadUtils.generate_find_url(@find_url, manga_name_in_find_format)

    manga_name
    |> Find.find_mangas(url)
    |> get_name_and_url()
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
    |> Floki.parse_document!()
    |> Floki.find(".container-chapter-reader")
    |> Floki.find("img")
    |> Enum.map(fn element ->
      element
      |> Floki.attribute("src")
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

  defp get_name_and_url(body) do
    body
    |> Floki.parse_document!()
    |> Floki.find(".story_item")
    |> Enum.map(fn element ->
      url =
        element
        |> Floki.find("a")
        |> Floki.attribute("href")
        |> List.first()
        |> URI.encode()

      manga_name =
        element
        |> Floki.find("img")
        |> Floki.attribute("alt")
        |> List.first()

      {manga_name, url}
    end)
    |> Find.handle_get_name_and_url()
  end

  defp get_chapters_url(body, manga_url, attempt) do
    parsed_document = Floki.parse_document!(body)
    possible_class = Floki.find(parsed_document, ".row-content-chapter")

    document_with_chapters =
      if possible_class == [],
        do: Floki.find(parsed_document, ".chapter-list"),
        else: possible_class

    document_with_chapters
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
        |> String.replace(["chapter", "-", "_"], "")

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

  def generate_chapter_url(manga_url, chapter) do
    manga_url
    |> String.contains?("readmanganato")
    |> if do
      "#{manga_url}/chapter-#{chapter}"
    else
      "#{manga_url}/chapter_#{chapter}"
    end
    |> String.replace("/manga/", "/chapter/")
  end
end
