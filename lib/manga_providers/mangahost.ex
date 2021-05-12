defmodule MangaEx.MangaProviders.Mangahost do
  @moduledoc """
  This module is responsible to find mangas, get chapters,
  get pages and download chapter.
  """
  use Tesla

  require Logger

  plug(Tesla.Middleware.Headers, [
    {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:76.0) Gecko/20100101 Firefox/76.0"}
  ])

  plug(Tesla.Middleware.JSON)

  @latest_url "mangahostz"
  @download_dir "~/Downloads/"
  @mangahost_url "https://" <> @latest_url <> ".com/"
  @find_url "find/"

  @spec download_pages(
          pages_url :: [String.t()],
          manga_name :: String.t(),
          chapter :: String.t() | integer()
        ) :: list()
  def download_pages(pages_url, manga_name, chapter) do
    filename = "#{manga_name} #{chapter}"
    manga_path = (@download_dir <> manga_name <> "/" <> filename) |> Path.expand()

    try do
      manga_path
      |> File.mkdir!()
    rescue
      _ -> :ok
    end

    Enum.map(pages_url, fn {page_number, page_url} ->
      page_path =
        (manga_path <> "/#{page_number}")
        |> Path.expand()
        |> String.replace("/files", "")

      page_path
      |> File.exists?()
      |> if do
        if File.read!(page_path) in curl_expected_errors() do
          download_page(page_url, manga_path, chapter, page_number, page_path)
        else
          {:ok, :page_already_downloaded}
        end
      else
        Task.async(fn ->
          download_page(page_url, manga_path, chapter, page_number, page_path)
        end)

        {:ok, :page_downloaded}
      end
    end)
  end

  @spec find_mangas(String.t()) ::
          [{manga_name :: String.t(), manga_url :: String.t()}]
          | {:error, :client_error | :server_error}
          | {:ok, :manga_not_found}
  def find_mangas(manga_name, attempt \\ 0) do
    manga_name_in_find_format =
      manga_name
      |> String.downcase()
      |> String.replace(" ", "+")

    url = (@mangahost_url <> @find_url <> manga_name_in_find_format) |> URI.encode()

    case get(url) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        get_name_and_url(body, manga_name_in_find_format, manga_name, attempt)

      {:ok, %{status: 403}} ->
        url
        |> get_curl()
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
        |> get_curl()
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
        |> get_curl()
        |> do_get_pages(manga_name, chapter_url, attempt)

      {:ok, %{status: status}} when status in 400..499 ->
        get_pages(chapter_url, manga_name, attempt)

      errors ->
        handle_errors(errors)
    end
  end

  defp do_get_pages(body, manga_name, chapter_url, attempt) do
    try do
      (@download_dir <> manga_name)
      |> Path.expand()
      |> File.mkdir!()
    rescue
      _ -> :ok
    end

    body
    |> Floki.parse_document!()
    |> Floki.find("a")
    |> Enum.map(fn element ->
      page_number =
        element
        |> Floki.attribute("title")
        |> List.last()

      if String.starts_with?(page_number, "Page") do
        page_url =
          element
          |> Floki.find("img")
          |> Floki.attribute("src")
          |> List.last()
          |> URI.encode()

        {page_number, page_url}
      end
    end)
    |> Enum.reject(&is_nil(&1))
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
      element
      |> Floki.attribute("href")
      |> List.last()
      |> String.downcase()
      |> String.contains?(manga_name_in_mangas_format)
    end)
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
    |> Floki.parse_document!()
    |> Floki.find("a")
    |> Enum.filter(fn element ->
      title = element |> Floki.attribute("title") |> List.last()

      not is_nil(title) &&
        title
        |> String.downcase()
        |> String.starts_with?("capítulo")
    end)
    |> Enum.map(fn element -> Floki.text(element) end)
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
    |> Enum.reduce(%{chapters: [], special_chapters: []}, fn chapter, acc ->
      if is_integer(chapter) do
        %{acc | chapters: acc[:chapters] ++ [chapter]}
      else
        %{acc | special_chapters: acc[:special_chapters] ++ [chapter]}
      end
    end)
  end

  defp download_page(page_url, manga_path, chapter, page_number, page_path) do
    page_url
    |> get()
    |> case do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        page_path
        |> File.write(body)

      {:ok, %{status: 403}} ->
        page_path
        |> File.write(get_curl(page_url))

      {:ok, %{status: status}} when status in 400..499 ->
        download_page(page_url, manga_path, chapter, page_number, page_path)

      error when error in [{:error, :invalid_uri}, {:error, :socket_closed_remotely}] ->
        page_path
        |> File.write(get_curl(page_url))
    end

    if File.read!(page_path) in curl_expected_errors() do
      download_page(page_url, manga_path, chapter, page_number, page_path)
    end
  end

  defp curl_expected_errors do
    [
      "error code: 1007",
      "<html>\r\n<head><title>403 Forbidden</title></head>\r\n<body>\r\n<center><h1>403 Forbidden</h1></center>\r\n<hr><center>nginx</center>\r\n</body>\r\n</html>\r\n<!-- a padding to disable MSIE and Chrome friendly error page -->\r\n<!-- a padding to disable MSIE and Chrome friendly error page -->\r\n<!-- a padding to disable MSIE and Chrome friendly error page -->\r\n<!-- a padding to disable MSIE and Chrome friendly error page -->\r\n<!-- a padding to disable MSIE and Chrome friendly error page -->\r\n<!-- a padding to disable MSIE and Chrome friendly error page -->\r\n"
    ]
  end

  def generate_chapter_url(manga_url, chapter), do: "#{manga_url}/#{chapter}"

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
    |> System.cmd(args ++ [URI.encode(url)], [])
    |> case do
      {body, _} when is_binary(body) ->
        body

      {error, _} when is_binary(error) ->
        :timer.sleep(:timer.seconds(1))
        get_curl(url)

      errors ->
        handle_errors(errors)
    end
  end
end
