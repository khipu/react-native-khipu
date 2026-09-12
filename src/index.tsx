import Khipu from './NativeKhipu';
import type {
  KhipuColors,
  KhipuEvent,
  KhipuOptions as SpecKhipuOptions,
  KhipuResult,
  StartOperationOptions as SpecStartOperationOptions,
} from './NativeKhipu';

/**
 * Public options type. Same as the codegen spec except `theme`, which keeps its
 * literal union here: the spec must declare it `string` so RN 0.75.5's ObjC++
 * generator does not abort `pod install`. This is what the package exports, so
 * merchants keep autocompletion and compile-time checking.
 *
 * `src/__tests__/key-contract.test.ts` asserts both declarations stay in sync.
 */
export type KhipuOptions = Omit<SpecKhipuOptions, 'theme'> & {
  theme?: 'light' | 'dark' | 'system';
};

/**
 * Same reason: without this, `startOperation()` would still take the spec's
 * `KhipuOptions`, so the union would be exported but out of reach where it is
 * actually used.
 */
export type StartOperationOptions = Omit<
  SpecStartOperationOptions,
  'options'
> & {
  options?: KhipuOptions;
};

export type { KhipuColors, KhipuEvent, KhipuResult };

export function startOperation(
  options: StartOperationOptions
): Promise<KhipuResult> {
  return Khipu.startOperation(options);
}
