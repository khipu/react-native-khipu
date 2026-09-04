import * as React from 'react';

import { StyleSheet, View, Text, Modal } from 'react-native';
import {
  type KhipuOptions,
  type KhipuResult,
  startOperation,
} from 'react-native-khipu';

// Harness de verificación del presenter.
//
// Dos cosas se miden acá, y ninguna requiere mirar capturas a ojo:
//
// 1. ¿Sobrevive el modal del comercio? La <Modal> de React Native dispara
//    onDismiss en iOS cuando algo la cierra. Si el plugin la cierra para
//    presentar Khipu, ese evento se dispara y queda en el log de Metro. Es la
//    señal exacta del bug, sin ambigüedad.
//
// 2. ¿Cuánto tarda en aparecer Khipu? La vista raíz se pinta magenta sólido y
//    el modal es una tarjeta verde encima. Los tres estados posibles (magenta
//    con tarjeta / magenta sola / UI de Khipu) tienen tamaños de PNG bien
//    distintos, así que el instante de cada transición sale del tamaño del
//    archivo.
const OPERATION_ID = 'a8klrrvmwtg9';

export default function App() {
  const [result, setResult] = React.useState<KhipuResult | undefined>();
  const [modalUp, setModalUp] = React.useState(false);
  const [started, setStarted] = React.useState(false);
  const [modalKilled, setModalKilled] = React.useState(false);

  React.useEffect(() => {
    const t = setTimeout(() => setModalUp(true), 1500);
    return () => clearTimeout(t);
  }, []);

  const onModalShown = React.useCallback(() => {
    console.log('HARNESS modal-shown');
    setTimeout(() => setStarted(true), 1500);
  }, []);

  React.useEffect(() => {
    if (!started) {
      return;
    }
    const raf = requestAnimationFrame(() => {
      console.log('HARNESS calling-start');
      startOperation({
        operationId: OPERATION_ID,
        options: {
          title: 'Harness',
          locale: 'es_CL',
          theme: 'light',
          showFooter: true,
          showPaymentDetails: true,
        } as KhipuOptions,
      })
        .then((r) => {
          console.log('HARNESS resolved', r.result);
          setResult(r);
        })
        .catch((e) => console.log('HARNESS rejected', String(e)));
    });
    return () => cancelAnimationFrame(raf);
  }, [started]);

  return (
    <View style={started ? styles.rootStarted : styles.root}>
      <Text style={styles.hidden}>{result?.result ?? ''}</Text>
      <Text style={styles.hidden}>{modalKilled ? 'KILLED' : 'ALIVE'}</Text>
      <Modal
        visible={modalUp}
        transparent={true}
        animationType="none"
        onShow={onModalShown}
        onDismiss={() => {
          // Si esto se dispara, el plugin cerró el modal del comercio.
          console.log('HARNESS modal-dismissed');
          setModalKilled(true);
        }}
        onRequestClose={() => {}}
      >
        <View style={styles.modalBackdrop}>
          <View style={styles.card} />
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#FF00FF' },
  rootStarted: { flex: 1, backgroundColor: '#000000' },
  hidden: { opacity: 0, height: 1 },
  modalBackdrop: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  card: { width: 240, height: 240, backgroundColor: '#00C853' },
});
