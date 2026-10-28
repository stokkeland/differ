;(function () {
  const restoreDiff = (diff) => {
    const lines = diff.split('\n').slice(3)
    const [fileA, fileB] = [[], []]
    for (const line of lines) {
      const [op, content] = [line[0], line.slice(1)]
      if (op === ' ' || op === '-') {
        fileA.push(content)
      }
      if (op === ' ' || op === '+') {
        fileB.push(content)
      }
    }
    return [fileA.join('\n'), fileB.join('\n')]
  }

  const diffStats = (diff) => {
    const lines = diff.split('\n').slice(3)
    let added = 0,
      removed = 0
    for (const line of lines) {
      if (line[0] === '+') added++
      else if (line[0] === '-') removed++
    }
    return [added, removed]
  }

  const escapeHtml = (s) =>
    s.replace(
      /[&<>"']/g,
      (c) =>
        ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]
    )

  const patchFilename = (title) => {
    const name = (title || '')
      .trim()
      .replace(/[^\w.-]+/g, '_')
      .replace(/^[_.]+|[_.]+$/g, '')
    return (name || 'diff') + '.patch'
  }

  const $ = document.querySelector.bind(document),
    MODAL_ID = 'modal-1',
    VIEW_MODE_EDIT = 'edit',
    VIEW_MODE_DIFF = 'diff'

  function App() {
    const _app = this

    this.ui = {
      compare: $('button.compare'),
      edit: $('button.edit'),
      download: $('button.download'),
      files: $('form#main .files'),
      fileA: $('#fileA'),
      fileB: $('#fileB'),
      form: $('form#main'),
      diff: $('.diff'),
      modalContent: $('#modal-1-content'),
      modalTitle: $('#modal-1-title'),
      title: $('input#title'),
    }

    this.state = {
      title: null,
      diff: null,
    }

    function compareHandler() {
      try {
        _app.compare()
        _app.render()
        _app.toggleView(VIEW_MODE_DIFF)
      } catch (e) {
        _app.error(e.message)
      }
    }

    this.ui.compare.onclick = compareHandler

    this.ui.edit.onclick = function () {
      _app.restore()
      _app.toggleView(VIEW_MODE_EDIT)
    }

    this.ui.download.onclick = function () {
      _app.download()
    }

    this.ui.form.onsubmit = function (e) {
      e.preventDefault()
      compareHandler()
    }
  }

  App.prototype.compare = function () {
    const fileA = this.ui.fileA.value
    const fileB = this.ui.fileB.value

    if (fileA == fileB) {
      const msg = `Files are ${fileA ? 'equal' : 'empty'}`
      throw Error(msg)
    }
    this.state.diff = Diff.createTwoFilesPatch(
      'fileA',
      'fileB',
      fileA,
      fileB,
      'old',
      'new',
      {
        context: Infinity,
      }
    )
    this.state.title = this.ui.title.value
  }

  App.prototype.render = function () {
    const configuration = {
      drawFileList: false,
      fileListToggle: false,
      fileListStartVisible: false,
      fileContentToggle: false,
      matching: 'words',
      outputFormat: 'side-by-side',
      synchronisedScroll: true,
      highlight: true,
      renderNothingWhenEmpty: true,
      stickyHeaders: false,
    }
    const diff2htmlUi = new Diff2HtmlUI(
      this.ui.diff,
      this.state.diff,
      configuration
    )
    diff2htmlUi.draw()
    diff2htmlUi.highlightCode()
    this.setDiffInfo()
  }

  App.prototype.setDiffInfo = function () {
    const header = $('.d2h-file-header')
    let html = `<div class="diff-info">`

    if (this.state.title) {
      html += `<div>Name: <strong>${escapeHtml(this.state.title)}</strong></div>`
    }

    html += `</div>`

    const [added, removed] = diffStats(this.state.diff)
    html +=
      '' +
      `<div class="diff-stats flex-row">` +
      `<span class="grow">➖ ${removed} removed</span>` +
      `<span class="grow">➕ ${added} added</span>` +
      `</div>`

    header.innerHTML = html
  }

  App.prototype.download = function () {
    const blob = new Blob([this.state.diff], { type: 'text/x-diff' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = patchFilename(this.state.title)
    document.body.appendChild(a)
    a.click()
    a.remove()
    setTimeout(() => URL.revokeObjectURL(url), 1000)
  }

  App.prototype.restore = function () {
    const [fileA, fileB] = restoreDiff(this.state.diff)
    this.ui.title.value = this.state.title
    this.ui.fileA.value = fileA
    this.ui.fileB.value = fileB
    this.state.diff = null
  }

  App.prototype.toggleView = function (mode) {
    if (mode == VIEW_MODE_DIFF) {
      this.ui.diff.show()
      this.ui.form.hide()
      this.ui.compare.hide()
      this.ui.edit.show()
      this.ui.download.show()
    } else if (mode === VIEW_MODE_EDIT) {
      this.ui.diff.hide()
      this.ui.form.show()
      this.ui.compare.show()
      this.ui.edit.hide()
      this.ui.download.hide()
      for (const editor of window.editors) {
        editor.updateLineNumbers()
      }
    }
  }

  App.prototype.modal = function (title, content) {
    if (!content) {
      throw Error('Empty content')
    }
    this.ui.modalTitle.innerHTML = title || ''
    this.ui.modalContent.innerHTML = content
    MicroModal.show(MODAL_ID)
  }

  App.prototype.error = function (msg) {
    this.modal('ERROR', escapeHtml(String(msg)))
  }

  App.prototype.init = function () {
    MicroModal.init()
    this.toggleView(VIEW_MODE_EDIT)
    return this
  }

  window.onload = function () {
    window.app = new App().init()
  }
})()
