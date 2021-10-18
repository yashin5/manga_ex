defmodule MangaEx.Actions.Download do
  use Tesla

  require Logger

  alias MangaEx.Util.DownloadUtils

  @spec download_pages(
          pages_url :: [String.t()],
          manga_name :: String.t(),
          chapter :: String.t() | integer()
        ) :: list()
  def download_pages(pages, manga_name, chapter, headers \\ []) do
    manga_path = DownloadUtils.verify_path_and_mkdir("#{manga_name}/#{manga_name} #{chapter}")

    Enum.map(pages, fn {page_url, page_number} ->
      page_path =
        (manga_path <> "/#{page_number}")
        |> Path.expand()
        |> String.replace("/files", "")

      page_path
      |> File.exists?()
      |> if do
        {:ok, :page_already_downloaded}
      else
        Task.async(fn ->
          download_page(page_url, manga_path, chapter, page_number, page_path, headers)
        end)

        :timer.sleep(500)
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
        File.write(page_path, body)

      {:ok, %{status: status}} when status in 400..499 ->
        download_page(page_url, manga_path, chapter, page_number, page_path, headers)

      error ->
        {:error, error}
    end
  end

  def download_dir, do: "~/Downloads/"
end
