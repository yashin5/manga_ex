defmodule MangaEx.Actions.Download do
  alias MangaEx.HttpClient.Curl
  use Tesla

  require Logger

  @spec download_pages(
          pages_url :: [String.t()],
          manga_name :: String.t(),
          chapter :: String.t() | integer()
        ) :: list()
  def download_pages(pages_url, manga_name, chapter, headers \\ []) do
    filename = "#{manga_name} #{chapter}"
    manga_path = (download_dir() <> manga_name <> "/" <> filename) |> Path.expand()

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
        if File.read!(page_path) in Curl.curl_expected_errors() do
          download_page(page_url, manga_path, chapter, page_number, page_path, headers)
        else
          {:ok, :page_already_downloaded}
        end
      else
        Task.async(fn ->
          download_page(page_url, manga_path, chapter, page_number, page_path, headers)
        end)

        {:ok, :page_downloaded}
      end
    end)
  end

  def download_page(page_url, manga_path, chapter, page_number, page_path, headers) do
    tesla_headers =
      headers
      |> Enum.reject(&(&1 == "-H"))
      |> Enum.map(fn header ->
        [key | value] = header |> String.split(": ")
        {key, value}
      end)

    page_url
    |> get(headers: tesla_headers)
    |> case do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        page_path
        |> File.write(body)

      {:ok, %{status: 403}} ->
        page_path
        |> File.write(Curl.get_curl(page_url, headers))

      {:ok, %{status: status}} when status in 400..499 ->
        download_page(page_url, manga_path, chapter, page_number, page_path, headers)

      error when error in [{:error, :invalid_uri}, {:error, :socket_closed_remotely}] ->
        page_path
        |> File.write(Curl.get_curl(page_url, headers))
    end

    if File.read!(page_path) in Curl.curl_expected_errors() do
      download_page(page_url, manga_path, chapter, page_number, page_path, headers)
    end
  end

  def download_dir, do: "~/Downloads/"
end
