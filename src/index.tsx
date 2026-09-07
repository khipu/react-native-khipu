import Khipu from './NativeKhipu';
import type {
  KhipuColors,
  KhipuEvent,
  KhipuOptions,
  KhipuResult,
  StartOperationOptions,
} from './NativeKhipu';

export type {
  KhipuColors,
  KhipuEvent,
  KhipuOptions,
  KhipuResult,
  StartOperationOptions,
};

export function startOperation(
  options: StartOperationOptions
): Promise<KhipuResult> {
  return Khipu.startOperation(options);
}
