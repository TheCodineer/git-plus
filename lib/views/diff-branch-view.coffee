{CompositeDisposable} = require 'atom'
Os = require 'os'
Path = require 'path'
fs = require 'fs-plus'

git = require '../git'
notifier = require '../notifier'
BranchListView = require './branch-list-view'
DiffBranchFilesView = require '../views/diff-branch-files-view'
GitDiff = require '../models/git-diff'
_repo = null

nothingToShow = 'Nothing to show.'

disposables = new CompositeDisposable

showFile = (filePath) ->
  if atom.config.get('git-plus.general.openInPane')
    splitDirection = atom.config.get('git-plus.general.splitPane')
    atom.workspace.getActivePane()["split#{splitDirection}"]()
  atom.workspace.open(filePath)

prepFile = (text, filePath) ->
  new Promise (resolve, reject) ->
    if text?.length is 0
      reject nothingToShow
    else
      fs.writeFile filePath, text, flag: 'w+', (err) ->
        if err then reject err else resolve true

module.exports =
  class DiffBranchListView extends BranchListView
    initialize: (@repo, @data) ->
      super
      console.log('initialize.@repo', @repo)
      _repo = @repo

    confirmed: ({name}) ->
      name = name.slice(1) if name.startsWith "*"
      console.log("diff-branch-view:", name)
      args = ['diff', '--name-status', name]
      console.log("diff-branch-view:args", args)
      git.cmd(args, cwd: _repo.getWorkingDirectory())
      .then (data) ->
        diffStat = data
        console.log("diff-branch-view.then", data)
        diffFilePath = Path.join(_repo.getPath(), "atom_git_plus.diff")
        args = ['diff', '--color=never', _repo.branch, name, '--', '.']
        args.push '--word-diff' if atom.config.get 'git-plus.diffs.wordDiff'
        console.log("diff-branch-view:args", args)
        git.cmd(args, cwd: _repo.getWorkingDirectory())
        .then (data) -> prepFile((diffStat ? '') + data, diffFilePath)
        .then -> showFile diffFilePath
        .then (textEditor) ->
          disposables.add textEditor.onDidDestroy -> fs.unlink diffFilePath
        .catch (err) ->
          if err is nothingToShow
            notifier.addInfo err
          else
            notifier.addError err
