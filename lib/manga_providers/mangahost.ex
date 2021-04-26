defmodule MangaEx.MangaProviders.Mangahost do
  @moduledoc """
  This module is responsible to find mangas, get chapters,
  get pages and make download from chapters.
  """
  use Tesla

  require Logger

  plug(Tesla.Middleware.Headers, [
    {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:76.0) Gecko/20100101 Firefox/76.0"}
  ])

  plug(Tesla.Middleware.JSON)

  @latest_url "mangahosted"
  @download_dir "~/Downloads/"
  @mangahost_url "https://" <> @latest_url <> ".com/"
  @find_url "find/"
  @manga_page_url "manga/"

  @spec download_pages(
          pages_url :: [String.t()],
          manga_name :: String.t(),
          chapter :: String.t() | integer()
        ) :: :ok
  def download_pages(pages_url, manga_name, chapter) do
    Logger.info("Starting chapter #{chapter} download")

    filename = String.replace(manga_name, " ", "_") <> "_" <> "#{chapter}"
    manga_path = (@download_dir <> manga_name <> "/" <> filename) |> Path.expand()

    try do
      manga_path
      |> File.mkdir!()
    rescue
      _ -> Logger.info("Chapter #{chapter} directory already exists")
    end

    Enum.each(pages_url, fn page_url ->
      page_number =
        page_url
        |> String.split(["_", "/", ".", "jpg", "png", "webp"], trim: true)
        |> List.last()

      Task.async(fn ->
        download_page(page_url, manga_path, chapter, page_number)
      end)
    end)
  end

  @spec find_mangas(String.t()) ::
          [{manga_name :: String.t(), manga_url :: String.t()}]
          | {:error, :client_error | :server_error}
          | {:ok, :manga_not_found}
  def find_mangas(manga_name) do
    manga_name_in_find_format =
      manga_name
      |> String.downcase()
      |> String.replace(" ", "+")

    url = @mangahost_url <> @find_url <> manga_name_in_find_format

    case get(url) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        get_name_and_url(body, manga_name_in_find_format)

      {:ok, %{status: 403}} ->
        url
        |> get_curl()
        |> get_name_and_url(manga_name_in_find_format)

      errors ->
        handle_errors(errors)
    end
  end

  @spec get_chapters(String.t()) ::
          %{chapters: String.t(), special_chapters: String.t() | nil}
          | {:error, :client_error | :server_error}
  def get_chapters(manga_url) do
    latest_url = generate_used_url(manga_url)

    case get(latest_url) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        body
        |> parse_html()
        |> get_chapters_url(manga_url, latest_url)

      {:ok, %{status: 403}} ->
        latest_url
        |> get_curl()
        |> parse_html()
        |> get_chapters_url(manga_url, latest_url)

      errors ->
        handle_errors(errors)
    end
  end

  defp generate_used_url(manga_url) do
    [_, old_url, _] = manga_url |> String.split(["//", ".com"])
    String.replace(manga_url, old_url, @latest_url)
  end

  @spec get_pages(chapter_url :: String.t(), manga_name :: String.t()) ::
          [String.t()] | {:error, :client_error | :server_error}
  def get_pages(chapter_url, manga_name) do
    latest_url = generate_used_url(chapter_url)

    case get(latest_url) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        do_get_pages(body, manga_name)

      {:ok, %{status: 403}} ->
        latest_url
        |> get_curl()
        |> do_get_pages(manga_name)

      {:ok, %{status: status}} when status in 400..499 ->
        get_pages(chapter_url, manga_name)

      errors ->
        handle_errors(errors)
    end
  end

  defp do_get_pages(body, manga_name) do
    try do
      (@download_dir <> manga_name)
      |> Path.expand()
      |> File.mkdir!()
    rescue
      _ -> Logger.info("Directory already exists")
    end

    manga_name_formated = manga_name |> String.downcase() |> String.replace(" ", "-")

    body
    |> String.split()
    |> Enum.map(fn
      "src='" <> url ->
        url
        |> String.contains?(manga_name_formated)
        |> if(do: url |> String.replace("'", ""))

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil(&1))
  end

  defp get_name_and_url(body, manga_name) do
    manga_name_in_mangas_format = String.replace(manga_name, "+", "-")

    manga_url_to_match = @manga_page_url <> manga_name_in_mangas_format

    body
    |> parse_html()
    |> Enum.map(fn
      "href=https://manga" <> url = manga_url ->
        if String.contains?(url, manga_url_to_match) do
          {generate_manga_name_to_show(url), String.replace(manga_url, "href=", "")}
        end

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil(&1))
    |> case do
      mangas when mangas == [] ->
        {:ok, :manga_not_found}

      mangas ->
        mangas
    end
  end

  defp generate_manga_name_to_show(formated_element) do
    [_, _, manga_name, _] =
      formated_element
      |> String.split(["/", "-mh"])

    String.replace(manga_name, "-", " ")
  end

  defp get_chapters_url(body, manga_url, latest_manga_url) do
    body
    |> Enum.map(fn
      "href=" <> url -> url
      _ -> nil
    end)
    |> Enum.reject(&is_nil(&1))
    |> Enum.filter(
      &(String.starts_with?(&1, manga_url) or String.starts_with?(&1, latest_manga_url))
    )
    |> generate_chapter_lists(manga_url)
  end

  defp generate_chapter_lists(chapters_url, manga_url) do
    chapters_url
    |> Enum.map(&String.trim(&1, manga_url <> "/"))
    |> Enum.map(fn chapter ->
      try do
        String.to_integer(chapter)
      rescue
        _ -> chapter
      end
    end)
    |> Enum.reduce(%{chapters: [], special_chapters: []}, fn chapter, acc ->
      if is_integer(chapter) do
        %{acc | chapters: acc[:chapters] ++ [chapter]}
      else
        %{acc | special_chapters: acc[:special_chapters] ++ [chapter]}
      end
    end)
  end

  defp download_page(page_url, manga_path, chapter, page_number) do
    page_path = (manga_path <> "/#{page_number}") |> Path.expand()

    if File.exists?(page_path) do
      Logger.info("Page #{page_number} alredy downloaded")
    else
      Logger.info("Downloading chapter #{chapter} page #{page_number}")

      page_url
      |> get()
      |> case do
        {:ok, %{body: body, status: status}} when status in 200..299 ->
          page_path
          |> String.replace("/files", "")
          |> File.write(body)

        {:ok, %{status: 403}} ->
          page_path
          |> String.replace("/files", "")
          |> File.write(get_curl(page_url))

        {:ok, %{status: status}} when status in 400..499 ->
          download_page(page_url, manga_path, chapter, page_number)
      end
    end
  end

  defp parse_html(body) do
    body
    |> String.replace(["'", "\""], "")
    |> String.split()
    |> Enum.filter(&String.starts_with?(&1, "href="))
    |> Enum.uniq()
  end

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

  defp get_curl(url) do
    args = [
      "-H",
      "user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.72 Safari/537.36",
      "-s"
    ]

    "curl"
    |> System.cmd(args ++ [url], [])
    |> case do
      {body, _status} when is_binary(body) ->
        body

      errors ->
        handle_errors(errors)
    end
  end
end
