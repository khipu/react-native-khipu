const reactNativeConfig = require('@react-native/eslint-config/flat');
const prettierConfig = require('eslint-config-prettier');
const prettierPlugin = require('eslint-plugin-prettier');

module.exports = [
  // node_modules ya lo ignora ESLint por defecto.
  { ignores: ['**/lib/', '**/build/'] },
  ...reactNativeConfig,
  // La config de RN aplica eslint-config-prettier al principio de su lista.
  // Aca va de nuevo al final, como el "prettier" que cerraba el extends de la
  // config vieja, para que apague las reglas de estilo que RN declara despues.
  prettierConfig,
  {
    plugins: { prettier: prettierPlugin },
    rules: {
      'prettier/prettier': [
        'error',
        {
          quoteProps: 'consistent',
          singleQuote: true,
          tabWidth: 2,
          trailingComma: 'es5',
          useTabs: false,
        },
      ],
    },
  },
];
