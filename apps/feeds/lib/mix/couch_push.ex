defmodule Mix.Tasks.CouchPush do
  use Mix.Task

  def run(_) do
    Application.start(:porcelain)
    couch_url = Application.get_env(:couch, :url)
    dbname = Application.get_env(:couch, :db)
    js = "
      var bootstrap = require('couchdb-bootstrap')
      var options = {
        mapDbName: {
          'app': '#{dbname}'
        }
      }
      bootstrap('#{couch_url}', 'couch', options, function(error, response) {
        if(error) {
          console.log(error)
          throw(err)
        }
        console.log('ok')
      })
    "
    {:ok, fd, file_path} = Temp.open "couch-push"
    IO.binwrite fd, js
    File.close fd
    opts = [out: :string, env: %{"NODE_PATH" => "node_modules"}]
    res = Porcelain.exec("node", [file_path], opts)
    File.rm file_path
    case res do
      %Porcelain.Result{out: out, status: 0} -> out
      %Porcelain.Result{err: err} -> err
      err -> err
    end
  end

end