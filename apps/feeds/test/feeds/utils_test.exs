defmodule Feeds.UtilsTest do
  use ExUnit.Case, async: true

  test "Id.make" do
    assert "bla" == Feeds.Utils.Id.make("bla")
    assert "bla-xx" == Feeds.Utils.Id.make("bla/(/&$%\"§/(%xx)")
  end

  test "map-diff simple equal" do
    map1 = %{id: 1, attr: 1}
    map2 = %{id: 1, attr: 1}
    assert nil == Feeds.Utils.MapDiffEx.diff(map1, map2)
  end

  test "map-diff simple difference" do
    map1 = %{id: 1, attr: 1}
    map2 = %{id: 1, attr: 2}
    assert %{attr: {1, 2}} == Feeds.Utils.MapDiffEx.diff(map1, map2)

    map1 = %{id: 1, attr: 1}
    map2 = %{id: 1}
    assert %{attr: {1, :key_not_set}} == Feeds.Utils.MapDiffEx.diff(map1, map2)

    map1 = %{id: 1, attr: 1, attr2: 1}
    map2 = %{id: 1, attr: 2, attr2: 1}
    assert %{attr: {1, 2}} == Feeds.Utils.MapDiffEx.diff(map1, map2)

    map1 = %{id: 1, attr: 1, attr2: 1}
    map2 = %{id: 1, attr: 2, attr2: 2}
    assert %{attr: {1, 2}, attr2: {1, 2}} == Feeds.Utils.MapDiffEx.diff(map1, map2)

    map1 = %{id: 1, attr: 1, attr2: 1}
    map2 = %{id: 1, attr: 1, attr2: 2}
    assert %{attr2: {1, 2}} == Feeds.Utils.MapDiffEx.diff(map1, map2)
  end

  test "map-diff nested map equal" do
    map1 = %{id: 1, attr: %{inner_id: 1}}
    map2 = %{id: 1, attr: %{inner_id: 1}}
    assert nil == Feeds.Utils.MapDiffEx.diff(map1, map2)
  end

  test "map-diff nested map difference" do
    map1 = %{id: 1, attr: %{inner_id: 1}}
    map2 = %{id: 1, attr: %{inner_id: 2}}
    assert %{attr: [inner_id: {1, 2}]} == Feeds.Utils.MapDiffEx.diff(map1, map2)

    map1 = %{id: 1, attr: %{inner_id: 1}}
    map2 = %{id: 1}
    assert %{attr: {%{inner_id: 1}, :key_not_set}} == Feeds.Utils.MapDiffEx.diff(map1, map2)

    map1 = %{id: 1, attr: %{inner_id: 1}}
    map2 = %{id: 2, attr: %{inner_id: 1}}
    assert %{id: {1, 2}} == Feeds.Utils.MapDiffEx.diff(map1, map2)
  end

  defmodule TestStruct do
    defstruct id: nil,
      attr: nil
  end

  test "map-diff map vs struct" do
    map1 = %{id: 1, attr: 1}
    map2 = %TestStruct{id: 1, attr: 1}
    assert nil == Feeds.Utils.MapDiffEx.diff(map1, map2)

    map1 = %TestStruct{id: 1, attr: 1}
    map2 = %TestStruct{id: 1, attr: 1}
    assert nil == Feeds.Utils.MapDiffEx.diff(map1, map2)

    map1 = %{id: 1, attr: 1}
    map2 = %TestStruct{id: 1, attr: 2}
    assert %{attr: {1, 2}} == Feeds.Utils.MapDiffEx.diff(map1, map2)
  end

  test "map-diff simple embedded list" do
    map1 = %{id: 1, list: [1,2,3]}
    map2 = %{id: 1, list: [1,2,3]}
    assert nil == Feeds.Utils.MapDiffEx.diff(map1, map2)

    map1 = %{id: 1, list: [1,3,2]}
    map2 = %{id: 1, list: [1,2,3]}
    assert %{list: [nil, {3, 2}, {2, 3}]} == Feeds.Utils.MapDiffEx.diff(map1, map2)
  end

  test "map-diff embedded list" do
    map1 = %{id: 1, list: [%{id: 1}, 2, 3]}
    map2 = %{id: 1, list: [%{id: 1}, 2, 3]}
    assert nil == Feeds.Utils.MapDiffEx.diff(map1, map2)

    map1 = %{id: 1, list: [%{id: 1}, 2, 3]}
    map2 = %{id: 1, list: [%{id: 2, attr: 1}, 2, 3]}
    assert %{list: [[id: {1, 2}, attr: {:key_not_set, 1}], nil, nil]} == Feeds.Utils.MapDiffEx.diff(map1, map2)
  end

  test "map-diff larger maps" do
    map1 = %{
      atom_links: [
        %PodcastFeeds.Parsers.Ext.Atom.Link{
          href: "http://cre.fm/cre207-planetarien#",
          rel: "http://podlove.org/deep-link",
          title: nil, 
          type: nil
        },
        %PodcastFeeds.Parsers.Ext.Atom.Link{
          href: "https://flattr.com/submit/auto?user_id=xyz",
          rel: "payment", 
          title: "Flattr this!", 
          type: "text/html"
        }
      ],
      psc: [
        %PodcastFeeds.Parsers.Ext.Psc.Chapter{href: nil, image: nil, start: "00:00:26.407", title: "Neil DeGrasse Tyson on Science"},
        %PodcastFeeds.Parsers.Ext.Psc.Chapter{href: nil, image: nil, start: "00:01:29.201", title: "Intro"},
        %PodcastFeeds.Parsers.Ext.Psc.Chapter{href: nil, image: nil, start: "00:02:04.729", title: "Begrüßung und Vorstellung"},
        %PodcastFeeds.Parsers.Ext.Psc.Chapter{href: nil, image: nil, start: "00:02:59.501", title: "Persönlicher Werdegang"}
      ]
    }
    map2 = %{
      atom_links: [
        %{
          href: "http://cre.fm/cre207-planetarien#",
          rel: "http://podlove.org/deep-link",
          title: nil, 
          type: nil
        },
        %{
          href: "https://flattr.com/submit/auto?user_id=xyz",
          rel: "payment", 
          title: "Flattr this!", 
          type: "text/html"
        }
      ],
      psc: [
        %{href: nil, image: nil, start: "00:00:26.407", title: "Neil DeGrasse Tyson on Science"},
        %{href: nil, image: nil, start: "00:01:29.201", title: "Intro"},
        %{href: nil, image: nil, start: "00:02:04.729", title: "Begrüßung und Vorstellung"},
        %{href: nil, image: nil, start: "00:02:59.501", title: "Persönlicher Werdegang"}
      ]
    }
    assert nil == Feeds.Utils.MapDiffEx.diff(map1, map2)

    map2 = %{
      atom_links: [
        %{
          href: "http://cre.fm/cre207-planetarien#",
          rel: "http://podlove.org/deep-link",
          title: nil, 
          type: nil
        },
        %{
          href: "https://flattr.com/submit/auto?user_id=xyz",
          rel: "payment", 
          title: "Flattr this!", 
          type: "application/sextett-stream"
        }
      ],
      psc: [
        %{href: nil, image: nil, start: "00:00:26.407", title: "Neil DeGrasse Tyson on Science"},
        %{href: nil, image: nil, start: "00:01:29.201", title: "Intro"},
        %{href: nil, image: nil, start: "00:02:04.729", title: "Begrüßung und Vorstellung"},
        %{href: nil, image: nil, start: "00:02:59.501", title: "Persönlicher Werdegang"}
      ]
    }
    assert %{atom_links: [nil, [type: {"text/html", "application/sextett-stream"}]]} == Feeds.Utils.MapDiffEx.diff(map1, map2)
  end


end