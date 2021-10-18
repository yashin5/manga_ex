defmodule MangaEx.Util.DownloadUtils do
  alias MangaEx.Actions.Download

  def verify_path_and_mkdir(manga_path) do
    manga_path = Download.download_dir() <> manga_path

    try do
      manga_path
      |> Path.expand()
      |> File.mkdir!()

      manga_path
    rescue
      _ -> manga_path
    end
  end

  def generate_find_url(provider_url, resource_url, manga_name_in_find_format) do
    (provider_url <> resource_url <> manga_name_in_find_format) |> URI.encode()
  end
end
