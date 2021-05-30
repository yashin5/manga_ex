defmodule MangaEx.HttpClient.Curl do
  require Logger

  def get_curl(url, opts \\ []) do
    args =
      opts ++
        [
          "-H",
          "user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.72 Safari/537.36",
          "-s"
        ]

    "curl"
    |> System.cmd(args ++ [URI.encode(url)], [])
    |> case do
      {body, _} when is_binary(body) ->
        body

      {error, _} when is_binary(error) ->
        :timer.sleep(:timer.seconds(1))
        get_curl(url)

      errors ->
        handle_errors(errors)
    end
  end

  def curl_expected_errors do
    [
      "error code: 1007",
      "<html>\r\n<head><title>403 Forbidden</title></head>\r\n<body>\r\n<center><h1>403 Forbidden</h1></center>\r\n<hr><center>nginx</center>\r\n</body>\r\n</html>\r\n<!-- a padding to disable MSIE and Chrome friendly error page -->\r\n<!-- a padding to disable MSIE and Chrome friendly error page -->\r\n<!-- a padding to disable MSIE and Chrome friendly error page -->\r\n<!-- a padding to disable MSIE and Chrome friendly error page -->\r\n<!-- a padding to disable MSIE and Chrome friendly error page -->\r\n<!-- a padding to disable MSIE and Chrome friendly error page -->\r\n"
    ]
  end

  defp handle_errors(errors) do
    case errors do
      {:ok, %{status: status}} when status in 400..499 ->
        {:error, :client_error}

      {:ok, %{status: status}} when status in 500..599 ->
        {:error, :server_error}

      error ->
        Logger.error("unexpected error")
        {:error, error}
    end
  end
end
