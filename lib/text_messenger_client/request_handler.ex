defmodule TextMessengerClient.RequestHandler do
  def fetch_request(endpoint, custom_headers \\ [], opts \\ []) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/x-protobuf"}
    ] ++ custom_headers

    IO.inspect(endpoint, label: "Sending GET request")

    case HTTPoison.get(endpoint, headers, opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{reason}"}
    end
  end

  def post_request(endpoint, payload, custom_headers \\ [], opts \\ []) do
    headers = [
      {"Accept", "application/json"}
    ] ++ custom_headers

    IO.inspect(endpoint, label: "Sending POST request")

    case HTTPoison.post(endpoint, payload, headers, opts) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:ok, status_code, Jason.decode!(body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{reason}"}
    end
  end
end
