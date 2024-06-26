defmodule CompilerTest do
  use ExUnit.Case, async: true

  alias Slime.Compiler

  alias Slime.Parser.Nodes.{DoctypeNode, EExNode, HTMLNode, VerbatimTextNode}

  defp compile(tree) do
    Compiler.compile(tree, Compiler.eex_delimiters())
  end

  describe "compile/1" do
    test "renders doctype" do
      tree = [%DoctypeNode{name: "html"}]
      assert compile(tree) == "<!DOCTYPE html>"
    end

    test "renders eex attributes" do
      tree = [%HTMLNode{name: "div", attributes: [{"id", {:eex, "variable"}}, {"class", ["class"]}]}]

      expected =
        """
        <div
        <% slim__k = "id"; slim__v = Slime.Compiler.hide_dialyzer_spec(variable) %>
        <%= if slim__v do %>
         <%= slim__k %>
        <%= unless slim__v == true do %>
        ="<%= slim__v %>"<% end %><% end %> class="class">
        </div>
        """
        |> String.replace("\n", "")

      assert compile(tree) == expected
    end

    test "renders eex" do
      tree = [
        %EExNode{
          content: ~s(number_input f, :amount, class: "js-donation-amount"),
          output: true
        }
      ]

      expected = ~s(<%= number_input f, :amount, class: "js-donation-amount" %>)
      assert compile(tree) == expected
    end

    test "inserts 'end' tokens for do blocks and anonymous functions" do
      tree = [
        %EExNode{
          content: "Enum.map stars, fn star ->",
          output: true,
          children: [[%EExNode{content: ~s(star <> "s"), output: true}]]
        },
        %EExNode{content: "if welcome do", output: true, children: [[%VerbatimTextNode{content: ["Hello!"]}]]}
      ]

      expected =
        ~S"""
        <%= Enum.map stars, fn star -> %>
        <%= star <> "s" %>
        <% end %>
        <%= if welcome do %>
        Hello!
        <% end %>
        """
        |> String.replace("\n", "")

      assert compile(tree) == expected
    end

    test "does not insert 'end' tokens for inline blocks" do
      tree = [
        %EExNode{content: ~s(if true, do: "ok"), output: true},
        %EExNode{content: ~s{Enum.map([], fn (_) -> "ok" end)}, output: true}
      ]

      expected =
        ~S"""
        <%= if true, do: "ok" %>
        <%= Enum.map([], fn (_) -> "ok" end) %>
        """
        |> String.replace("\n", "")

      assert compile(tree) == expected
    end

    test "renders boolean attributes" do
      tree = [
        %HTMLNode{name: "input", attributes: [{"class", "class"}, {"required", {:eex, "true"}}]},
        %HTMLNode{name: "input", attributes: [{"class", "class"}, {"required", {:eex, "false"}}]}
      ]

      expected =
        ~S"""
        <input class="class" required>
        <input class="class">
        """
        |> String.replace("\n", "")

      assert compile(tree) == expected
    end
  end
end
