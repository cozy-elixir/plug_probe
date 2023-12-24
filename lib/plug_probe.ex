defmodule PlugProbe do
  @default_path "/probe"

  @moduledoc """
  A plug for responding to HTTP probe requests.

  This plug responds to `GET` or `HEAD` requests at a specific path
  (`#{@default_path}` by default), with:

    * status code: `200`
    * body: `OK` or `{}` (when `json: true` option is set)

  ## Options

  The following options can be used when calling `plug PlugProbe`.

    * `:path` (string) - specify the path on which `PlugProbe` will be mounted
      to respond to probe requests. Default to `#{@default_path}`.
    * `:json` (boolean) - specify whether the response will be an
      `application/json` response. Default to `false`.

  ## Examples

  In general, probe requests are separated from the functionality of the
  application, because of that, it's better to handle them as light as
  possible.

  In order to do that, this plug should be placed near the top of a plug
  pipeline, then it can match requests early so that subsequent plugs don't
  have the chance to tamper the connection.

  For a simple plug pipeline:

      defmodule DemoServer do
        use Plug.Builder

        # Put it before any other plugs
        plug PlugProbe

        # ...
      end

  For a Phoenix endpoint:

      defmodule DemoWeb.Endpoint do
        use Phoenix.Endpoint, otp_app: :demo

        # Put it before any other plugs
        plug PlugProbe

        # ...
      end

  Using a custom probe path is easy:

      defmodule DemoServer do
        use Plug.Builder

        # Put it before any other plugs
        plug PlugProbe, path: "/heartbeat"

        # ...
      end

  """

  @behaviour Plug
  import Plug.Conn

  def init(opts),
    do: Keyword.merge([path: @default_path, json: false], opts)

  def call(%Plug.Conn{} = conn, opts) do
    expected_path_info = String.split(opts[:path], "/", trim: true)

    if conn.path_info == expected_path_info and conn.method in ~w(GET HEAD) do
      conn |> halt() |> response(opts[:json])
    else
      conn
    end
  end

  defp response(conn, false = _json),
    do: send_resp(conn, 200, "OK")

  defp response(conn, true = _json),
    do: conn |> put_resp_content_type("application/json") |> send_resp(200, "{}")
end
