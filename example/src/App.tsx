import * as React from 'react';

import { StyleSheet, View, Text } from 'react-native';
import {
  type KhipuOptions,
  type KhipuResult,
  startOperation,
} from 'react-native-khipu';

// Instrumentacion de medicion: la pantalla se pinta magenta solido justo antes
// de llamar a startOperation. Un PNG de color solido pesa muy poco y la UI de
// Khipu pesa mucho, asi que el salto de tamano entre capturas marca los dos
// instantes sin necesidad de mirar cada imagen.
const OPERATION_ID = 'a8klrrvmwtg9';

export default function App() {
  const [result, setResult] = React.useState<KhipuResult | undefined>();
  const [started, setStarted] = React.useState(false);

  React.useEffect(() => {
    const t = setTimeout(() => setStarted(true), 2000);
    return () => clearTimeout(t);
  }, []);

  React.useEffect(() => {
    if (!started) {
      return;
    }
    // Un frame despues de pintar el marcador, para que la captura lo alcance.
    const raf = requestAnimationFrame(() => {
      startOperation({
        operationId: OPERATION_ID,
        options: {
          title: 'Baseline',
          locale: 'es_CL',
          theme: 'light',
          showFooter: true,
          showPaymentDetails: true,
        } as KhipuOptions,
      }).then(setResult);
    });
    return () => cancelAnimationFrame(raf);
  }, [started]);

  if (started) {
    return <View style={styles.marker} />;
  }

  return (
    <View style={styles.container}>
      <Text>esperando</Text>
      <Text>result: {result?.result}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  marker: { flex: 1, backgroundColor: '#FF00FF' },
});
