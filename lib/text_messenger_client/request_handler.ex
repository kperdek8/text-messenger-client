defmodule TextMessengerClient.RequestHandler do
  @headers [
    {"Content-Type", "application/json"},
    {"Accept", "application/x-protobuf"}
  ]

  def fetch_request(endpoint, custom_headers \\ [], opts \\ []) do
    headers = @headers ++ custom_headers

    IO.inspect(endpoint, label: "Sending request")

    case HTTPoison.get(endpoint, headers, opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{reason}"}
    end
  end
end
