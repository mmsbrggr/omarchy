#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

run_node_test <<'JS'
const source = require('fs').readFileSync(path.join(root, 'shell/plugins/bar/widgets/Workspaces.qml'), 'utf8')

// Run the widget's own row logic against a fake Hyprland.
function body(pattern) {
  const match = source.match(pattern)
  if (!match) fail('Workspaces.qml row logic can be extracted', String(pattern))
  return match[1]
}
const workspaceIds = new Function('root', 'Hyprland', body(/\n  function workspaceIds\(\) \{([\s\S]*?)\n  \}/))
const countSetting = new Function('root', body(/\n  function countSetting\(\) \{([\s\S]*?)\n  \}/))
const shown = new Function('root', 'return ' + body(/\n  readonly property int shown: (.*)\n/))

// The row a bar on the monitor holding `block` shows, with `settings` on its
// shell.json entry and the workspaces in `used` holding windows on it.
function row(settings, block, used) {
  const root = {
    slots: 10,
    block: block,
    monitorName: 'DP-1',
    settings: settings,
    setting(name, fallback) {
      const value = this.settings[name]
      return value === undefined || value === null ? fallback : value
    },
    blockOf: id => Math.floor((id - 1) / 10),
  }
  root.countSetting = () => countSetting(root)
  root.shown = shown(root)
  const hyprland = { workspaces: { values: used.map(id => ({ id: id, monitor: { name: 'DP-1' } })) } }
  return workspaceIds(root, hyprland)
}

assertDeepEqual(row({}, 0, []), [1, 2, 3, 4, 5], 'five of the monitor\'s own show by default')
assertDeepEqual(row({ count: 3 }, 1, []), [11, 12, 13], 'count sets how many always show')
assertDeepEqual(row({ count: 3 }, 1, [15]), [11, 12, 13, 15], 'one in use past the count still shows')
assertDeepEqual(row({ count: 8 }, 0, []), [1, 2, 3, 4, 5, 6, 7, 8], 'count goes past five')
assertDeepEqual(row({ count: 12 }, 0, []), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 'count stops at the ten there are')
assertDeepEqual(row({ count: 0 }, 0, []), [1], 'the first always shows')
assertDeepEqual(row({ count: '3' }, 0, []), [1, 2, 3], 'a count set as text counts')
assertDeepEqual(row({ count: 'lots' }, 0, []), [1, 2, 3, 4, 5], 'a count that is not a number falls back to five')
assertDeepEqual(row({ count: 2 }, 0, [1, 23]), [1, 2, 23], 'a visiting workspace still follows the monitor\'s own')
JS
