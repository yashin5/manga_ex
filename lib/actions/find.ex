defmodule MangaEx.Actions.Find do
  use Tesla

  require Logger

  plug(Tesla.Middleware.Headers, [
    {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:76.0) Gecko/20100101 Firefox/76.0"}
  ])

  plug(Tesla.Middleware.JSON)

  def find_mangas(_, url, redirected_url \\ nil, attempt \\ 0)

  def find_mangas(manga_name, url, redirected_url, attempt) when attempt <= 10 do
    redirected_url
    |> Kernel.||(url)
    |> URI.encode()
    |> get()
    |> case do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        body

      {:ok, %{status: 301} = tesla_response} ->
        find_mangas(manga_name, url, Tesla.get_header(tesla_response, "location"), attempt + 1)

      _response ->
        :timer.sleep(:timer.seconds(1))

        find_mangas(manga_name, url, nil, attempt + 1)
    end
  end

  def find_mangas(manga_name, _url, _redirected_url, _attempt) do
    Logger.error("Error getting #{manga_name}")
    :ok
  end

  def handle_get_name_and_url(name_and_urls) do
    name_and_urls
    |> Enum.uniq()
    |> case do
      mangas when mangas == [] ->
        {:ok, :manga_not_found}

      mangas ->
        mangas
    end
  end
end
