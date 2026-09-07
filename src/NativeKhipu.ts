import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export type KhipuColors = {
  lightBackground?: string;
  lightOnBackground?: string;
  lightPrimary?: string;
  lightOnPrimary?: string;
  lightTopBarContainer?: string;
  lightOnTopBarContainer?: string;
  darkBackground?: string;
  darkOnBackground?: string;
  darkPrimary?: string;
  darkOnPrimary?: string;
  darkTopBarContainer?: string;
  darkOnTopBarContainer?: string;
};

export type KhipuOptions = {
  locale?: string;
  title?: string;
  titleImageUrl?: string;
  skipExitPage?: boolean;
  skipExitSuccessPage?: boolean;
  showFooter?: boolean;
  showMerchantLogo?: boolean;
  showPaymentDetails?: boolean;
  theme?: 'light' | 'dark' | 'system';
  colors?: KhipuColors;
};

export type StartOperationOptions = {
  operationId: string;
  options?: KhipuOptions;
};

export type KhipuEvent = {
  name: string;
  type: string;
  timestamp: string;
};

export type KhipuResult = {
  operationId: string;
  exitTitle: string;
  exitMessage: string;
  exitUrl?: string;
  result: string;
  failureReason?: string;
  continueUrl?: string;
  events: Array<KhipuEvent>;
};

export interface Spec extends TurboModule {
  startOperation(options: StartOperationOptions): Promise<KhipuResult>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('Khipu');
