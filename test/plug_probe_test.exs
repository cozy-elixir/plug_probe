defmodule PlugProbeTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule DefaultPipeline do
    use Plug.Router

    plug PlugProbe
    plug :match
    plug :dispatch
    match _, do: send_resp(conn, 200, "end-of-pipeline")
  end

  defmodule CustomPathPipeline do
    use Plug.Router

    plug PlugProbe, path: "/custom-probe"
    plug :match
    plug :dispatch
    match _, do: send_resp(conn, 200, "end-of-pipeline")
  end

  defmodule JsonPipeline do
    use Plug.Router

    plug PlugProbe, json: true
    plug :match
    plug :dispatch
    match _, do: send_resp(conn, 200, "end-of-pipeline")
  end

  describe "check requests with method:" do
    test "GET requests" do
      conn = conn(:get, "/probe") |> DefaultPipeline.call([])
      assert conn.status == 200
      assert conn.resp_body == "OK"
    end

    test "HEAD request work" do
      conn = conn(:head, "/probe") |> DefaultPipeline.call([])
      assert conn.status == 200
      assert conn.resp_body == ""
    end

    test "only GET and HEAD requests work" do
      Enum.each([:post, :put, :delete, :options, :foo], fn method ->
        conn = conn(method, "/probe") |> DefaultPipeline.call([])
        assert conn.resp_body == "end-of-pipeline"
      end)
    end
  end

  describe "check path option:" do
    test "default path" do
      conn = conn(:get, "/probe") |> DefaultPipeline.call([])
      assert conn.status == 200
      assert conn.resp_body == "OK"
    end

    test "custom path" do
      conn = conn(:get, "/custom-probe") |> CustomPathPipeline.call([])
      assert conn.status == 200
      assert conn.resp_body == "OK"
    end
  end

  describe "check json option:" do
    test "disabled" do
      conn = conn(:get, "/probe") |> DefaultPipeline.call([])
      assert conn.status == 200
      assert conn.resp_body == "OK"
    end

    test "enabled" do
      conn = conn(:get, "/probe") |> JsonPipeline.call([])
      assert conn.resp_body == "{}"
      assert conn |> get_resp_header("content-type") |> hd =~ "application/json"
    end
  end

  describe "check halted requests:" do
    test "the request is halted after matching" do
      conn = conn(:get, "/probe") |> DefaultPipeline.call([])
      assert conn.status == 200
      assert conn.resp_body == "OK"
    end

    test "only matching requests are halted" do
      conn = conn(:get, "/passthrough") |> DefaultPipeline.call([])
      assert conn.status == 200
      assert conn.resp_body == "end-of-pipeline"

      conn = conn(:get, "/passthrough") |> CustomPathPipeline.call([])
      assert conn.status == 200
      assert conn.resp_body == "end-of-pipeline"
    end
  end

  test "forwarded requests is supported" do
    conn = %{path_info: ["upstream" | rest]} = conn(:get, "/upstream/probe")
    conn = Plug.forward(conn, rest, DefaultPipeline, [])
    assert conn.status == 200
    assert conn.resp_body == "OK"
  end
end
