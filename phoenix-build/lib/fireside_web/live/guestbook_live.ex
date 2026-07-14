defmodule FiresideWeb.GuestbookLive do
  use FiresideWeb, :live_view
  alias Fireside.Guestbook

  def mount(_params, _session, socket) do
    {:ok, refresh(socket)}
  end

  def handle_event("save", %{"entry" => params}, socket) do
    case Guestbook.create_entry(params) do
      {:ok, _} -> {:noreply, refresh(socket)}
      {:error, cs} -> {:noreply, assign(socket, form: to_form(cs))}
    end
  end

  defp refresh(socket) do
    assign(socket, entries: Guestbook.list_entries(), form: to_form(Guestbook.change_entry()))
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-xl p-8">
      <h1 class="text-2xl font-bold mb-6">Fireside guestbook</h1>
      <.form for={@form} id="entry-form" phx-submit="save" class="flex flex-col gap-2 mb-8">
        <.input field={@form[:name]} placeholder="Your name" />
        <.input field={@form[:message]} placeholder="Say something" />
        <button class="btn btn-primary">Sign</button>
      </.form>
      <ul id="entries" class="flex flex-col gap-2">
        <li :for={e <- @entries} class="card bg-base-200 p-3">
          <span class="font-semibold">{e.name}</span>
          <span>{e.message}</span>
        </li>
      </ul>
    </div>
    """
  end
end
