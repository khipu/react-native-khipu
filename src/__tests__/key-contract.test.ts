import { readFileSync } from 'fs';
import { join } from 'path';

const root = join(__dirname, '..', '..');
const read = (p: string) => readFileSync(join(root, p), 'utf8');

/** Claves declaradas en el spec de codegen, por bloque de tipo. */
function tsKeys(typeName: string): Set<string> {
  const src = read('src/NativeKhipu.ts');
  const block = new RegExp(
    `export type ${typeName} = \\{([\\s\\S]*?)\\n\\};`
  ).exec(src);
  if (!block)
    throw new Error(`No se encontro el tipo ${typeName} en src/NativeKhipu.ts`);
  return new Set(
    [...(block[1] as string).matchAll(/^\s{2}(\w+)\??:/gm)].map(
      (m) => m[1] as string
    )
  );
}

/** Claves que Swift lee del NSDictionary entrante. */
function swiftReadKeys(): Set<string> {
  const src = read('ios/Khipu.swift');
  return new Set([...src.matchAll(/\["(\w+)"\]/g)].map((m) => m[1] as string));
}

/** Claves que Kotlin lee del ReadableMap entrante. */
function kotlinReadKeys(): Set<string> {
  const src = read('android/src/main/java/com/khipu/KhipuModule.kt');
  return new Set(
    [
      ...src.matchAll(/\.(?:getString|getBoolean|getMap|hasKey)\("(\w+)"\)/g),
    ].map((m) => m[1] as string)
  );
}

/** Claves que Kotlin escribe en el mapa de vuelta. */
function kotlinWriteKeys(): Set<string> {
  const src = read('android/src/main/java/com/khipu/KhipuModule.kt');
  return new Set(
    [...src.matchAll(/\.put(?:String|Array|Map)\("(\w+)"/g)].map(
      (m) => m[1] as string
    )
  );
}

/** Claves que Swift escribe en el diccionario de vuelta. */
function swiftWriteKeys(): Set<string> {
  const src = read('ios/Khipu.swift');
  return new Set(
    [...src.matchAll(/^\s*"(\w+)":/gm)].map((m) => m[1] as string)
  );
}

const missing = (a: Set<string>, b: Set<string>) =>
  [...a].filter((k) => !b.has(k)).sort();

describe('el extractor sigue mordiendo', () => {
  // Sin estos, un reformateo que rompa un patron colapsa los conjuntos a vacio
  // y todas las comparaciones de abajo pasan trivialmente. Un extractor roto se
  // ve identico a un contrato sano, que es el peor modo de falla posible.
  it('encuentra los tipos del spec de codegen', () => {
    expect(tsKeys('KhipuOptions').size).toBeGreaterThanOrEqual(10);
    expect(tsKeys('KhipuColors').size).toBe(12);
    expect(tsKeys('KhipuResult').size).toBeGreaterThanOrEqual(7);
    expect(tsKeys('KhipuEvent').size).toBe(3);
  });

  it('encuentra claves leidas en Swift', () => {
    expect(swiftReadKeys().size).toBeGreaterThanOrEqual(20);
  });

  it('encuentra claves escritas en Swift', () => {
    expect(swiftWriteKeys().size).toBeGreaterThanOrEqual(7);
  });

  it('encuentra claves leidas en Kotlin', () => {
    expect(kotlinReadKeys().size).toBeGreaterThanOrEqual(20);
  });

  it('encuentra claves escritas en Kotlin', () => {
    expect(kotlinWriteKeys().size).toBeGreaterThanOrEqual(7);
  });
});

describe('contrato de entrada: JS -> nativo', () => {
  const declared = new Set([
    ...tsKeys('KhipuOptions'),
    ...tsKeys('KhipuColors'),
  ]);

  it('Swift no lee ninguna clave que el spec no declare', () => {
    const read = swiftReadKeys();
    read.delete('operationId');
    read.delete('options');
    expect(missing(read, declared)).toEqual([]);
  });

  it('Kotlin no lee ninguna clave que el spec no declare', () => {
    const read = kotlinReadKeys();
    read.delete('operationId');
    read.delete('options');
    expect(missing(read, declared)).toEqual([]);
  });

  it('las dos plataformas leen exactamente el mismo conjunto', () => {
    expect(missing(swiftReadKeys(), kotlinReadKeys())).toEqual([]);
    expect(missing(kotlinReadKeys(), swiftReadKeys())).toEqual([]);
  });
});

describe('contrato de salida: nativo -> JS', () => {
  const declared = new Set([...tsKeys('KhipuResult'), ...tsKeys('KhipuEvent')]);

  it('Swift no escribe ninguna clave que el spec no declare', () => {
    expect(missing(swiftWriteKeys(), declared)).toEqual([]);
  });

  it('Kotlin no escribe ninguna clave que el spec no declare', () => {
    expect(missing(kotlinWriteKeys(), declared)).toEqual([]);
  });

  it('el spec no declara nada que ninguna plataforma entregue', () => {
    const written = new Set([...swiftWriteKeys(), ...kotlinWriteKeys()]);
    expect(missing(declared, written)).toEqual([]);
  });
});
