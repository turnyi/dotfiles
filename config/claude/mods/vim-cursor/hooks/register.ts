import type { Register } from 'claude-code'

const INSERT_LABEL = '-- INSERT --'
const SHAPE = { beam: '6', block: '2' } as const
const FIND_TTY =
  'p=$PPID; while [ "$p" -gt 1 ]; do t=$(ps -o tty= -p "$p" | tr -d " "); if [ -n "$t" ] && [ "$t" != "?" ]; then printf "/dev/%s" "$t"; exit 0; fi; p=$(ps -o ppid= -p "$p" | tr -d " "); done'
const WRITE_SHAPE = 'printf "\\033[%s q" "$1" > "$2"'

export const register: Register = on => {
  let tty: Promise<string> | undefined
  let shape = ''
  let hasVimMode = false

  on('ui.render', { component: 'PromptHint' }, ($, e, next) => {
    if (e.surface !== 'terminal') {
      return next(e)
    }

    const isInsert = e.props.hint.includes(INSERT_LABEL)
    hasVimMode ||= isInsert

    if (!hasVimMode) {
      return next(e)
    }

    const wanted = isInsert ? SHAPE.beam : SHAPE.block

    if (wanted !== shape) {
      shape = wanted
      tty ??= $.process.run(['sh', '-c', FIND_TTY]).then(found => found.stdout)
      void tty.then(path =>
        path === '' ? undefined : $.process.run(['sh', '-c', WRITE_SHAPE, 'sh', wanted, path]),
      )
    }

    return next(e)
  })
}
