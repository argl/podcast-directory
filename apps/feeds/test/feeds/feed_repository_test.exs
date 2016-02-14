defmodule Feeds.FeedRepositoryTest do
  use ExUnit.Case, async: false

  alias Feeds.FeedFetcher.Repository
  alias Feeds.FeedFetcher.FeedInfo

  setup do
    # delete the test database and recreate it with all design docs
    # via the mix task. slow, but it works for now
    Feeds.TestHelpers.delete_db(Application.get_env(:couch, :db))
    Mix.Tasks.CouchPush.run(nil)

    :random.seed(:os.timestamp)
    r = :random.uniform()
    name = String.to_atom "test_feed_repository_name_#{r}"

    {:ok, repo} = Repository.start_link([name: name])

    {:ok, repo: repo}
  end

  test "insert", %{repo: repo} do  
    feed_info = Feeds.TestHelpers.feed_info
    res = Repository.insert(repo, feed_info)
    assert {:ok, feed_info2} = res
    assert feed_info2._id == feed_info._id
    assert feed_info2._rev != feed_info._rev
  end

  test "insert without id", %{repo: repo} do
    feed_info = Feeds.TestHelpers.feed_info
    feed_info = %FeedInfo{feed_info | _id: nil}
    res = Repository.insert(repo, feed_info)
    assert {:error, :no_id} = res
  end

  test "get all", %{repo: repo} do
    feed_info = Feeds.TestHelpers.feed_info
    {:ok, feed_info} = Repository.insert(repo, feed_info)
    feed_info2 = Feeds.TestHelpers.feed_info
    feed_info2 = %FeedInfo{feed_info2 | _id: "podcast/localhost-8081/feed/localhost-8081-example2.xml"}
    {:ok, feed_info2} = Repository.insert(repo, feed_info2)

    res = Repository.all(repo)
    assert {:ok, docs} = res
    
  end




end