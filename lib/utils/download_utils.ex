defmodule MangaEx.Util.DownloadUtils do
  alias MangaEx.Actions.Download

  def verify_path_and_mkdir(manga_name) do
    try do
      (Download.download_dir() <> manga_name)
      |> Path.expand()
      |> File.mkdir!()
    rescue
      _ -> :ok
    end
  end

  def generate_find_url(provider_url, resource_url, manga_name_in_find_format) do
    (provider_url <> resource_url <> manga_name_in_find_format) |> URI.encode()
  end
end
