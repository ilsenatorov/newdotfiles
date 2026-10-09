import { expect, test } from 'claude-code/testing'

import { fit } from './register'

test('fit keeps aspect inside the box', () => {
  expect(fit(800, 400, 74)).toEqual({ columns: 74, rows: 19 }) // wide: width-bound
  expect(fit(400, 1600, 74)).toEqual({ columns: 15, rows: 30 }) // tall: height-bound
  expect(fit(16, 16, 74)).toEqual({ columns: 2, rows: 1 }) // tiny icon stays tiny
})
