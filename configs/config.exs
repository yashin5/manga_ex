import Config

config :manga_ex,
  retry_opts: [delay: 500,
    max_retries: 10,
    max_delay: 4_000,
    should_retry: fn
      {:ok, %{status: status}} when status in [400, 500] -> true
      {:ok, _} -> false
      {:error, _} -> true
    end]

config :manga_ex, MangaEx.MangaProviders.Provider,
 mangakakalot: MangaEx.MangaProviders.Mangakakalot,
  mangahost: MangaEx.MangaProviders.Mangahost

import_config "#{Mix.env()}.exs"
