import * as React from 'react';

import { StyleSheet, View, Text, TextInput, Button, Modal } from 'react-native';
import {
  type KhipuOptions,
  type KhipuResult,
  startOperation,
} from 'react-native-khipu';

// Rellena esto localmente con un operationId real para que el harness arranque
// solo. Dejalo vacio antes de commitear: un operationId es el dato de una
// operacion, no configuracion del repo. Con el vacio, la app muestra el campo
// de texto y se comporta como el ejemplo de siempre.
const OPERATION_ID = '';

// Harness de verificacion del presenter.
//
// Dos cosas se miden aca, y ninguna requiere mirar capturas a ojo:
//
// 1. Sobrevive el modal del comercio? Se usa el <Modal> de react-native a
//    proposito, no un overlay con un View absoluto: <Modal> presenta un
//    UIViewController nativo (RCTModalHostView llama a present), que es lo que
//    deja al root presentando y reproduce el bug. Un View absoluto vive en la
//    misma jerarquia de vistas y NO lo reproduce.
//
// 2. Cuanto tarda en aparecer Khipu? La raiz se pinta magenta y cambia a negro
//    en el instante exacto de la llamada; el modal es una tarjeta verde encima.
//    Cada estado tiene un tamano de PNG bien distinto, asi que el instante de
//    cada transicion sale del tamano del archivo sin abrir ninguna captura.
export default function App() {
  const [result, setResult] = React.useState<KhipuResult | undefined>();
  const [id, setId] = React.useState<string>(OPERATION_ID);
  const [modalUp, setModalUp] = React.useState(false);
  const [started, setStarted] = React.useState(false);

  const launch = React.useCallback((operationId: string) => {
    console.log('HARNESS calling-start');
    startOperation({
      operationId,
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
  }, []);

  // Auto-arranque solo si hay un operationId compilado.
  React.useEffect(() => {
    if (!OPERATION_ID) {
      return;
    }
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
    const raf = requestAnimationFrame(() => launch(OPERATION_ID));
    return () => cancelAnimationFrame(raf);
  }, [started, launch]);

  if (OPERATION_ID) {
    return (
      <View style={started ? styles.rootStarted : styles.root}>
        <Modal
          visible={modalUp}
          transparent={true}
          animationType="none"
          onShow={onModalShown}
          // Si esto se dispara, el plugin cerro el modal del comercio.
          onDismiss={() => console.log('HARNESS modal-dismissed')}
          onRequestClose={() => {}}
        >
          <View style={styles.modalBackdrop}>
            <View style={styles.card} />
          </View>
        </Modal>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <TextInput
        style={styles.input}
        onChangeText={setId}
        value={id}
        placeholder="operationId"
        autoCapitalize="none"
        autoCorrect={false}
      />
      <Button title="Start" onPress={() => launch(id)} />
      <Text>result: {result?.result}</Text>
      <Text>exitTitle: {result?.exitTitle}</Text>
      <Text>exitMessage: {result?.exitMessage}</Text>
      <Text>exitUrl: {result?.exitUrl}</Text>
      <Text>failureReason: {result?.failureReason}</Text>
      <Text>continueUrl: {result?.continueUrl}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 24, gap: 8 },
  input: { borderWidth: 1, borderColor: '#999', padding: 10, borderRadius: 6 },
  root: { flex: 1, backgroundColor: '#FF00FF' },
  rootStarted: { flex: 1, backgroundColor: '#000000' },
  modalBackdrop: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  card: { width: 240, height: 240, backgroundColor: '#00C853' },
});
