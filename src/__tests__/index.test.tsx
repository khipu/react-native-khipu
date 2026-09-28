import type { Spec } from '../NativeKhipu';
import type { KhipuResult, StartOperationOptions } from '../index';

/**
 * `NativeKhipu.ts` resolves the native module at import time, with
 * `TurboModuleRegistry.getEnforcing('Khipu')`. So the fake has to be in place
 * before `../index` is required, and each test needs its own module registry:
 * `jest.isolateModules` gives it a fresh `react-native` and a fresh import.
 */
function loadWith(native: Spec) {
  let lib!: typeof import('../index');
  let getEnforcing!: jest.SpyInstance;
  jest.isolateModules(() => {
    const { TurboModuleRegistry } = require('react-native');
    getEnforcing = jest
      .spyOn(TurboModuleRegistry, 'getEnforcing')
      .mockReturnValue(native);
    lib = require('../index');
  });
  return { lib, getEnforcing };
}

const options: StartOperationOptions = {
  operationId: 'op-123',
  options: {
    locale: 'es_CL',
    theme: 'dark',
    skipExitPage: true,
    colors: { lightPrimary: '#8347AD', darkPrimary: '#3CB4E5' },
  },
};

const result: KhipuResult = {
  operationId: 'op-123',
  exitTitle: 'Pago realizado',
  exitMessage: 'Tu pago fue recibido',
  exitUrl: null,
  result: 'OK',
  failureReason: null,
  continueUrl: null,
  events: [{ name: 'operationStarted', type: 'info', timestamp: '0' }],
};

afterEach(() => {
  jest.restoreAllMocks();
});

describe('startOperation', () => {
  it('hands the options to the native module unchanged', async () => {
    const startOperation = jest.fn().mockResolvedValue(result);
    const { lib } = loadWith({ startOperation });

    await lib.startOperation(options);

    expect(startOperation).toHaveBeenCalledTimes(1);
    expect(startOperation.mock.calls[0][0]).toStrictEqual(options);
  });

  it('resolves with what the native module resolves, nulls included', async () => {
    // Both platforms emit null rather than omitting these keys, and the public
    // type says so: a merchant testing `=== undefined` must not be surprised.
    const { lib } = loadWith({
      startOperation: jest.fn().mockResolvedValue(result),
    });

    const resolved = await lib.startOperation(options);

    expect(resolved).toStrictEqual(result);
    expect(resolved.exitUrl).toBeNull();
    expect(resolved.failureReason).toBeNull();
    expect(resolved.continueUrl).toBeNull();
  });

  it('rejects with what the native module rejects', async () => {
    const error = new Error('E_OPERATION_FAILED');
    const { lib } = loadWith({
      startOperation: jest.fn().mockRejectedValue(error),
    });

    await expect(lib.startOperation(options)).rejects.toBe(error);
  });
});

describe('native module lookup', () => {
  it('asks for the module registered as "Khipu"', () => {
    const { getEnforcing } = loadWith({
      startOperation: jest.fn().mockResolvedValue(result),
    });

    expect(getEnforcing).toHaveBeenCalledWith('Khipu');
  });

  it('fails at import when the native module is not linked', () => {
    // `getEnforcing`, unlike `get`, throws. A merchant who skipped `pod install`
    // or a native rebuild gets an error naming the module at import, instead of
    // `startOperation is not a function` in the middle of a payment.
    expect(() =>
      jest.isolateModules(() => {
        require('../index');
      })
    ).toThrow(/'Khipu' could not be found/);
  });
});
