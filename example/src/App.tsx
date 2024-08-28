import * as React from 'react';

import { StyleSheet, View, Text, TextInput, Button } from 'react-native';
import {
  type KhipuColors,
  type KhipuOptions,
  type KhipuResult,
  startOperation,
} from 'react-native-khipu';

export default function App() {
  const [result, setResult] = React.useState<KhipuResult | undefined>();
  const [id, setId] = React.useState<string | null>(null);
  const start = function () {
    if (id !== null) {
      startOperation({
        operationId: id,
        options: {
          title: 'KhipuReactNative',
          titleImageUrl:
            'https://s3.amazonaws.com/static.khipu.com/buttons/2024/200x75-black.png',
          locale: 'es_CL',
          theme: 'light',
          skipExitPage: false,
          showFooter: false,
          showMerchantLogo: true,
          showPaymentDetails: true,
          colors: {
            // lightBackground: '#0000ff',
            // lightPrimary: '#ff00ff',
            // lightTopBarContainer: '#ffffff',
            // lightOnTopBarContainer: '#333333',
          } as KhipuColors,
        } as KhipuOptions,
      }).then(setResult);
    }
  };

  return (
    <View style={styles.container}>
      <TextInput
        id={'id'}
        onChangeText={setId}
        placeholder={'PaymentId'}
      ></TextInput>
      <Button title={'Start'} onPress={start}></Button>
      <Text>OperationId: {result?.operationId}</Text>
      <Text>Result: {result?.result}</Text>
      <Text>ExitTitle: {result?.exitTitle}</Text>
      <Text>ExitMessage: {result?.exitMessage}</Text>
      <Text>ExitUrl: {result?.exitUrl}</Text>
      <Text>FailureReason: {result?.failureReason}</Text>
      <Text>ContinueUrl: {result?.continueUrl}</Text>
      <Text>
        Events:
        {result?.events.map((e) => {
          return `${e.name} (${e.type}) : ${e.timestamp}`;
        })}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
