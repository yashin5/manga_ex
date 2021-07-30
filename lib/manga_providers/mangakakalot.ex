defmodule MangaEx.MangaProviders.Mangakakalot do
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

  @latest_url "mangakakalot"
  @mangakakalot_url "https://" <> @latest_url <> ".com/"
  @find_url "search/story/"

  @impl true
  def download_pages(pages_url, manga_name, chapter) do
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

    Download.download_pages(pages_url, manga_name, chapter, headers)
  end

  @impl true
  def find_mangas(_, attempt \\ 0)

  def find_mangas(manga_name, attempt) when attempt <= 10 do
    manga_name_in_find_format =
      manga_name
      |> String.downcase()
      |> String.replace(" ", "_")

    @mangakakalot_url
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
    |> Floki.find("img")
    |> Enum.filter(fn element ->
      title = Floki.attribute(element, "title") |> List.last()

      title &&
        title
        |> String.downcase()
        |> String.contains?("page")
    end)
    |> Enum.map(fn element ->
      page_number =
        element
        |> Floki.attribute("title")
        |> List.last()
        |> String.replace(" - MangaNelo.com", "")

      page_url =
        element
        |> Floki.attribute("src")
        |> List.last()
        |> URI.encode()

      {page_number, page_url}
    end)
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

  defp get_name_and_url(body, manga_name, manga_name_unformated, attempt) do
    manga_name_in_mangas_format =
      String.replace(manga_name, "_", " ") |> String.replace(["(", ")"], "")

    body
    |> Floki.parse_document!()
    |> Floki.find("a")
    |> Enum.filter(&Floki.text(&1))
    |> Enum.filter(fn element ->
      element
      |> Floki.text()
      |> String.downcase()
      |> String.contains?(manga_name_in_mangas_format)
    end)
    |> Enum.map(fn element ->
      {
        Floki.text(element),
        element |> Floki.attribute("href") |> List.last()
      }
    end)
    |> Enum.reject(fn {name, _url} ->
      name == "" or String.starts_with?(String.downcase(name), ["\n", "chapter", "ch.", "vol."])
    end)
    |> Enum.uniq()
    |> case do
      mangas when mangas == [] and attempt < 1 ->
        find_mangas(manga_name_unformated, attempt + 1)

      mangas when mangas == [] and attempt > 10 ->
        {:ok, :manga_not_found}

      mangas ->
        mangas
    end
  end

  defp get_chapters_url(body, manga_url, attempt) do
    body
    |> Floki.parse_document!()
    |> Floki.find("a")
    |> Enum.filter(fn element ->
      classes = Floki.attribute(element, "class") |> List.first()

      classes && String.contains?(classes, "chapter-name")
    end)
    |> Enum.filter(&Floki.text(&1))
    |> Enum.map(fn element ->
      element
      |> Floki.text()
      |> String.downcase()
      |> String.split("chapter", trim: true)
      |> Enum.map(fn split_elem ->
        result = Regex.run(~r([0-9][0-9.]*[0-9]|[0-9]), split_elem)

        result && result |> List.last()
      end)
      |> Enum.reject(&is_nil(&1))
      |> List.last()
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
