import { createHash } from 'node:crypto'
import { copyFileSync, existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const versionPattern = /^\d+\.\d+\.\d+$/

const sha512 = (file) => createHash('sha512').update(readFileSync(file)).digest('base64')

function fileEntry(filePath, name) {
  if (!existsSync(filePath)) throw new Error(`Missing signed LeWork artifact: ${filePath}`)
  return { name, sha512: sha512(filePath), size: statSync(filePath).size }
}

function renderManifest(version, entries, defaultEntry, releaseDate) {
  return [
    `version: ${version}`,
    'files:',
    ...entries.flatMap(({ name, sha512: digest, size }) => [
      `  - url: ${name}`,
      `    sha512: ${digest}`,
      `    size: ${size}`,
    ]),
    `path: ${defaultEntry.name}`,
    `sha512: ${defaultEntry.sha512}`,
    `releaseDate: '${releaseDate}'`,
    '',
  ].join('\n')
}

/** Flatten the three verified CI artifacts and generate manifests from the signed bytes. */
export function createLeWorkPublication(root, output, version, releaseDate = new Date().toISOString()) {
  if (!versionPattern.test(version)) throw new Error(`Invalid LeWork version: ${version}`)
  mkdirSync(output, { recursive: true })

  const expected = [
    ['macos-arm64', `LeWork-${version}-arm64-mac.zip`],
    ['macos-arm64', `lework-${version}-arm64.dmg`],
    ['macos-x64', `LeWork-${version}-x64-mac.zip`],
    ['macos-x64', `lework-${version}-x64.dmg`],
    ['windows-signed', `lework-${version}-setup.exe`],
  ]
  const entries = expected.map(([folder, name]) => {
    const source = join(root, folder, name)
    const entry = fileEntry(source, name)
    copyFileSync(source, join(output, name))
    return entry
  })
  const macEntries = entries.slice(0, 4)
  const windowsEntries = entries.slice(4)
  writeFileSync(join(output, 'latest-mac.yml'), renderManifest(version, macEntries, macEntries[0], releaseDate))
  writeFileSync(join(output, 'latest.yml'), renderManifest(version, windowsEntries, windowsEntries[0], releaseDate))
  return entries
}

if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  const [root, output, version] = process.argv.slice(2)
  if (!root || !output || !version) {
    console.error('Usage: node scripts/lework-create-publication.mjs <artifact-root> <output-dir> <version>')
    process.exit(2)
  }
  const entries = createLeWorkPublication(root, output, version)
  for (const entry of entries) console.log(`${entry.name} ${entry.size} bytes`)
}
