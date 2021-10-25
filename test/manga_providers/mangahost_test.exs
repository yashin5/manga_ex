defmodule MangaEx.MangaProviders.MangahostTest do
  use ExUnit.Case
  doctest MangaEx

  alias MangaEx.MangaProviders.Mangahost

  test "should return a list of tuple with the name and url of mangas that match with the input" do
    assert [
             {"Vagabond", _url1},
             {"Vagabond (Edição Colorida)", _url2}
           ] = Mangahost.find_mangas("vagabond")
  end

  test "should return a map with the chapters and special chapters" do
    [{_manga_name, manga_url} | _] = Mangahost.find_mangas("vagabond")

    %{chapters: chapters, special_chapters: special_chapters} =
      manga_url
      |> Mangahost.get_chapters()

    refute is_nil(chapters) && is_nil(special_chapters)
  end

  test "should return a list of pages from a chapter" do
    [{manga_name, manga_url} | _] = Mangahost.find_mangas("naruto")
    manga_path = Path.expand("~/Downloads/#{manga_name}")

    pages = Mangahost.get_pages(manga_url <> "/1", manga_name)

    assert pages |> length() |> Kernel.>(0)

    assert manga_path |> Path.expand() |> File.exists?()
    File.rm_rf!(manga_path)
  end

  test "should download a chapter" do
    [{manga_name, manga_url} | _] = Mangahost.find_mangas("naruto")
    manga_path = Path.expand("~/Downloads/#{manga_name}")
    pages = Mangahost.get_pages(manga_url <> "/1", manga_name |> String.replace(" ", "-"))

    assert length(pages) ==
             :mangahost
             |> MangaEx.download_pages(pages, manga_name |> String.replace(" ", "-"), 1, 500)
             |> length()

    File.rm_rf!(manga_path)
  end
end
