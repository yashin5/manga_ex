defmodule MangaEx.MangaExTest do
  use ExUnit.Case, async: true
  doctest MangaEx

  import Mox

  setup :verify_on_exit!

  MangaEx.Options.possible_languages_and_providers()
  |> Map.values()
  |> Enum.flat_map(& &1)
  |> Enum.each(fn provider ->
    atom_to_match = String.to_atom(provider)

    setup_all do
      expect(ProvidersMock, :find_mangas, fn _ ->
        [
          {"Boruto: Naruto Next Generations",
           "https://mangahosted.com/manga/boruto-naruto-next-generations-mh26410"}
        ]
      end)

      %{mangas: MangaEx.find_mangas(unquote(atom_to_match), "naruto")}
    end

    describe "find_mangas/1 - using #{provider} provider" do
      test "should return a list of tuple with the name and url of mangas that match with the input for provider - #{
             provider
           }",
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

    describe "get_chapters/1 - using #{provider} provider" do
      test "should return a map with the chapters and special chapters for provider - #{provider}",
           %{
             mangas: [{_manga_name, manga_url} | _]
           } do
        expect_request(:chapters)

        %{chapters: chapters, special_chapters: special_chapters} =
          MangaEx.get_chapters(unquote(atom_to_match), manga_url)

        refute is_nil(chapters) && is_nil(special_chapters)
      end
    end

    describe "get_pages/2 - using #{provider} provider" do
      test "should return a list of pages from a chapter for provider - #{provider}", %{
        mangas: [{_manga_name, manga_url} | _]
      } do
        expect_request(:chapters)
        expect_request(:get_pages)
        provider = unquote(atom_to_match)
        %{chapters: [{chapter_url, _} | _]} = MangaEx.get_chapters(provider, manga_url)

        pages = MangaEx.get_pages(provider, chapter_url, "temporary_to_test_#{provider}")

        assert pages |> length() |> Kernel.>(0)
      end
    end

    describe "download_pages/4 - using #{provider} provider" do
      test "should download a chapter for provider - #{provider}", %{
        mangas: [{_manga_name, manga_url} | _]
      } do
        expect_request(:chapters)
        expect_request(:get_pages)

        expect(ProvidersMock, :download_pages, fn _, _, _, _ ->
          [
            {:ok, :page_downloaded}
          ]
        end)

        provider = unquote(atom_to_match)

        manga_path = Path.expand("~/Downloads/temporary_to_test_#{provider}")
        %{chapters: [{chapter_url, _} | _]} = MangaEx.get_chapters(provider, manga_url)

        pages = MangaEx.get_pages(provider, chapter_url, "temporary_to_test_#{provider}")

        assert length(pages) ==
                 provider
                 |> MangaEx.download_pages(pages, "temporary_to_test_#{provider}", 1, 500)
                 |> length()

        File.rm_rf!(manga_path)
      end
    end
  end)

  defp expect_request(:get_pages) do
    expect(ProvidersMock, :get_pages, fn _, _ ->
      [
        {"https://img-host.filestatic3.xyz/mangas_files/boruto-naruto-next-generations/69/img_or2004221710_0001.jpg",
         0}
      ]
    end)
  end

  defp expect_request(:chapters) do
    expect(ProvidersMock, :get_chapters, fn _ ->
      %{
        chapters: [
          {"https://mangahosted.com/manga/boruto-naruto-next-generations-mh26410/69", 69}
        ],
        special_chapters: []
      }
    end)
  end
end
