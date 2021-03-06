defmodule MangaEx.MangaProviders.MangahostTest do
  use ExUnit.Case, async: true
  doctest MangaEx

  alias MangaEx.MangaProviders.Mangahost

  setup_all do
    %{mangas: Mangahost.find_mangas("naruto")}
  end

  describe "find_mangas/1" do
    test "should return a list of tuple with the name and url of mangas that match with the input",
         %{
           mangas: mangas
         } do
      assert Enum.find(mangas, fn {manga_name, _url} ->
               manga_name
               |> String.downcase()
               |> String.contains?("naruto")
             end)
    end
  end

  describe "get_chapters/1" do
    test "should return a map with the chapters and special chapters", %{
      mangas: [{_manga_name, manga_url} | _]
    } do
      %{chapters: chapters, special_chapters: special_chapters} =
        Mangahost.get_chapters(manga_url)

      refute is_nil(chapters) && is_nil(special_chapters)
    end
  end

  describe "get_pages/2" do
    test "should return a list of pages from a chapter", %{mangas: [{_manga_name, manga_url} | _]} do
      manga_path = Path.expand("~/Downloads/temporary_to_test_mangahost")

      pages = Mangahost.get_pages(manga_url <> "/1", "temporary_to_test_mangahost")

      assert pages |> length() |> Kernel.>(0)

      assert manga_path |> Path.expand() |> File.exists?()
      File.rm_rf!(manga_path)
    end
  end

  describe "download_pages/4" do
    test "should download a chapter", %{mangas: [{_manga_name, manga_url} | _]} do
      manga_path = Path.expand("~/Downloads/temporary_to_test_mangahost")
      pages = Mangahost.get_pages(manga_url <> "/1", "temporary_to_test_mangahost")

      assert length(pages) ==
               pages
               |> Mangahost.download_pages("temporary_to_test_mangahost", 1, 500)
               |> length()

      File.rm_rf!(manga_path)
    end
  end
end
