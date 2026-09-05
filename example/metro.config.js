const path = require('path');
const { getDefaultConfig } = require('@react-native/metro-config');
const { withMetroConfig } = require('react-native-monorepo-config');

const root = path.resolve(__dirname, '..');

/**
 * Metro configuration
 * https://facebook.github.io/metro/docs/configuration
 *
 * Reemplaza la configuracion hecha a mano que teniamos, que dejo de funcionar
 * en React Native 0.87 por dos razones distintas:
 *
 * - `blacklistRE` ya no existe. Metro lo mantenia como alias deprecado hasta
 *   0.74 y no queda ni una referencia en 0.87, asi que la deduplicacion de
 *   peerDependencies se apagaba en silencio y terminabas con dos copias de
 *   React.
 * - `require('metro-config/src/defaults/exclusionList')` ahora falla con
 *   ERR_PACKAGE_PATH_NOT_EXPORTED. El archivo sigue existiendo en disco, pero
 *   el mapa `exports` de metro-config solo expone "." y "./private/*".
 *
 * `withMetroConfig` hace lo mismo que haciamos a mano (watchFolders sobre la
 * raiz, y bloquear las peerDependencies del root para que solo se cargue la
 * copia del example) y lo mantiene alguien mas.
 *
 * @type {import('metro-config').MetroConfig}
 */
module.exports = withMetroConfig(getDefaultConfig(__dirname), {
  root,
  dirname: __dirname,
});
