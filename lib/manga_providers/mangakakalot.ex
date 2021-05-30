defmodule MangaEx.MangaProviders.Mangakakalot do
  @moduledoc """
  This module is responsible to find mangas, get chapters,
  get pages and download chapter.
  """
  use Tesla

  alias MangaEx.Actions.Download
  alias MangaEx.HttpClient.Curl

  require Logger

  plug(Tesla.Middleware.Headers, [
    {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:76.0) Gecko/20100101 Firefox/76.0"}
  ])

  plug(Tesla.Middleware.JSON)

  @latest_url "mangakakalot"
  @mangakakalot_url "https://" <> @latest_url <> ".com/"
  @find_url "search/story/"

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

  @spec find_mangas(String.t()) ::
          [{manga_name :: String.t(), manga_url :: String.t()}]
          | {:error, :client_error | :server_error}
          | {:ok, :manga_not_found}
  def find_mangas(manga_name, attempt \\ 0) do
    manga_name_in_find_format =
      manga_name
      |> String.downcase()
      |> String.replace(" ", "_")

    url = (@mangakakalot_url <> @find_url <> manga_name_in_find_format) |> URI.encode()

    case get(url) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        get_name_and_url(body, manga_name_in_find_format, manga_name, attempt)

      {:ok, %{status: 403}} ->
        url
        |> Curl.get_curl()
        |> get_name_and_url(manga_name_in_find_format, manga_name, attempt)

      errors ->
        handle_errors(errors)
    end
  end

  @spec get_chapters(String.t()) ::
          %{chapters: String.t(), special_chapters: String.t() | nil}
          | {:error, :client_error | :server_error}
  def get_chapters(manga_url, attempt \\ 0) do
    case get(manga_url) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        body
        |> get_chapters_url(manga_url, attempt)

      {:ok, %{status: 403}} ->
        manga_url
        |> Curl.get_curl()
        |> get_chapters_url(manga_url, attempt)

      errors ->
        handle_errors(errors)
    end
  end

  @spec get_pages(chapter_url :: String.t(), manga_name :: String.t()) ::
          [String.t()] | {:error, :client_error | :server_error}
  def get_pages(chapter_url, manga_name, attempt \\ 0) do
    case get(chapter_url) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        do_get_pages(body, manga_name, chapter_url, attempt)

      {:ok, %{status: 403}} ->
        chapter_url
        |> Curl.get_curl()
        |> do_get_pages(manga_name, chapter_url, attempt)

      {:ok, %{status: status}} when status in 400..499 ->
        get_pages(chapter_url, manga_name, attempt)

      errors ->
        handle_errors(errors)
    end
  end

  defp do_get_pages(body, manga_name, chapter_url, attempt) do
    try do
      (Download.download_dir() <> manga_name)
      |> Path.expand()
      |> File.mkdir!()
    rescue
      _ -> :ok
    end

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
      String.replace(manga_name, "+", "-") |> String.replace(["(", ")"], "")

    body
    |> Floki.parse_document!()
    |> Floki.find("a")
    |> Enum.filter(fn element ->
      expected_name = Floki.text(element)

      if not is_nil(expected_name) do
        expected_name
        |> String.downcase()
        |> String.contains?(manga_name_in_mangas_format)
      end
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
    |> Floki.parse_document!()
    |> Floki.find("a")
    |> Enum.filter(fn element ->
      classes = Floki.attribute(element, "class") |> List.first()

      classes && String.contains?(classes, "chapter-name")
    end)
    |> Enum.map(fn element ->
      chapter_name = Floki.text(element)

      if not is_nil(chapter_name) do
        chapter_name
        |> String.downcase()
        |> String.split("chapter", trim: true)
        |> Enum.map(fn split_elem ->
          result = Regex.run(~r([0-9][0-9.]*[0-9]|[0-9]), split_elem)

          result && result |> List.last()
        end)
        |> Enum.reject(&is_nil(&1))
        |> List.last()
      end
    end)
    |> case do
      chapters when chapters == [] and attempt < 10 ->
        get_chapters(manga_url, attempt + 1)

      chapters when chapters == [] and attempt > 10 ->
        {:error, :manga_not_found}

      chapters ->
        generate_chapter_lists(chapters)
    end
  end

  defp generate_chapter_lists(chapters) do
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

  def generate_chapter_url(manga_url, chapter),
    do: "#{manga_url}/chapter-#{chapter}" |> String.replace("/manga/", "/chapter/")

  defp handle_errors(errors) do
    case errors do
      {:ok, %{status: status}} when status in 400..499 ->
        {:error, :client_error}

      {:ok, %{status: status}} when status in 500..599 ->
        {:error, :server_error}

      error ->
        Logger.error("unexpected error")
        {:error, error}
    end
  end
end
