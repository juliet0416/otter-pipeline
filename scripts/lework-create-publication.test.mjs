import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { test } from 'node:test'
import { createLeWorkPublication } from './lework-create-publication.mjs'

test('publication uses only expected LeWork files and signed Windows bytes', () => {
  const root = mkdtempSync(join(tmpdir(), 'lework-publication-'))
  try {
    const inputs = [
      ['macos-arm64', 'LeWork-0.1.4-arm64-mac.zip'],
      ['macos-arm64', 'lework-0.1.4-arm64.dmg'],
      ['macos-x64', 'LeWork-0.1.4-mac.zip'],
      ['macos-x64', 'lework-0.1.4-x64.dmg'],
      ['windows-signed', 'lework-0.1.4-setup.exe'],
    ]
    for (const [folder, name] of inputs) {
      mkdirSync(join(root, folder), { recursive: true })
      writeFileSync(join(root, folder, name), `signed:${name}`)
    }
    const output = join(root, 'published')
    const entries = createLeWorkPublication(root, output, '0.1.4', '2026-10-12T00:00:00.000Z')
    assert.equal(entries.length, 5)
    const mac = readFileSync(join(output, 'latest-mac.yml'), 'utf8')
    const windows = readFileSync(join(output, 'latest.yml'), 'utf8')
    assert.match(mac, /lework-0\.1\.4-arm64\.dmg/)
    assert.match(mac, /lework-0\.1\.4-x64\.dmg/)
    assert.match(windows, /lework-0\.1\.4-setup\.exe/)
    assert.match(windows, /sha512: [A-Za-z0-9+/]+=*/)
    assert.doesNotMatch(mac + windows, /ottermind-|electron\/releases\/latest/)
  } finally {
    rmSync(root, { recursive: true, force: true })
  }
})
