defmodule MangaEx do
  @moduledoc """
  Documentation for `MangaEx`.
  """
  alias MangaEx.MangaProviders.Mangahost

  def download_chapters(manga_url, from, to, :mangahost) do
    %{chapters: chapters} = Mangahost.get_chapters(manga_url)

    if from in chapters and to in chapters do
      get_chapters_pages(manga_url, from..to)
    else
      {:error, :chapters_out_of_range}
    end
  end

  def download_chapters(manga_url, :all_chapters, :mangahost) do
    %{chapters: chapters} = Mangahost.get_chapters(manga_url)
    manga_name = get_manga_name(manga_url)

    chapters
    |> Enum.reverse()
    |> Enum.each(fn chapter ->
      do_download_chapters(manga_url, chapter, manga_name)
    end)
  end

  defp do_download_chapters(manga_url, chapter, manga_name) do
    manga_url
    |> generate_chapter_url(chapter)
    |> Mangahost.get_pages(manga_name)
    |> Mangahost.download_pages(manga_name, chapter)
    |> case do
      result when result == [] ->
        :timer.sleep(:timer.seconds(1))
        do_download_chapters(manga_url, chapter, manga_name)

      result ->
        result
        |> Enum.all?(fn chapter_download_result ->
          {:ok, :page_downloaded} == chapter_download_result
        end)
        |> if do
          :timer.sleep(:timer.seconds(1))
        else
          :timer.sleep(:timer.seconds(1))
          do_download_chapters(manga_url, chapter, manga_name)
        end
    end
  end

  defp get_chapters_pages(manga_url, chapters) do
    manga_name = get_manga_name(manga_url)

    Enum.each(chapters, fn chapter ->
      manga_url
      |> generate_chapter_url(chapter)
      |> Mangahost.get_pages(manga_name)
      |> Mangahost.download_pages(manga_name, chapter)
    end)
  end

  defp generate_chapter_url(manga_url, chapter), do: "#{manga_url}/#{chapter}"

  defp get_manga_name(manga_url) do
    [_, _, _, manga_name, _] = manga_url |> String.split(["/", "-mh"], trim: true)
    manga_name
  end
end
