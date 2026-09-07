import { readFileSync } from 'fs';
import { join } from 'path';

const root = join(__dirname, '..', '..');
const read = (p: string) => readFileSync(join(root, p), 'utf8');

/**
 * Android logic lives here ONCE. The two `KhipuModule.kt` files are module
 * declarations that delegate; if either started handling keys on its own the
 * extractors below would stop seeing them, so they are asserted key-free.
 */
const KOTLIN_IMPL = 'android/src/main/java/com/khipu/KhipuModuleImpl.kt';
const THIN_MODULES = [
  'android/src/newarch/java/com/khipu/KhipuModule.kt',
  'android/src/oldarch/java/com/khipu/KhipuModule.kt',
];

/** Factories: `matchAll` requires a global flag, which is stateful. */
const reKotlinRead = () =>
  /\.(?:getString|getBoolean|getMap|hasKey)\("(\w+)"\)/g;
const reKotlinWrite = () => /\.put(?:String|Array|Map)\("(\w+)"/g;

/** Keys declared in the codegen spec, per type block. */
function tsKeys(typeName: string): Set<string> {
  const src = read('src/NativeKhipu.ts');
  const block = new RegExp(
    `export type ${typeName} = \\{([\\s\\S]*?)\\n\\};`
  ).exec(src);
  if (!block)
    throw new Error(`Type ${typeName} not found in src/NativeKhipu.ts`);
  return new Set(
    [...(block[1] as string).matchAll(/^\s{2}(\w+)\??:/gm)].map(
      (m) => m[1] as string
    )
  );
}

/** Public types that `src/index.tsx` rebuilds as `Omit<SpecX, '...'> & { ... }`. */
type Redeclaration = {
  publicName: string;
  specName: string;
  omitted: Set<string>;
  added: Set<string>;
};

function publicRedeclarations(): Redeclaration[] {
  const src = read('src/index.tsx');
  const re =
    /export type (\w+) = Omit<\s*Spec(\w+)\s*,\s*([^>]+?)\s*>\s*&\s*\{([\s\S]*?)\n\};/g;
  return [...src.matchAll(re)].map((m) => ({
    publicName: m[1] as string,
    specName: m[2] as string,
    omitted: new Set(
      [...(m[3] as string).matchAll(/'(\w+)'/g)].map((x) => x[1] as string)
    ),
    added: new Set(
      [...(m[4] as string).matchAll(/^\s{2}(\w+)\??:/gm)].map(
        (x) => x[1] as string
      )
    ),
  }));
}

/** Keys Swift reads from the incoming NSDictionary. */
function swiftReadKeys(): Set<string> {
  const src = read('ios/Khipu.swift');
  return new Set([...src.matchAll(/\["(\w+)"\]/g)].map((m) => m[1] as string));
}

/** Keys Kotlin reads from the incoming ReadableMap. */
function kotlinReadKeys(): Set<string> {
  const src = read(KOTLIN_IMPL);
  return new Set([...src.matchAll(reKotlinRead())].map((m) => m[1] as string));
}

/** Keys Kotlin writes back. */
function kotlinWriteKeys(): Set<string> {
  const src = read(KOTLIN_IMPL);
  return new Set([...src.matchAll(reKotlinWrite())].map((m) => m[1] as string));
}

/** Keys Swift writes back. */
function swiftWriteKeys(): Set<string> {
  const src = read('ios/Khipu.swift');
  return new Set(
    [...src.matchAll(/^\s*"(\w+)":/gm)].map((m) => m[1] as string)
  );
}

const missing = (a: Set<string>, b: Set<string>) =>
  [...a].filter((k) => !b.has(k)).sort();

describe('the extractors still bite', () => {
  // Without these, a reformat that breaks a pattern collapses the sets to empty
  // and every comparison below passes trivially. A broken extractor looks
  // exactly like a healthy contract, which is the worst possible failure mode.
  it('finds the codegen spec types', () => {
    expect(tsKeys('KhipuOptions').size).toBeGreaterThanOrEqual(10);
    expect(tsKeys('KhipuColors').size).toBe(12);
    expect(tsKeys('KhipuResult').size).toBeGreaterThanOrEqual(7);
    expect(tsKeys('KhipuEvent').size).toBe(3);
    expect(tsKeys('StartOperationOptions').size).toBe(2);
  });

  it('finds keys read in Swift', () => {
    expect(swiftReadKeys().size).toBeGreaterThanOrEqual(20);
  });

  it('finds keys written in Swift', () => {
    expect(swiftWriteKeys().size).toBeGreaterThanOrEqual(7);
  });

  it('finds keys read in Kotlin', () => {
    expect(kotlinReadKeys().size).toBeGreaterThanOrEqual(20);
  });

  it('finds keys written in Kotlin', () => {
    expect(kotlinWriteKeys().size).toBeGreaterThanOrEqual(7);
  });

  it('finds the public redeclarations in src/index.tsx', () => {
    const rs = publicRedeclarations();
    expect(rs.map((r) => r.publicName).sort()).toEqual([
      'KhipuOptions',
      'StartOperationOptions',
    ]);
    for (const r of rs) {
      expect(r.omitted.size).toBeGreaterThanOrEqual(1);
      expect(r.added.size).toBeGreaterThanOrEqual(1);
    }
  });
});

describe('android: logic is not duplicated across source sets', () => {
  it('all three declarations exist and only the Impl holds logic', () => {
    expect(read(KOTLIN_IMPL)).toMatch(/fun startOperation\(/);
    expect(read(THIN_MODULES[0] as string)).toMatch(/:\s*NativeKhipuSpec\(/);
    expect(read(THIN_MODULES[1] as string)).toMatch(/@ReactMethod/);
    for (const p of THIN_MODULES) {
      expect(read(p)).toMatch(/impl\.startOperation\(/);
    }
  });

  it('the thin KhipuModule.kt files carry no key literals', () => {
    const keys = new Set([
      ...tsKeys('KhipuOptions'),
      ...tsKeys('KhipuColors'),
      ...tsKeys('KhipuResult'),
      ...tsKeys('KhipuEvent'),
      ...tsKeys('StartOperationOptions'),
    ]);
    for (const file of THIN_MODULES) {
      const src = read(file);
      const literals = [...src.matchAll(/"(\w+)"/g)]
        .map((m) => m[1] as string)
        .filter((k) => keys.has(k));
      expect({ file, literals }).toEqual({ file, literals: [] });
      expect([...src.matchAll(reKotlinRead())]).toEqual([]);
      expect([...src.matchAll(reKotlinWrite())]).toEqual([]);
    }
  });
});

describe('the public type does not drift from the spec', () => {
  // Two declarations of the same type in different files: if they drift
  // silently, merchants find out at runtime.
  it('each public redeclaration exposes exactly the spec keys', () => {
    for (const r of publicRedeclarations()) {
      const spec = tsKeys(r.specName);
      expect(missing(r.omitted, spec)).toEqual([]);
      expect(missing(r.added, spec)).toEqual([]);
      expect(missing(r.omitted, r.added)).toEqual([]);
      const publicKeys = new Set([
        ...[...spec].filter((k) => !r.omitted.has(k)),
        ...r.added,
      ]);
      expect([...publicKeys].sort()).toEqual([...spec].sort());
    }
  });

  it('the spec declares theme as string and the public type as a union', () => {
    // The other way around breaks `pod install` on RN 0.75.5.
    expect(read('src/NativeKhipu.ts')).toMatch(/^\s{2}theme\?: string;$/m);
    expect(read('src/NativeKhipu.ts')).not.toMatch(/theme\?: '/);
    expect(read('src/index.tsx')).toMatch(
      /theme\?: 'light' \| 'dark' \| 'system';/
    );
  });
});

describe('inbound contract: JS -> native', () => {
  const declared = new Set([
    ...tsKeys('KhipuOptions'),
    ...tsKeys('KhipuColors'),
  ]);

  it('Swift reads no key the spec does not declare', () => {
    const keys = swiftReadKeys();
    keys.delete('operationId');
    keys.delete('options');
    expect(missing(keys, declared)).toEqual([]);
  });

  it('Kotlin reads no key the spec does not declare', () => {
    const keys = kotlinReadKeys();
    keys.delete('operationId');
    keys.delete('options');
    expect(missing(keys, declared)).toEqual([]);
  });

  it('both platforms read exactly the same set', () => {
    expect(missing(swiftReadKeys(), kotlinReadKeys())).toEqual([]);
    expect(missing(kotlinReadKeys(), swiftReadKeys())).toEqual([]);
  });
});

describe('outbound contract: native -> JS', () => {
  const declared = new Set([...tsKeys('KhipuResult'), ...tsKeys('KhipuEvent')]);

  it('Swift writes no key the spec does not declare', () => {
    expect(missing(swiftWriteKeys(), declared)).toEqual([]);
  });

  it('Kotlin writes no key the spec does not declare', () => {
    expect(missing(kotlinWriteKeys(), declared)).toEqual([]);
  });

  it('the spec declares nothing neither platform delivers', () => {
    const written = new Set([...swiftWriteKeys(), ...kotlinWriteKeys()]);
    expect(missing(declared, written)).toEqual([]);
  });
});
