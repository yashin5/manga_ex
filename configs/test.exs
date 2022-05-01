import Config

config :manga_ex, MangaEx.MangaProviders.Provider,
 mangakakalot: ProvidersMock,
  mangahost: ProvidersMock

config :logger, level: :info
