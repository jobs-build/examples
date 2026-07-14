defmodule FiresideWeb.GuestbookLiveTest do
  use FiresideWeb.ConnCase
  import Phoenix.LiveViewTest

  test "signs the guestbook and lists the entry", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/")
    html = lv |> form("#entry-form", entry: %{name: "alice", message: "hello hermetic"}) |> render_submit()
    assert html =~ "alice"
    assert html =~ "hello hermetic"
  end

  test "rejects an empty entry", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/")
    html = lv |> form("#entry-form", entry: %{name: "", message: ""}) |> render_submit()
    assert html =~ "can&#39;t be blank"
  end
end
