defmodule MangaEx.MangaProviders.Mangahost do
  use Tesla

  require Logger

  plug(Tesla.Middleware.Headers, [
    {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:76.0) Gecko/20100101 Firefox/76.0"}
  ])

  plug(Tesla.Middleware.JSON)

  @download_dir "~/Downloads/"
  @mangahost_url "https://mangahosted.com/"
  @find_url "find/"
  @manga_page_url "manga/"

  def download_pages(pages_url, manga_name, chapter) do
    filename = String.replace(manga_name, " ", "_") <> "_" <> chapter
    try do
      @download_dir <> filename
      |> Path.expand()
      |> File.mkdir!()
    rescue
      _ -> Logger.info("Directory already exists")
    end

    Enum.each(pages_url, fn page_url ->
      page_number = String.split(page_url, ["_", ".", "jpg"], trim: true) |> List.last()

      Logger.info("Downloading chapter #{chapter} page #{page_number}")
      Task.async(fn ->
        download_page(page_url, filename, page_number)
      end)
    end)
  end

  defp download_page(page_url, filename, page_number) do
    page_url
    |> get()
    |> case do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        @download_dir <> filename <> "/#{page_number}"
        |> Path.expand()
        |> File.write(body)

      errors ->
        handle_errors(errors)
      end
  end
  def find_mangas(manga_name) do
    manga_name_in_find_format =
      manga_name
      |> String.downcase()
      |> String.replace(" ", "+")

    case get(@mangahost_url <> @find_url <> manga_name_in_find_format) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        get_name_and_url(body, manga_name_in_find_format)

      errors ->
        handle_errors(errors)
    end
  end

  def get_chapters(manga_url) do
    case get(manga_url) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        body
        |> parse_html()
        |> get_chapters_url(manga_url)

      errors ->
        handle_errors(errors)
    end
  end

  def get_pages(chapter_url, manga_name) do
    case get(chapter_url) do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        manga_name_formated = manga_name |> String.downcase() |> String.replace(" ", "-")
        body
        |> String.split()
        |> Enum.map(fn
          "src='" <> url ->
            url
            |> String.contains?(manga_name_formated)
            |> (if do: url |> String.replace("'", ""))

          _ ->
            nil
        end)
        |> Enum.reject(&is_nil(&1))

      errors ->
        handle_errors(errors)
    end
  end

  defp get_name_and_url(body, manga_name) do
    manga_name_in_mangas_format = String.replace(manga_name, "+", "-")

    manga_url_to_match =
      "href=" <> @mangahost_url <> @manga_page_url <> manga_name_in_mangas_format

    body
    |> parse_html()
    |> Enum.map(fn element ->
      formated_element = String.replace(element, "\"", "")

      if String.starts_with?(formated_element, manga_url_to_match) do
        {generate_manga_name_to_show(formated_element),
         String.replace(formated_element, "href=", "")}
      end
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
    formated_element
    |> String.split("-mh")
    |> List.first()
    |> String.replace([@mangahost_url <> @manga_page_url, "href="], "")
    |> String.replace("-", " ")
  end

  defp get_chapters_url(body, manga_url) do
    body
    |> Enum.map(fn
      "href=" <> url -> url |> String.replace("'", "")
      _ -> nil
    end)
    |> Enum.reject(&is_nil(&1))
    |> Enum.filter(&String.starts_with?(&1, manga_url))
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
    |> Enum.reduce(%{chapters: [], special_chapters: []}, fn i, acc ->
      if is_integer(i) do
        %{acc | chapters: acc[:chapters] ++ [i]}
      else
        %{acc | special_chapters: acc[:special_chapters] ++ [i]}
      end
    end)
  end

  defp parse_html(body) do
    body
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
    end
  end
end
