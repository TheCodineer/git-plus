git = require '../git'
OutputViewManager = require '../output-view-manager'
notifier = require '../notifier'
BranchListView = require './branch-list-view'

branchFilter = (item) ->
  item isnt '' and item.indexOf('origin/HEAD') < 0 and item.indexOf(@remote + '/') == 0
module.exports =
  # Extension of BranchListView
  # Takes the name of the remote to pull from
  class PullBranchListView extends BranchListView
    initialize: (@repo, @data, @remote, @extraArgs) ->
      super
      @result = new Promise (resolve, reject) =>
        @resolve = resolve
        @reject = reject

    parseData: ->
      @currentBranchString = '== Current =='
      currentBranch =
        name: @currentBranchString
      items = @data.split("\n").map (item) -> item.replace(/\s/g, '')
      branches = items.filter(branchFilter.bind(@)).map (item) -> {name: item}
      if branches.length is 1
        @confirmed branches[0]
      else
        @setItems [currentBranch].concat branches
      @focusFilterEditor()

    confirmed: ({name}) ->
      if name is @currentBranchString
        @pull()
      else
        @pull name.substring(name.indexOf('/') + 1)
      @cancel()

    pull: (remoteBranch='') ->
      view = OutputViewManager.create()
      startMessage = notifier.addInfo "Pulling...", dismissable: true
      args = ['pull'].concat(@extraArgs, @remote, remoteBranch).filter((arg) -> arg isnt '')
      git.cmd(args, cwd: @repo.getWorkingDirectory(), {color: true})
      .then (data) =>
        @resolve remoteBranch
        view.setContent(data).finish()
        startMessage.dismiss()
        git.refresh @repo
      .catch (error) =>
        ## Should @result be rejected for those depending on this view?
        # @reject()
        view.setContent(error).finish()
        startMessage.dismiss()
