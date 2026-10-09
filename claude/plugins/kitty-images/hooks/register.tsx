import type { Register } from 'claude-code'

type ImageOut = {
  type: 'image'
  file: {
    base64: string
    type: string
    dimensions?: { originalWidth?: number; originalHeight?: number; displayWidth?: number; displayHeight?: number }
  }
}

const CACHE = '/tmp/claude-kitty-images'

const isImage = (o: unknown): o is ImageOut =>
  (o as ImageOut | undefined)?.type === 'image' && typeof (o as ImageOut).file?.base64 === 'string'

// Box in cells keeping the picture's aspect; kitty cells are ~1:2 (w:h).
export const fit = (w: number, h: number, maxCols: number, maxRows = 30) => {
  let columns = Math.min(maxCols, Math.ceil(w / 8))
  let rows = Math.round((columns * h) / w / 2)
  if (rows > maxRows) {
    rows = maxRows
    columns = Math.round((rows * 2 * w) / h)
  }
  const clamp = (n: number) => Math.max(1, Math.min(255, n))
  return { columns: clamp(columns), rows: clamp(rows) }
}

export const register: Register = on => {
  // Image reads fold into "Read N files"; unfold that group so its rows draw.
  on('ui.render', { component: 'ToolGroup' }, ($, e, next) =>
    e.props.calls.some(c => c.tool === 'Read' && isImage(c.output))
      ? next({ ...e, props: { ...e.props, isExpanded: true } })
      : next(e),
  )

  on('ui.render', { component: 'ToolUse', props: { tool: 'Read' } }, async ($, e, next) => {
    const out = e.props.output
    const own = await next(e)
    if (e.surface !== 'terminal' || !isImage(out)) return own

    // The terminal decodes PNG only: anything else goes through ImageMagick once, cached per call.
    let source
    if (out.file.type === 'image/png') {
      source = { png: out.file.base64 }
    } else {
      const file = `${CACHE}/${e.props.tool_use_id}.png`
      if (!(await $.fs.exists(file))) {
        const ran = await $.process.run(
          ['sh', '-c', 'mkdir -p "$1" && base64 -d | magick -[0] "png:$2"', 'sh', CACHE, file],
          { stdin: out.file.base64 },
        )
        if (ran.exitCode !== 0) return own
      }
      source = { file, format: 'png' as const }
    }

    const d = out.file.dimensions
    // Not `h`: that name is the global JSX factory.
    const width = d?.displayWidth ?? d?.originalWidth ?? 512
    const height = d?.displayHeight ?? d?.originalHeight ?? 512
    const { columns, rows } = fit(width, height, Math.max(10, (e.viewport?.columns ?? 80) - 6))
    const { Box, Image } = $.ui.resolve(e)

    return (
      <Box flexDirection="column">
        {own}
        <Box paddingLeft={5}>
          <Image source={source} columns={columns} rows={rows} alt={`[image ${width}x${height}]`} />
        </Box>
      </Box>
    )
  })
}
