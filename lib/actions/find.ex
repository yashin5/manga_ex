defmodule MangaEx.Actions.Find do
  use Tesla, docs: false

  require Logger

  plug(Tesla.Middleware.Headers, [
    {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:76.0) Gecko/20100101 Firefox/76.0"}
  ])

  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.Retry, Application.fetch_env!(:manga_ex, :retry_opts))

  def find_mangas(_, url, redirected_url \\ nil)

  def find_mangas(manga_name, url, redirected_url) do
    redirected_url
    |> Kernel.||(url)
    |> URI.encode()
    |> get()
    |> case do
      {:ok, %{body: body, status: status}} when status in 200..299 ->
        body

      {:ok, %{status: 301} = tesla_response} ->
        find_mangas(manga_name, url, Tesla.get_header(tesla_response, "location"))

      _response ->
        Logger.error("Error getting #{manga_name}")
        :ok
    end
  end

  def handle_get_name_and_url(name_and_urls) do
    name_and_urls
    |> Enum.uniq()
    |> case do
      [] ->
        {:ok, :manga_not_found}

      mangas ->
        mangas
    end
  end
end
