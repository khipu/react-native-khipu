import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-khipu' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const Khipu = NativeModules.Khipu
  ? NativeModules.Khipu
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export function startOperation(
  options: StartOperationOptions
): Promise<KhipuResult> {
  return Khipu.startOperation(options);
}

export interface StartOperationOptions {
  operationId: string;
  options: KhipuOptions;
}

export interface KhipuOptions {
  locale: string | undefined;
  title: string | undefined;
  titleImageUrl: string | undefined;
  skipExitPage: boolean | undefined;
  showFooter: boolean | undefined;
  showMerchantLogo: boolean | undefined;
  showPaymentDetails: boolean | undefined;
  theme: 'light' | 'dark' | 'system' | undefined;
  colors: KhipuColors | undefined;
}

export interface KhipuColors {
  lightBackground: string | undefined;
  lightOnBackground: string | undefined;
  lightPrimary: string | undefined;
  lightOnPrimary: string | undefined;
  lightTopBarContainer: string | undefined;
  lightOnTopBarContainer: string | undefined;
  darkBackground: string | undefined;
  darkOnBackground: string | undefined;
  darkPrimary: string | undefined;
  darkOnPrimary: string | undefined;
  darkTopBarContainer: string | undefined;
  darkOnTopBarContainer: string | undefined;
}

export interface KhipuResult {
  operationId: string;
  exitTitle: string;
  exitMessage: string;
  exitUrl: string;
  result: 'OK' | 'ERROR' | 'WARNING' | 'CONTINUE';
  failureReason: string | undefined;
  continueUrl: string | undefined;
  events: KhipuEvent[];
}

export interface KhipuEvent {
  name: string;
  timestamp: string;
  type: string;
}
